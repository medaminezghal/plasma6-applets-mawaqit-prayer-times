import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import "../code/mawaqit.js" as Mawaqit

// Plain Item (not PlasmaExtras.Representation): the popup height is derived
// directly from the content's implicit height, so nothing can be clipped.
Item {
    id: full

    LayoutMirroring.enabled: root.rtl
    LayoutMirroring.childrenInherit: true

    // The expanded view (desktop body and panel popup) always shows the full
    // table. displayMode only affects the inline panel strip.
    readonly property bool hasContent: root.configured && root.calendar !== null
    readonly property int outerMargin: Kirigami.Units.largeSpacing * 2

    Layout.minimumWidth: Kirigami.Units.gridUnit * 14
    Layout.preferredWidth: Kirigami.Units.gridUnit * 16
    Layout.minimumHeight: hasContent
                          ? contentColumn.implicitHeight + outerMargin * 2
                          : Kirigami.Units.gridUnit * 10
    Layout.preferredHeight: Layout.minimumHeight
    Layout.maximumHeight: Layout.minimumHeight

    /* --------------------- custom background ------------------------ *
     * Drawn behind everything when the user enables it. On the desktop the
     * theme frame is already suppressed via Plasmoid.backgroundHints; in the
     * panel popup we additionally drop the dialog's own frame below so this
     * rounded rectangle is the only background. */
    Rectangle {
        anchors.fill: parent
        visible: root.appCustomBackground
        color: root.appBackgroundColor
        radius: root.appBackgroundRadius
    }

    // Remove the popup dialog's theme frame when a custom background is used,
    // so the rectangle above isn't boxed inside it. No-op on the desktop (no
    // popup window) and safely skipped if the window has no backgroundHints.
    function applyPopupBackground() {
        var w = Window.window;
        if (w && typeof w.backgroundHints !== "undefined") {
            w.backgroundHints = Qt.binding(function () {
                return root.appCustomBackground
                    ? PlasmaCore.Types.NoBackground
                    : PlasmaCore.Types.DefaultBackground;
            });
        }
    }
    Component.onCompleted: applyPopupBackground()
    onVisibleChanged: if (visible) applyPopupBackground()

    /* ------------------------- Unconfigured ------------------------- */
    PlasmaExtras.PlaceholderMessage {
        anchors.centerIn: parent
        width: parent.width - Kirigami.Units.gridUnit * 2
        visible: !root.configured
        iconName: "configure"
        text: i18n("No mosque selected")
        explanation: i18n("Choose your mosque in the widget settings")
        helpfulAction: Kirigami.Action {
            icon.name: "configure"
            text: i18n("Configure…")
            onTriggered: Plasmoid.internalAction("configure").trigger()
        }
    }

    /* --------------------------- Loading --------------------------- */
    PlasmaComponents3.BusyIndicator {
        anchors.centerIn: parent
        visible: root.configured && root.calendar === null && root.fetching
        running: visible
    }

    /* ---------------------------- Error ---------------------------- */
    PlasmaExtras.PlaceholderMessage {
        anchors.centerIn: parent
        width: parent.width - Kirigami.Units.gridUnit * 2
        visible: root.configured && root.calendar === null && !root.fetching
        iconName: "network-disconnect"
        text: i18n("Couldn't load prayer times")
        explanation: root.errorMessage
        helpfulAction: Kirigami.Action {
            icon.name: "view-refresh"
            text: i18n("Retry")
            onTriggered: root.refetch(true)
        }
    }

    /* --------------------------- Content --------------------------- */
    ColumnLayout {
        id: contentColumn
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: full.outerMargin
        }
        visible: full.hasContent
        spacing: Kirigami.Units.smallSpacing

        PlasmaExtras.Heading {
            Layout.fillWidth: true
            level: 3
            text: root.mosqueName
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            font.family: root.appFontFamily
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.2 * root.appFontScale
            color: root.appTextColor
        }

        PlasmaComponents3.Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: root.hijriDateText
            font.family: root.appFontFamily
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * root.appFontScale
            font.weight: Font.DemiBold
            color: root.appTextColor
            opacity: 0.85
        }

        Kirigami.Separator {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing
        }

        /* ---------- Full times table ---------- */
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Repeater {
                model: 6

                delegate: Rectangle {
                    id: prayerRow
                    required property int index

                    readonly property bool isSunrise: index === 1
                    readonly property bool isNext: root.next !== null
                                                   && root.next.index === index
                                                   && !root.next.tomorrow

                    visible: !isSunrise || Plasmoid.configuration.showSunrise
                    Layout.fillWidth: true
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 1.7
                    radius: Kirigami.Units.cornerRadius
                    color: isNext
                           ? Qt.alpha(root.appAccentColor, 0.25)
                           : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Kirigami.Units.largeSpacing
                        anchors.rightMargin: Kirigami.Units.largeSpacing

                        PlasmaComponents3.Label {
                            text: root.names[prayerRow.index]
                            font.family: root.appFontFamily
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize * root.appFontScale
                            font.weight: (prayerRow.isNext && root.appBoldNext) ? Font.Bold : Font.Normal
                            color: root.appTextColor
                            opacity: prayerRow.isSunrise ? 0.65 : 1
                        }

                        Item { Layout.fillWidth: true }

                        PlasmaComponents3.Label {
                            text: root.todayTimes
                                  ? Mawaqit.formatTime(root.todayTimes[prayerRow.index], root.use24h)
                                  : "—"
                            font.family: root.appFontFamily
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize * root.appFontScale
                            font.weight: (prayerRow.isNext && root.appBoldNext) ? Font.Bold : Font.Normal
                            color: root.appTextColor
                            opacity: prayerRow.isSunrise ? 0.65 : 1
                        }
                    }
                }
            }

            Kirigami.Separator {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
            }

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                horizontalAlignment: Text.AlignHCenter
                visible: root.next !== null
                text: root.next && root.next.tomorrow
                      ? root.nextName + " " + Mawaqit.uiString("tomorrow", Plasmoid.configuration.labelLanguage)
                        + " " + root.nextTimeFormatted + " — "
                        + Mawaqit.inCountdown(root.countdown, Plasmoid.configuration.labelLanguage)
                      : root.nextName + " " + Mawaqit.inCountdown(root.countdown, Plasmoid.configuration.labelLanguage)
                opacity: 0.7
                font.family: root.appFontFamily
                font.pointSize: Kirigami.Theme.smallFont.pointSize * root.appFontScale
                color: root.appTextColor
            }
        }
    }
}
