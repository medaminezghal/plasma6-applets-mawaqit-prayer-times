import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import "../code/mawaqit.js" as Mawaqit

MouseArea {
    id: compact

    // Arabic prayer names read right-to-left: hijri date rightmost, then
    // Fajr through Isha flowing leftward
    LayoutMirroring.enabled: root.rtl
    LayoutMirroring.childrenInherit: true

    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool fullMode: root.displayMode === "full"
    readonly property bool ready: root.configured && root.calendar !== null
                                  && root.todayTimes !== null
    readonly property bool showCountdown: Plasmoid.configuration.showCountdownInPanel
    readonly property bool showHijri: Plasmoid.configuration.showHijriInPanel

    // Vertical panel: the next prayer's own glyph, sized to leave room for
    // the countdown line underneath
    readonly property var prayerIcons: ["fajr", "shuruq", "dhuhr",
                                        "asr", "maghrib", "isha"]
    readonly property string nextIcon: root.next !== null
        ? prayerIcon(root.next.index, root.appBoldNext)
        : Qt.resolvedUrl("../icons/mosque.svg")
    // A glyph has no font weight, so "bold" is a second copy of each SVG with
    // thicker strokes. The geometry is identical, so the icon does not shift
    // when it becomes the next prayer.
    function prayerIcon(index, bold) {
        return Qt.resolvedUrl("../icons/" + prayerIcons[index]
                              + (bold ? "-bold" : "") + ".svg");
    }

    // Horizontal strip: glyphs in place of prayer names, and the hijri date
    // as digits. Both are panel-only; the popup is never affected.
    readonly property bool useIcons: Plasmoid.configuration.usePrayerIconsInPanel
    readonly property string hijriText: Plasmoid.configuration.numericHijriInPanel
                                        ? root.hijriDateNumeric : root.hijriDateText
    // Fill the panel thickness, leaving just enough clearance that the glyph
    // never touches the panel edge
    readonly property real iconSide: Math.max(Kirigami.Units.iconSizes.small,
                                              compact.width - Kirigami.Units.smallSpacing * 2)

    // Prayer indices to render in full mode (sunrise optional)
    readonly property var shownIndices: Plasmoid.configuration.showSunrise
                                        ? [0, 1, 2, 3, 4, 5] : [0, 2, 3, 4, 5]

    // Appearance shortcuts (resolved in main.qml). The font-size slider is
    // deliberately not used here: inside a panel the text has to fit the
    // panel's thickness, so the size follows the panel, not the slider.
    // The slider still scales the expanded view.
    readonly property string appFont: root.appFontFamily

    /* ------------------ panel-driven text sizing -----------------------
     * Same recipe as Plasma's digital clock (DigitalClock.qml, state
     * "horizontalPanel"): a label's font.pixelSize is set equal to the box
     * height it is given, the boxes are cut from the panel thickness -
     * 0.71 of it for a single line, 0.56 for the upper of two lines and
     * 0.8 of that for the lower one, so 0.56 + 0.45 fills the thickness -
     * and everything is capped at three times the default font size. The
     * numbers come with the clock's own testing behind them; a family with
     * generous line spacing simply overhangs its box a little instead of
     * hanging out of the panel. */
    readonly property real panelThickness: vertical ? compact.width : compact.height
    readonly property real maxPanelPx: 3 * Kirigami.Theme.defaultFont.pixelSize
    readonly property real oneLinePx: Math.min(panelThickness * 0.71, maxPanelPx)
    readonly property real upperLinePx: Math.min(panelThickness * 0.56, maxPanelPx)
    readonly property real lowerLinePx: 0.8 * upperLinePx
    // Vertical panel: minutes line under the icon, between the tiny
    // fitted label and a full single line
    readonly property real verticalLinePx: Math.min(Math.round(panelThickness * 0.42),
                                                    maxPanelPx)

    // In "all prayers" mode the next prayer carries its countdown underneath,
    // so it is the two-line case; the other prayers use a slightly smaller
    // single line so the next one stays the largest.
    readonly property bool twoLines: fullMode && showCountdown
    readonly property real nextPx: twoLines ? upperLinePx : oneLinePx
    readonly property real basePx: nextPx / 1.15

    // Icons have one size, cut from the panel thickness alone, so neither
    // the font family nor the display mode changes them
    readonly property int panelIconSide: Math.round(Math.min(panelThickness * 0.6,
                                                             maxPanelPx * 1.3))

    /* ---------------------- optical centring ---------------------------
     * Centring a label centres its line box, and where the digits' ink sits
     * inside that box depends on the family: fonts with a tall ascender or
     * big descender area put the digits visibly below the middle. Measure
     * it once for the chosen family - baseline position from a hidden Text,
     * ink bounds from TextMetrics - and pad every label so the ink, not the
     * box, lands on the centre line. */
    Text {
        id: inkProbe
        visible: false
        text: "0123456789"
        font.family: compact.appFont
        font.pixelSize: 100
    }
    TextMetrics {
        id: inkBounds
        font: inkProbe.font
        text: inkProbe.text
    }
    // Pixels the ink sits below the centre of its line box, per pixel of
    // font size (negative: above)
    readonly property real inkShift: (inkProbe.baselineOffset
                                      + inkBounds.tightBoundingRect.y
                                      + inkBounds.tightBoundingRect.height / 2
                                      - inkProbe.implicitHeight / 2) / 100
    function inkTopPad(px) { return Math.max(0, Math.round(-2 * inkShift * px)); }
    function inkBottomPad(px) { return Math.max(0, Math.round(2 * inkShift * px)); }

    Layout.minimumWidth: vertical ? 0 : mainLoader.implicitWidth + Kirigami.Units.smallSpacing * 2
    Layout.minimumHeight: vertical ? mainLoader.implicitHeight + Kirigami.Units.smallSpacing * 2 : 0

    onClicked: root.expanded = !root.expanded

    Loader {
        id: mainLoader
        anchors.centerIn: parent
        sourceComponent: {
            if (compact.vertical) {
                return verticalComp;
            }
            if (!compact.ready) {
                return placeholderComp;
            }
            return compact.fullMode ? fullHorizontalComp : nextHorizontalComp;
        }
    }

    /* ---------------- vertical panel: glyph + minutes ------------------
     * A vertical panel is only as wide as it is thick, nowhere near enough
     * for a prayer name and a time side by side, so the strip is replaced
     * by the next prayer's glyph with the minutes left underneath. The
     * tooltip still carries the hijri date and the full countdown, and a
     * click opens the same table the horizontal panel shows. */
    Component {
        id: verticalComp
        ColumnLayout {
            spacing: 0

            Kirigami.Icon {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: compact.iconSide
                Layout.preferredHeight: compact.iconSide
                source: compact.nextIcon
                isMask: true
                color: root.appTextColor
            }

            PlasmaComponents3.Label {
                Layout.alignment: Qt.AlignHCenter
                // Minutes line under the icon, cut from the panel thickness
                // like the horizontal sizes; HorizontalFit only steps in if
                // the string is wider than the panel
                Layout.preferredWidth: compact.panelThickness
                Layout.preferredHeight: compact.verticalLinePx
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 6
                visible: compact.ready && root.countdownMin !== ""
                text: root.countdownMin
                font.family: compact.appFont
                font.pixelSize: compact.verticalLinePx
                font.weight: Font.DemiBold
                style: root.fontLacksBold ? Text.Raised : Text.Normal
                styleColor: color
                color: root.appTextColor
            }
        }
    }

    /* ------------- not configured / loading placeholder -------------- */
    Component {
        id: placeholderComp
        RowLayout {
            spacing: Kirigami.Units.smallSpacing
            Kirigami.Icon {
                source: Qt.resolvedUrl("../icons/mosque.svg")
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
            }
            PlasmaComponents3.Label {
                visible: !root.configured && !compact.vertical
                text: i18n("Set mosque")
                opacity: 0.7
            }
        }
    }

    /* ---------------- next-prayer mode, horizontal panel --------------
     * Same hijri date + separator as the full-mode strip, so the date is
     * presented identically in both display modes, followed by the next
     * prayer and its optional countdown. */
    Component {
        id: nextHorizontalComp
        RowLayout {
            spacing: Kirigami.Units.smallSpacing * 1.5

            PlasmaComponents3.Label {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredHeight: compact.oneLinePx
                verticalAlignment: Text.AlignVCenter
                topPadding: compact.inkTopPad(font.pixelSize)
                bottomPadding: compact.inkBottomPad(font.pixelSize)
                visible: compact.showHijri
                text: compact.hijriText
                font.family: compact.appFont
                font.pixelSize: compact.oneLinePx
                font.weight: Font.DemiBold
                style: root.fontLacksBold ? Text.Raised : Text.Normal
                styleColor: color
                color: root.appTextColor
            }

            Kirigami.Separator {
                visible: compact.showHijri
                Layout.fillHeight: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                Layout.bottomMargin: Kirigami.Units.smallSpacing
            }

            RowLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: Kirigami.Units.smallSpacing
                Kirigami.Icon {
                    visible: compact.useIcons && root.next !== null
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: compact.panelIconSide
                    Layout.preferredHeight: compact.panelIconSide
                    source: root.next !== null
                            ? compact.prayerIcon(root.next.index, root.appBoldNext)
                            : ""
                    isMask: true
                    color: root.appTextColor
                }
                PlasmaComponents3.Label {
                    id: nextLabel
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredHeight: compact.oneLinePx
                    verticalAlignment: Text.AlignVCenter
                    topPadding: compact.inkTopPad(font.pixelSize)
                    bottomPadding: compact.inkBottomPad(font.pixelSize)
                    text: compact.useIcons
                          ? root.nextTimeFormatted
                          : root.nextName + " " + root.nextTimeFormatted
                    font.family: compact.appFont
                    font.pixelSize: compact.oneLinePx
                    font.weight: Font.DemiBold
                    style: root.fontLacksBold ? Text.Raised : Text.Normal
                    styleColor: color
                    color: root.appTextColor
                }
                PlasmaComponents3.Label {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredHeight: compact.oneLinePx
                    verticalAlignment: Text.AlignVCenter
                    topPadding: compact.inkTopPad(font.pixelSize)
                    bottomPadding: compact.inkBottomPad(font.pixelSize)
                    visible: compact.showCountdown
                    text: "· " + root.countdown
                    font.family: compact.appFont
                    font.pixelSize: compact.oneLinePx
                    color: root.appTextColor
                    opacity: 0.7
                }
            }
        }
    }

    /* --------------- all-prayers mode, horizontal panel ----------------
     * One line: hijri date first, then every prayer. The next prayer gets
     * its remaining time (h:mm) right beneath it. */
    Component {
        id: fullHorizontalComp
        RowLayout {
            spacing: Kirigami.Units.smallSpacing * 1.5

            PlasmaComponents3.Label {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredHeight: compact.basePx
                verticalAlignment: Text.AlignVCenter
                topPadding: compact.inkTopPad(font.pixelSize)
                bottomPadding: compact.inkBottomPad(font.pixelSize)
                visible: compact.showHijri
                text: compact.hijriText
                font.family: compact.appFont
                font.pixelSize: compact.basePx
                font.weight: Font.DemiBold
                style: root.fontLacksBold ? Text.Raised : Text.Normal
                styleColor: color
                color: root.appTextColor
            }

            Kirigami.Separator {
                visible: compact.showHijri
                Layout.fillHeight: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                Layout.bottomMargin: Kirigami.Units.smallSpacing
            }

            Repeater {
                model: compact.shownIndices
                delegate: RowLayout {
                    id: prayerCell
                    required property var modelData
                    readonly property bool isNext: root.next !== null
                                                   && root.next.index === modelData
                                                   && !root.next.tomorrow
                    Layout.alignment: Qt.AlignVCenter
                    spacing: Kirigami.Units.smallSpacing
                    opacity: modelData === 1 ? 0.7 : 1

                    // Sibling of the text column, not part of it: the next
                    // prayer's cell grows downwards by a countdown line, and
                    // an icon inside the column would ride up half a line and
                    // break alignment with the other prayers' icons
                    readonly property real linePx: isNext ? compact.nextPx : compact.basePx

                    Kirigami.Icon {
                        visible: compact.useIcons
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: compact.panelIconSide
                        Layout.preferredHeight: compact.panelIconSide
                        source: compact.prayerIcon(prayerCell.modelData,
                                                   prayerCell.isNext && root.appBoldNext)
                        isMask: true
                        color: prayerCell.isNext ? root.appAccentColor
                                                 : root.appTextColor
                    }

                    // Each label is given exactly the box its font.pixelSize
                    // is cut from, so the two stacked lines of the next
                    // prayer add up to the panel thickness whatever the font
                    Column {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 0

                        PlasmaComponents3.Label {
                            id: cellLabel
                            anchors.horizontalCenter: parent.horizontalCenter
                            height: prayerCell.linePx
                            verticalAlignment: Text.AlignVCenter
                            topPadding: compact.inkTopPad(font.pixelSize)
                            bottomPadding: compact.inkBottomPad(font.pixelSize)
                            text: (compact.useIcons
                                   ? "" : root.names[prayerCell.modelData] + " ")
                                  + Mawaqit.formatTime(root.todayTimes[prayerCell.modelData],
                                                       root.use24h)
                            font.family: compact.appFont
                            font.weight: (prayerCell.isNext && root.appBoldNext)
                                         ? Font.Bold : Font.Normal
                            style: (prayerCell.isNext && root.appFakeBold)
                                   ? Text.Raised : Text.Normal
                            styleColor: color
                            font.pixelSize: prayerCell.linePx
                            color: prayerCell.isNext ? root.appAccentColor
                                                     : root.appTextColor
                        }

                        PlasmaComponents3.Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            height: compact.lowerLinePx
                            verticalAlignment: Text.AlignVCenter
                            topPadding: compact.inkTopPad(font.pixelSize)
                            bottomPadding: compact.inkBottomPad(font.pixelSize)
                            visible: prayerCell.isNext && compact.showCountdown
                                     && root.countdownHM !== ""
                            text: Mawaqit.inCountdown(root.countdownHM,
                                                      Plasmoid.configuration.labelLanguage)
                            font.family: compact.appFont
                            font.pixelSize: compact.lowerLinePx
                            color: root.appAccentColor
                            opacity: 0.85
                        }
                    }
                }
            }
        }
    }
}
