import QtQuick
import "../code/dial.js" as Dial

/* The Sundial layout: today's prayers around a 24-hour dial drawn on a
 * rounded rectangle - midnight at the bottom, noon at the top, read
 * clockwise - with the countdown to the next prayer in the middle.
 *
 * Only QtQuick is used here and everything it shows comes in through the
 * properties below, so FullRepresentation decides what to show and the
 * view can be previewed outside Plasma. It always fills the space it is
 * given: the size of the expanded view is set by the Classic table, so
 * switching layout never resizes the widget or the popup. */
Item {
    id: dial

    /* ----------------------------- input ----------------------------- */
    property var times: null          // ["HH:MM" x 6], Fajr..Isha incl. sunrise
    property var names: []            // prayer names, same order
    property var timeLabels: []       // times as displayed (12/24 h)
    property int nextIndex: -1
    property string countdownText: ""
    property bool showSunrise: true
    property bool boldNext: true

    property string fontFamily: ""
    property real pointSize: 10
    property real sizeScale: 1        // the widget-size slider
    property real cornerRadius: 4

    /* --------------------------- derived ----------------------------- */
    readonly property bool hasTimes: times !== null && times !== undefined
                                     && times.length >= 6

    readonly property real spacing: Math.max(2, Math.round(4 * sizeScale))
    readonly property real dotSize: Math.max(4, Math.round(6 * sizeScale))
    // Track: a rounded rectangle just inside the edges, with room for the
    // dots and the "now" marker that sit on it
    readonly property real trackMargin: Math.ceil(dotSize * 1.25)
    readonly property real halfW: Math.max(1, width / 2 - trackMargin)
    readonly property real halfH: Math.max(1, height / 2 - trackMargin)
    readonly property real trackRadius: Math.min(halfW, halfH, Math.max(cornerRadius * 2, 12 * sizeScale))
    // Tick marks need room; on a very small widget they would only clutter
    readonly property bool showTicks: Math.min(width, height) >= 110

    /* ---------------------------- palette ---------------------------- *
     * The dial always stands on the Sky (SkyBackground), so it chooses its
     * own colours rather than the theme's or the custom ones: white ink,
     * dark glass cards, and a warm gold for the next prayer that reads on
     * the day sky as well as the night. */
    readonly property color textColor: "white"
    readonly property color accentColor: "#f2c45a"
    readonly property color accentTextColor: "#241a06"
    readonly property color cardColor: Qt.rgba(0, 0, 0, 0.28)
    readonly property color trackColor: Qt.rgba(1, 1, 1, 0.55)

    // Minutes since midnight, for the "now" marker; a minute is far finer
    // than a pixel on the track, so twice a minute is plenty
    property real nowMinutes: minutesNow()
    function minutesNow() {
        var d = new Date();
        return d.getHours() * 60 + d.getMinutes() + d.getSeconds() / 60;
    }
    Timer {
        interval: 30000
        running: dial.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: dial.nowMinutes = dial.minutesNow()
    }

    function shown(i) {
        return i !== 1 || showSunrise;
    }
    function pointAt(minutes) {
        var p = Dial.trackPoint(minutes, halfW, halfH, trackRadius);
        return Qt.point(width / 2 + p.x, height / 2 + p.y);
    }

    /* --------------------------- card sizes -------------------------- *
     * Measured from the text rather than read back from the delegates, so
     * the layout below is a plain binding with no creation-order games. */
    FontMetrics {
        id: cardMetrics
        font.family: dial.fontFamily
        font.pointSize: dial.pointSize * 0.92
    }
    FontMetrics {
        id: cardBoldMetrics
        font.family: dial.fontFamily
        font.pointSize: dial.pointSize * 0.92
        font.weight: Font.Bold
    }
    readonly property real cardPadH: Math.round(5 * sizeScale)
    readonly property real cardPadV: Math.round(2 * sizeScale)
    // Room between the track and a card, and between two cards
    readonly property real cardInset: Math.round(dotSize / 2 + 2 * sizeScale)
    readonly property real cardGap: Math.max(2, Math.round(3 * sizeScale))
    readonly property real cardHeight: Math.ceil(cardMetrics.height * 2 + cardPadV * 2)

    function cardWidth(i) {
        var bold = i === nextIndex && boldNext;
        var m = bold ? cardBoldMetrics : cardMetrics;
        var name = names && names.length > i ? names[i] : "";
        var time = timeLabels && timeLabels.length > i ? timeLabels[i] : "";
        return Math.ceil(Math.max(m.advanceWidth(name), m.advanceWidth(time)) + cardPadH * 2);
    }

    // Card centres, relative to the dial centre, indexed like `times`
    readonly property var cardCentres: {
        var out = [null, null, null, null, null, null];
        if (!hasTimes || width <= 0 || height <= 0) {
            return out;
        }
        var cards = [];
        var which = [];
        for (var i = 0; i < 6; ++i) {
            if (!shown(i)) {
                continue;
            }
            cards.push({ minutes: Dial.toMinutes(times[i]), w: cardWidth(i), h: cardHeight });
            which.push(i);
        }
        var pos = Dial.layoutCards(cards, halfW, halfH, cardInset, cardGap);
        for (var k = 0; k < which.length; ++k) {
            out[which[k]] = pos[k];
        }
        return out;
    }

    // The dial reads clockwise in every language: mirroring it for an RTL
    // prayer-name language would turn the clock backwards. Text inside the
    // cards still follows its own direction.
    LayoutMirroring.enabled: false
    LayoutMirroring.childrenInherit: true

    /* ----------------------------- track ----------------------------- */
    Rectangle {
        id: track
        x: dial.trackMargin
        y: dial.trackMargin
        width: dial.halfW * 2
        height: dial.halfH * 2
        radius: dial.trackRadius
        color: "transparent"
        border.width: Math.max(1, Math.round(dial.sizeScale))
        border.color: dial.trackColor
    }

    // An hour tick every hour, longer every six hours, pointing at the
    // centre from just inside the track
    Repeater {
        model: dial.showTicks ? 24 : 0
        delegate: Rectangle {
            required property int index
            readonly property bool major: index % 6 === 0
            readonly property point at: dial.pointAt(index * 60)
            readonly property real len: Math.round((major ? 7 : 4) * dial.sizeScale)
            width: Math.max(1, Math.round(dial.sizeScale * (major ? 1.5 : 1)))
            height: len
            color: dial.trackColor
            antialiasing: true
            // Tick hangs inwards from the track: rotate about its top end,
            // which sits on the track. Unrotated it points down, at the
            // centre from midnight; each hour turns it 15 degrees.
            x: at.x - width / 2
            y: at.y
            transformOrigin: Item.Top
            rotation: 180 + index * 15
        }
    }

    /* ---------------------------- leaders ---------------------------- *
     * A card that had to slide away from its own point to make room for a
     * neighbour gets a thin line back to that point, so it is never in
     * doubt which time on the dial it belongs to. */
    Repeater {
        model: dial.hasTimes ? 6 : 0
        delegate: Rectangle {
            id: leader
            required property int index
            readonly property var centre: dial.cardCentres[index]
            readonly property point from: dial.pointAt(Dial.toMinutes(dial.times[index]))
            // Nearest point of the card to its dot
            readonly property real cw: dial.cardWidth(index)
            readonly property real cx: centre ? dial.width / 2 + centre.x : 0
            readonly property real cy: centre ? dial.height / 2 + centre.y : 0
            readonly property real toX: Math.max(cx - cw / 2, Math.min(cx + cw / 2, from.x))
            readonly property real toY: Math.max(cy - dial.cardHeight / 2,
                                                 Math.min(cy + dial.cardHeight / 2, from.y))
            readonly property real len: Math.sqrt((toX - from.x) * (toX - from.x)
                                                  + (toY - from.y) * (toY - from.y))
            visible: dial.shown(index) && centre !== null && len > dial.dotSize * 1.5
            x: from.x
            y: from.y - height / 2
            width: len
            height: Math.max(1, Math.round(dial.sizeScale))
            transformOrigin: Item.Left
            rotation: Math.atan2(toY - from.y, toX - from.x) * 180 / Math.PI
            antialiasing: true
            color: dial.trackColor
        }
    }

    /* ------------------------- prayer dots --------------------------- */
    Repeater {
        model: dial.hasTimes ? 6 : 0
        delegate: Rectangle {
            required property int index
            readonly property point at: dial.pointAt(Dial.toMinutes(dial.times[index]))
            readonly property bool isNext: index === dial.nextIndex
            visible: dial.shown(index)
            width: dial.dotSize
            height: width
            radius: width / 2
            x: at.x - width / 2
            y: at.y - height / 2
            // Sunrise is not a prayer: an outline on the track, not a dot
            color: index === 1 ? "transparent"
                               : (isNext ? dial.accentColor : dial.textColor)
            border.width: index === 1 ? Math.max(1, Math.round(dial.sizeScale)) : 0
            border.color: dial.textColor
        }
    }

    /* ---------------------------- now -------------------------------- */
    Item {
        id: nowMarker
        readonly property point at: dial.pointAt(dial.nowMinutes)
        readonly property color tint: "white"
        visible: dial.hasTimes
        x: at.x
        y: at.y

        Rectangle {
            width: dial.dotSize * 3.2
            height: width
            radius: width / 2
            anchors.centerIn: parent
            color: Qt.rgba(nowMarker.tint.r, nowMarker.tint.g, nowMarker.tint.b, 0.22)
        }
        Rectangle {
            width: dial.dotSize * 1.9
            height: width
            radius: width / 2
            anchors.centerIn: parent
            color: nowMarker.tint
        }
    }

    /* ---------------------------- cards ------------------------------ */
    Repeater {
        model: dial.hasTimes ? 6 : 0
        delegate: Rectangle {
            id: card
            required property int index
            readonly property bool isNext: index === dial.nextIndex
            readonly property var centre: dial.cardCentres[index]
            readonly property color ink: isNext ? dial.accentTextColor : dial.textColor
            visible: dial.shown(index) && centre !== null
            width: dial.cardWidth(index)
            height: dial.cardHeight
            x: centre ? Math.round(dial.width / 2 + centre.x - width / 2) : 0
            y: centre ? Math.round(dial.height / 2 + centre.y - height / 2) : 0
            radius: Math.min(dial.cornerRadius * 1.5, height / 4)
            color: isNext ? dial.accentColor : dial.cardColor
            opacity: index === 1 ? 0.75 : 1

            Column {
                anchors.centerIn: parent

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: dial.names && dial.names.length > card.index ? dial.names[card.index] : ""
                    color: card.ink
                    font.family: dial.fontFamily
                    font.pointSize: dial.pointSize * 0.92
                    font.weight: card.isNext && dial.boldNext ? Font.Bold : Font.Normal
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: dial.timeLabels && dial.timeLabels.length > card.index
                          ? dial.timeLabels[card.index] : ""
                    color: card.ink
                    font.family: dial.fontFamily
                    font.pointSize: dial.pointSize * 0.92
                    font.weight: card.isNext && dial.boldNext ? Font.Bold : Font.Normal
                }
            }
        }
    }

    /* --------------------------- countdown --------------------------- */
    Text {
        anchors.centerIn: parent
        visible: dial.countdownText !== ""
        text: dial.countdownText
        color: dial.textColor
        font.family: dial.fontFamily
        font.pointSize: dial.pointSize * 1.5
        font.weight: Font.DemiBold
    }
}
