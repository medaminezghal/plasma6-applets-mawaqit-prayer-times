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
import "../code/horizon.js" as Horizon

// Plain Item (not PlasmaExtras.Representation): the popup height is derived
// directly from the content's implicit height, so nothing can be clipped.
Item {
    id: full

    LayoutMirroring.enabled: root.rtl
    LayoutMirroring.childrenInherit: true

    // The expanded view (desktop body and panel popup) shows the layout
    // picked on the Appearance/Popup page; displayMode only affects the
    // inline panel strip.
    readonly property bool hasContent: root.configured && root.calendar !== null
    readonly property bool sundial: root.appLayout === "sundial"
    readonly property bool cardsLayout: root.appLayout === "cards"
    readonly property bool horizonLayout: root.appLayout === "horizon"
    readonly property bool kaabaLayout: root.appLayout === "kaaba"
    readonly property bool qalamLayout: root.appLayout === "qalam"

    /* The Horizon layout's sky at this minute, shared by its background and the
     * text over it. Minutes are fine enough: the colours and the sun move
     * far less than a pixel in a minute. */
    property real nowMinutes: minutesNow()
    function minutesNow() {
        var d = new Date();
        return d.getHours() * 60 + d.getMinutes() + d.getSeconds() / 60;
    }
    Timer {
        interval: 30000
        // The Kaaba layout uses the minute too, to tell which prayers are done
        running: (full.horizonLayout || full.kaabaLayout || full.qalamLayout) && full.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: full.nowMinutes = full.minutesNow()
    }
    readonly property var horizonSky: root.appHorizonScene && root.todayTimes
                                      ? Horizon.skyAt(nowMinutes, root.todayTimes) : null
    // The moon's age is the day of the hijri month
    readonly property int hijriDay: {
        var d = parseInt(String(root.hijriDateNumeric).split("/")[0], 10);
        return d > 0 ? d : 1;
    }

    // The Qalam's paper turns dark from a little after Maghrib until a
    // little before sunrise
    readonly property bool qalamNight: root.todayTimes
                                       ? (nowMinutes < Horizon.toMinutes(root.todayTimes[1]) - 15
                                          || nowMinutes > Horizon.toMinutes(root.todayTimes[4]) + 20)
                                       : false
    // Its names are written in a calligraphic hand when one is installed,
    // for Arabic names; otherwise in the widget's font
    readonly property string calligraphyFamily: {
        if (!root.rtl) {
            return "";
        }
        var have = Qt.fontFamilies();
        var wanted = ["Aref Ruqaa", "Amiri", "Scheherazade New", "Noto Naskh Arabic"];
        for (var i = 0; i < wanted.length; ++i) {
            if (have.indexOf(wanted[i]) >= 0) {
                return wanted[i];
            }
        }
        return "";
    }

    // The layouts that paint their own background choose their own colours,
    // whatever is set for Classic and Cards: text over the Sundial's Sky is
    // white, and over the Horizon layout it is dark navy while the sky
    // behind it is bright
    readonly property color inkColor: root.appSkyBackground ? "#ffffff"
                                      : root.appKaabaScene ? "#d8cdb2"
                                      : root.appQalamScene ? (qalamNight ? "#f2e6ce" : "#24190e")
                                      : horizonSky ? (horizonDarkInk ? Horizon.NAVY_INK : Horizon.SILVER_INK)
                                      : root.appTextColor
    // Navy or light, for the header and the countdown alike (Horizon.darkInk)
    readonly property bool horizonDarkInk: horizonSky ? Horizon.darkInk(horizonSky) : false
    /* The Horizon header is lit by the sun and the moon passing behind it
     * (shaders/headerlight.frag); its text is then drawn white, as the mask
     * the shader reads, under the lit band. Without a GPU, or if the shader
     * cannot load, the header keeps its plain ink. */
    readonly property bool headerLit: root.appHorizonScene
                                      && GraphicsInfo.api !== GraphicsInfo.Software
                                      && headerLight.status !== ShaderEffect.Error
    // Every spacing below is multiplied by the font-size slider too, so a
    // bigger font grows the whole layout uniformly instead of only the text.
    // Animated, so applying a new size eases the layout into it instead of
    // jumping; fitToContent() then eases the desktop container after it.
    property real sp: root.appFontScale
    Behavior on sp {
        NumberAnimation {
            id: scaleAnimation
            duration: Kirigami.Units.longDuration
            easing.type: Easing.InOutCubic
            // The size is final now: fit the container straight away rather
            // than after fitTimer's debounce
            onRunningChanged: if (!running) full.fitToContent()
        }
    }
    readonly property real outerMargin: Math.round(Kirigami.Units.smallSpacing * 2 * sp)

    /* -------------------- font-driven metrics ------------------------ *
     * Nothing here is a fixed grid multiple any more: the row height comes
     * from the line height of the family and size the user picked, and the
     * width from the widest row, so the font-size slider changes both
     * dimensions and the widget is never larger than its text needs. */
    FontMetrics {
        id: bodyMetrics
        font.family: root.appFontFamily
        font.pointSize: Kirigami.Theme.defaultFont.pointSize * full.sp
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
    readonly property real framePad: (root.appPaintsBackground && onDesktop) ? 1 : 0
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

        // Free the cells, ease the container to its new size, then let the
        // layout re-take them (containerResize below); the re-take is what
        // flags the geometry as needing saving. A resize still running is
        // stopped first, which re-takes the cells at its current size.
        if (containerResize.running) {
            containerResize.stop();
        }
        appletsLayout.releaseSpace(container);
        containerResize.container = container;
        resizeWidth.to = wantWidth;
        resizeHeight.to = wantHeight;
        containerResize.start();
    }

    ParallelAnimation {
        id: containerResize
        property Item container: null

        NumberAnimation {
            id: resizeWidth
            target: containerResize.container
            property: "width"
            duration: Kirigami.Units.longDuration
            easing.type: Easing.InOutCubic
        }
        NumberAnimation {
            id: resizeHeight
            target: containerResize.container
            property: "height"
            duration: Kirigami.Units.longDuration
            easing.type: Easing.InOutCubic
        }

        // Finished or stopped: re-take the cells at the size reached
        onRunningChanged: {
            if (running || container === null) {
                return;
            }
            var item = container;
            container = null;
            if (item.layout) {
                item.layout.positionItem(item);
            }
        }
    }

    Timer {
        id: fitTimer
        interval: 250
        onTriggered: full.fitToContent()
    }

    Connections {
        target: contentColumn
        // While the size animation runs, the content changes every frame;
        // fitToContent() runs once when it ends instead
        function onImplicitWidthChanged() {
            if (!scaleAnimation.running) {
                fitTimer.restart();
            }
        }
        function onImplicitHeightChanged() {
            if (!scaleAnimation.running) {
                fitTimer.restart();
            }
        }
    }

    // Width: the widest row wins, with a 14-gridUnit floor (the original
    // minimum) so the table does not turn into a narrow strip at small sizes.
    // The frame padding we add back ourselves goes on top of the floor, the
    // way the container's own padding does, so a layout that paints its own
    // background is exactly as wide as one on the theme frame.
    Layout.minimumWidth: hasContent
                         ? Math.max(Kirigami.Units.gridUnit * 14 * sp,
                                    Math.ceil(contentColumn.implicitWidth) + outerMargin * 2)
                           + (padLeft - outerMargin) + (padRight - outerMargin)
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
        visible: root.appCustomBackground && !root.appSkyBackground && !root.appHorizonScene
                 && !root.appKaabaScene && !root.appQalamScene
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

    // The Sundial's Sky takes the custom background's place, same shape
    SkyBackground {
        id: skyBackground
        anchors.fill: parent
        visible: root.appSkyBackground
        times: root.todayTimes
        radius: full.inPopup ? full.popupRadius : root.appBackgroundRadius
        // The dial's centre, in our own coordinates
        centreX: contentColumn.x + body.x + body.width / 2 - x
        centreY: contentColumn.y + body.y + body.height / 2 - y
        anchors.leftMargin: full.inPopup ? frameMetrics.bleed("left")
                                         : frameMetrics.shadow("left")
        anchors.rightMargin: full.inPopup ? frameMetrics.bleed("right")
                                          : frameMetrics.shadow("right")
        anchors.topMargin: full.inPopup ? frameMetrics.bleed("top")
                                        : frameMetrics.shadow("top")
        anchors.bottomMargin: full.inPopup ? frameMetrics.bleed("bottom")
                                           : frameMetrics.shadow("bottom")
    }

    // The Horizon layout's sky over its mosque, same shape again
    HorizonBackground {
        id: horizonBackground
        anchors.fill: parent
        visible: root.appHorizonScene
        mosque: root.appHorizonMosque
        times: root.todayTimes
        hijriDay: full.hijriDay
        minutes: full.nowMinutes
        sky: full.horizonSky
        radius: full.inPopup ? full.popupRadius : root.appBackgroundRadius
        // Where the cards start and the countdown ends, in our coordinates
        horizonY: contentColumn.y + body.y + horizonView.y + horizonView.horizonY - y
        textBottom: contentColumn.y + body.y + horizonView.y + horizonView.textBottom - y
        anchors.leftMargin: full.inPopup ? frameMetrics.bleed("left")
                                         : frameMetrics.shadow("left")
        anchors.rightMargin: full.inPopup ? frameMetrics.bleed("right")
                                          : frameMetrics.shadow("right")
        anchors.topMargin: full.inPopup ? frameMetrics.bleed("top")
                                        : frameMetrics.shadow("top")
        anchors.bottomMargin: full.inPopup ? frameMetrics.bleed("bottom")
                                           : frameMetrics.shadow("bottom")
    }

    // The Qalam's sheet of paper with its ruled frame
    QalamBackground {
        anchors.fill: parent
        visible: root.appQalamScene
        night: full.qalamNight
        radius: full.inPopup ? full.popupRadius : root.appBackgroundRadius
        sizeScale: full.sp
        anchors.leftMargin: full.inPopup ? frameMetrics.bleed("left")
                                         : frameMetrics.shadow("left")
        anchors.rightMargin: full.inPopup ? frameMetrics.bleed("right")
                                          : frameMetrics.shadow("right")
        anchors.topMargin: full.inPopup ? frameMetrics.bleed("top")
                                        : frameMetrics.shadow("top")
        anchors.bottomMargin: full.inPopup ? frameMetrics.bleed("bottom")
                                           : frameMetrics.shadow("bottom")
    }

    // The Kaaba's black cloth, with its belt across the widget
    KaabaBackground {
        anchors.fill: parent
        visible: root.appKaabaScene
        radius: full.inPopup ? full.popupRadius : root.appBackgroundRadius
        sizeScale: full.sp
        // Where the belt runs, in our coordinates
        bandTop: contentColumn.y + body.y + kaabaView.y + kaabaView.bandTop - y
        bandBottom: contentColumn.y + body.y + kaabaView.y + kaabaView.bandBottom - y
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
            frame.visible = !root.appPaintsBackground;
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
        target: root
        function onAppPaintsBackgroundChanged() {
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
        visible: root.configured && root.calendar === null
                 && (root.fetching || root.errorMessage === "")
        running: visible
    }

    /* ---------------------------- Error ---------------------------- */
    PlasmaExtras.PlaceholderMessage {
        anchors.centerIn: parent
        width: parent.width - Kirigami.Units.gridUnit * 2
        // errorMessage is the explanation, so without it this renders as a
        // bare title over an empty line. That happens for a moment right
        // after a mosque is chosen: the slug is written, calendar is still
        // null and refetch() has not set fetching yet. Let the busy
        // indicator below cover that gap instead.
        visible: root.configured && root.calendar === null
                 && !root.fetching && root.errorMessage !== ""
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
            id: headerName
            Layout.fillWidth: true
            // A floor, not a demand: a long mosque name elides instead of
            // stretching the widget to fit
            Layout.preferredWidth: Kirigami.Units.gridUnit * 8 * full.sp
            level: 3
            text: root.mosqueName
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            font.family: root.appFontFamily
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.2 * full.sp
            color: full.headerLit ? "white" : full.inkColor
        }

        PlasmaComponents3.Label {
            id: headerDate
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: root.hijriDateText
            font.family: root.appFontFamily
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * full.sp
            font.weight: Font.DemiBold
            color: full.headerLit ? "white" : full.inkColor
            opacity: full.headerLit ? 1 : 0.85
        }

        Kirigami.Separator {
            id: headerRule
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing * full.sp
            Layout.bottomMargin: Kirigami.Units.smallSpacing * full.sp
            // The Kaaba layout's gold belt runs right under it; hidden, not
            // removed, so the size stays the same in every layout
            // the Qalam draws its own ornament there
            opacity: full.kaabaLayout || full.qalamLayout ? 0 : 1
        }

        /* ------------------------- Body ------------------------- *
         * The Classic table always lays itself out, even when another
         * layout is shown, and its size is the body's size. So the widget
         * and the popup keep exactly the same size whichever layout or
         * background is picked; the other layouts fill that space.
         * Opacity 0, not visible: false, so the table keeps taking part in
         * the size calculation. */
        Item {
            id: body
            Layout.fillWidth: true
            implicitWidth: classicTable.implicitWidth
            implicitHeight: classicTable.implicitHeight

            ColumnLayout {
                id: classicTable
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: 0
                opacity: full.sundial || full.cardsLayout || full.horizonLayout || full.kaabaLayout
                         || full.qalamLayout ? 0 : 1
                enabled: !full.sundial && !full.cardsLayout && !full.horizonLayout && !full.kaabaLayout
                         && !full.qalamLayout

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
                                font.pointSize: Kirigami.Theme.defaultFont.pointSize * full.sp
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
                                font.pointSize: Kirigami.Theme.defaultFont.pointSize * full.sp
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
                            + Mawaqit.inCountdown(root.countdownFull, Plasmoid.configuration.labelLanguage)
                          : root.nextName + " " + Mawaqit.inCountdown(root.countdownFull, Plasmoid.configuration.labelLanguage)
                    opacity: 0.7
                    font.family: root.appFontFamily
                    font.pointSize: Kirigami.Theme.smallFont.pointSize * full.sp
                    color: root.appTextColor
                }
            }

            SundialView {
                anchors.fill: parent
                visible: full.sundial

                times: root.todayTimes
                names: root.names
                timeLabels: {
                    var out = [];
                    if (root.todayTimes) {
                        for (var i = 0; i < 6; ++i) {
                            out.push(Mawaqit.formatTime(root.todayTimes[i], root.use24h));
                        }
                    }
                    return out;
                }
                // On the dial the day wraps round, so after Isha tomorrow's
                // Fajr is marked too: it is the next point the countdown runs to
                nextIndex: root.next !== null ? root.next.index : -1
                countdownText: root.countdownClock
                showSunrise: Plasmoid.configuration.showSunrise
                boldNext: root.appBoldNext

                fontFamily: root.appFontFamily
                pointSize: Kirigami.Theme.defaultFont.pointSize * full.sp
                sizeScale: full.sp
                cornerRadius: Kirigami.Units.cornerRadius
            }

            CardsView {
                anchors.fill: parent
                visible: full.cardsLayout

                times: root.todayTimes
                names: root.names
                timeLabels: {
                    var out = [];
                    if (root.todayTimes) {
                        for (var i = 0; i < 6; ++i) {
                            out.push(Mawaqit.formatTime(root.todayTimes[i], root.use24h));
                        }
                    }
                    return out;
                }
                // After Isha the countdown runs to tomorrow's Fajr, so that
                // card is the one marked
                nextIndex: root.next !== null ? root.next.index : -1
                countdownText: root.countdownClock
                progress: root.nextProgress
                showSunrise: Plasmoid.configuration.showSunrise
                boldNext: root.appBoldNext

                fontFamily: root.appFontFamily
                pointSize: Kirigami.Theme.defaultFont.pointSize * full.sp
                sizeScale: full.sp
                cornerRadius: Kirigami.Units.cornerRadius
                textColor: root.appTextColor
                accentColor: root.appAccentColor
            }

            QalamView {
                anchors.fill: parent
                visible: full.qalamLayout

                times: root.todayTimes
                minutes: full.nowMinutes
                names: root.names
                timeLabels: {
                    var out = [];
                    if (root.todayTimes) {
                        for (var i = 0; i < 6; ++i) {
                            out.push(Mawaqit.formatTime(root.todayTimes[i], root.use24h));
                        }
                    }
                    return out;
                }
                nextIndex: root.next !== null ? root.next.index : -1
                nextIsTomorrow: root.next !== null && root.next.tomorrow === true
                countdownText: root.countdownClock
                progress: root.nextProgress
                boldNext: root.appBoldNext
                night: full.qalamNight

                fontFamily: root.appFontFamily
                nameFamily: full.calligraphyFamily
                pointSize: Kirigami.Theme.defaultFont.pointSize * full.sp
                sizeScale: full.sp
            }

            KaabaView {
                id: kaabaView
                anchors.fill: parent
                visible: full.kaabaLayout

                times: root.todayTimes
                minutes: full.nowMinutes
                names: root.names
                timeLabels: {
                    var out = [];
                    if (root.todayTimes) {
                        for (var i = 0; i < 6; ++i) {
                            out.push(Mawaqit.formatTime(root.todayTimes[i], root.use24h));
                        }
                    }
                    return out;
                }
                nextIndex: root.next !== null ? root.next.index : -1
                nextIsTomorrow: root.next !== null && root.next.tomorrow === true
                countdownText: root.countdownClock
                progress: root.nextProgress

                fontFamily: root.appFontFamily
                pointSize: Kirigami.Theme.defaultFont.pointSize * full.sp
                sizeScale: full.sp
                labelColor: full.inkColor
            }

            HorizonView {
                id: horizonView
                anchors.fill: parent
                visible: full.horizonLayout

                times: root.todayTimes
                minutes: full.nowMinutes
                names: root.names
                timeLabels: {
                    var out = [];
                    if (root.todayTimes) {
                        for (var i = 0; i < 6; ++i) {
                            out.push(Mawaqit.formatTime(root.todayTimes[i], root.use24h));
                        }
                    }
                    return out;
                }
                nextIndex: root.next !== null ? root.next.index : -1
                countdownText: root.countdownClock
                progress: root.nextProgress
                showSunrise: Plasmoid.configuration.showSunrise
                boldNext: root.appBoldNext

                fontFamily: root.appFontFamily
                pointSize: Kirigami.Theme.defaultFont.pointSize * full.sp
                sizeScale: full.sp
                // Switches with the header (Horizon.darkInk), white at night
                inkColor: full.horizonSky && full.horizonDarkInk ? Horizon.NAVY_INK : "#ffffff"
            }
        }
    }

    /* ------------------- Horizon header lighting --------------------- *
     * The band from the top of the sky down to the rule under the hijri
     * date, redrawn by headerlight.frag from the sky behind it and the
     * header text over it. Declared last, so it is drawn over both. */
    ShaderEffectSource {
        id: headerSky
        visible: false
        sourceItem: full.headerLit ? horizonBackground : null
        sourceRect: Qt.rect(0, 0, headerLight.width, headerLight.height)
        live: full.headerLit
    }
    // Not live: the countdown under the band changes every second, and a
    // live source would recapture the whole column each time. The header
    // text is captured again only when it, its size or its place changes.
    ShaderEffectSource {
        id: headerLetters
        visible: false
        sourceItem: full.headerLit ? contentColumn : null
        sourceRect: Qt.rect(headerLight.x - contentColumn.x, headerLight.y - contentColumn.y,
                            headerLight.width, headerLight.height)
        live: false
        readonly property var watched: [full.headerLit, headerName.text, headerName.contentWidth,
                                        headerName.contentHeight, headerName.y, headerDate.text,
                                        headerDate.contentWidth, headerDate.contentHeight,
                                        headerDate.y, contentColumn.x, contentColumn.y,
                                        contentColumn.width, headerLight.x, headerLight.y,
                                        headerLight.width, headerLight.height]
        onWatchedChanged: scheduleUpdate()
    }
    ShaderEffect {
        id: headerLight
        visible: full.headerLit
        x: horizonBackground.x
        y: horizonBackground.y
        width: horizonBackground.width
        height: Math.max(1, contentColumn.y + headerRule.y - y)
        fragmentShader: Qt.resolvedUrl("../shaders/headerlight.frag.qsb")

        readonly property var bodies: horizonBackground.bodies
        property var sky: headerSky
        property var letters: headerLetters
        property size bandSize: Qt.size(width, height)
        property real darkInk: full.horizonDarkInk ? 1 : 0
        property real skyLum: full.horizonSky ? Horizon.luminance(full.horizonSky.top) : 0
        property vector4d sun: bodies ? Qt.vector4d(bodies.sun.x, bodies.sun.y, bodies.r * 1.08,
                                                    bodies.sun.up ? 1 : 0)
                                      : Qt.vector4d(0, 0, 1, 0)
        property vector4d moon: bodies ? Qt.vector4d(bodies.moon.x, bodies.moon.y, bodies.r,
                                                     bodies.moon.up ? 1 : 0)
                                       : Qt.vector4d(0, 0, 1, 0)
    }
}
