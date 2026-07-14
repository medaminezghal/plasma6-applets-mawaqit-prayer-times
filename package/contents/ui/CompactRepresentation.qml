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

    // Prayer indices to render in full mode (sunrise optional)
    readonly property var shownIndices: Plasmoid.configuration.showSunrise
                                        ? [0, 1, 2, 3, 4, 5] : [0, 2, 3, 4, 5]

    Layout.minimumWidth: vertical ? 0 : mainLoader.implicitWidth + Kirigami.Units.smallSpacing * 2
    Layout.minimumHeight: vertical ? mainLoader.implicitHeight + Kirigami.Units.smallSpacing * 2 : 0

    onClicked: root.expanded = !root.expanded

    Loader {
        id: mainLoader
        anchors.centerIn: parent
        sourceComponent: {
            if (!compact.ready) {
                return placeholderComp;
            }
            if (compact.fullMode) {
                return compact.vertical ? fullVerticalComp : fullHorizontalComp;
            }
            return compact.vertical ? nextVerticalComp : nextHorizontalComp;
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
                text: root.hijriDateText
                font.weight: Font.DemiBold
            }

            Kirigami.Separator {
                Layout.fillHeight: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                Layout.bottomMargin: Kirigami.Units.smallSpacing
            }

            RowLayout {
                spacing: Kirigami.Units.smallSpacing
                PlasmaComponents3.Label {
                    text: root.nextName + " " + root.nextTimeFormatted
                    font.weight: Font.DemiBold
                }
                PlasmaComponents3.Label {
                    visible: compact.showCountdown
                    text: "· " + root.countdown
                    opacity: 0.7
                }
            }
        }
    }

    /* ----------------- next-prayer mode, vertical panel --------------- */
    Component {
        id: nextVerticalComp
        ColumnLayout {
            spacing: 0
            PlasmaComponents3.Label {
                Layout.alignment: Qt.AlignHCenter
                text: root.nextName
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                font.weight: Font.DemiBold
            }
            PlasmaComponents3.Label {
                Layout.alignment: Qt.AlignHCenter
                text: root.next ? root.next.time : ""
                font.pointSize: Kirigami.Theme.smallFont.pointSize
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
                text: root.hijriDateText
                font.weight: Font.DemiBold
            }

            Kirigami.Separator {
                Layout.fillHeight: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                Layout.bottomMargin: Kirigami.Units.smallSpacing
            }

            Repeater {
                model: compact.shownIndices
                delegate: Column {
                    id: prayerCell
                    required property var modelData
                    readonly property bool isNext: root.next !== null
                                                   && root.next.index === modelData
                                                   && !root.next.tomorrow
                    Layout.alignment: Qt.AlignVCenter
                    spacing: -5  // hug the countdown against the prayer label

                    PlasmaComponents3.Label {
                        id: cellLabel
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.names[prayerCell.modelData] + " "
                              + Mawaqit.formatTime(root.todayTimes[prayerCell.modelData], root.use24h)
                        font.weight: prayerCell.isNext ? Font.Bold : Font.Normal
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize
                                        * (prayerCell.isNext ? 1.15 : 1)
                        color: prayerCell.isNext ? Kirigami.Theme.highlightColor
                                                 : Kirigami.Theme.textColor
                        opacity: prayerCell.modelData === 1 ? 0.7 : 1
                    }

                    PlasmaComponents3.Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: prayerCell.isNext && compact.showCountdown
                                 && root.countdownHM !== ""
                        text: Mawaqit.inCountdown(root.countdownHM, Plasmoid.configuration.labelLanguage)
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        color: Kirigami.Theme.highlightColor
                        opacity: 0.85
                    }
                }
            }
        }
    }

    /* ---------------- all-prayers mode, vertical panel ----------------- */
    Component {
        id: fullVerticalComp
        ColumnLayout {
            spacing: 0
            Repeater {
                model: compact.shownIndices
                delegate: PlasmaComponents3.Label {
                    required property var modelData
                    readonly property bool isNext: root.next !== null
                                                   && root.next.index === modelData
                                                   && !root.next.tomorrow
                    Layout.alignment: Qt.AlignHCenter
                    text: root.todayTimes[modelData]
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    font.weight: isNext ? Font.Bold : Font.Normal
                    color: isNext ? Kirigami.Theme.highlightColor
                                  : Kirigami.Theme.textColor
                    opacity: modelData === 1 ? 0.65 : 1
                }
            }
        }
    }
}
