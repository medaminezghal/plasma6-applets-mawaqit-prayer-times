.pragma library

/*
 * The Horizon layout: the sky over a mosque - al-Masjid al-Aqsa or
 * al-Masjid an-Nabawi - through the day, with the sun and the moon where
 * they stand. Pure functions, no QML types, so they can be checked
 * outside Plasma.
 *
 * Times are minutes since midnight. The sun and the moon share one arc,
 * from the left horizon (rising) to the right (setting); a position f runs
 * 0..1 along it while the body is up.
 */

function toMinutes(hm) {
    var parts = String(hm).split(":");
    return parseInt(parts[0], 10) * 60 + parseInt(parts[1], 10);
}

function _rgb(hex) {
    return [1, 3, 5].map(function (i) { return parseInt(hex.slice(i, i + 2), 16); });
}

function _hex(c) {
    return "#" + c.map(function (v) {
        var s = Math.round(Math.max(0, Math.min(255, v))).toString(16);
        return s.length < 2 ? "0" + s : s;
    }).join("");
}

/** Blend two "#rrggbb" colours, t = 0..1 from a to b. */
function mix(a, b, t) {
    var x = _rgb(a), y = _rgb(b);
    return _hex(x.map(function (v, i) { return v + (y[i] - v) * t; }));
}

/** Relative brightness 0..1 of a "#rrggbb" colour. */
function luminance(hex) {
    var v = _rgb(hex);
    return (0.2126 * v[0] + 0.7152 * v[1] + 0.0722 * v[2]) / 255;
}

var NIGHT = ["#050a1c", "#0b1534", "#17224a"];

/*
 * Sky colours [top, middle, horizon] and how dark it is (0 = day,
 * 1 = full night) at minute n, blended between keyframes tied to today's
 * prayers: night, Fajr, sunrise, morning, Dhuhr, Asr, golden hour,
 * Maghrib, Isha, night.
 */
function skyAt(n, times) {
    var F = toMinutes(times[0]), SR = toMinutes(times[1]), DH = toMinutes(times[2]);
    var AS = toMinutes(times[3]), MG = toMinutes(times[4]), IS = toMinutes(times[5]);
    var K = [
        [0, NIGHT, 1],
        [F - 45, NIGHT, 1],
        [F, ["#0a1436", "#23286a", "#53457f"], 0.75],
        [SR, ["#3a5799", "#c07a98", "#f5b47f"], 0.05],
        [SR + 70, ["#4a82c4", "#8eb9e3", "#d5e7f5"], 0],
        [DH, ["#3b7ccd", "#7db2e8", "#cfe4f6"], 0],
        [AS, ["#477fc4", "#8bb6de", "#e0e8ee"], 0],
        [MG - 45, ["#4b78b6", "#d9a877", "#f4c27a"], 0],
        [MG, ["#2d3b74", "#b05e79", "#ee8558"], 0.1],
        [IS, ["#101a42", "#2c2b69", "#58406f"], 0.7],
        [IS + 55, NIGHT, 1],
        [1440, NIGHT, 1]
    ];
    var k = 0;
    while (k < K.length - 2 && n > K[k + 1][0]) {
        k++;
    }
    var a = K[k], b = K[k + 1];
    var t = b[0] > a[0] ? Math.max(0, Math.min(1, (n - a[0]) / (b[0] - a[0]))) : 0;
    var c = [0, 1, 2].map(function (i) { return mix(a[1][i], b[1][i], t); });
    // A warm glow on the horizon through the two twilights
    var warm = (n > MG - 60 && n < IS + 20) || (n > F - 20 && n < SR + 40);
    return {
        top: c[0], mid: c[1], horizon: c[2],
        night: a[2] + (b[2] - a[2]) * t,
        warmGlow: warm
    };
}

/** Where the sun is on the arc: f 0..1 from sunrise to Maghrib. */
function sunAt(n, times) {
    var SR = toMinutes(times[1]), MG = toMinutes(times[4]);
    var f = (n - SR) / (MG - SR);
    return { f: f, up: f > -0.04 && f < 1.04 };
}

/*
 * Where the moon is on the same arc. Its age in days is the Hijri day of
 * the month; it trails the sun by about 49 minutes a day (1440 / 29.53),
 * so it rises with the sun at the new moon and with Maghrib at the full.
 * Gone for the last day or two of the month.
 */
function moonAt(n, times, hijriDay) {
    var SR = toMinutes(times[1]), MG = toMinutes(times[4]);
    var lag = hijriDay / 29.53 * 1440;
    var span = MG - SR;
    var f = ((((n - SR - lag) % 1440) + 1440) % 1440) / span;
    if (f > 1.5) {
        f -= 1440 / span;
    }
    return { f: f, up: hijriDay < 29 && f > -0.04 && f < 1.04 };
}

/*
 * Point on the arc in a box w wide whose horizon is at horizonY: rises at
 * the left edge, peaks `lift` above the horizon, sets at the right edge.
 * Slightly outside 0..1 the body sits just under the horizon.
 */
function arcPoint(f, w, horizonY, lift) {
    f = Math.max(-0.04, Math.min(1.04, f));
    return {
        x: w * (0.055 + 0.89 * f),
        y: horizonY - lift * Math.sin(Math.PI * f)
    };
}

/*
 * Where the sun and the moon stand in a scene w wide whose horizon is at
 * horizonY, and how big they are: { r, sun: {x, y, f, up}, moon: {...} }.
 * The arc rises nearly to the top: at their highest the two pass behind
 * the mosque name and the Hijri date, which the header lighting keeps
 * readable (see shaders/headerlight.frag).
 */
function bodiesAt(n, times, hijriDay, w, horizonY) {
    var u = Math.min(1.6, w / 400);
    var r = Math.max(6, 12 * u);
    var lift = Math.max(r * 2, horizonY - r * 2);
    var sun = sunAt(n, times), moon = moonAt(n, times, hijriDay);
    var sp = arcPoint(sun.f, w, horizonY, lift), mp = arcPoint(moon.f, w, horizonY, lift);
    return {
        r: r,
        u: u,
        sun: { x: sp.x, y: sp.y, f: sun.f, up: sun.up },
        moon: { x: mp.x, y: mp.y, f: moon.f, up: moon.up }
    };
}

/*
 * The ink of the text in the sky - the mosque name, the Hijri date and the
 * countdown - all switch together: deep navy while the sky behind the
 * header is bright, light once it is dark. One rule for all of them, so
 * they never disagree at twilight, and an instant switch, never grey.
 */
var NAVY_INK = "#0d2242";
var SILVER_INK = "#ced8ee";
function darkInk(sky) {
    return luminance(sky.top) > 0.45;
}

/*
 * SVG path of the lit part of the moon on day `hijriDay`, a disc of radius
 * r at (cx, cy), as seen from the northern hemisphere: lit on the right
 * while it grows, on the left while it wanes.
 */
function moonPhasePath(cx, cy, r, hijriDay) {
    var ph = hijriDay / 29.53;
    var rx = Math.abs(Math.cos(ph * 2 * Math.PI)) * r;
    var waxing = ph < 0.5, gibbous = ph > 0.25 && ph < 0.75;
    var top = cx + " " + (cy - r), bottom = cx + " " + (cy + r);
    var outer = "A" + r + " " + r + " 0 0 " + (waxing ? 1 : 0) + " " + bottom;
    var sweep = waxing ? (gibbous ? 1 : 0) : (gibbous ? 0 : 1);
    var inner = "A" + rx.toFixed(2) + " " + r + " 0 0 " + sweep + " " + top;
    return "M" + top + outer + inner + "Z";
}

/** Fixed pseudo-random stars [{x, y, r}], x/y as fractions of the sky. */
function stars(count) {
    var out = [];
    for (var i = 0; i < count; i++) {
        var v = Math.sin(i * 127.1 + 311.7) * 43758.5453;
        var w = Math.sin((i + 99) * 127.1 + 311.7) * 43758.5453;
        var s = Math.sin((i + 7) * 127.1 + 311.7) * 43758.5453;
        out.push({
            x: v - Math.floor(v),
            y: 0.03 + (w - Math.floor(w)) * 0.8,
            big: (s - Math.floor(s)) > 0.85
        });
    }
    return out;
}

/* The skylines, each drawn in a 400-wide box whose horizon is at y = 200.
 * Every part is an SVG path with the name of the colour it takes from
 * landColors(), so the colours follow the sky; the hills are shared. */
var hills = {
    far: "M0 188 C 60 176 118 192 182 182 S 304 170 400 183 V214 H0 Z",
    near: "M0 203 C 70 196 150 207 228 199 S 344 193 400 201 V214 H0 Z"
};

// A slender minaret of the Prophet's Mosque: square shaft, two balconies,
// a narrower top storey, a pointed cap and a gold crescent on its finial
function _minaret(x, top, w) {
    var h = w / 2;
    var b1 = top + (194 - top) * 0.45;
    return {
        body: "M" + (x - h) + " " + (top + 18) + " H" + (x + h) + " V194 H" + (x - h) + " Z"
              + " M" + (x - h - 3) + " " + b1.toFixed(1) + " H" + (x + h + 3) + " V" + (b1 + 3).toFixed(1)
              + " H" + (x - h - 3) + " Z"
              + " M" + (x - h - 3) + " " + (top + 18) + " H" + (x + h + 3) + " V" + (top + 21)
              + " H" + (x - h - 3) + " Z"
              + " M" + (x - h + 1) + " " + (top + 6) + " H" + (x + h - 1) + " V" + (top + 18)
              + " H" + (x - h + 1) + " Z"
              + " M" + (x - h + 1) + " " + (top + 6) + " Q" + x + " " + (top - 8) + " " + (x + h - 1)
              + " " + (top + 6) + " Z",
        finial: "M" + (x - 0.7) + " " + (top - 14) + " H" + (x + 0.7) + " V" + (top - 3) + " H" + (x - 0.7) + " Z",
        crescent: "M" + (x - 3) + " " + (top - 16) + " A3 3 0 0 0 " + (x + 3) + " " + (top - 16)
    };
}

// An open courtyard umbrella of the Prophet's Mosque, its rim scalloped
function _umbrella(x) {
    return "M" + (x - 0.8) + " 180 H" + (x + 0.8) + " V194 H" + (x - 0.8) + " Z"
           + " M" + (x - 14) + " 182 Q" + (x - 7) + " 172 " + x + " 170 Q" + (x + 7) + " 172 " + (x + 14) + " 182"
           + " Q" + (x + 10.5) + " 179 " + (x + 7) + " 182 Q" + (x + 3.5) + " 179 " + x + " 182"
           + " Q" + (x - 3.5) + " 179 " + (x - 7) + " 182 Q" + (x - 10.5) + " 179 " + (x - 14) + " 182 Z";
}

function _nabawi() {
    var minarets = [_minaret(40, 96, 8), _minaret(92, 112, 7), _minaret(226, 100, 8), _minaret(352, 92, 8)];
    var body = "", finials = "", crescents = "";
    for (var i = 0; i < minarets.length; ++i) {
        body += minarets[i].body + " ";
        finials += minarets[i].finial + " ";
        crescents += minarets[i].crescent + " ";
    }
    // the little domes along the roof of the Ottoman hall
    var smallDomes = "";
    for (var x = 76; x <= 196; x += 12) {
        if (x > 104 && x < 152) {
            continue;                    // the Green Dome stands here
        }
        smallDomes += "M" + (x - 5) + " 176 A5 5 0 0 1 " + (x + 5) + " 176 Z ";
    }
    var windows = "";
    for (var wx = 70; wx < 204; wx += 10) {
        windows += "M" + wx + " 191 V186 A2.2 2.2 0 0 1 " + (wx + 4.4) + " 186 V191 Z ";
    }
    for (var vx = 214; vx < 368; vx += 11) {
        windows += "M" + vx + " 192 V186 A2.6 2.6 0 0 1 " + (vx + 5.2) + " 186 V192 Z ";
    }
    return {
        layers: [
            // courtyard wall, the Ottoman hall and the newer prayer hall
            { d: "M14 192 H386 V204 H14 Z M66 176 H206 V194 H66 Z M210 178 H372 V194 H210 Z", color: "near" },
            { d: body, color: "near" },
            // the Green Dome's drum and the silver dome's drum
            { d: "M112 154 H144 V176 H112 Z M160 164 H184 V176 H160 Z", color: "near" },
            { d: smallDomes, color: "silver" },
            { d: "M157 166 C 157 150 187 150 187 166 Z M171.3 144 H172.7 V152 H171.3 Z", color: "silver" },
            // the Green Dome over the Prophet's chamber
            { d: "M108 156 C 107 134 118 122 128 106 C 138 122 149 134 148 156 Z", color: "green" },
            { d: "M127.3 94 H128.7 V107 H127.3 Z " + finials, color: "gold" },
            { d: _umbrella(262) + " " + _umbrella(292) + " " + _umbrella(322), color: "canopy" }
        ],
        strokes: [
            { d: "M125 92 A3 3 0 0 0 131 92 " + crescents, color: "gold", width: 1.2 }
        ],
        windows: windows,
        // Tallest point above the horizon: a minaret's crescent
        height: 128
    };
}

var lands = {
    /* al-Masjid al-Aqsa: the compound wall, the Dome of the Rock on its
     * platform with its tiled octagon and golden dome, cypresses, the Qibli
     * mosque with its arcade and silver dome, and two square minarets */
    aqsa: {
        layers: [
            {
                d: "M22 192 H368 V204 H22 Z"
                   + " M36 142 H44 V194 H36 Z M33 158 H47 V161 H33 Z M37.5 135 H42.5 V142 H37.5 Z"
                   + " M37.5 135 C 37.5 129 42.5 129 42.5 135 Z"
                   + " M54 186 H138 V194 H54 Z M74 152 H118 V165 H74 Z"
                   + " M146 184 A4 12 0 1 0 154 184 A4 12 0 1 0 146 184 Z"
                   + " M156.6 187 A3.4 9 0 1 0 163.4 187 A3.4 9 0 1 0 156.6 187 Z"
                   + " M312 185 A4 11 0 1 0 320 185 A4 11 0 1 0 312 185 Z"
                   + " M176 180 L240 176 L304 180 V194 H176 Z M186 172 H206 V180 H186 Z"
                   + " M326 128 H335 V194 H326 Z M323 146 H338 V149 H323 Z M327.5 120 H333.5 V128 H327.5 Z"
                   + " M327.5 120 C 327.5 113 333.5 113 333.5 120 Z M329.8 106 H331.2 V114 H329.8 Z",
                color: "near"
            },
            { d: "M60 186 V168 L68 165 H124 L132 168 V186 Z", color: "tiles" },
            { d: "M72 152 C 70 132 84 120 96 116 C 108 120 122 132 120 152 Z M95.3 104 H96.7 V116 H95.3 Z", color: "gold" },
            { d: "M184 172 C 184 160 208 160 208 172 Z M195.3 154 H196.7 V161 H195.3 Z", color: "silver" }
        ],
        strokes: [
            // the crescent on the Dome of the Rock's finial
            { d: "M92.8 101 A3.2 3.2 0 0 0 99.2 101", color: "gold", width: 1.3 }
        ],
        // windows that glow warm after Maghrib: the octagon's, the Qibli arcade
        windows: "M70 182 V176 A2.5 2.5 0 0 1 75 176 V182 Z M82 182 V176 A2.5 2.5 0 0 1 87 176 V182 Z"
                 + " M94 182 V176 A2.5 2.5 0 0 1 99 176 V182 Z M106 182 V176 A2.5 2.5 0 0 1 111 176 V182 Z"
                 + " M118 182 V176 A2.5 2.5 0 0 1 123 176 V182 Z"
                 + " M184 193 V187 A3.5 3.5 0 0 1 191 187 V193 Z M200 193 V187 A3.5 3.5 0 0 1 207 187 V193 Z"
                 + " M216 193 V187 A3.5 3.5 0 0 1 223 187 V193 Z M232 193 V187 A3.5 3.5 0 0 1 239 187 V193 Z"
                 + " M248 193 V187 A3.5 3.5 0 0 1 255 187 V193 Z M264 193 V187 A3.5 3.5 0 0 1 271 187 V193 Z"
                 + " M280 193 V187 A3.5 3.5 0 0 1 287 187 V193 Z M329 141 V136 A1.5 1.5 0 0 1 332 136 V141 Z",
        // Tallest point above the horizon, the Dome's finial crescent
        height: 100
    },
    /* al-Masjid an-Nabawi: the Green Dome over the Prophet's chamber with
     * the silver dome beside it, the little domes of the Ottoman hall, four
     * minarets, the newer prayer hall and the courtyard umbrellas */
    nabawi: _nabawi()
};

/** Colours of the land for a sky from skyAt(). */
function landColors(sky) {
    var near = mix(sky.horizon, "#04060e", 0.86);
    var day = 1 - sky.night;
    return {
        far: mix(sky.horizon, "#0a0f24", 0.6),
        near: near,
        // The golden and green domes keep their colour: sunlit by day,
        // floodlit at night
        gold: mix(near, "#e2b24c", 0.85 - sky.night * 0.3),
        green: mix(near, "#2f8f5b", 0.85 - sky.night * 0.3),
        silver: mix(near, "#a9b2bc", 0.45 * day + 0.12),
        tiles: mix(near, "#3c6ca8", 0.4 * day),
        canopy: mix(near, "#efeae0", 0.7 * day + 0.12),
        windowGlow: sky.night * 0.95
    };
}
