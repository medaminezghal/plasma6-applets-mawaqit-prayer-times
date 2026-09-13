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

/**
 * Keep only the essential mosque name. Admins often pack the address into
 * the name field ("NAME — street city country"); cut at the first spaced
 * dash or em/en dash. Bare hyphens inside words (Al-Hidaya) are preserved.
 */
function cleanMosqueName(name) {
    var cut = name.split(/\s+[\u2014\u2013]\s*|\s+-\s+/)[0].trim();
    return cut.length > 0 ? cut : name.trim();
}

function fetchConf(slug, onSuccess, onError) {
    var xhr = new XMLHttpRequest();
    xhr.open("GET", BASE + "/fr/" + encodeURIComponent(slug));
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
                                          || extractTitle(xhr.responseText) || slug),
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
            onError("Mosque \u201C" + slug + "\u201D not found on mawaqit.net");
        } else {
            onError("HTTP " + xhr.status + " from mawaqit.net");
        }
    };
    xhr.send();
}

/* --------------------------- mosque search ---------------------------- *
 * Layered:
 *   1. JSON endpoint api/2.0/mosque/search (word or lat/lon). May be
 *      auth-walled; if so we get 401/403 and fall through.
 *   2. Scrape the public /en/search page for mosque links.
 * Callers should offer the mawaqit.net map + paste-URL flow when both
 * yield nothing.
 * --------------------------------------------------------------------- */

function apiSearch(query, onSuccess, onFail) {
    var xhr = new XMLHttpRequest();
    xhr.open("GET", BASE + "/api/2.0/mosque/search?" + query);
    xhr.setRequestHeader("Accept", "application/json");
    xhr.onreadystatechange = function () {
        if (xhr.readyState !== XMLHttpRequest.DONE) return;
        if (xhr.status !== 200) {
            console.log("[mawaqit] api search HTTP " + xhr.status);
            onFail("HTTP " + xhr.status);
            return;
        }
        try {
            var arr = JSON.parse(xhr.responseText);
            if (!Array.isArray(arr)) {
                onFail("unexpected payload");
                return;
            }
            var results = [];
            for (var i = 0; i < arr.length; i++) {
                var it = arr[i];
                if (!it.slug) continue;
                var label = it.label || it.name || it.slug;
                if (it.localisation && label.indexOf(it.localisation) === -1) {
                    label += " \u2014 " + it.localisation;
                }
                results.push({ slug: it.slug, label: label });
            }
            onSuccess(results);
        } catch (e) {
            onFail("parse: " + e);
        }
    };
    xhr.send();
}

var RESERVED_SLUGS = [
    "search", "map", "login", "register", "logout", "about", "faq",
    "backoffice", "contact", "terms", "privacy", "stats", "mosque",
    "assets", "bundles", "upload", "js", "css", "img"
];

function scrapeSearch(word, onSuccess, onError) {
    var xhr = new XMLHttpRequest();
    xhr.open("GET", BASE + "/en/search?word=" + encodeURIComponent(word));
    xhr.onreadystatechange = function () {
        if (xhr.readyState !== XMLHttpRequest.DONE) return;
        if (xhr.status !== 200) {
            onError("HTTP " + xhr.status + " from mawaqit.net search");
            return;
        }
        var html = xhr.responseText;
        var results = [];
        var seen = {};
        var re = /<a[^>]+href="(?:https?:\/\/mawaqit\.net)?\/(?:en|fr|ar|de|es|it|nl|pt|tr)\/([a-z0-9][a-z0-9\-]*)"[^>]*>([\s\S]*?)<\/a>/gi;
        var m;
        while ((m = re.exec(html)) !== null) {
            var slug = m[1];
            if (seen[slug] || RESERVED_SLUGS.indexOf(slug) !== -1) continue;
            var label = m[2].replace(/<[^>]*>/g, " ")
                .replace(/&amp;/g, "&").replace(/&#39;|&apos;/g, "'")
                .replace(/&quot;/g, "\"").replace(/\s+/g, " ").trim();
            seen[slug] = true;
            results.push({ slug: slug, label: label.length > 0 ? label : slug });
        }
        onSuccess(results);
    };
    xhr.send();
}

/** Search by keyword: JSON API first, page scrape as fallback. */
function searchMosques(word, onSuccess, onError) {
    apiSearch("word=" + encodeURIComponent(word), function (results) {
        onSuccess(results, "api");
    }, function () {
        scrapeSearch(word, function (results) {
            onSuccess(results, "scrape");
        }, onError);
    });
}

/** Proximity search by coordinates (only works if the endpoint is open). */
function searchMosquesByCoords(lat, lon, onSuccess, onError) {
    apiSearch("lat=" + lat + "&lon=" + lon, function (results) {
        onSuccess(results, "api");
    }, onError);
}

/* ------------------------------ location ------------------------------ */

var IP_PROVIDERS = [
    {
        url: "https://ipwho.is/",
        parse: function (j) {
            return (j.success !== false && j.city)
                ? { lat: j.latitude, lon: j.longitude, city: j.city } : null;
        }
    },
    {
        url: "https://ipapi.co/json/",
        parse: function (j) {
            return j.city ? { lat: j.latitude, lon: j.longitude, city: j.city } : null;
        }
    },
    {
        url: "http://ip-api.com/json",
        parse: function (j) {
            return (j.status === "success")
                ? { lat: j.lat, lon: j.lon, city: j.city } : null;
        }
    }
];

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

function reverseGeocode(lat, lon, onSuccess, onError) {
    var xhr = new XMLHttpRequest();
    xhr.open("GET", "https://nominatim.openstreetmap.org/reverse?format=jsonv2&zoom=10&lat="
             + lat + "&lon=" + lon);
    xhr.setRequestHeader("Accept", "application/json");
    xhr.onreadystatechange = function () {
        if (xhr.readyState !== XMLHttpRequest.DONE) return;
        if (xhr.status !== 200) {
            onError("Reverse geocoding failed (HTTP " + xhr.status + ")");
            return;
        }
        try {
            var j = JSON.parse(xhr.responseText);
            var a = j.address || {};
            var city = a.city || a.town || a.village || a.municipality || a.county || j.name;
            if (city) onSuccess(city);
            else onError("No city in reverse geocoding result");
        } catch (e) {
            onError("Reverse geocoding parse error: " + e);
        }
    };
    xhr.send();
}

/* --------------------------- hijri calendar --------------------------- *
 * Mawaqit renders its own hijri date with the Kuwaiti arithmetic
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
 * The same hijri date as formatHijri, rendered as DD/MM/YYYY digits for
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
          h: "h", m: "m", s: "s" },
    ar: { inPrefix: "\u0628\u0639\u062F", tomorrow: "\u063A\u062F\u064B\u0627",
          h: "\u0633", m: "\u062F", s: "\u062B" },
    fr: { inPrefix: "dans", tomorrow: "demain",
          h: "h", m: "min", s: "s" }
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

function timesForDate(calendar, date) {
    if (!calendar || calendar.length !== 12) return null;
    var month = calendar[date.getMonth()];
    if (!month) return null;
    var day = month[String(date.getDate())];
    return (day && day.length >= 6) ? day : null;
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

function formatTime(hm, use24h) {
    if (use24h) return hm;
    var parts = hm.split(":");
    var h = parseInt(parts[0], 10);
    var suffix = h >= 12 ? "PM" : "AM";
    h = h % 12;
    if (h === 0) h = 12;
    return h + ":" + parts[1] + " " + suffix;
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

/** Accept a full mawaqit.net URL or bare slug; return the slug. */
function normalizeSlug(text) {
    var m = text.match(/mawaqit\.net\/(?:[a-z]{2}\/)?([A-Za-z0-9][A-Za-z0-9\-]*)/);
    if (m) return m[1].toLowerCase();
    return text.trim().toLowerCase();
}
