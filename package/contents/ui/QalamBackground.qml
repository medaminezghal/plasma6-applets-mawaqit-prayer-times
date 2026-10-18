import QtQuick

/* The background of the Qalam layout: a sheet of paper with faint fibres
 * and a double ruled frame inside its edge - cream by day, dark at night.
 * The writing on it is QalamView's.
 *
 * Only QtQuick is used; FullRepresentation places it where the theme frame
 * would be, like the other painted backgrounds. */
Canvas {
    id: paper

    property bool night: false
    property real radius: 0
    property real sizeScale: 1

    onNightChanged: requestPaint()
    onRadiusChanged: requestPaint()
    onSizeScaleChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    function rnd(i) {
        var v = Math.sin(i * 127.1 + 311.7) * 43758.5453;
        return v - Math.floor(v);
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

        ctx.fillStyle = night ? "#1e1a16" : "#f4ecdb";
        ctx.fillRect(0, 0, width, height);

        // fibres in the paper, the same everywhere so it never flickers
        ctx.strokeStyle = night ? "rgba(255,240,210,0.04)" : "rgba(140,110,70,0.10)";
        ctx.lineWidth = 0.6;
        var count = Math.round(width * height / 1600);
        for (var f = 0; f < count; ++f) {
            var x = rnd(f) * width, y = rnd(f + 70) * height, l = 6 + rnd(f + 140) * 14;
            ctx.beginPath();
            ctx.moveTo(x, y);
            ctx.quadraticCurveTo(x + l / 2, y + (rnd(f + 3) - 0.5) * 3, x + l, y);
            ctx.stroke();
        }

        // the double ruled frame
        var s = Math.max(0.6, sizeScale);
        var inset = 10 * s, inner = 15 * s;
        var r = Math.max(0, radius - inset);
        ctx.strokeStyle = night ? "rgba(232,200,140,0.35)" : "rgba(140,100,50,0.45)";
        ctx.lineWidth = Math.max(1, s);
        ctx.beginPath();
        ctx.roundedRect(inset + 0.5, inset + 0.5, width - 2 * inset - 1, height - 2 * inset - 1, r, r);
        ctx.stroke();
        ctx.lineWidth = Math.max(0.6, 0.6 * s);
        ctx.beginPath();
        ctx.roundedRect(inner + 0.5, inner + 0.5, width - 2 * inner - 1, height - 2 * inner - 1,
                        Math.max(0, r - 3), Math.max(0, r - 3));
        ctx.stroke();
        ctx.restore();
    }
}
