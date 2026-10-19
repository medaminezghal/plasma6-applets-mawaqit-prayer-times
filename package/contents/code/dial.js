.pragma library

/*
 * Geometry for the Sundial layout: a 24-hour dial drawn on a rounded
 * rectangle, midnight at the bottom, noon at the top, read clockwise
 * (06:00 on the left, 18:00 on the right). Pure functions, no QML types,
 * so the layout can be checked outside Plasma.
 *
 * Coordinates are relative to the dial centre, y pointing down.
 */

/** "HH:MM" or minutes since midnight -> minutes since midnight. */
function toMinutes(hm) {
    if (typeof hm === "number") {
        return hm;
    }
    var parts = String(hm).split(":");
    return parseInt(parts[0], 10) * 60 + parseInt(parts[1], 10);
}

/** Unit direction of a time of day on the dial. */
function direction(minutes) {
    var a = (minutes / 1440) * 2 * Math.PI;
    return { x: -Math.sin(a), y: Math.cos(a) };
}

/** Time of day (minutes) of a direction; inverse of direction(). */
function minutesOf(dx, dy) {
    var a = Math.atan2(-dx, dy);
    if (a < 0) {
        a += 2 * Math.PI;
    }
    return a / (2 * Math.PI) * 1440;
}

/**
 * Where a ray from the centre along (dx, dy) leaves a rounded rectangle of
 * half-size a x b and corner radius r.
 */
function rayToRoundedRect(dx, dy, a, b, r) {
    r = Math.max(0, Math.min(r, a, b));
    var ax = Math.abs(dx);
    var ay = Math.abs(dy);
    var t = Math.min(ax > 1e-9 ? a / ax : Infinity, ay > 1e-9 ? b / ay : Infinity);
    var px = dx * t;
    var py = dy * t;
    if (r > 0 && Math.abs(px) > a - r && Math.abs(py) > b - r) {
        // Corner arc: |t*d - c| = r, far root
        var cx = (px > 0 ? 1 : -1) * (a - r);
        var cy = (py > 0 ? 1 : -1) * (b - r);
        var bq = dx * cx + dy * cy;
        var cq = cx * cx + cy * cy - r * r;
        var disc = bq * bq - cq;
        if (disc >= 0) {
            t = bq + Math.sqrt(disc);
            px = dx * t;
            py = dy * t;
        }
    }
    return { x: px, y: py };
}

/** Point of a time of day on the track. */
function trackPoint(minutes, a, b, r) {
    var d = direction(minutes);
    return rayToRoundedRect(d.x, d.y, a, b, r);
}

function _overlap(p, q, gap) {
    var ox = (p.w + q.w) / 2 + gap - Math.abs(p.x - q.x);
    var oy = (p.h + q.h) / 2 + gap - Math.abs(p.y - q.y);
    return { x: ox, y: oy, hit: ox > 0 && oy > 0 };
}

// Centre of a card standing on the inside of the track at a time of day:
// as close to its own point as it can be while staying the inset inside the
// track. That is the point itself, clamped to the box the card's centre may
// move in, so the card sits right against its point on a straight edge and
// tucks into the corner when the point is near one. (Walking out from the
// centre along the ray instead left cards near a corner well short of their
// point - the side of that box is reached first - so they got a leader.)
function _cardAt(minutes, c, a, b, inset) {
    var p = trackPoint(minutes, a, b, 0);
    var ca = Math.max(0, a - inset - c.w / 2);
    var cb = Math.max(0, b - inset - c.h / 2);
    return {
        x: Math.max(-ca, Math.min(ca, p.x)),
        y: Math.max(-cb, Math.min(cb, p.y)),
        w: c.w, h: c.h
    };
}

/**
 * Places the prayer cards inside the track.
 *
 *   cards:  [{ minutes, w, h }]
 *   a, b:   half-size of the track
 *   inset:  space kept between the track and a card
 *   gap:    space kept between two cards
 *
 * Each card starts next to its own point on the track, along the same ray,
 * so it reads as belonging to that point. Cards always stay on that ring,
 * in the order of their times: when two neighbours collide - Maghrib and
 * Isha in summer, Fajr and Isha at high latitudes - both slide away from
 * each other along the ring a little at a time until they clear. Returns
 * [{ x, y }] card centres in the order given. With too little room the
 * cards may still touch; the caller hides detail before that happens.
 */
function layoutCards(cards, a, b, inset, gap) {
    var n = cards.length;
    var shown = [];
    var i;
    for (i = 0; i < n; ++i) {
        shown.push(i);
    }
    shown.sort(function (p, q) { return cards[p].minutes - cards[q].minutes; });

    var at = [];
    for (i = 0; i < n; ++i) {
        at.push(cards[i].minutes);
    }

    var STEP = 1; // minutes of dial per nudge
    for (var iter = 0; n > 1 && iter < 1500; ++iter) {
        var moved = false;
        for (var k = 0; k < n; ++k) {
            // Two cards only have one pair; more wrap around the dial
            if (n === 2 && k === 1) {
                break;
            }
            var p = shown[k];
            var q = shown[(k + 1) % n];
            if (_overlap(_cardAt(at[p], cards[p], a, b, inset),
                         _cardAt(at[q], cards[q], a, b, inset), gap).hit) {
                at[p] -= STEP;
                at[q] += STEP;
                moved = true;
            }
        }
        if (!moved) {
            break;
        }
    }

    var out = [];
    for (i = 0; i < n; ++i) {
        var c = _cardAt(at[i], cards[i], a, b, inset);
        out.push({ x: c.x, y: c.y });
    }
    return out;
}

/**
 * Countdown as "hh:mm:ss", dropping the leading units that are zero:
 * "01:05:09", "05:09", "09".
 */
function formatCountdown(ms) {
    if (!(ms > 0)) {
        ms = 0;
    }
    var total = Math.floor(ms / 1000);
    var h = Math.floor(total / 3600);
    var m = Math.floor((total % 3600) / 60);
    var s = total % 60;
    function pad(n) { return n < 10 ? "0" + n : "" + n; }
    if (h > 0) {
        return pad(h) + ":" + pad(m) + ":" + pad(s);
    }
    if (m > 0) {
        return pad(m) + ":" + pad(s);
    }
    return pad(s);
}
