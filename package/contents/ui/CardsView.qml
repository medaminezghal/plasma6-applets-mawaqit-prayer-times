pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes

/* The Cards layout: a half-circle gauge with the countdown to the next
 * prayer in it, filling up from the previous prayer to the next, above one
 * card per prayer, three to a row.
 *
 * Only QtQuick is used here and everything it shows comes in through the
 * properties below, like SundialView. It always fills the space it is
 * given: the size of the expanded view is set by the Classic table, so
 * switching layout never resizes the widget or the popup. When that space
 * is tight the text shrinks to fit rather than the view growing. */
Item {
    id: cards

    /* ----------------------------- input ----------------------------- */
    property var times: null          // ["HH:MM" x 6], Fajr..Isha incl. sunrise
    property var names: []            // prayer names, same order
    property var timeLabels: []       // times as displayed (12/24 h)
    property int nextIndex: -1
    property string countdownText: ""
    property real progress: 0         // 0..1 from the previous prayer to the next
    property bool showSunrise: true
    property bool boldNext: true

    property string fontFamily: ""
    property real pointSize: 10
    property real sizeScale: 1        // the widget-size slider
    property real cornerRadius: 4
    property color textColor: "black"
    property color accentColor: "#3daee9"

    /* --------------------------- derived ----------------------------- */
    readonly property bool hasTimes: times !== null && times !== undefined
                                     && times.length >= 6

    // Prayers shown, in order; the first three make the top row
    readonly property var shownIndexes: showSunrise ? [0, 1, 2, 3, 4, 5] : [0, 2, 3, 4, 5]
    readonly property var topRow: shownIndexes.slice(0, 3)
    readonly property var bottomRow: shownIndexes.slice(3)

    readonly property real gap: Math.max(2, Math.round(4 * sizeScale))
    readonly property real cardPad: Math.max(2, Math.round(4 * sizeScale))
    readonly property real stroke: Math.max(4, Math.round(8 * sizeScale))
    readonly property real cellWidth: Math.max(1, (width - gap * 2) / 3)

    readonly property real nameRatio: 0.9
    readonly property real timeRatio: 1.25
    readonly property real countdownRatio: 1.7

    /* ------------------------------ fit ------------------------------ *
     * Everything is measured at full size, then one factor shrinks all the
     * text together when the cards would be too narrow or the cards plus
     * the gauge too tall. Font heights scale with the point size, so the
     * measured heights times the factor are what the scaled text needs. */
    FontMetrics {
        id: nameMetrics
        font.family: cards.fontFamily
        font.pointSize: cards.pointSize * cards.nameRatio
    }
    FontMetrics {
        id: timeMetrics
        font.family: cards.fontFamily
        font.pointSize: cards.pointSize * cards.timeRatio
        font.weight: Font.Bold
    }
    FontMetrics {
        id: countdownMetrics
        font.family: cards.fontFamily
        font.pointSize: cards.pointSize * cards.countdownRatio
        font.weight: Font.DemiBold
    }

    readonly property real widestCard: {
        // advanceWidth() is a call, so name the fonts to re-measure when
        // the family or size changes
        void [nameMetrics.font, timeMetrics.font];
        var w = 0;
        for (var k = 0; k < shownIndexes.length; ++k) {
            var i = shownIndexes[k];
            var name = names && names.length > i ? names[i] : "";
            var time = timeLabels && timeLabels.length > i ? timeLabels[i] : "";
            w = Math.max(w, nameMetrics.advanceWidth(name), timeMetrics.advanceWidth(time));
        }
        return w;
    }
    readonly property real fullCardHeight: nameMetrics.height + timeMetrics.height
    // The gauge needs at least room for the countdown inside the half circle
    readonly property real fullGaugeHeight: countdownMetrics.height * 1.9
    readonly property real fit: {
        // Text width does not shrink exactly with the point size (hinting,
        // rounding), so leave a little slack rather than elide a time
        var byWidth = widestCard > 0 ? (cellWidth - cardPad * 2) / (widestCard * 1.1) : 1;
        var tall = (fullCardHeight * 2 + fullGaugeHeight);
        var byHeight = tall > 0 ? (height - cardPad * 4 - gap * 2 - stroke) / tall : 1;
        return Math.max(0.3, Math.min(1, byWidth, byHeight));
    }

    readonly property real cardHeight: Math.ceil(fullCardHeight * fit + cardPad * 2)
    readonly property real gridHeight: cardHeight * 2 + gap
    // The gauge takes whatever the cards leave
    readonly property real gaugeHeight: Math.max(0, height - gridHeight - gap)

    /* ----------------------------- gauge ----------------------------- *
     * A half circle standing on its ends; the round caps reach half a
     * stroke below them, which is kept free above the cards. It fills from
     * the left, or from the right when the layout is mirrored, like a
     * progress bar. */
    Item {
        id: gauge
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: cards.gaugeHeight
        visible: cards.hasTimes

        readonly property bool mirrored: LayoutMirroring.enabled
        readonly property real centreX: width / 2
        readonly property real centreY: height - cards.stroke / 2
        readonly property real radius: Math.max(1, Math.min(height - cards.stroke,
                                                             width * 0.3))
        // The countdown stays clear of the stroke: its height within the
        // radius, its width within the inner diameter at its own height.
        // Measured on "00:00:00" so the size holds still as the digits tick.
        readonly property real inner: radius - cards.stroke / 2
        readonly property real textFit: {
            void countdownMetrics.font;
            var h = countdownMetrics.height * 1.1;
            var w = countdownMetrics.advanceWidth(cards.countdownText.length > 5 ? "00:00:00" : "00:00");
            return Math.max(0.3, Math.min(1, inner / h, inner * 1.6 / Math.max(1, w)));
        }
        readonly property color trackColor: Qt.rgba(cards.textColor.r, cards.textColor.g,
                                                     cards.textColor.b, 0.15)

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: "transparent"
                strokeColor: gauge.trackColor
                strokeWidth: cards.stroke
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: gauge.centreX
                    centerY: gauge.centreY
                    radiusX: gauge.radius
                    radiusY: gauge.radius
                    startAngle: 180
                    sweepAngle: 180
                }
            }

            ShapePath {
                fillColor: "transparent"
                // Nothing at all at zero: a round cap alone would be a dot
                strokeColor: cards.progress > 0 ? cards.accentColor : "transparent"
                strokeWidth: cards.stroke
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: gauge.centreX
                    centerY: gauge.centreY
                    radiusX: gauge.radius
                    radiusY: gauge.radius
                    startAngle: gauge.mirrored ? 0 : 180
                    sweepAngle: (gauge.mirrored ? -180 : 180) * cards.progress
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            visible: cards.countdownText !== ""
            text: cards.countdownText
            color: cards.accentColor
            font.family: cards.fontFamily
            // Sized by the half circle it sits in, not by the cards: full
            // size when it fits, smaller only when the gauge is small
            font.pointSize: cards.pointSize * cards.countdownRatio * gauge.textFit
            font.weight: Font.DemiBold
        }
    }

    /* ----------------------------- cards ----------------------------- */
    component PrayerCard: Rectangle {
        id: card
        required property int modelData
        readonly property int prayerIndex: modelData
        readonly property bool isNext: prayerIndex === cards.nextIndex
        readonly property bool isSunrise: prayerIndex === 1

        width: cards.cellWidth
        height: cards.cardHeight
        radius: Math.min(cards.cornerRadius * 2, height / 4)
        color: isNext ? Qt.alpha(cards.accentColor, 0.25)
                      : Qt.rgba(cards.textColor.r, cards.textColor.g, cards.textColor.b, 0.07)

        Column {
            anchors.centerIn: parent
            width: parent.width - cards.cardPad * 2
            opacity: card.isSunrise ? 0.65 : 1

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: cards.names && cards.names.length > card.prayerIndex ? cards.names[card.prayerIndex] : ""
                color: cards.textColor
                opacity: card.isNext ? 1 : 0.75
                font.family: cards.fontFamily
                font.pointSize: cards.pointSize * cards.nameRatio * cards.fit
                font.weight: card.isNext && cards.boldNext ? Font.Bold : Font.Normal
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: cards.timeLabels && cards.timeLabels.length > card.prayerIndex
                      ? cards.timeLabels[card.prayerIndex] : ""
                color: card.isNext ? cards.accentColor : cards.textColor
                font.family: cards.fontFamily
                font.pointSize: cards.pointSize * cards.timeRatio * cards.fit
                font.weight: card.isNext && cards.boldNext ? Font.Bold : Font.Normal
            }
        }
    }

    Column {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: cards.gap
        visible: cards.hasTimes

        // Rows follow the layout direction: Fajr starts on the right in an
        // RTL language, as in a table read right to left
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: cards.gap
            Repeater {
                model: cards.topRow
                delegate: PrayerCard {}
            }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: cards.gap
            Repeater {
                model: cards.bottomRow
                delegate: PrayerCard {}
            }
        }
    }
}
