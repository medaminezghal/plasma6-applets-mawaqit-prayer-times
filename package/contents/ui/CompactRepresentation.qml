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
        ? prayerIcon(root.next.index)
        : Qt.resolvedUrl("../icons/mosque.svg")
    function prayerIcon(index) {
        return Qt.resolvedUrl("../icons/" + prayerIcons[index] + ".svg");
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

    // Appearance shortcuts (resolved in main.qml)
    readonly property string appFont: root.appFontFamily
    readonly property real appScale: root.appFontScale

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
                visible: compact.ready && root.countdownMin !== ""
                text: root.countdownMin
                font.family: compact.appFont
                font.pointSize: Kirigami.Theme.smallFont.pointSize * compact.appScale
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
            spacing: Kirigami.Units.largeSpacing

            PlasmaComponents3.Label {
                visible: compact.showHijri
                text: compact.hijriText
                font.family: compact.appFont
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * compact.appScale
                font.weight: Font.DemiBold
                color: root.appTextColor
            }

            Kirigami.Separator {
                visible: compact.showHijri
                Layout.fillHeight: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                Layout.bottomMargin: Kirigami.Units.smallSpacing
            }

            RowLayout {
                spacing: Kirigami.Units.smallSpacing
                Kirigami.Icon {
                    visible: compact.useIcons && root.next !== null
                    Layout.preferredWidth: nextLabel.implicitHeight
                    Layout.preferredHeight: nextLabel.implicitHeight
                    source: root.next !== null ? compact.prayerIcon(root.next.index) : ""
                    isMask: true
                    color: root.appTextColor
                }
                PlasmaComponents3.Label {
                    id: nextLabel
                    text: compact.useIcons
                          ? root.nextTimeFormatted
                          : root.nextName + " " + root.nextTimeFormatted
                    font.family: compact.appFont
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * compact.appScale
                    font.weight: Font.DemiBold
                    color: root.appTextColor
                }
                PlasmaComponents3.Label {
                    visible: compact.showCountdown
                    text: "· " + root.countdown
                    font.family: compact.appFont
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * compact.appScale
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
            spacing: Kirigami.Units.largeSpacing

            PlasmaComponents3.Label {
                visible: compact.showHijri
                text: compact.hijriText
                font.family: compact.appFont
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * compact.appScale
                font.weight: Font.DemiBold
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
                    Kirigami.Icon {
                        visible: compact.useIcons
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: cellLabel.implicitHeight
                        Layout.preferredHeight: cellLabel.implicitHeight
                        source: compact.prayerIcon(prayerCell.modelData)
                        isMask: true
                        color: prayerCell.isNext ? root.appAccentColor
                                                 : root.appTextColor
                    }

                    Column {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: -5  // hug the countdown against the prayer label

                        PlasmaComponents3.Label {
                            id: cellLabel
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: (compact.useIcons
                                   ? "" : root.names[prayerCell.modelData] + " ")
                                  + Mawaqit.formatTime(root.todayTimes[prayerCell.modelData],
                                                       root.use24h)
                            font.family: compact.appFont
                            font.weight: (prayerCell.isNext && root.appBoldNext)
                                         ? Font.Bold : Font.Normal
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize
                                            * (prayerCell.isNext ? 1.15 : 1) * compact.appScale
                            color: prayerCell.isNext ? root.appAccentColor
                                                     : root.appTextColor
                        }

                        PlasmaComponents3.Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: prayerCell.isNext && compact.showCountdown
                                     && root.countdownHM !== ""
                            text: Mawaqit.inCountdown(root.countdownHM,
                                                      Plasmoid.configuration.labelLanguage)
                            font.family: compact.appFont
                            font.pointSize: Kirigami.Theme.smallFont.pointSize * compact.appScale
                            color: root.appAccentColor
                            opacity: 0.85
                        }
                    }
                }
            }
        }
    }
}
