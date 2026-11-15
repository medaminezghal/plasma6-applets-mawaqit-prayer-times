.pragma library

/*
 * Mawaqit Prayer Times - core logic (v0.2.0)
 */

var BASE = "https://mawaqit.net";

/* ---------------- confData extraction (brace-balanced) ---------------- */

function extractConfData(html) {
    var declMatch = html.match(/(?:var|let|const)\s+confData\s*=/);
    if (!declMatch) {
        return null;
    }
    var start = html.indexOf("{", declMatch.index);
    if (start < 0) {
        return null;
    }
    var depth = 0, inString = false, quote = "", escaped = false;
    for (var i = start; i < html.length; i++) {
        var c = html[i];
        if (inString) {
            if (escaped) escaped = false;
            else if (c === "\\") escaped = true;
            else if (c === quote) inString = false;
        } else {
            if (c === '"' || c === "'") { inString = true; quote = c; }
            else if (c === "{") depth++;
            else if (c === "}") {
                depth--;
                if (depth === 0) return html.substring(start, i + 1);
            }
        }
    }
    return null;
}

/** Mosque display name from the page <title>: "Name | Mawaqit - ..." */
function extractTitle(html) {
    var m = html.match(/<title>\s*([^<|]+?)\s*\|/i);
    return m ? m[1].trim() : "";
}

/* ---------------------------- hidden word ----------------------------- *
 * The widget never shows the name "Israel", in any script, whatever
 * Mawaqit's data holds: mosque names, addresses and cities, slugs and the
 * messages built from them all go through hideWord() or displaySlug()
 * before they reach the screen. In the finder its mosques are listed under
 * Palestine (see countries.js).
 * --------------------------------------------------------------------- */

var HIDDEN_WORD = /isra[e\u00eb]l[a-z\u00e0-\u00ff]*|[\u0625\u0627]\u0633\u0631\u0627\u0626\u064a\u0644[\u0600-\u06ff]*|\u05d9\u05e9\u05e8\u05d0\u05dc[\u05d0-\u05ea]*/gi;
var SEPARATORS = "\\s,\u060c;\\-\u2013\u2014|/";

/** text without the hidden word, and without the separators it leaves. */
function hideWord(text) {
    var s = String(text === undefined || text === null ? "" : text);
    HIDDEN_WORD.lastIndex = 0;
    if (!HIDDEN_WORD.test(s)) return s;
    HIDDEN_WORD.lastIndex = 0;
    s = s.replace(HIDDEN_WORD, "\u0000");
    // A separator next to a removed word goes with it ("Hura, X" stays,
    // "X, <word>" and "<word> - X" lose theirs), then empty brackets
    s = s.replace(new RegExp("[" + SEPARATORS + "]*\u0000[" + SEPARATORS + "]*", "g"), function (m, offset, all) {
        var before = all.substring(0, offset).trim();
        var after = all.substring(offset + m.length).trim();
        if (before === "" || after === "") return "";
        var sep = /[,\u060c]/.exec(m);
        return sep ? sep[0] + " " : " ";
    });
    s = s.replace(/\(\s*\)|\[\s*\]/g, "").replace(/\s{2,}/g, " ");
    return s.trim();
}

/** A slug as shown in the settings: without the segments of the hidden
 * word. The configured slug keeps them, since mawaqit.net needs them. */
function displaySlug(slug) {
    var parts = String(slug || "").split("-");
    var kept = [];
    for (var i = 0; i < parts.length; i++) {
        HIDDEN_WORD.lastIndex = 0;
        if (!HIDDEN_WORD.test(parts[i])) kept.push(parts[i]);
    }
    HIDDEN_WORD.lastIndex = 0;
    return kept.join("-");
}

/**
 * Keep only the essential mosque name. Admins often pack the address into
 * the name field ("NAME — street city country"); cut at the first spaced
 * dash or em/en dash. Bare hyphens inside words (Al-Hidaya) are preserved.
 * A name that is a slug (the fallback before the real name is known) is
 * shown like the settings show it.
 */
function cleanMosqueName(name) {
    var n = /^[a-z0-9]+(?:-[a-z0-9]+)+$/.test(name) ? displaySlug(name) : hideWord(name);
    var cut = n.split(/\s+[\u2014\u2013]\s*|\s+-\s+/)[0].trim();
    return cut.length > 0 ? cut : n.trim();
}

/* -------------------------- mosque page ------------------------------ *
 * A mosque has two public pages carrying the same confData: the regular
 * one, /<lang>/<slug>, and /<lang>/id/<number>, which is the link the
 * Mawaqit app shares. The configured mosque (mosqueSlug) holds either a
 * slug or "id/<number>"; mosqueId() tells them apart and fetchConf()
 * picks the matching fetch.
 * --------------------------------------------------------------------- */

/** The mosque's number when mosque is "id/<number>", otherwise "". */
function mosqueId(mosque) {
    var m = /^id\/(\d+)$/.exec(mosque);
    return m ? m[1] : "";
}

function fetchConf(mosque, onSuccess, onError) {
    var id = mosqueId(mosque);
    return id !== "" ? fetchConfById(id, onSuccess, onError)
                     : fetchConfBySlug(mosque, onSuccess, onError);
}

function fetchConfBySlug(slug, onSuccess, onError) {
    return requestConf("/fr/" + encodeURIComponent(slug), slug,
                       "Mosque “" + displaySlug(slug) + "” not found on mawaqit.net",
                       onSuccess, onError);
}

function fetchConfById(id, onSuccess, onError) {
    return requestConf("/fr/id/" + id, id,
                       "No mosque with ID " + id + " on mawaqit.net",
                       onSuccess, onError);
}

/* fallbackName is the name used when the page has none; notFound is the
 * message for a 404. */
function requestConf(path, fallbackName, notFound, onSuccess, onError) {
    var xhr = new XMLHttpRequest();
    xhr.open("GET", BASE + path);
    xhr.onreadystatechange = function () {
        if (xhr.readyState !== XMLHttpRequest.DONE) return;
        if (xhr.status === 200) {
            var raw = extractConfData(xhr.responseText);
            if (!raw) {
                onError("confData not found on page (Mawaqit may have changed their layout)");
                return;
            }
            try {
                var conf = JSON.parse(raw);
                onSuccess({
                    name: cleanMosqueName(conf.name || conf.label
                                          || extractTitle(xhr.responseText) || fallbackName),
                    calendar: conf.calendar || null,
                    iqamaCalendar: conf.iqamaCalendar || null,
                    times: conf.times || null,
                    shuruq: conf.shuruq || null,
                    jumua: conf.jumua || null,
                    hijriAdjustment: (typeof conf.hijriAdjustment === "number")
                                     ? conf.hijriAdjustment : 0,
                    hijriForce30: conf.hijriDateForceTo30 === true
                });
            } catch (e) {
                onError("Failed to parse confData JSON: " + e);
            }
        } else if (xhr.status === 404) {
            onError(notFound);
        } else if (xhr.status === 0) {
            // No HTTP status: the connection failed, or abort() was called
            // (QQmlXMLHttpRequest::abort dispatches the callback with the
            // state set to Done).
            onError("Could not reach mawaqit.net");
        } else {
            onError("HTTP " + xhr.status + " from mawaqit.net");
        }
    };
    xhr.send();
    // Returned so the caller can abort it: QML's XMLHttpRequest has no
    // timeout property, so the watchdog has to live on the caller's side.
    return xhr;
}

/* --------------------------- mosque finder ---------------------------- *
 * Mawaqit's keyword search (api/2.0/mosque/search) answers 401 without an
 * account token since 6 October 2026. The mosque map on mawaqit.net uses
 * another endpoint, api/2.0/mosque/map/<country code>, which still
 * answers without one: every mosque of a country on its map, with slug,
 * name, address, city, zipcode, lat and lng, unsorted and unpaged (about
 * 2,500 for Tunisia, 1.3 MB). So the finder downloads a country once and
 * searches and sorts it here. It may not list every mosque Mawaqit has,
 * and it may close like the search did, which is why the settings always
 * keep the link field and the web search next to it.
 * --------------------------------------------------------------------- */

// The endpoint itself is publicly cached for a day (max-age=86400)
var MAP_CACHE_MS = 24 * 60 * 60 * 1000;
// Country code -> { time, mosques }. A .pragma library is shared by the
// whole engine, so this outlives one opening of the settings.
var _mapCache = {};

/*
 * Text folded for matching: lowercase, without Latin accents or Arabic
 * diacritics and tatweel, with the Arabic letters people write
 * interchangeably made the same (أ إ آ ٱ -> ا, ة -> ه, ى ی -> ي, ک -> ك)
 * and punctuation turned into spaces. Padded with spaces, so " word"
 * finds a word start.
 */
function searchKey(text) {
    var s = String(text || "").toLowerCase();
    if (typeof s.normalize === "function") {
        s = s.normalize("NFD");
    }
    s = s.replace(/[̀-ًͯ-ٰٟـ]/g, "")
         .replace(/[آأإٱ]/g, "ا")
         .replace(/ة/g, "ه")
         .replace(/[ىی]/g, "ي")
         .replace(/ک/g, "ك")
         .replace(/[\s\-_.,;:!?'"`’‘“”()\[\]{}\/\\|+*&#@،؛؟·–—]+/g, " ");
    return " " + s.trim() + " ";
}

function _toMosque(it) {
    var address = hideWord(it.address).trim();
    var city = hideWord(it.city).trim();
    var place = [];
    if (address !== "") place.push(address);
    if (city !== "" && address.indexOf(city) === -1) place.push(city);
    var name = it.name ? hideWord(it.name) : "";
    if (name === "") name = displaySlug(it.slug);
    return {
        slug: String(it.slug),
        name: name,
        place: place.join(", "),
        lat: typeof it.lat === "number" ? it.lat : NaN,
        lon: typeof it.lng === "number" ? it.lng : NaN,
        nameKey: searchKey(name),
        // The slug is a Latin transliteration, so "sfax" also finds a
        // mosque whose name and city are only written in Arabic
        key: searchKey([name, address, city, it.zipcode,
                        displaySlug(it.slug)].join(" "))
    };
}

/**
 * The mosques of one or more map countries (ISO 3166 alpha-2 codes, see
 * Countries.mapCodes()), merged, from the cache when it is fresh.
 * onSuccess gets an array of mosques (see _toMosque), possibly empty; it
 * runs before this returns when the cache answers every code. Returns an
 * object whose abort() drops the download in progress, or null when
 * nothing was sent.
 */
function fetchCountryMosques(codes, onSuccess, onError) {
    var list = [].concat(codes);
    var merged = [];
    var seen = {};
    var current = null;
    var handle = { abort: function () { if (current !== null) current.abort(); } };
    var sent = false;
    function next(i) {
        if (i >= list.length) {
            onSuccess(merged);
            return;
        }
        var request = _fetchMapCode(list[i], function (mosques) {
            current = null;
            for (var j = 0; j < mosques.length; j++) {
                if (!seen[mosques[j].slug]) {
                    seen[mosques[j].slug] = true;
                    merged.push(mosques[j]);
                }
            }
            next(i + 1);
        }, function (err) {
            current = null;
            onError(err);
        });
        if (request !== null) {
            current = request;
            sent = true;
        }
    }
    next(0);
    return sent ? handle : null;
}

function _fetchMapCode(code, onSuccess, onError) {
    var cc = String(code).toUpperCase();
    var cached = _mapCache[cc];
    if (cached && Date.now() - cached.time < MAP_CACHE_MS) {
        onSuccess(cached.mosques);
        return null;
    }
    var xhr = new XMLHttpRequest();
    xhr.open("GET", BASE + "/api/2.0/mosque/map/" + encodeURIComponent(cc));
    xhr.setRequestHeader("Accept", "application/json");
    xhr.onreadystatechange = function () {
        if (xhr.readyState !== XMLHttpRequest.DONE) return;
        if (xhr.status === 0) {
            onError("could not reach mawaqit.net");
            return;
        }
        if (xhr.status !== 200) {
            console.log("[mawaqit] mosque map HTTP " + xhr.status);
            onError("HTTP " + xhr.status + " from mawaqit.net");
            return;
        }
        var arr;
        try {
            arr = JSON.parse(xhr.responseText);
        } catch (e) {
            arr = null;
        }
        if (!Array.isArray(arr)) {
            onError("unexpected response from mawaqit.net");
            return;
        }
        var mosques = [];
        for (var i = 0; i < arr.length; i++) {
            if (arr[i] && arr[i].slug) {
                mosques.push(_toMosque(arr[i]));
            }
        }
        _mapCache[cc] = { time: Date.now(), mosques: mosques };
        onSuccess(mosques);
    };
    xhr.send();
    return xhr;
}

/** Great-circle distance in kilometres. */
function distanceKm(lat1, lon1, lat2, lon2) {
    var rad = Math.PI / 180;
    var dLat = (lat2 - lat1) * rad;
    var dLon = (lon2 - lon1) * rad;
    var a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
          + Math.cos(lat1 * rad) * Math.cos(lat2 * rad)
          * Math.sin(dLon / 2) * Math.sin(dLon / 2);
    return 6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

/**
 * Search mosques (from fetchCountryMosques).
 * query   What the user typed; every word must appear in the name,
 *         address, city, zipcode or slug. Empty lists all of them, which
 *         only makes sense with an origin.
 * origin  { lat, lon } or null. With one, results carry their distance
 *         and the nearest come first among equally good matches.
 * limit   Most results returned.
 * Returns { results: [{ slug, name, place, distance }], total } where
 * distance is in km, or -1 without an origin, and total counts every
 * match, not only the ones returned.
 */
function findMosques(mosques, query, origin, limit) {
    var words = searchKey(query).trim();
    words = words === "" ? [] : words.split(" ");
    var hasOrigin = origin && !isNaN(origin.lat) && !isNaN(origin.lon);
    var found = [];
    for (var i = 0; i < mosques.length; i++) {
        var m = mosques[i];
        var ok = true;
        for (var w = 0; w < words.length && ok; w++) {
            ok = m.key.indexOf(words[w]) !== -1;
        }
        if (!ok) continue;
        // 0: the name starts with the first word, 1: a word of the name
        // does, 2: any other match
        var rank = 2;
        if (words.length > 0) {
            if (m.nameKey.indexOf(" " + words[0]) === 0) rank = 0;
            else if (m.nameKey.indexOf(" " + words[0]) > 0) rank = 1;
        }
        var d = (hasOrigin && !isNaN(m.lat) && !isNaN(m.lon))
                ? distanceKm(origin.lat, origin.lon, m.lat, m.lon) : -1;
        found.push({ m: m, rank: rank, distance: d });
    }
    found.sort(function (a, b) {
        if (a.rank !== b.rank) return a.rank - b.rank;
        if (a.distance !== b.distance) {
            // Unknown distances (-1) go last
            if (a.distance < 0) return 1;
            if (b.distance < 0) return -1;
            return a.distance - b.distance;
        }
        return a.m.name.localeCompare(b.m.name);
    });
    var results = [];
    for (var j = 0; j < found.length && j < limit; j++) {
        results.push({
            slug: found[j].m.slug,
            name: found[j].m.name,
            place: found[j].m.place,
            distance: found[j].distance
        });
    }
    return { results: results, total: found.length };
}

/**
 * Web search for a mosque's mawaqit.net page, for when the finder can't
 * help: the mosque isn't on the map, or the map endpoint is gone.
 * text     What the user typed in the finder, may be empty.
 * country  Name of the chosen country, may be empty.
 */
function webSearchUrl(text, country) {
    var q = "site:mawaqit.net";
    var t = String(text || "").trim();
    var c = String(country || "").trim();
    if (t !== "") q += " " + t;
    if (c !== "") q += " " + c;
    return "https://duckduckgo.com/?q=" + encodeURIComponent(q);
}

/* ------------------------------ location ------------------------------ *
 * Only for "Near me" in the settings. Each IP provider is tried in turn;
 * they give the location of the internet provider, which is usually right
 * about the country but often points to another city.
 * --------------------------------------------------------------------- */

var IP_PROVIDERS = [
    {
        url: "https://ipwho.is/",
        parse: function (j) {
            return (j.success !== false && typeof j.latitude === "number")
                ? { lat: j.latitude, lon: j.longitude, country: j.country_code || "" } : null;
        }
    },
    {
        url: "https://ipapi.co/json/",
        parse: function (j) {
            return (typeof j.latitude === "number")
                ? { lat: j.latitude, lon: j.longitude, country: j.country_code || "" } : null;
        }
    },
    {
        url: "http://ip-api.com/json",
        parse: function (j) {
            return (j.status === "success")
                ? { lat: j.lat, lon: j.lon, country: j.countryCode || "" } : null;
        }
    }
];

/* onSuccess gets { lat, lon, country } (country: alpha-2 code or ""). */
function ipLocate(onSuccess, onError, _index) {
    var index = _index || 0;
    if (index >= IP_PROVIDERS.length) {
        onError("all IP geolocation providers failed");
        return;
    }
    var provider = IP_PROVIDERS[index];
    var xhr = new XMLHttpRequest();
    xhr.open("GET", provider.url);
    xhr.setRequestHeader("Accept", "application/json");
    // Nominatim and ipapi.co refuse QML's default "Mozilla/5.0" agent
    xhr.setRequestHeader("User-Agent", APP_USER_AGENT);
    xhr.onreadystatechange = function () {
        if (xhr.readyState !== XMLHttpRequest.DONE) return;
        var next = function () { ipLocate(onSuccess, onError, index + 1); };
        if (xhr.status !== 200) {
            console.log("[mawaqit] ip provider " + provider.url + " HTTP " + xhr.status);
            next();
            return;
        }
        try {
            var loc = provider.parse(JSON.parse(xhr.responseText));
            if (loc) onSuccess(loc);
            else next();
        } catch (e) {
            console.log("[mawaqit] ip provider " + provider.url + " parse error");
            next();
        }
    };
    xhr.send();
}

/* The country (alpha-2 code) at a position, for a GeoClue fix, which
 * comes without one. */
function reverseCountry(lat, lon, onSuccess, onError) {
    var xhr = new XMLHttpRequest();
    xhr.open("GET", "https://nominatim.openstreetmap.org/reverse?format=jsonv2&zoom=3&lat="
             + lat + "&lon=" + lon);
    xhr.setRequestHeader("Accept", "application/json");
    xhr.setRequestHeader("User-Agent", APP_USER_AGENT);
    xhr.onreadystatechange = function () {
        if (xhr.readyState !== XMLHttpRequest.DONE) return;
        if (xhr.status !== 200) {
            onError("reverse geocoding failed (HTTP " + xhr.status + ")");
            return;
        }
        try {
            var a = JSON.parse(xhr.responseText).address || {};
            if (a.country_code) onSuccess(String(a.country_code).toUpperCase());
            else onError("no country in the reverse geocoding result");
        } catch (e) {
            onError("unexpected reverse geocoding response");
        }
    };
    xhr.send();
}

/* --------------------------- Hijri calendar --------------------------- *
 * Mawaqit renders its own Hijri date with the Kuwaiti arithmetic
 * algorithm: a 30-year cycle of 10631 days with mean 29.5-day months, so
 * odd months run 30 days and even months 29. It never consults an
 * observation-based calendar, which is exactly why every mosque page
 * carries a `hijriAdjustment` for the admin to correct it against the
 * local announcement.
 *
 * What follows is a port of that algorithm, taken from mawaqit.net's own
 * bundle. Matching it is not cosmetic: `hijriAdjustment` is calibrated by
 * the admin against what Mawaqit displays, so it only means anything when
 * applied to the same base calendar. The Umm al-Qura table this replaced
 * disagreed with the Kuwaiti algorithm on roughly 40% of days, which made
 * the cached adjustment worse than useless.
 * --------------------------------------------------------------------- */

var HIJRI_CYCLE_DAYS = 10631;              // days in the 30-year cycle
var HIJRI_MEAN_YEAR = HIJRI_CYCLE_DAYS / 30;
var HIJRI_EPOCH_JD = 1948084;              // julian day of 1 Muharram 1 AH

function _julianDay(d) {
    var day = d.getDate();
    var month = d.getMonth() + 1;
    var year = d.getFullYear();
    if (month < 3) {
        year -= 1;
        month += 12;
    }
    var century = Math.floor(year / 100);
    var gregorianOffset = year < 1583
                          ? 0 : 2 - century + Math.floor(century / 4);
    return Math.floor(365.25 * (year + 4716))
           + Math.floor(30.6001 * (month + 1))
           + day + gregorianOffset - 1524;
}

/* The bare arithmetic, with no adjustment and no force30 applied. */
function _kuwaitiHijri(d) {
    var days = _julianDay(d) - HIJRI_EPOCH_JD;
    var cycles = Math.floor(days / HIJRI_CYCLE_DAYS);
    days -= HIJRI_CYCLE_DAYS * cycles;

    var yearInCycle = Math.floor((days - 0.1335) / HIJRI_MEAN_YEAR);
    var year = 30 * cycles + yearInCycle;
    days -= Math.floor(yearInCycle * HIJRI_MEAN_YEAR + 0.1335);

    var month = Math.floor((days + 28.5001) / 29.5);
    if (month === 13) {
        month = 12;
    }
    return {
        year: year,
        month: month,
        day: days - Math.floor(29.5001 * month - 29)
    };
}

/**
 * date        Gregorian day to convert.
 * adjustment  The mosque's hijriAdjustment, in days.
 * force30     The mosque's hijriDateForceTo30 flag: the moon was not
 *             sighted, so the admin holds the running month at 30 days.
 */
function gregorianToHijri(date, adjustment, force30) {
    var d = new Date(date.getFullYear(), date.getMonth(), date.getDate());
    // setDate rather than adding 86400000 ms as Mawaqit does: a raw
    // millisecond offset can cross a DST boundary and land on the wrong
    // local day
    d.setDate(d.getDate() + (adjustment || 0));

    var h = _kuwaitiHijri(d);
    if (!force30) {
        return h;
    }

    // A month can only be held at 30 days if the arithmetic gave it 29,
    // so look at the arithmetic month that just ended. While we are still
    // inside a held 29-day month the displayed day is unchanged; once the
    // arithmetic rolls over, every day of the new month shifts back by one
    // so its day 1 becomes day 30 of the held month. Shifting the whole
    // month is what keeps the sequence continuous — the previous code
    // remapped only day 1, so the display skipped from 30 straight to 2.
    var endOfPrevMonth = new Date(d.getTime());
    endOfPrevMonth.setDate(endOfPrevMonth.getDate() - h.day);
    if (_kuwaitiHijri(endOfPrevMonth).day !== 29) {
        return h;
    }

    h.day -= 1;
    if (h.day === 0) {
        h.month -= 1;
        if (h.month === 0) {
            h.month = 12;
            h.year -= 1;
        }
        h.day = 30;
    }
    return h;
}

var HIJRI_MONTHS = {
    en: ["Muharram", "Safar", "Rabi\u02BB al-Awwal", "Rabi\u02BB al-Thani",
         "Jumada al-Ula", "Jumada al-Akhira", "Rajab", "Sha\u02BBban",
         "Ramadan", "Shawwal", "Dhu al-Qi\u02BBdah", "Dhu al-Hijjah"],
    ar: ["\u0645\u062D\u0631\u0645", "\u0635\u0641\u0631",
         "\u0631\u0628\u064A\u0639 \u0627\u0644\u0623\u0648\u0644",
         "\u0631\u0628\u064A\u0639 \u0627\u0644\u062B\u0627\u0646\u064A",
         "\u062C\u0645\u0627\u062F\u0649 \u0627\u0644\u0623\u0648\u0644\u0649",
         "\u062C\u0645\u0627\u062F\u0649 \u0627\u0644\u0622\u062E\u0631\u0629",
         "\u0631\u062C\u0628", "\u0634\u0639\u0628\u0627\u0646",
         "\u0631\u0645\u0636\u0627\u0646", "\u0634\u0648\u0627\u0644",
         "\u0630\u0648 \u0627\u0644\u0642\u0639\u062F\u0629",
         "\u0630\u0648 \u0627\u0644\u062D\u062C\u0629"],
    fr: ["Mouharram", "Safar", "Rabia al-Awwal", "Rabia ath-Thani",
         "Joumada al-Oula", "Joumada ath-Thania", "Rajab", "Chaabane",
         "Ramadan", "Chawwal", "Dhou al-Qi\u02BBda", "Dhou al-Hijja"]
};

function hijriMonthNames(langSetting) {
    var lang = langSetting;
    if (lang === "auto" || !HIJRI_MONTHS[lang]) {
        var sys = Qt.locale().name.substring(0, 2);
        lang = HIJRI_MONTHS[sys] ? sys : "en";
    }
    return HIJRI_MONTHS[lang];
}

/**
 * The same Hijri date as formatHijri, rendered as DD/MM/YYYY digits for
 * the panel strip, where the spelled-out month name is too wide.
 */
function formatHijriNumeric(date, adjustment, force30) {
    var h = gregorianToHijri(date, adjustment, force30);
    var dd = h.day < 10 ? "0" + h.day : "" + h.day;
    var mm = h.month < 10 ? "0" + h.month : "" + h.month;
    return dd + "/" + mm + "/" + h.year;
}

function formatHijri(date, adjustment, force30, langSetting) {
    var h = gregorianToHijri(date, adjustment, force30);
    var months = hijriMonthNames(langSetting);
    var isArabic = (langSetting === "ar")
        || (langSetting === "auto" && Qt.locale().name.substring(0, 2) === "ar");
    if (isArabic) {
        return h.day + " " + months[h.month - 1] + " " + h.year + " \u0647\u0640";
    }
    return h.day + " " + months[h.month - 1] + " " + h.year + " AH";
}

/* --------------------------- prayer helpers --------------------------- */

var PRAYER_NAMES = {
    en: ["Fajr", "Sunrise", "Dhuhr", "Asr", "Maghrib", "Isha"],
    ar: ["\u0627\u0644\u0641\u062C\u0631", "\u0627\u0644\u0634\u0631\u0648\u0642",
         "\u0627\u0644\u0638\u0647\u0631", "\u0627\u0644\u0639\u0635\u0631",
         "\u0627\u0644\u0645\u063A\u0631\u0628", "\u0627\u0644\u0639\u0634\u0627\u0621"],
    fr: ["Fajr", "Chourouq", "Dhohr", "Asr", "Maghreb", "Icha"]
};

/* Small UI strings that follow the prayer-name language setting rather
 * than the system locale (no gettext catalogs are shipped). */
var UI_STRINGS = {
    en: { inPrefix: "in",   tomorrow: "tomorrow",
          h: "h", m: "m", s: "s", am: "AM", pm: "PM" },
    // \u0635 / \u0645 (sabahan / masa'an): CLDR's Arabic day periods
    ar: { inPrefix: "\u0628\u0639\u062F", tomorrow: "\u063A\u062F\u064B\u0627",
          h: "\u0633", m: "\u062F", s: "\u062B", am: "\u0635", pm: "\u0645" },
    fr: { inPrefix: "dans", tomorrow: "demain",
          h: "h", m: "min", s: "s", am: "AM", pm: "PM" }
};

function uiString(key, langSetting) {
    var lang = langSetting;
    if (lang === "auto" || !UI_STRINGS[lang]) {
        var sys = Qt.locale().name.substring(0, 2);
        lang = UI_STRINGS[sys] ? sys : "en";
    }
    return UI_STRINGS[lang][key];
}

/** "in 1:52" / "\u0628\u0639\u062F 1:52" / "dans 1:52" */
function inCountdown(text, langSetting) {
    return uiString("inPrefix", langSetting) + " " + text;
}

function isArabic(langSetting) {
    if (langSetting === "ar") {
        return true;
    }
    if (langSetting === "auto") {
        return Qt.locale().name.substring(0, 2) === "ar";
    }
    return false;
}

function prayerNames(langSetting) {
    var lang = langSetting;
    if (lang === "auto" || !PRAYER_NAMES[lang]) {
        var sys = Qt.locale().name.substring(0, 2);
        lang = PRAYER_NAMES[sys] ? sys : "en";
    }
    return PRAYER_NAMES[lang];
}

/* A calendar day is [fajr, shuruq, dhuhr, asr, maghrib, isha], except at
 * mosques that display Imsak (displayingSabahImsak), whose days carry it
 * first: [imsak, fajr, shuruq, dhuhr, asr, maghrib, isha]. The widget
 * doesn't show Imsak, so drop it. The length is checked per day rather
 * than through the mosque setting, since a mosque can limit Imsak to a
 * date range (sabahImsakStartDate/EndDate). */
function timesForDate(calendar, date) {
    if (!calendar || calendar.length !== 12) return null;
    var month = calendar[date.getMonth()];
    if (!month) return null;
    var day = month[String(date.getDate())];
    if (!day) return null;
    if (day.length === 7) return day.slice(1);
    return day.length === 6 ? day : null;
}

function parseHM(hm, baseDate) {
    var parts = hm.split(":");
    return new Date(baseDate.getFullYear(), baseDate.getMonth(), baseDate.getDate(),
                    parseInt(parts[0], 10), parseInt(parts[1], 10), 0);
}

function nextPrayer(calendar, now) {
    var today = timesForDate(calendar, now);
    if (!today) return null;
    var order = [0, 2, 3, 4, 5];
    for (var i = 0; i < order.length; i++) {
        var idx = order[i];
        var t = parseHM(today[idx], now);
        if (t > now) {
            return { index: idx, time: today[idx], date: t, tomorrow: false };
        }
    }
    var tmrw = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
    var tTimes = timesForDate(calendar, tmrw);
    if (!tTimes) {
        // Dec 31 after Isha: next year's calendar isn't published yet.
        // Reuse today's Fajr time as tomorrow's estimate rather than
        // showing nothing; the refetch at midnight corrects it.
        return { index: 0, time: today[0], date: parseHM(today[0], tmrw),
                 tomorrow: true, estimated: true };
    }
    return { index: 0, time: tTimes[0], date: parseHM(tTimes[0], tmrw), tomorrow: true };
}

/**
 * Start of the stretch that `next` (from nextPrayer) ends: the prayer just
 * before it, skipping sunrise like nextPrayer does. Before Fajr that is
 * yesterday's Isha, after Isha it is today's. Returns a Date, or null.
 */
function previousPrayerDate(calendar, next, now) {
    if (!next) return null;
    var today = timesForDate(calendar, now);
    if (!today) return null;
    if (next.tomorrow) {
        return parseHM(today[5], now);
    }
    var order = [0, 2, 3, 4, 5];
    var at = order.indexOf(next.index);
    if (at > 0) {
        return parseHM(today[order[at - 1]], now);
    }
    // Before Fajr. On January 1st the calendar has no last year's December,
    // so this year's December 31st stands in for it - a minute or two off
    var yday = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1);
    var yTimes = timesForDate(calendar, yday);
    return parseHM((yTimes || today)[5], yday);
}

/**
 * A prayer time ("HH:MM") split into what is displayed: the hour, the
 * minutes, and the day period ("" in 24-hour format). The period marker
 * follows the prayer-name language: AM/PM, or \u0635/\u0645 in Arabic.
 */
function timeParts(hm, use24h, langSetting) {
    var parts = hm.split(":");
    if (use24h) return { hour: parts[0], minute: parts[1], period: "" };
    var h = parseInt(parts[0], 10);
    var period = uiString(h >= 12 ? "pm" : "am", langSetting);
    h = h % 12;
    if (h === 0) h = 12;
    return { hour: "" + h, minute: parts[1], period: period };
}

/** "17:05", "5:05 PM" or "5:05 \u0645" */
function formatTime(hm, use24h, langSetting) {
    var t = timeParts(hm, use24h, langSetting);
    return t.hour + ":" + t.minute + (t.period !== "" ? " " + t.period : "");
}

/** Remaining time as "h:mm" (e.g. "1:46"), rounded up to the minute. */
function formatCountdownHM(ms) {
    if (ms < 0) ms = 0;
    var totalMin = Math.ceil(ms / 60000);
    var h = Math.floor(totalMin / 60);
    var m = totalMin % 60;
    return h + ":" + (m < 10 ? "0" + m : m);
}

/**
 * Minutes remaining, for the vertical panel strip. Bare digits, with no
 * unit: a vertical panel is only as wide as it is thick, and the gap to
 * the next prayer regularly runs past 100 minutes.
 */
function formatCountdownMin(ms) {
    if (ms < 0) ms = 0;
    return "" + Math.ceil(ms / 60000);
}

/**
 * Full countdown for the expanded view, seconds always included:
 * "7h 25m 30s" / "7\u0633 25\u062F 30\u062B"; "25m 30s" under an hour.
 */
function formatCountdownFull(ms, langSetting) {
    if (ms < 0) ms = 0;
    var totalSec = Math.floor(ms / 1000);
    var h = Math.floor(totalSec / 3600);
    var m = Math.floor((totalSec % 3600) / 60);
    var s = totalSec % 60;
    function pad(n) { return n < 10 ? "0" + n : "" + n; }
    var U = { h: uiString("h", langSetting),
              m: uiString("m", langSetting),
              s: uiString("s", langSetting) };
    if (h > 0) return h + U.h + " " + pad(m) + U.m + " " + pad(s) + U.s;
    return m + U.m + " " + pad(s) + U.s;
}

function formatCountdown(ms, langSetting) {
    if (ms < 0) ms = 0;
    var totalSec = Math.floor(ms / 1000);
    var h = Math.floor(totalSec / 3600);
    var m = Math.floor((totalSec % 3600) / 60);
    var s = totalSec % 60;
    function pad(n) { return n < 10 ? "0" + n : "" + n; }
    var U = { h: uiString("h", langSetting),
              m: uiString("m", langSetting),
              s: uiString("s", langSetting) };
    if (h > 0) return h + U.h + " " + pad(m) + U.m;
    return m + U.m + " " + pad(s) + U.s;
}

/**
 * Turn what was pasted in the settings - a mawaqit.net URL, or a bare
 * slug - into the configured mosque: "id/<number>" for a link shared from
 * the Mawaqit app (mawaqit.net/<lang>/id/<number>), the slug otherwise.
 * Only a URL is parsed, not text around it. Besides the regular page
 * (/<lang>/<slug>), Mawaqit serves the same mosque at /<lang>/m/<slug>
 * (mobile view, redirects to the regular page) and /<lang>/w/<slug>
 * (widget page); skip that segment so a link copied from a phone or a
 * mosque's website resolves too.
 */
function normalizeMosque(text) {
    var t = text.trim();
    var m = /^(?:https?:\/\/)?(?:www\.)?mawaqit\.net\/(?:[a-z]{2}\/)?(?:id\/(\d+)|(?:[mw]\/)?([A-Za-z0-9][A-Za-z0-9\-]*))(?:[\/?#].*)?$/i.exec(t);
    if (m) return m[1] ? "id/" + m[1] : m[2].toLowerCase();
    return t.toLowerCase();
}

/* --------------------------- version check ---------------------------- *
 * The KDE Store (OCS API) is the one place every release lands, so it is
 * the only source checked; distro packages follow it with some delay. The
 * store answers XML unless asked for JSON with format=json; the version is
 * data[0].version.
 * --------------------------------------------------------------------- */

var STORE_ID = "2365203";
var STORE_PAGE = "https://store.kde.org/p/" + STORE_ID;

/* QML's XMLHttpRequest sends "User-Agent: Mozilla/5.0" unless told
 * otherwise; name the application instead (the KDE Store and the location
 * services). mawaqit.net requests are left as they were. */
var APP_USER_AGENT = "plasma6-applets-mawaqit-prayer-times "
                   + "(+https://github.com/medaminezghal/plasma6-applets-mawaqit-prayer-times)";

function fetchStoreVersion(onSuccess, onError) {
    var xhr = new XMLHttpRequest();
    xhr.open("GET", "https://api.kde-look.org/ocs/v1/content/data/" + STORE_ID
             + "?format=json");
    xhr.setRequestHeader("Accept", "application/json");
    xhr.setRequestHeader("User-Agent", APP_USER_AGENT);
    xhr.onreadystatechange = function () {
        if (xhr.readyState !== XMLHttpRequest.DONE) return;
        if (xhr.status !== 200) {
            onError(xhr.status === 0 ? "could not reach the KDE Store"
                                     : "HTTP " + xhr.status + " from the KDE Store");
            return;
        }
        try {
            var j = JSON.parse(xhr.responseText);
            var item = (j.data && j.data.length > 0) ? j.data[0] : null;
            var v = item && typeof item.version === "string" ? item.version.trim() : "";
            if (v) onSuccess(v);
            else onError("no version in the KDE Store response");
        } catch (e) {
            onError("unexpected response from the KDE Store");
        }
    };
    xhr.send();
    // Returned so the caller can abort it (no timeout property in QML's XHR)
    return xhr;
}

/**
 * Compare dotted numeric versions ("0.7.0", "0.10"); missing parts count
 * as 0 and a non-numeric part as 0. Returns <0, 0 or >0 like a comparator.
 */
function compareVersions(a, b) {
    var pa = String(a).replace(/^v/i, "").split(".");
    var pb = String(b).replace(/^v/i, "").split(".");
    for (var i = 0; i < Math.max(pa.length, pb.length); i++) {
        var x = parseInt(pa[i], 10) || 0;
        var y = parseInt(pb[i], 10) || 0;
        if (x !== y) return x - y;
    }
    return 0;
}
