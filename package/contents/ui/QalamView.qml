pragma ComponentBehavior: Bound

import QtQuick

/* The Qalam layout's foreground: the countdown, a ruled ornament, and the
 * five prayer names written large on the paper. The prayers already prayed
 * today are in dry dark ink; the next one is being written, from the
 * reading side, by a reed pen as its time approaches, its ink still wet;
 * the rest are the calligrapher's faint pencil guide. The paper behind the
 * whole widget, with its ruled frame, is QalamBackground.
 *
 * Only QtQuick is used and everything comes in through the properties.
 * It fills the space the Classic table sets, so switching layout never
 * resizes the widget or the popup; when that space is tight the text
 * shrinks to fit. */
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
    property bool boldNext: true
    property bool night: false        // dark paper and light ink

    property string fontFamily: ""
    property string nameFamily: ""    // a calligraphic family when one is installed
    property real pointSize: 10
    property real sizeScale: 1

    /* ---------------------------- palette ---------------------------- */
    readonly property color ink: night ? "#efe4cf" : "#1e1710"
    readonly property color wetInk: night ? "#f4d79a" : "#3a2410"
    readonly property color wetSheen: night ? "#8a6a2a" : "#a0703a"
    readonly property color guide: night ? Qt.rgba(232 / 255, 220 / 255, 196 / 255, 0.22)
                                         : Qt.rgba(120 / 255, 100 / 255, 70 / 255, 0.30)
    readonly property color soft: night ? Qt.rgba(242 / 255, 230 / 255, 206 / 255, 0.72)
                                        : Qt.rgba(60 / 255, 44 / 255, 26 / 255, 0.72)
    readonly property color rule: night ? Qt.rgba(232 / 255, 200 / 255, 140 / 255, 0.4)
                                        : Qt.rgba(140 / 255, 100 / 255, 50 / 255, 0.5)

    /* --------------------------- derived ----------------------------- */
    // The five prayers; sunrise is not written
    readonly property var prayers: [0, 2, 3, 4, 5]
    readonly property bool mirrored: LayoutMirroring.enabled
    readonly property real gap: Math.max(3, Math.round(6 * sizeScale))
    readonly property real cellWidth: Math.max(1, width / 5)

    readonly property real nameRatio: 2.0
    readonly property real timeRatio: 1.05
    readonly property real countdownRatio: 2.4
    readonly property real labelRatio: 1.05

    FontMetrics {
        id: nameMetrics
        font.family: view.nameFamily !== "" ? view.nameFamily : view.fontFamily
        font.pointSize: view.pointSize * view.nameRatio
        font.weight: Font.Bold
    }
    FontMetrics {
        id: timeMetrics
        font.family: view.fontFamily
        font.pointSize: view.pointSize * view.timeRatio
        font.weight: Font.DemiBold
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

    readonly property real widestName: {
        void nameMetrics.font;
        var w = 0;
        for (var k = 0; k < prayers.length; ++k) {
            var i = prayers[k];
            w = Math.max(w, nameMetrics.advanceWidth(names && names.length > i ? names[i] : ""));
        }
        return w;
    }
    readonly property real widestTime: {
        void timeMetrics.font;
        var w = 0;
        for (var k = 0; k < prayers.length; ++k) {
            var i = prayers[k];
            w = Math.max(w, timeMetrics.advanceWidth(timeLabels && timeLabels.length > i ? timeLabels[i] : ""));
        }
        return w;
    }
    readonly property real countdownWidth: {
        void countdownMetrics.font;
        return countdownMetrics.advanceWidth("00:00:00");
    }
    /* Each kind of text has its own fit, so five long names in narrow cells
     * do not shrink the countdown or the times with them; then one factor
     * shrinks everything together if the whole would be too tall. */
    readonly property real nameFit: widestName > 0
                                    ? Math.min(1, (cellWidth - gap * 0.5) / (widestName * 1.04)) : 1
    readonly property real timeFit: widestTime > 0
                                    ? Math.min(1, (cellWidth - gap) / (widestTime * 1.05)) : 1
    readonly property real countdownFit: countdownWidth > 0
                                         ? Math.min(1, width * 0.9 / countdownWidth) : 1
    readonly property real tallFit: {
        var tall = countdownMetrics.height * countdownFit + labelMetrics.height
                   + nameMetrics.height * nameFit + timeMetrics.height * timeFit;
        return tall > 0 ? Math.min(1, (height - gap * 4 - ornament.height) / (tall * 1.08)) : 1;
    }
    readonly property real fullCell: nameMetrics.height * nameFit + timeMetrics.height * timeFit

    function minutesOf(hm) {
        var p = String(hm).split(":");
        return parseInt(p[0], 10) * 60 + parseInt(p[1], 10);
    }
    // 1 when written, the progress when it is the next prayer, else 0
    function written(i) {
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
    // Left edge of the k-th cell: Fajr first in reading order
    function cellX(k) {
        return mirrored ? width - (k + 1) * cellWidth : k * cellWidth;
    }

    /* --------------------------- countdown --------------------------- */
    Column {
        id: header
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: view.countdownText !== ""
            text: view.countdownText
            color: view.ink
            font.family: view.fontFamily
            font.pointSize: Math.max(1, view.pointSize * view.countdownRatio * view.countdownFit * view.tallFit)
            font.weight: Font.DemiBold
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: view.names && view.nextIndex >= 0 && view.names.length > view.nextIndex
                  ? view.names[view.nextIndex] : ""
            color: view.soft
            font.family: view.fontFamily
            font.pointSize: Math.max(1, view.pointSize * view.labelRatio * view.tallFit)
        }
    }

    /* ---------------------------- ornament --------------------------- *
     * Two ruled lines and a small diamond between them, between the
     * countdown and the names */
    Item {
        id: ornament
        anchors.top: header.bottom
        anchors.topMargin: view.gap
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(view.width * 0.6, 170 * view.sizeScale)
        height: Math.max(8, Math.round(12 * view.sizeScale))

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            width: parent.width / 2 - parent.height
            height: 1
            color: view.rule
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            width: parent.width / 2 - parent.height
            height: 1
            color: view.rule
        }
        Rectangle {
            anchors.centerIn: parent
            width: parent.height * 0.6
            height: width
            rotation: 45
            color: "transparent"
            border.color: view.rule
            border.width: Math.max(1, Math.round(1.5 * view.sizeScale))
        }
    }

    /* ----------------------------- names ----------------------------- */
    // A prayer's name over its time, in pencil or in ink
    component Lines: Column {
        id: lines
        property int prayerIndex: 0
        property real boxWidth: 0
        property color nameInk
        property color timeInk
        property bool wet: false
        property bool bold: false
        anchors.horizontalCenter: parent.horizontalCenter
        width: boxWidth

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: view.names && view.names.length > lines.prayerIndex ? view.names[lines.prayerIndex] : ""
            color: lines.nameInk
            // fresh ink catches the light
            style: lines.wet ? Text.Raised : Text.Normal
            styleColor: view.wetSheen
            font.family: view.nameFamily !== "" ? view.nameFamily : view.fontFamily
            font.pointSize: Math.max(1, view.pointSize * view.nameRatio * view.nameFit * view.tallFit)
            font.weight: lines.bold ? Font.Bold : Font.Normal
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: view.timeLabels && view.timeLabels.length > lines.prayerIndex
                  ? view.timeLabels[lines.prayerIndex] : ""
            color: lines.timeInk
            font.family: view.fontFamily
            font.pointSize: Math.max(1, view.pointSize * view.timeRatio * view.timeFit * view.tallFit)
            font.weight: lines.bold ? Font.DemiBold : Font.Normal
        }
    }

    Repeater {
        model: view.prayers
        delegate: Item {
            id: cell
            required property int modelData
            required property int index
            readonly property real done: view.written(modelData)
            readonly property bool isNext: modelData === view.nextIndex

            x: view.cellX(index)
            y: ornament.y + ornament.height + Math.max(view.gap, (view.height - ornament.y - ornament.height - height) / 2)
            width: view.cellWidth
            height: Math.ceil(view.fullCell * view.tallFit)

            // The pencil guide, until the ink covers it
            Lines {
                prayerIndex: cell.modelData
                boxWidth: cell.width
                nameInk: view.guide
                timeInk: view.guide
                visible: cell.done < 1
            }

            // The ink, written from the reading side as the time approaches;
            // anchors follow the layout direction, so this starts on the
            // right in Arabic
            Item {
                id: reveal
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * cell.done
                clip: true
                visible: cell.done > 0

                Item {
                    // Keeps the text where it is while the window grows
                    width: cell.width
                    height: cell.height
                    x: view.mirrored ? reveal.width - cell.width : 0

                    Lines {
                        prayerIndex: cell.modelData
                        boxWidth: cell.width
                        nameInk: cell.isNext ? view.wetInk : view.ink
                        timeInk: cell.isNext ? view.wetInk : view.soft
                        wet: cell.isNext
                        bold: cell.isNext && view.boldNext
                    }
                }
            }

            // The reed pen, its nib where the writing has reached
            Canvas {
                id: pen
                visible: cell.isNext && cell.done > 0.01 && cell.done < 0.99
                width: Math.max(12, 22 * view.sizeScale)
                height: Math.max(20, 36 * view.sizeScale)
                readonly property real edge: view.mirrored ? cell.width - reveal.width : reveal.width
                x: edge - (view.mirrored ? width * 0.04 : width * 0.96)
                y: -height * 0.55
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Connections {
                    target: view
                    function onMirroredChanged() { pen.requestPaint(); }
                }
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    var w = width, h = height;
                    // drawn leaning toward the unwritten side, nib at the bottom
                    if (!view.mirrored) {
                        ctx.translate(w, 0);
                        ctx.scale(-1, 1);
                    }
                    // the reed
                    ctx.fillStyle = "#9c7a4c";
                    ctx.beginPath();
                    ctx.moveTo(w * 0.14, h * 0.88);
                    ctx.lineTo(w * 0.78, h * 0.04);
                    ctx.lineTo(w * 0.94, h * 0.12);
                    ctx.lineTo(w * 0.3, h * 0.92);
                    ctx.closePath();
                    ctx.fill();
                    // its inked nib, touching the paper at the bottom-left
                    ctx.fillStyle = "#2a1f14";
                    ctx.beginPath();
                    ctx.moveTo(w * 0.14, h * 0.88);
                    ctx.lineTo(w * 0.3, h * 0.92);
                    ctx.lineTo(w * 0.04, h);
                    ctx.closePath();
                    ctx.fill();
                    ctx.strokeStyle = "#c9a877";
                    ctx.lineWidth = Math.max(0.6, 0.8 * view.sizeScale);
                    ctx.beginPath();
                    ctx.moveTo(w * 0.3, h * 0.75);
                    ctx.lineTo(w * 0.68, h * 0.25);
                    ctx.stroke();
                }
            }
        }
    }
}
