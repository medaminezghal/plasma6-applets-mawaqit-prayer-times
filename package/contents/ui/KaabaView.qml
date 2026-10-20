pragma ComponentBehavior: Bound

import QtQuick

/* The Kaaba layout's foreground: the gold belt (hizam) of the Kaaba's
 * cover with one cartouche per prayer, and the countdown under it. The
 * prayers already prayed today are embroidered in gold; the next one is
 * being stitched as its time approaches - a needle runs a gold thread
 * round its frame while its name fills in with gold - and the rest are
 * still the embroiderer's chalk sketch. The black cloth behind the whole
 * widget, with the belt's band and borders, is KaabaBackground.
 *
 * Only QtQuick is used and everything comes in through the properties.
 * It fills the space the Classic table sets, so switching layout never
 * resizes the widget or the popup; when that space is tight the text
 * shrinks to fit. It tells FullRepresentation where the band is, in its
 * own coordinates. */
Item {
    id: view

    /* ----------------------------- input ----------------------------- */
    property var times: null          // ["HH:MM" x 6], Fajr..Isha incl. sunrise
    property real minutes: 0          // minutes since midnight
    property var names: []            // prayer names, same order
    property var timeLabels: []       // times as displayed (12/24 h)
    property int nextIndex: -1
    property bool nextIsTomorrow: false
    property string countdownText: ""
    property real progress: 0         // 0..1 from the previous prayer to the next

    property string fontFamily: ""
    property real pointSize: 10
    property real sizeScale: 1
    property color labelColor: "#d8cdb2"

    /* ---------------------------- output ----------------------------- */
    readonly property real bandTop: 0
    readonly property real bandBottom: bandHeight

    /* ---------------------------- palette ---------------------------- */
    readonly property color gold: "#ebcb7c"
    readonly property color goldEdge: "#4a3510"
    readonly property color ghost: "#77705f"
    readonly property color sketch: "#6e6758"

    /* --------------------------- derived ----------------------------- */
    // The five prayers; sunrise has no place on the belt
    readonly property var prayers: [0, 2, 3, 4, 5]
    readonly property bool mirrored: LayoutMirroring.enabled
    readonly property real gap: Math.max(3, Math.round(5 * sizeScale))
    readonly property real pad: Math.max(2, Math.round(3 * sizeScale))
    // Room between the band's gold borders and the cartouches
    readonly property real bandPad: Math.max(5, Math.round(10 * sizeScale))
    readonly property real cellWidth: Math.max(1, (width - gap * 4) / 5)

    readonly property real nameRatio: 1.05
    readonly property real timeRatio: 1.0
    readonly property real countdownRatio: 2.4
    readonly property real labelRatio: 1.0

    FontMetrics {
        id: nameMetrics
        font.family: view.fontFamily
        font.pointSize: view.pointSize * view.nameRatio
        font.weight: Font.Bold
    }
    FontMetrics {
        id: timeMetrics
        font.family: view.fontFamily
        font.pointSize: view.pointSize * view.timeRatio
    }
    FontMetrics {
        id: countdownMetrics
        font.family: view.fontFamily
        font.pointSize: view.pointSize * view.countdownRatio
        font.weight: Font.DemiBold
    }
    FontMetrics {
        id: labelMetrics
        font.family: view.fontFamily
        font.pointSize: view.pointSize * view.labelRatio
    }

    readonly property real widestText: {
        void [nameMetrics.font, timeMetrics.font];
        var w = 0;
        for (var k = 0; k < prayers.length; ++k) {
            var i = prayers[k];
            var name = names && names.length > i ? names[i] : "";
            var time = timeLabels && timeLabels.length > i ? timeLabels[i] : "";
            w = Math.max(w, nameMetrics.advanceWidth(name), timeMetrics.advanceWidth(time));
        }
        return w;
    }
    readonly property real countdownWidth: {
        void countdownMetrics.font;
        return countdownMetrics.advanceWidth("00:00:00");
    }
    readonly property real fullCardText: nameMetrics.height + timeMetrics.height
    readonly property real fullBelow: countdownMetrics.height + labelMetrics.height
    // One factor shrinks all the text together when it would not fit
    readonly property real fit: {
        // The cartouche is widest at mid-height, where the text sits, so
        // only the padding and a sliver for the slanted edges are lost
        var byCards = widestText > 0 ? (cellWidth - pad * 2 - pointDepth) / (widestText * 1.05) : 1;
        var tall = fullCardText + fullBelow;
        var byHeight = tall > 0 ? (height - bandPad * 2 - pad * 2 - gap * 2) / (tall * 1.15) : 1;
        return Math.max(0.3, Math.min(1, byCards, byHeight));
    }
    // Taller than the text needs when there is room, like the belt's
    // cartouches, but never so tall that the countdown is squeezed
    readonly property real cardHeight: {
        var textHeight = fullCardText * fit + pad * 2;
        return Math.ceil(Math.max(textHeight, Math.min(height * 0.34, textHeight * 1.7)));
    }
    // The countdown has its own fit: it is not held back by narrow cartouches
    readonly property real countdownFit: {
        var room = height - bandHeight - gap * 2;
        var byWidth = countdownWidth > 0 ? width / (countdownWidth * 1.15) : 1;
        var byHeight = fullBelow > 0 ? room / (fullBelow * 1.15) : 1;
        return Math.max(0.3, Math.min(1.25, byWidth, byHeight));
    }
    readonly property real pointDepth: Math.max(3, Math.min(8 * sizeScale, cellWidth * 0.12))
    readonly property real bandHeight: cardHeight + bandPad * 2

    function minutesOf(hm) {
        var p = String(hm).split(":");
        return parseInt(p[0], 10) * 60 + parseInt(p[1], 10);
    }
    // 1 when embroidered, the progress when it is the next prayer, else 0
    function stitched(i) {
        if (i === nextIndex) {
            return Math.max(0, Math.min(1, progress));
        }
        if (!times || times.length < 6) {
            return 0;
        }
        if (nextIsTomorrow) {
            return 1;
        }
        return (minutes >= minutesOf(times[0]) && minutesOf(times[i]) <= minutes) ? 1 : 0;
    }
    // Left edge of the k-th cartouche: Fajr first in reading order
    function cellX(k) {
        return mirrored ? width - (k + 1) * cellWidth - k * gap : k * (cellWidth + gap);
    }

    /* -------------------------- cartouches --------------------------- *
     * Outlines, thread and needle are drawn here; the names and times are
     * Text items above, so they take the user's font like the rest. */
    Canvas {
        id: frames
        anchors.fill: parent

        // Repaint when anything drawn changes
        readonly property var watch: [view.width, view.cellWidth, view.cardHeight, view.bandPad,
                                      view.progress, view.nextIndex, view.nextIsTomorrow,
                                      view.minutes, view.times, view.mirrored]
        onWatchChanged: requestPaint()

        function corners(x, y, w, h, d) {
            // Start at the top corner on the reading side, so the thread
            // runs in the reading direction
            if (view.mirrored) {
                return [[x + w - d, y], [x + d, y], [x, y + h / 2], [x + d, y + h],
                        [x + w - d, y + h], [x + w, y + h / 2]];
            }
            return [[x + d, y], [x + w - d, y], [x + w, y + h / 2], [x + w - d, y + h],
                    [x + d, y + h], [x, y + h / 2]];
        }
        function outline(ctx, pts) {
            ctx.beginPath();
            ctx.moveTo(pts[0][0], pts[0][1]);
            for (var i = 1; i < pts.length; ++i) {
                ctx.lineTo(pts[i][0], pts[i][1]);
            }
            ctx.closePath();
        }
        function goldStroke(ctx, x, w) {
            var g = ctx.createLinearGradient(x, 0, x + w, 0);
            g.addColorStop(0, "#9a7628");
            g.addColorStop(0.45, "#e3c170");
            g.addColorStop(0.5, "#fff0c4");
            g.addColorStop(0.55, "#e3c170");
            g.addColorStop(1, "#9a7628");
            return g;
        }

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            if (width <= 0 || height <= 0) {
                return;
            }
            var y = view.bandPad, h = view.cardHeight, w = view.cellWidth;
            var d = Math.min(view.pointDepth, w / 4, h / 3);
            var line = Math.max(1, 1.6 * view.sizeScale);
            ctx.lineJoin = "round";
            ctx.lineCap = "round";

            for (var k = 0; k < view.prayers.length; ++k) {
                var i = view.prayers[k];
                var x = view.cellX(k);
                var pts = corners(x, y, w, h, d);
                var p = view.stitched(i);

                if (p < 1) {
                    // The chalk sketch under the work still to do
                    ctx.save();
                    ctx.strokeStyle = view.sketch;
                    ctx.lineWidth = Math.max(1, view.sizeScale);
                    var dash = Math.max(1.5, 2 * view.sizeScale);
                    ctx.setLineDash([dash, dash * 1.5]);
                    outline(ctx, pts);
                    ctx.stroke();
                    ctx.restore();
                }
                if (p <= 0) {
                    continue;
                }

                ctx.strokeStyle = goldStroke(ctx, x, w);
                ctx.lineWidth = line;
                if (p >= 1) {
                    outline(ctx, pts);
                    ctx.stroke();
                    continue;
                }

                // The thread so far, then the needle where it has reached
                var total = 0, segs = [];
                for (var s = 0; s < 6; ++s) {
                    var a = pts[s], b = pts[(s + 1) % 6];
                    var len = Math.sqrt((b[0] - a[0]) * (b[0] - a[0]) + (b[1] - a[1]) * (b[1] - a[1]));
                    segs.push([a, b, len]);
                    total += len;
                }
                var left = p * total, end = pts[0], seg = 0;
                ctx.beginPath();
                ctx.moveTo(pts[0][0], pts[0][1]);
                for (var j = 0; j < segs.length && left > 0; ++j) {
                    var t = Math.min(1, left / segs[j][2]);
                    end = [segs[j][0][0] + (segs[j][1][0] - segs[j][0][0]) * t,
                           segs[j][0][1] + (segs[j][1][1] - segs[j][0][1]) * t];
                    ctx.lineTo(end[0], end[1]);
                    left -= segs[j][2];
                    seg = j;
                }
                ctx.stroke();

                // The needle stands out of the cartouche, never across its
                // text: up from the upper half of the outline and down from
                // the lower half, leaning the way the thread runs, so it
                // never crosses a name, a time or the next cartouche
                var u = view.sizeScale;
                var sa = segs[seg][0], sb = segs[seg][1];
                var tx = (sb[0] - sa[0]) / segs[seg][2], ty = (sb[1] - sa[1]) / segs[seg][2];
                var vy = (end[1] < y + h / 2 || (end[1] === y + h / 2 && ty < 0)) ? -1 : 1;
                var lean = Math.abs(tx) > 0.1 ? (tx > 0 ? 1 : -1) : (view.mirrored ? -1 : 1);
                // Full length until less outline is left than the needle is
                // long, then as long as what is left
                var rest = (1 - p) * total;
                var want = Math.min(Math.max(9, 14 * u), rest);
                // On a slanted side, leaning toward the middle would cut the
                // corner of the cartouche, and near the widget's edge leaning
                // out would leave it: stand straight then
                var onSlant = Math.abs(ty) > 0.3;
                var towardMiddle = (end[0] < x + w / 2) === (lean > 0);
                var lx = 0.55 / Math.sqrt(1 + 0.55 * 0.55);
                if ((onSlant && towardMiddle)
                        || (lean > 0 && end[0] + lx * want > width - 1)
                        || (lean < 0 && end[0] - lx * want < 1)) {
                    lean = 0;
                }
                var dx = lean * lx, dy = vy * Math.sqrt(1 - dx * dx);
                var nl = dy < 0 ? Math.min(want, (end[1] - 1) / -dy)
                                : Math.min(want, (height - 1 - end[1]) / dy);
                nl = Math.max(Math.min(want, 3 * u), nl);
                var tipX = end[0] + dx * nl, tipY = end[1] + dy * nl;
                ctx.strokeStyle = "#ece6d6";
                ctx.lineWidth = Math.max(1, 1.3 * u);
                ctx.beginPath();
                ctx.moveTo(end[0], end[1]);
                ctx.lineTo(tipX, tipY);
                ctx.stroke();
                // The thread left on the needle is the outline still to
                // stitch, at a third of its length. It lies loose along the
                // band's edge, outside every cartouche, away from the middle
                // of this one, or back the other way near the widget's edge.
                var fx = lean !== 0 ? lean : (end[0] < x + w / 2 ? -1 : 1);
                var slack = rest / 3;
                var room = fx > 0 ? width - 1 - tipX : tipX - 1;
                if (room < slack) {
                    var other = fx > 0 ? tipX - 1 : width - 1 - tipX;
                    if (other > room) {
                        fx = -fx;
                        room = other;
                    }
                }
                // A gentle wave, so it reads as slack thread
                var amp = 1.2 * u, wave = 7 * u;
                var run = Math.min(room, slack / 1.08);
                var steps = Math.max(2, Math.ceil(run / (1.5 * u)));
                ctx.strokeStyle = view.gold;
                ctx.lineWidth = Math.max(0.6, 0.8 * u);
                ctx.beginPath();
                ctx.moveTo(tipX, tipY);
                for (var q = 1; q <= steps; ++q) {
                    var r = run * q / steps;
                    var lift = Math.min(1, r / (4 * u));
                    ctx.lineTo(tipX + fx * r, tipY + Math.sin(2 * Math.PI * r / wave) * amp * lift);
                }
                ctx.stroke();
            }
        }
    }

    // A cartouche's name over its time, in sketch grey or in gold
    component Lines: Column {
        id: lines
        property int prayerIndex: 0
        property real boxWidth: 0
        property color ink
        property bool raised: false
        anchors.centerIn: parent
        width: boxWidth - view.pad * 2 - view.pointDepth

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: view.names && view.names.length > lines.prayerIndex ? view.names[lines.prayerIndex] : ""
            color: lines.ink
            style: lines.raised ? Text.Raised : Text.Normal
            styleColor: view.goldEdge
            font.family: view.fontFamily
            font.pointSize: view.pointSize * view.nameRatio * view.fit
            font.weight: Font.Bold
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: view.timeLabels && view.timeLabels.length > lines.prayerIndex
                  ? view.timeLabels[lines.prayerIndex] : ""
            color: lines.ink
            style: lines.raised ? Text.Raised : Text.Normal
            styleColor: view.goldEdge
            font.family: view.fontFamily
            font.pointSize: view.pointSize * view.timeRatio * view.fit
        }
    }

    Repeater {
        model: view.prayers
        delegate: Item {
            id: cartouche
            required property int modelData
            required property int index
            readonly property real done: view.stitched(modelData)

            x: view.cellX(index)
            y: view.bandPad
            width: view.cellWidth
            height: view.cardHeight

            // The sketch, until the gold covers it
            Lines {
                prayerIndex: cartouche.modelData
                boxWidth: cartouche.width
                ink: view.ghost
                visible: cartouche.done < 1
            }

            // The gold, revealed from the reading side as the thread goes on;
            // anchors follow the layout direction, so this starts on the
            // right in Arabic
            Item {
                id: reveal
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * cartouche.done
                clip: true
                visible: cartouche.done > 0

                Item {
                    // Keeps the text where it is while the window grows
                    width: cartouche.width
                    height: cartouche.height
                    x: view.mirrored ? reveal.width - cartouche.width : 0

                    Lines {
                        prayerIndex: cartouche.modelData
                        boxWidth: cartouche.width
                        ink: view.gold
                        raised: true
                    }
                }
            }
        }
    }

    /* --------------------------- countdown --------------------------- */
    Column {
        anchors.top: parent.top
        anchors.topMargin: view.bandHeight
                           + Math.max(view.gap, (view.height - view.bandHeight - height) / 2)
        anchors.horizontalCenter: parent.horizontalCenter

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: view.countdownText !== ""
            text: view.countdownText
            color: view.gold
            style: Text.Raised
            styleColor: view.goldEdge
            font.family: view.fontFamily
            font.pointSize: view.pointSize * view.countdownRatio * view.countdownFit
            font.weight: Font.DemiBold
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: view.names && view.nextIndex >= 0 && view.names.length > view.nextIndex
                  ? view.names[view.nextIndex] : ""
            color: view.labelColor
            font.family: view.fontFamily
            font.pointSize: view.pointSize * view.labelRatio * Math.min(1, view.countdownFit)
        }
    }
}
