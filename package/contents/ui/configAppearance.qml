import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.kquickcontrols as KQControls
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

KCM.SimpleKCM {
    id: page

    // In a panel the expanded view is a popup window whose shape is the
    // theme's, so it keeps the theme's own corner radius and the setting has
    // nothing to act on; there the custom background only changes colour and
    // opacity.
    readonly property bool inPanel: Plasmoid.formFactor === PlasmaCore.Types.Horizontal
                                    || Plasmoid.formFactor === PlasmaCore.Types.Vertical

    /* ------------------- bound configuration keys ------------------- */
    // This page styles the expanded view: the desktop widget, or the popup
    // of a panel widget. The panel strip has its own page (configPanel.qml).
    // fontFamily is set by the font picker sheet below; "" = system default.
    property string cfg_fontFamily
    property alias cfg_fontScale: scaleSlider.value
    property alias cfg_boldNextPrayer: boldNextCheck.checked

    property alias cfg_customTextColor: customTextColorCheck.checked
    property alias cfg_textColor: textColorButton.color
    property alias cfg_customAccentColor: customAccentColorCheck.checked
    property alias cfg_accentColor: accentColorButton.color

    property alias cfg_customBackground: customBgCheck.checked
    property alias cfg_backgroundColor: bgColorButton.color
    // Int config keys are driven explicitly (value + onMoved) so the slider's
    // real value never gets coerced into the alias with a type warning.
    property int cfg_backgroundOpacity
    property int cfg_backgroundRadius

    // Layout of the expanded view, and the Horizon layout's mosque
    property string cfg_layout
    property string cfg_horizonMosque
    readonly property bool sundial: cfg_layout === "sundial"
    readonly property bool horizon: cfg_layout === "horizon"
    readonly property bool kaaba: cfg_layout === "kaaba"
    readonly property bool qalam: cfg_layout === "qalam"
    // Layouts that paint their own background and choose their own colors,
    // so the custom colors and background are unused
    readonly property bool ownBackground: sundial || horizon || kaaba || qalam
    // The layout actually shown, with main.qml's fallback to Classic
    readonly property string layoutKey: ["sundial", "cards", "horizon", "kaaba", "qalam"]
                                        .indexOf(cfg_layout) >= 0 ? cfg_layout : "classic"
    // Size of the layout pictures, large enough to read; the row of them
    // scrolls sideways
    readonly property real thumbWidth: Kirigami.Units.gridUnit * 16
    readonly property real thumbHeight: Kirigami.Units.gridUnit * 16
    readonly property string ownLayoutName: sundial ? i18n("Sundial")
                                            : horizon ? i18n("Horizon")
                                            : kaaba ? i18n("Kaaba")
                                            : qalam ? i18n("Qalam") : ""

    FontPickerSheet {
        id: fontSheet
        selected: page.cfg_fontFamily
        onPicked: (family) => page.cfg_fontFamily = family
    }

    /* ============================= UI ================================ *
     * The layout pictures run across the whole page, between two forms:
     * one for the Layout heading and one for everything else. The two are
     * twins, so their label and field columns line up as one form would. */
    ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        /* ------------------------- Layout ------------------------- */
        Kirigami.FormLayout {
            id: layoutHeading
            Layout.fillWidth: true
            twinFormLayouts: [form]

            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Layout")
            }
        }

        // One choice per layout in a single row, each under a picture of
        // it; the row scrolls sideways (drag it, use its scroll bar or a
        // touchpad, or Tab between the choices). A plain mouse wheel keeps
        // scrolling the page.
        // Radio buttons write the key directly, like "Panel shows:" on the
        // Panel page. Anything other than "sundial", "cards", "horizon",
        // "kaaba" or "qalam" reads as Classic, the same fallback main.qml
        // uses.
        // Across the whole page, outside the forms: inside one it would
        // either stand beside the shared label column, which right-aligns
        // every label, or widen the form and every stretching field with it
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing

            QQC2.Label {
                Layout.alignment: Qt.AlignVCenter
                text: i18n("Layout:")
            }

            ListView {
                id: layoutChoices
                Layout.fillWidth: true
                Accessible.name: i18n("Layout")
                // ListView has no implicit size of its own: without one it would
                // be 0 px tall
                implicitWidth: page.thumbWidth
                implicitHeight: delegateHeight + layoutScrollBar.implicitHeight
                                + Kirigami.Units.smallSpacing
                orientation: ListView.Horizontal
                spacing: Kirigami.Units.largeSpacing
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                // Keep every choice alive, so the radio buttons stay in their group
                cacheBuffer: 10000
                // The chosen layout, in view when the page opens
                currentIndex: layoutModel.findIndex(entry => entry.key === page.layoutKey)
                highlightFollowsCurrentItem: false
                Component.onCompleted: Qt.callLater(() => positionViewAtIndex(currentIndex, ListView.Contain))

                readonly property real delegateHeight: page.thumbHeight + Kirigami.Units.smallSpacing
                                                       + radioMetrics.implicitHeight
                readonly property var layoutModel: [
                    { key: "classic", text: i18n("Classic") },
                    { key: "sundial", text: i18n("Sundial") },
                    { key: "cards", text: i18n("Cards") },
                    { key: "horizon", text: i18n("Horizon") },
                    { key: "kaaba", text: i18n("Kaaba") },
                    { key: "qalam", text: i18n("Qalam") }
                ]
                model: layoutModel

                QQC2.ScrollBar.horizontal: QQC2.ScrollBar {
                    id: layoutScrollBar
                    policy: QQC2.ScrollBar.AlwaysOn
                }

                // Only measured, for the height of a choice
                QQC2.RadioButton {
                    id: radioMetrics
                    visible: false
                    text: "X"
                }

                QQC2.ButtonGroup {
                    id: layoutGroup
                }

                delegate: ColumnLayout {
                    id: choice

                    required property var modelData
                    required property int index
                    readonly property bool selected: page.layoutKey === modelData.key

                    // A translated name longer than the picture widens its own
                    // choice rather than being cut
                    width: Math.max(page.thumbWidth, radio.implicitWidth)
                    height: layoutChoices.delegateHeight
                    spacing: Kirigami.Units.smallSpacing

                    // The picture picks the layout too, like the radio button's
                    // own label
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: page.thumbWidth
                        implicitHeight: page.thumbHeight
                        radius: Kirigami.Units.cornerRadius
                        color: "transparent"
                        border.width: choice.selected ? 2 : 0
                        border.color: Kirigami.Theme.highlightColor

                        Image {
                            anchors.fill: parent
                            anchors.margins: 4
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            smooth: true
                            mipmap: true
                            // Horizon shows the mosque chosen below it
                            source: Qt.resolvedUrl("../images/layout-"
                                                   + (choice.modelData.key === "horizon"
                                                      ? (page.cfg_horizonMosque === "nabawi"
                                                         ? "horizon-nabawi" : "horizon-aqsa")
                                                      : choice.modelData.key)
                                                   + ".png")
                        }

                        HoverHandler {
                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            onTapped: if (!choice.selected) radio.click()
                        }
                    }

                    QQC2.RadioButton {
                        id: radio
                        Layout.alignment: Qt.AlignHCenter
                        QQC2.ButtonGroup.group: layoutGroup
                        text: choice.modelData.text
                        checked: choice.selected
                        onToggled: if (checked) page.cfg_layout = choice.modelData.key
                        // Moving between the choices with the keyboard brings
                        // the focused one into view
                        onActiveFocusChanged: if (activeFocus) {
                            layoutChoices.positionViewAtIndex(choice.index, ListView.Contain);
                        }
                    }
                }
            }
        }

        Kirigami.FormLayout {
            id: form
            Layout.fillWidth: true

            // Radio buttons write the key directly; anything other than
            // "nabawi" reads as al-Aqsa, the same fallback main.qml uses
            ColumnLayout {
                Kirigami.FormData.label: i18n("Mosque:")
                visible: page.horizon
                spacing: Kirigami.Units.smallSpacing

                QQC2.RadioButton {
                    text: i18n("Al-Aqsa Mosque")
                    checked: page.cfg_horizonMosque !== "nabawi"
                    onToggled: page.cfg_horizonMosque = "aqsa"
                }

                QQC2.RadioButton {
                    text: i18n("Prophet's Mosque")
                    checked: page.cfg_horizonMosque === "nabawi"
                    onToggled: page.cfg_horizonMosque = "nabawi"
                }
            }


            /* -------------------------- Size -------------------------- */
            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Size")
            }

            // The expanded view only: the desktop widget, or the popup when the
            // widget sits in a panel. The panel strip is sized on the Panel page.
            RowLayout {
                Kirigami.FormData.label: page.inPanel ? i18n("Popup size:") : i18n("Widget size:")
                Layout.fillWidth: true

                QQC2.Slider {
                    id: scaleSlider
                    Layout.fillWidth: true
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 12
                    from: 0.5
                    to: 2.0
                    stepSize: 0.05
                }
                QQC2.Label {
                    text: i18n("%1%", Math.round(scaleSlider.value * 100))
                    Layout.minimumWidth: Kirigami.Units.gridUnit * 3
                }
            }

            /* ------------------------- Fonts -------------------------- */
            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Fonts")
            }

            RowLayout {
                Kirigami.FormData.label: i18n("Font:")
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                QQC2.Label {
                    Layout.fillWidth: true
                    Layout.maximumWidth: Kirigami.Units.gridUnit * 12
                    elide: Text.ElideRight
                    text: page.cfg_fontFamily === ""
                          ? i18n("System default")
                          : page.cfg_fontFamily
                }

                QQC2.Button {
                    text: i18n("Choose…")
                    icon.name: "settings-configure"
                    onClicked: fontSheet.open()
                }

                QQC2.Button {
                    icon.name: "edit-clear"
                    text: i18n("Reset")
                    enabled: page.cfg_fontFamily !== ""
                    onClicked: page.cfg_fontFamily = ""
                    QQC2.ToolTip.text: i18n("Use the system default font")
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                }
            }

            // Bold is requested as a real font weight (the synthetic fallback
            // misfired on monospace families), so a family without a bold face
            // simply renders regular. Say so where the family is picked.
            QQC2.Label {
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 22
                visible: page.cfg_fontFamily !== ""
                text: i18n("Some fonts have no bold style. With those, “Show the next prayer in bold” has no effect; the next prayer is still marked by its accent color.")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.7
                wrapMode: Text.WordWrap
            }

            QQC2.CheckBox {
                id: boldNextCheck
                enabled: !page.kaaba
                text: i18n("Show the next prayer in bold")
            }

            QQC2.Label {
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 22
                visible: page.kaaba
                text: i18n("The Kaaba layout shows the next prayer by the needle stitching its cartouche.")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.7
                wrapMode: Text.WordWrap
            }

            /* ------------------------ Colors -------------------------- */
            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Colors")
            }

            QQC2.CheckBox {
                id: customTextColorCheck
                Kirigami.FormData.label: i18n("Text color:")
                enabled: !page.ownBackground
                text: i18n("Use a custom color")
            }

            KQControls.ColorButton {
                id: textColorButton
                Kirigami.FormData.label: i18n("Custom text color:")
                enabled: customTextColorCheck.checked && !page.ownBackground
                showAlphaChannel: false
            }

            QQC2.CheckBox {
                id: customAccentColorCheck
                Kirigami.FormData.label: i18n("Next-prayer accent:")
                enabled: !page.ownBackground
                text: i18n("Use a custom color")
            }

            KQControls.ColorButton {
                id: accentColorButton
                Kirigami.FormData.label: i18n("Custom accent color:")
                enabled: customAccentColorCheck.checked && !page.ownBackground
                showAlphaChannel: false
            }

            QQC2.Label {
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 22
                visible: page.ownBackground
                text: i18n("The %1 layout uses its own colors; the custom colors apply again with the Classic or Cards layout.", page.ownLayoutName)
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.7
                wrapMode: Text.WordWrap
            }

            /* ---------------------- Background ------------------------- */
            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Background")
            }

            QQC2.CheckBox {
                id: customBgCheck
                Kirigami.FormData.label: i18n("Background:")
                enabled: !page.ownBackground
                text: i18n("Use a custom background")
            }

            KQControls.ColorButton {
                id: bgColorButton
                Kirigami.FormData.label: i18n("Color:")
                enabled: customBgCheck.checked && !page.ownBackground
                showAlphaChannel: false
            }

            RowLayout {
                Kirigami.FormData.label: i18n("Opacity:")
                enabled: customBgCheck.checked && !page.ownBackground
                Layout.fillWidth: true

                QQC2.Slider {
                    id: bgOpacitySlider
                    Layout.fillWidth: true
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 12
                    from: 0
                    to: 100
                    stepSize: 1
                    value: page.cfg_backgroundOpacity
                    onMoved: page.cfg_backgroundOpacity = value
                }
                QQC2.Label {
                    text: i18n("%1%", Math.round(bgOpacitySlider.value))
                    Layout.minimumWidth: Kirigami.Units.gridUnit * 3
                }
            }

            RowLayout {
                Kirigami.FormData.label: i18n("Corner radius:")
                // The Sundial, Horizon, Kaaba and Qalam layouts are cut to this
                // radius too
                enabled: customBgCheck.checked || page.ownBackground
                visible: !page.inPanel
                Layout.fillWidth: true

                QQC2.Slider {
                    id: bgRadiusSlider
                    Layout.fillWidth: true
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 12
                    from: 0
                    to: 40
                    stepSize: 1
                    value: page.cfg_backgroundRadius
                    onMoved: page.cfg_backgroundRadius = value
                }
                QQC2.Label {
                    text: i18np("%1 px", "%1 px", Math.round(bgRadiusSlider.value))
                    Layout.minimumWidth: Kirigami.Units.gridUnit * 3
                }
            }

            QQC2.Label {
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 22
                text: page.horizon
                      ? i18n("The Horizon layout draws its own sky; the custom background applies again with the Classic or Cards layout.")
                      : page.kaaba
                      ? i18n("The Kaaba layout draws its own cloth; the custom background applies again with the Classic or Cards layout.")
                      : page.qalam
                      ? i18n("The Qalam layout draws its own paper; the custom background applies again with the Classic or Cards layout.")
                      : page.sundial
                      ? i18n("The Sundial layout draws its own sky; the custom background applies again with the Classic or Cards layout.")
                      : page.inPanel
                      ? i18n("A custom background replaces the popup's theme frame, behind the prayer times. The popup keeps the theme's corner shape.")
                      : i18n("A custom background replaces the widget's theme frame, behind the prayer times.")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.7
                wrapMode: Text.WordWrap
            }
        }
    }
}
