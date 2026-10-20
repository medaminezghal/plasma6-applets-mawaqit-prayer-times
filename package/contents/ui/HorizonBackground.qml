import QtQuick
import "../code/horizon.js" as Horizon

/* The background of the Horizon layout: the sky over the chosen mosque at
 * this minute. Its colours follow today's prayers, the sun crosses from
 * sunrise to Maghrib, the moon stands where its age - the Hijri day - puts
 * it and shows that day's phase, stars come out at night and the windows
 * light up after Maghrib.
 *
 * Only QtQuick is used; FullRepresentation places it where the theme frame
 * would be, like the Sundial's Sky, and tells it where the horizon and the
 * bottom of the countdown are in its own coordinates. */
Canvas {
    id: scene

    property var times: null          // ["HH:MM" x 6]
    property int hijriDay: 1
    property string mosque: "aqsa"    // a key of Horizon.lands
    property real minutes: 0          // minutes since midnight
    property var sky: null            // Horizon.skyAt() for `minutes`
    property real horizonY: height * 0.7
    // The land is never taller than the space between the text and the
    // horizon, so the skyline stays behind the cards, not the countdown
    property real textBottom: 0
    property real radius: 0

    readonly property var starList: Horizon.stars(46)
    // Where the sun and the moon stand now, in this item's coordinates;
    // the header lighting in FullRepresentation reads them too
    readonly property var bodies: times && times.length >= 6 && width > 0
                                  ? Horizon.bodiesAt(minutes, times, hijriDay, width,
                                                     Math.max(1, horizonY))
                                  : null

    onTimesChanged: requestPaint()
    onHijriDayChanged: requestPaint()
    onMosqueChanged: requestPaint()
    onSkyChanged: requestPaint()
    onHorizonYChanged: requestPaint()
    onTextBottomChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onRadiusChanged: requestPaint()
    onBodiesChanged: requestPaint()

    function radial(ctx, x, y, r, stops) {
        var g = ctx.createRadialGradient(x, y, 0, x, y, r);
        for (var i = 0; i < stops.length; ++i) {
            g.addColorStop(stops[i][0], stops[i][1]);
        }
        ctx.fillStyle = g;
        ctx.beginPath();
        ctx.arc(x, y, r, 0, 2 * Math.PI);
        ctx.fill();
    }

    function fillPath(ctx, svg, color) {
        ctx.fillStyle = color;
        ctx.path = svg;
        ctx.fill();
    }

    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        if (width <= 0 || height <= 0 || !sky || !bodies) {
            return;
        }
        ctx.save();
        ctx.beginPath();
        ctx.roundedRect(0, 0, width, height, radius, radius);
        ctx.clip();

        var hz = Math.max(1, horizonY);

        /* ------------------------------ sky ------------------------------ */
        var g = ctx.createLinearGradient(0, 0, 0, hz);
        g.addColorStop(0, sky.top);
        g.addColorStop(0.62, sky.mid);
        g.addColorStop(1, sky.horizon);
        ctx.fillStyle = g;
        ctx.fillRect(0, 0, width, height);

        var sun = bodies.sun, moon = bodies.moon;
        var u = bodies.u, bodyR = bodies.r;
        var sunP = sun, moonP = moon;

        // Warm light along the horizon through the twilights, under the sun
        if (sky.warmGlow) {
            var gx = sun.up ? sunP.x
                            : (minutes > Horizon.toMinutes(times[2]) ? width * 0.85 : width * 0.15);
            var glow = ctx.createRadialGradient(gx, hz, 0, gx, hz, width * 0.75);
            glow.addColorStop(0, "rgba(255,154,98,0.45)");
            glow.addColorStop(1, "rgba(255,154,98,0)");
            ctx.fillStyle = glow;
            ctx.fillRect(0, 0, width, hz);
        }

        /* ----------------------------- stars ----------------------------- */
        if (sky.night > 0.02) {
            for (var i = 0; i < starList.length; ++i) {
                var st = starList[i];
                ctx.fillStyle = "rgba(255,255,255," + (sky.night * (st.big ? 0.95 : 0.6)).toFixed(3) + ")";
                ctx.beginPath();
                ctx.arc(st.x * width, st.y * hz * 0.9, (st.big ? 1.3 : 0.75) * Math.max(0.8, u), 0, 2 * Math.PI);
                ctx.fill();
            }
        }

        /* ------------------------------ moon ----------------------------- */
        var daylight = sky.night < 0.3;
        if (moon.up) {
            ctx.save();
            // pale in a day sky, as the real moon is
            ctx.globalAlpha = daylight ? 0.45 : 1;
            if (!daylight) {
                radial(ctx, moonP.x, moonP.y, bodyR * 3.8,
                       [[0, "rgba(243,240,255,0.4)"], [1, "rgba(243,240,255,0)"]]);
            }
            // The dark side, faintly lit by the earth
            ctx.fillStyle = daylight ? "rgba(201,211,242,0.08)" : "rgba(201,211,242,0.16)";
            ctx.beginPath();
            ctx.arc(moonP.x, moonP.y, bodyR, 0, 2 * Math.PI);
            ctx.fill();
            fillPath(ctx, Horizon.moonPhasePath(moonP.x, moonP.y, bodyR, hijriDay), "#f6f2e4");
            ctx.restore();
        }

        /* ------------------------------ sun ------------------------------ */
        if (sun.up) {
            radial(ctx, sunP.x, sunP.y, bodyR * 5.3,
                   [[0, "rgba(255,231,174,0.75)"], [0.35, "rgba(255,213,138,0.28)"],
                    [1, "rgba(255,213,138,0)"]]);
            ctx.fillStyle = (sun.f < 0.1 || sun.f > 0.9) ? "#ffc07a" : "#fff4d6";
            ctx.beginPath();
            ctx.arc(sunP.x, sunP.y, bodyR * 1.08, 0, 2 * Math.PI);
            ctx.fill();
        }

        /* ------------------------------ land ----------------------------- *
         * Drawn in its own 400-wide box with the horizon at y = 200: the
         * hills stretch to the full width, the buildings keep their shape. */
        var land = Horizon.lands[mosque] || Horizon.lands.aqsa;
        var c = Horizon.landColors(sky);
        var room = hz - textBottom;
        var s = Math.max(0.35, Math.min(width / 400, room > 0 ? room / land.height : width / 400));

        ctx.save();
        ctx.translate(0, hz - 200 * s);
        ctx.scale(width / 400, s);
        fillPath(ctx, Horizon.hills.far, c.far);
        fillPath(ctx, Horizon.hills.near, c.near);
        ctx.restore();

        ctx.save();
        ctx.translate((width - 400 * s) / 2, hz - 200 * s);
        ctx.scale(s, s);
        for (var p = 0; p < land.layers.length; ++p) {
            fillPath(ctx, land.layers[p].d, c[land.layers[p].color]);
        }
        for (var q = 0; q < land.strokes.length; ++q) {
            ctx.strokeStyle = c[land.strokes[q].color];
            ctx.lineWidth = land.strokes[q].width;
            ctx.path = land.strokes[q].d;
            ctx.stroke();
        }
        if (c.windowGlow > 0.02) {
            fillPath(ctx, land.windows, "rgba(255,206,122," + c.windowGlow.toFixed(3) + ")");
        }
        ctx.restore();

        // The ground the prayer cards stand on
        ctx.fillStyle = c.near;
        ctx.fillRect(0, hz + 3 * s, width, height - hz);

        ctx.restore();
    }
}
