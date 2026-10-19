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
    readonly property string ownLayoutName: sundial ? i18n("Sundial")
                                            : horizon ? i18n("Horizon")
                                            : kaaba ? i18n("Kaaba")
                                            : qalam ? i18n("Qalam") : ""

    FontPickerSheet {
        id: fontSheet
        selected: page.cfg_fontFamily
        onPicked: (family) => page.cfg_fontFamily = family
    }

    /* ============================= UI ================================ */
    Kirigami.FormLayout {
        Layout.fillWidth: true

        /* ------------------------- Layout ------------------------- */
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Layout")
        }

        // Radio buttons write the key directly, like "Panel shows:" on the
        // Panel page. Anything other than "sundial", "cards", "horizon",
        // "kaaba" or "qalam" reads as Classic, the same fallback main.qml
        // uses.
        ColumnLayout {
            Kirigami.FormData.label: i18n("Layout:")
            spacing: Kirigami.Units.smallSpacing

            QQC2.RadioButton {
                text: i18n("Classic")
                checked: !page.sundial && page.cfg_layout !== "cards" && !page.horizon && !page.kaaba
                         && !page.qalam
                onToggled: page.cfg_layout = "classic"
            }

            QQC2.RadioButton {
                text: i18n("Sundial")
                checked: page.sundial
                onToggled: page.cfg_layout = "sundial"
            }

            QQC2.RadioButton {
                text: i18n("Cards")
                checked: page.cfg_layout === "cards"
                onToggled: page.cfg_layout = "cards"
            }

            QQC2.RadioButton {
                text: i18n("Horizon")
                checked: page.horizon
                onToggled: page.cfg_layout = "horizon"
            }

            QQC2.RadioButton {
                text: i18n("Kaaba")
                checked: page.kaaba
                onToggled: page.cfg_layout = "kaaba"
            }

            QQC2.RadioButton {
                text: i18n("Qalam")
                checked: page.qalam
                onToggled: page.cfg_layout = "qalam"
            }
        }

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

        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            visible: page.horizon
            text: i18n("The sky over the mosque through the day, following today's prayer times, with the sun and the moon where they stand. The moon's phase follows the hijri date.")
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            opacity: 0.7
            wrapMode: Text.WordWrap
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            visible: page.kaaba
            text: i18n("The black cloth of the Kaaba with its gold belt, one cartouche per prayer. The prayers already prayed today are embroidered in gold, and the next one is stitched as its time approaches.")
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            opacity: 0.7
            wrapMode: Text.WordWrap
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            visible: page.qalam
            text: i18n("The prayer names written on paper with a reed pen. The prayers already prayed today are in dry ink, and the next one is written as its time approaches. Arabic names use a calligraphic font when one is installed (Aref Ruqaa, Amiri, Scheherazade New or Noto Naskh Arabic).")
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            opacity: 0.7
            wrapMode: Text.WordWrap
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            visible: page.sundial
            text: i18n("Today's prayers around a 24-hour dial, on a sky drawn from today's prayer times: day from sunrise to maghrib, night from isha to fajr, and the twilights between them.")
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            opacity: 0.7
            wrapMode: Text.WordWrap
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
            text: i18n("Show the next prayer in bold")
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
