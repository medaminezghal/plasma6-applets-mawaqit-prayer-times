pragma ComponentBehavior: Bound

import QtQuick

/* The Horizon layout's foreground: the countdown to the next prayer in the
 * sky, with a thin line under it filling from the previous prayer to the
 * next, and the prayers on frosted cards standing on the ground. The scene
 * itself is HorizonBackground, behind the whole widget.
 *
 * Only QtQuick is used and everything comes in through the properties, like
 * the other layouts. It fills the space the Classic table sets, so
 * switching layout never resizes the widget or the popup; when that space
 * is tight the text shrinks to fit. It tells FullRepresentation where the
 * cards start (the horizon) and where the countdown ends, in its own
 * coordinates. */
Item {
    id: view

    /* ----------------------------- input ----------------------------- */
    property var times: null          // ["HH:MM" x 6], to fade the prayers already past
    property real minutes: 0          // minutes since midnight
    property var names: []            // prayer names, Fajr..Isha incl. sunrise
    property var timeLabels: []       // times as displayed (12/24 h)
    property int nextIndex: -1
    property string countdownText: ""
    property real progress: 0         // 0..1 from the previous prayer to the next
    property bool showSunrise: true
    property bool boldNext: true

    property string fontFamily: ""
    property real pointSize: 10
    property real sizeScale: 1
    property color inkColor: "white"  // text in the sky; the cards are always white

    /* ---------------------------- output ----------------------------- */
    readonly property real horizonY: cardsRow.y - gap
    readonly property real textBottom: countdownBlock.y + countdownBlock.height

    /* --------------------------- derived ----------------------------- */
    readonly property var shownIndexes: showSunrise ? [0, 1, 2, 3, 4, 5] : [0, 2, 3, 4, 5]
    readonly property real gap: Math.max(3, Math.round(6 * sizeScale))
    readonly property real cardGap: Math.max(2, Math.round(4 * sizeScale))
    // Little side padding: with six cards side by side every pixel goes to the times
    readonly property real cardPad: Math.max(1, Math.round(2 * sizeScale))
    readonly property real cellWidth: Math.max(1, (width - cardGap * (shownIndexes.length - 1))
                                                  / shownIndexes.length)

    readonly property real nameRatio: 0.85
    readonly property real timeRatio: 1.15
    readonly property real countdownRatio: 2.2
    readonly property real labelRatio: 0.9

    FontMetrics {
        id: nameMetrics
        font.family: view.fontFamily
        font.pointSize: view.pointSize * view.nameRatio
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
        font.weight: Font.Medium
    }
    FontMetrics {
        id: labelMetrics
        font.family: view.fontFamily
        font.pointSize: view.pointSize * view.labelRatio
    }

    readonly property real widestName: {
        void nameMetrics.font;
        var w = 0;
        for (var k = 0; k < shownIndexes.length; ++k) {
            var i = shownIndexes[k];
            w = Math.max(w, nameMetrics.advanceWidth(names && names.length > i ? names[i] : ""));
        }
        return w;
    }
    readonly property real widestTime: {
        void timeMetrics.font;
        var w = 0;
        for (var k = 0; k < shownIndexes.length; ++k) {
            var i = shownIndexes[k];
            w = Math.max(w, timeMetrics.advanceWidth(timeLabels && timeLabels.length > i ? timeLabels[i] : ""));
        }
        return w;
    }
    readonly property real countdownWidth: {
        void countdownMetrics.font;
        return countdownMetrics.advanceWidth("00:00:00");
    }
    /* Each kind of text has its own fit, so a long name in a narrow card
     * does not shrink the times or the countdown with it; then one factor
     * shrinks everything together if the whole would be too tall, leaving
     * a band of sky between the countdown and the cards. */
    readonly property real nameFit: widestName > 0
                                    ? Math.min(1, (cellWidth - cardPad * 2) / (widestName * 1.08)) : 1
    readonly property real timeFit: widestTime > 0
                                    ? Math.min(1, (cellWidth - cardPad * 2) / (widestTime * 1.08)) : 1
    readonly property real countdownFit: countdownWidth > 0
                                         ? Math.min(1, width * 0.9 / countdownWidth) : 1
    readonly property real fullCardHeight: nameMetrics.height * nameFit + timeMetrics.height * timeFit
    readonly property real tallFit: {
        var tall = fullCardHeight + countdownMetrics.height * countdownFit + labelMetrics.height;
        var room = height - cardPad * 2 - gap * 3 - bar.height;
        return tall > 0 ? Math.max(0.3, Math.min(1, room / (tall * 1.2))) : 1;
    }

    /* --------------------------- countdown --------------------------- */
    Column {
        id: countdownBlock
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Math.round(view.gap / 2)

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: view.countdownText !== ""
            text: view.countdownText
            color: view.inkColor
            font.family: view.fontFamily
            font.pointSize: Math.max(1, view.pointSize * view.countdownRatio * view.countdownFit * view.tallFit)
            font.weight: Font.Medium
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: view.names && view.nextIndex >= 0 && view.names.length > view.nextIndex
                  ? view.names[view.nextIndex] : ""
            color: view.inkColor
            opacity: 0.9
            font.family: view.fontFamily
            font.pointSize: Math.max(1, view.pointSize * view.labelRatio * view.tallFit)
        }
        // Fills from the previous prayer to the next, from the start side
        // of the reading direction, like a progress bar
        Item {
            id: bar
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.round(Math.min(view.width * 0.4, 132 * view.sizeScale))
            height: Math.max(2, Math.round(3 * view.sizeScale))

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: view.inkColor
                opacity: 0.22
            }
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * Math.max(0, Math.min(1, view.progress))
                radius: height / 2
                color: view.inkColor
            }
        }
    }

    /* ----------------------------- cards ----------------------------- */
    Row {
        id: cardsRow
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: view.cardGap

        Repeater {
            model: view.shownIndexes
            delegate: Rectangle {
                id: card
                required property int modelData
                readonly property bool isNext: modelData === view.nextIndex
                readonly property bool isSunrise: modelData === 1
                // Past today; before Fajr the whole day is still ahead
                readonly property bool isPast: {
                    if (isNext || !view.times || view.times.length < 6) {
                        return false;
                    }
                    var at = function (hm) {
                        var p = String(hm).split(":");
                        return parseInt(p[0], 10) * 60 + parseInt(p[1], 10);
                    };
                    return view.minutes >= at(view.times[0]) && at(view.times[modelData]) <= view.minutes;
                }

                width: view.cellWidth
                height: Math.ceil(view.fullCardHeight * view.tallFit + view.cardPad * 2)
                radius: Math.min(Math.round(12 * view.sizeScale), height / 3)
                color: Qt.rgba(1, 1, 1, isNext ? 0.24 : 0.08)
                opacity: isPast ? 0.55 : 1

                Column {
                    anchors.centerIn: parent
                    width: parent.width - view.cardPad * 2
                    opacity: card.isSunrise ? 0.6 : 1

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: view.names && view.names.length > card.modelData
                              ? view.names[card.modelData] : ""
                        color: Qt.rgba(1, 1, 1, 0.82)
                        font.family: view.fontFamily
                        font.pointSize: Math.max(1, view.pointSize * view.nameRatio * view.nameFit * view.tallFit)
                        font.weight: card.isNext && view.boldNext ? Font.DemiBold : Font.Normal
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: view.timeLabels && view.timeLabels.length > card.modelData
                              ? view.timeLabels[card.modelData] : ""
                        color: "white"
                        font.family: view.fontFamily
                        font.pointSize: Math.max(1, view.pointSize * view.timeRatio * view.timeFit * view.tallFit)
                        font.weight: card.isNext && view.boldNext ? Font.DemiBold : Font.Normal
                    }
                }
            }
        }
    }
}
