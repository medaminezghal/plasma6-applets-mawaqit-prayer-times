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
    // Every spacing below is multiplied by the font-size slider too, so a
    // bigger font grows the whole layout uniformly instead of only the text
    readonly property real sp: root.appFontScale
    readonly property real outerMargin: Math.round(Kirigami.Units.smallSpacing * 2 * sp)

    /* -------------------- font-driven metrics ------------------------ *
     * Nothing here is a fixed grid multiple any more: the row height comes
     * from the line height of the family and size the user picked, and the
     * width from the widest row, so the font-size slider changes both
     * dimensions and the widget is never larger than its text needs. */
    FontMetrics {
        id: bodyMetrics
        font.family: root.appFontFamily
        font.pointSize: Kirigami.Theme.defaultFont.pointSize * root.appFontScale
    }
    readonly property real rowHeight: Math.round(bodyMetrics.height
                                                 + Kirigami.Units.smallSpacing * sp)

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

    /* The popup keeps the theme's own shape: the corner tile of
     * "dialogs/background" is what rounds a Plasma dialog, and SvgItem
     * reports its size as a bindable property, so the custom background can
     * use exactly that radius instead of a guessed number. In a panel the
     * corner-radius setting is hidden for the same reason - there the custom
     * background only changes colour and opacity. */
    KSvg.SvgItem {
        id: dialogCorner
        visible: false
        width: 0
        height: 0
        imagePath: "dialogs/background"
        elementId: "topleft"
    }
    readonly property real popupRadius: dialogCorner.naturalSize.width > 0
                                        ? dialogCorner.naturalSize.width
                                        : Kirigami.Units.cornerRadius

    // Padding the applet container stops adding once we turn its frame off
    readonly property real framePad: (root.appCustomBackground && onDesktop) ? 1 : 0
    readonly property real padLeft: outerMargin + framePad * frameMetrics.fixedMargins.left
    readonly property real padRight: outerMargin + framePad * frameMetrics.fixedMargins.right
    readonly property real padTop: outerMargin + framePad * frameMetrics.fixedMargins.top
    readonly property real padBottom: outerMargin + framePad * frameMetrics.fixedMargins.bottom

    /* ------------------- fit the desktop widget ---------------------- *
     * The desktop containment only ever grows an applet:
     * GridLayoutManager::adjustToItemSizeHints raises the size to the
     * minimum and preferred hints and has the maximum branch commented out,
     * so a widget placed larger once - or whose content later shrank - keeps
     * the old size for good. This widget publishes a fixed size
     * (maximum == minimum), so shrink the container down to it ourselves.
     *
     * Only public QML API of the containment layout is used:
     * ItemContainer.layout with its paddings and cell sizes, and the
     * invokable releaseSpace()/positionItem(). Every lookup is duck-typed
     * and guarded, so on a containment that works differently this quietly
     * does nothing. */
    function appletContainer() {
        var item = full.parent;
        while (item) {
            if (item.layout !== undefined && item.layout !== null
                    && typeof item.layout.releaseSpace === "function"
                    && typeof item.layout.positionItem === "function"
                    && item.topPadding !== undefined) {
                return item;
            }
            item = item.parent;
        }
        return null;
    }

    function fitToContent() {
        if (!full.onDesktop || !full.hasContent) {
            return;
        }
        var container = appletContainer();
        if (!container || container.editMode) {
            return;
        }
        var appletsLayout = container.layout;
        if (appletsLayout.editMode) {
            return;
        }

        // Round up to whole cells, exactly as adjustToItemSizeHints would,
        // so it has nothing left to correct afterwards
        var cellW = appletsLayout.cellWidth > 0 ? appletsLayout.cellWidth : 1;
        var cellH = appletsLayout.cellHeight > 0 ? appletsLayout.cellHeight : 1;
        var wantWidth = cellW * Math.ceil((full.Layout.preferredWidth
                                           + container.leftPadding
                                           + container.rightPadding) / cellW);
        var wantHeight = cellH * Math.ceil((full.Layout.preferredHeight
                                            + container.topPadding
                                            + container.bottomPadding) / cellH);
        wantWidth = Math.max(appletsLayout.minimumItemWidth, wantWidth);
        wantHeight = Math.max(appletsLayout.minimumItemHeight, wantHeight);

        if (container.width <= wantWidth + 1 && container.height <= wantHeight + 1) {
            return;
        }

        // Free the cells, resize, then let the layout re-take them; the
        // re-take is what flags the geometry as needing saving.
        appletsLayout.releaseSpace(container);
        container.width = wantWidth;
        container.height = wantHeight;
        appletsLayout.positionItem(container);
    }

    Timer {
        id: fitTimer
        interval: 250
        onTriggered: full.fitToContent()
    }

    Connections {
        target: contentColumn
        function onImplicitWidthChanged() { fitTimer.restart(); }
        function onImplicitHeightChanged() { fitTimer.restart(); }
    }

    // Width: the widest row wins, with a 14-gridUnit floor (the original
    // minimum) so the table does not turn into a narrow strip at small sizes
    Layout.minimumWidth: hasContent
                         ? Math.max(Kirigami.Units.gridUnit * 14 * sp,
                                    Math.ceil(contentColumn.implicitWidth) + padLeft + padRight)
                         : Kirigami.Units.gridUnit * 14
    Layout.preferredWidth: Layout.minimumWidth
    Layout.maximumWidth: Layout.minimumWidth
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
        radius: full.inPopup ? full.popupRadius : root.appBackgroundRadius
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

    Component.onCompleted: {
        updatePopupFrame();
        fitTimer.restart();
    }
    onVisibleChanged: {
        updatePopupFrame();
        if (visible) {
            fitTimer.restart();
        }
    }

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
        spacing: Kirigami.Units.smallSpacing * full.sp

        PlasmaExtras.Heading {
            Layout.fillWidth: true
            // A floor, not a demand: a long mosque name elides instead of
            // stretching the widget to fit
            Layout.preferredWidth: Kirigami.Units.gridUnit * 8 * full.sp
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
            Layout.topMargin: Kirigami.Units.smallSpacing * full.sp
            Layout.bottomMargin: Kirigami.Units.smallSpacing * full.sp
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
                    Layout.preferredHeight: full.rowHeight
                    // Sets the widget width: name + gap + time, never elided
                    implicitWidth: rowContent.implicitWidth
                                   + Kirigami.Units.smallSpacing * 4 * full.sp
                    radius: Kirigami.Units.cornerRadius
                    color: isNext
                           ? Qt.alpha(root.appAccentColor, 0.25)
                           : "transparent"

                    RowLayout {
                        id: rowContent
                        anchors.fill: parent
                        anchors.leftMargin: Kirigami.Units.smallSpacing * 2 * full.sp
                        anchors.rightMargin: Kirigami.Units.smallSpacing * 2 * full.sp

                        PlasmaComponents3.Label {
                            text: root.names[prayerRow.index]
                            font.family: root.appFontFamily
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize * root.appFontScale
                            font.weight: (prayerRow.isNext && root.appBoldNext) ? Font.Bold : Font.Normal
                            color: root.appTextColor
                            opacity: prayerRow.isSunrise ? 0.65 : 1
                        }

                        Item {
                            Layout.fillWidth: true
                            // Smallest gap allowed between name and time
                            Layout.preferredWidth: Kirigami.Units.gridUnit * full.sp
                        }

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
                Layout.topMargin: Kirigami.Units.smallSpacing * full.sp
            }

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing * full.sp
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
