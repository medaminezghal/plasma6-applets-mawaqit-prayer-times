import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.ksvg as KSvg
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

    /* ------------------- container frame metrics --------------------- *
     * Who draws the frame around this item depends on where it lives:
     *
     *   - desktop: the containment's applet container draws
     *     "widgets/background" and pads us by its margins
     *     (BasicAppletContainer.qml: leftPadding: background.margins.left).
     *     Plasmoid.backgroundHints = NoBackground drops the frame *and* that
     *     padding, which is why enabling a custom background used to shift
     *     every label outwards. We add the padding back ourselves.
     *
     *   - panel popup: PlasmaQuick::PlasmaWindow draws "dialogs/background"
     *     itself and insets us by its margins. It cannot be switched off
     *     through any property (see popupFrameItem() below).
     *
     * Metrics come from the same place Plasma's own
     * PlasmaExtras.Representation gets them. */
    readonly property bool inPopup: Window.window instanceof PlasmaCore.AppletPopup
    readonly property bool onDesktop: !inPopup
                                      && Plasmoid.formFactor === PlasmaCore.Types.Planar

    KSvg.FrameSvgItem {
        id: frameMetrics
        visible: false
        imagePath: full.inPopup ? "dialogs/background"
                                : (full.onDesktop ? "widgets/background" : "")
        readonly property bool hasInset: inset.left >= 0 && inset.right >= 0
                                         && inset.top >= 0 && inset.bottom >= 0
        // Negative margin that takes an item out to the frame's visual edge,
        // past the shadow area the frame reserves for itself.
        function bleed(side) {
            return hasInset ? -fixedMargins[side] + inset[side]
                            : -fixedMargins[side];
        }
        function shadow(side) {
            return hasInset ? inset[side] : 0;
        }
    }

    // Padding the applet container stops adding once we turn its frame off
    readonly property real framePad: (root.appCustomBackground && onDesktop) ? 1 : 0
    readonly property real padLeft: outerMargin + framePad * frameMetrics.fixedMargins.left
    readonly property real padRight: outerMargin + framePad * frameMetrics.fixedMargins.right
    readonly property real padTop: outerMargin + framePad * frameMetrics.fixedMargins.top
    readonly property real padBottom: outerMargin + framePad * frameMetrics.fixedMargins.bottom

    Layout.minimumWidth: Kirigami.Units.gridUnit * 14
    Layout.preferredWidth: Kirigami.Units.gridUnit * 16
    Layout.minimumHeight: hasContent
                          ? contentColumn.implicitHeight + padTop + padBottom
                          : Kirigami.Units.gridUnit * 10
    Layout.preferredHeight: Layout.minimumHeight
    Layout.maximumHeight: Layout.minimumHeight

    /* --------------------- custom background ------------------------ *
     * In a popup we bleed outwards over the window's own frame (which we
     * also hide, below); on the desktop that frame is already gone, so we
     * only keep clear of the shadow area it used to reserve. Either way the
     * painted card lands exactly where the theme frame was. */
    Rectangle {
        anchors.fill: parent
        visible: root.appCustomBackground
        color: root.appBackgroundColor
        radius: root.appBackgroundRadius
        anchors.leftMargin: full.inPopup ? frameMetrics.bleed("left")
                                         : frameMetrics.shadow("left")
        anchors.rightMargin: full.inPopup ? frameMetrics.bleed("right")
                                          : frameMetrics.shadow("right")
        anchors.topMargin: full.inPopup ? frameMetrics.bleed("top")
                                        : frameMetrics.shadow("top")
        anchors.bottomMargin: full.inPopup ? frameMetrics.bleed("bottom")
                                           : frameMetrics.shadow("bottom")
    }

    /* -------------------- popup frame suppression -------------------- *
     * PlasmaWindow::backgroundHints is its own enum - StandardBackground = 0,
     * SolidBackground = 1 - which does not line up with
     * PlasmaCore.Types.BackgroundHints, so the old assignment was selecting
     * the standard frame when a custom background was on and the solid one
     * when it was off. setBackgroundHints() only ever swaps
     * "dialogs/background" for "solid/dialogs/background" anyway; it can
     * never turn the frame off.
     *
     * The frame is a plain QQuickItem sibling of ours, created in the
     * PlasmaWindow constructor as `new DialogBackground(contentItem())`, so
     * hide that item directly. Painting over it is not enough once the
     * background has rounded corners. */
    function popupFrameItem() {
        var w = Window.window;
        if (!full.inPopup || !w || !w.contentItem) {
            return null;
        }
        // Walk up to the direct child of contentItem that we live under
        var ours = full;
        while (ours && ours.parent !== w.contentItem) {
            ours = ours.parent;
        }
        if (!ours) {
            return null;
        }
        var kids = w.contentItem.children;
        for (var i = 0; i < kids.length; ++i) {
            // Match the class name rather than "whatever is not us", so an
            // extra child of the window can never be hidden by mistake
            if (kids[i] !== ours
                    && String(kids[i]).indexOf("DialogBackground") === 0) {
                return kids[i];
            }
        }
        return null;
    }

    function updatePopupFrame() {
        var frame = popupFrameItem();
        if (frame) {
            frame.visible = !root.appCustomBackground;
        }
    }

    Component.onCompleted: updatePopupFrame()
    onVisibleChanged: updatePopupFrame()

    Connections {
        target: Plasmoid.configuration
        function onCustomBackgroundChanged() {
            full.updatePopupFrame();
        }
    }

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
            topMargin: full.padTop
            leftMargin: full.padLeft
            rightMargin: full.padRight
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
