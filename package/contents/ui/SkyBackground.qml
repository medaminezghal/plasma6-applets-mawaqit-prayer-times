import QtQuick
import "../code/dial.js" as Dial

/* The Sky background of the Sundial layout, drawn from today's own times
 * rather than a picture: seen from the centre of the dial, the day (sunrise
 * to maghrib) is the sky above, the night (isha to fajr) the dark below,
 * and the two twilights fade between them in bands. Every boundary lies on
 * the ray through that time's point on the dial, so the horizon moves with
 * the seasons - low in summer, high in winter.
 *
 * Only QtQuick is used; FullRepresentation places it where the theme frame
 * would be and gives it the centre of the dial in its own coordinates. */
Canvas {
    id: sky

    property var times: null          // ["HH:MM" x 6]
    property real centreX: width / 2
    property real centreY: height / 2
    property real radius: 0

    readonly property color nightColor: "#070c1c"
    readonly property color dayTopColor: "#2b5ea6"
    readonly property color dayHorizonColor: "#5a8ed3"
    // Twilight bands, from the night side to the day side
    readonly property var twilightColors: ["#0d1a3d", "#15295a", "#1f3c7a"]

    onTimesChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onCentreXChanged: requestPaint()
    onCentreYChanged: requestPaint()
    onRadiusChanged: requestPaint()

    function wedge(ctx, from, to) {
        var far = (width + height) * 4;
        while (to < from) {
            to += 1440;
        }
        ctx.beginPath();
        ctx.moveTo(centreX, centreY);
        for (var m = from; ; m += 5) {
            var t = Math.min(m, to);
            var d = Dial.direction(t);
            ctx.lineTo(centreX + d.x * far, centreY + d.y * far);
            if (t >= to) {
                break;
            }
        }
        ctx.closePath();
        ctx.fill();
    }

    function band(ctx, from, to, colors) {
        while (to < from) {
            to += 1440;
        }
        var step = (to - from) / colors.length;
        for (var i = 0; i < colors.length; ++i) {
            ctx.fillStyle = colors[i];
            // A hair of overlap so no seam shows between bands
            wedge(ctx, from + step * i, Math.min(to, from + step * (i + 1) + 0.5));
        }
    }

    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        if (width <= 0 || height <= 0) {
            return;
        }
        ctx.save();
        ctx.beginPath();
        ctx.roundedRect(0, 0, width, height, radius, radius);
        ctx.clip();

        ctx.fillStyle = nightColor;
        ctx.fillRect(0, 0, width, height);

        if (times && times.length >= 6) {
            var fajr = Dial.toMinutes(times[0]);
            var sunrise = Dial.toMinutes(times[1]);
            var maghrib = Dial.toMinutes(times[4]);
            var isha = Dial.toMinutes(times[5]);

            var day = ctx.createLinearGradient(0, 0, 0, Math.max(1, centreY));
            day.addColorStop(0, dayTopColor);
            day.addColorStop(1, dayHorizonColor);
            ctx.fillStyle = day;
            wedge(ctx, sunrise, maghrib);

            // Dawn runs night -> day, dusk day -> night
            band(ctx, fajr, sunrise, twilightColors);
            band(ctx, maghrib, isha, twilightColors.slice().reverse());
        }
        ctx.restore();
    }
}
