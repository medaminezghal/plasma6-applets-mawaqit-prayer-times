import QtQuick

/* The background of the Kaaba layout: the black cloth of the Kaaba's cover,
 * with a fine diagonal weave, and the dark band of its gold belt running
 * the full width between double gold borders edged with small diamonds.
 * The cartouches on the band are KaabaView's.
 *
 * Only QtQuick is used; FullRepresentation places it where the theme frame
 * would be, like the other painted backgrounds, and tells it where the band
 * is in its own coordinates. */
Canvas {
    id: cloth

    property real bandTop: height * 0.3
    property real bandBottom: height * 0.6
    property real radius: 0
    property real sizeScale: 1

    onBandTopChanged: requestPaint()
    onBandBottomChanged: requestPaint()
    onRadiusChanged: requestPaint()
    onSizeScaleChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

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

        // The cloth and its weave
        ctx.fillStyle = "#0a0a0a";
        ctx.fillRect(0, 0, width, height);
        ctx.strokeStyle = "#101010";
        ctx.lineWidth = 2.2;
        var step = 6;
        for (var x = -height; x < width; x += step) {
            ctx.beginPath();
            ctx.moveTo(x, height);
            ctx.lineTo(x + height, 0);
            ctx.stroke();
        }

        // The belt's band
        var s = Math.max(0.6, sizeScale);
        ctx.fillStyle = "#060606";
        ctx.fillRect(0, bandTop, width, bandBottom - bandTop);

        var g = ctx.createLinearGradient(0, 0, width, 0);
        g.addColorStop(0, "#9a7628");
        g.addColorStop(0.3, "#e3c170");
        g.addColorStop(0.5, "#c9a24e");
        g.addColorStop(0.7, "#e3c170");
        g.addColorStop(1, "#9a7628");
        ctx.strokeStyle = g;
        ctx.lineWidth = Math.max(1, s);
        var rules = [bandTop + 3.5 * s, bandTop + 7.5 * s, bandBottom - 7.5 * s, bandBottom - 3.5 * s];
        for (var r = 0; r < rules.length; ++r) {
            ctx.beginPath();
            ctx.moveTo(0, Math.round(rules[r]) + 0.5);
            ctx.lineTo(width, Math.round(rules[r]) + 0.5);
            ctx.stroke();
        }

        // Small diamonds just outside the band, above and below
        ctx.fillStyle = g;
        var dz = 2 * s, pitch = 8 * s;
        var rows = [bandTop - 3 * s, bandBottom + 3 * s];
        for (var k = 0; k < rows.length; ++k) {
            var y = rows[k];
            ctx.beginPath();
            for (var dx = pitch / 2; dx < width; dx += pitch) {
                ctx.moveTo(dx - dz, y);
                ctx.lineTo(dx, y - dz);
                ctx.lineTo(dx + dz, y);
                ctx.lineTo(dx, y + dz);
                ctx.closePath();
            }
            ctx.fill();
        }
        ctx.restore();
    }
}
