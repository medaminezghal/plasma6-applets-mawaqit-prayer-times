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

    // Layout of the expanded view, and the Sundial's background
    property string cfg_layout
    property string cfg_dialBackground
    property string cfg_horizonMosque
    readonly property bool sundial: cfg_layout === "sundial"
    // The Sky replaces the custom background in the Sundial layout
    readonly property bool skyShown: sundial && cfg_dialBackground === "sky"
    readonly property bool horizon: cfg_layout === "horizon"
    // Layouts that paint their own background, so the custom one is unused
    readonly property bool ownBackground: skyShown || horizon

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
        // Panel page. Anything other than "sundial", "cards" or "horizon"
        // reads as Classic, the same fallback main.qml uses.
        ColumnLayout {
            Kirigami.FormData.label: i18n("Layout:")
            spacing: Kirigami.Units.smallSpacing

            QQC2.RadioButton {
                text: i18n("Classic")
                checked: !page.sundial && page.cfg_layout !== "cards" && !page.horizon
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

        ColumnLayout {
            Kirigami.FormData.label: i18n("Sundial background:")
            visible: page.sundial
            spacing: Kirigami.Units.smallSpacing

            QQC2.RadioButton {
                text: i18n("Theme")
                checked: page.cfg_dialBackground !== "sky"
                onToggled: page.cfg_dialBackground = "theme"
            }

            QQC2.RadioButton {
                text: i18n("Sky")
                checked: page.cfg_dialBackground === "sky"
                onToggled: page.cfg_dialBackground = "sky"
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            visible: page.sundial
            text: page.skyShown
                  ? i18n("The sky is drawn from today's prayer times: day from sunrise to maghrib, night from isha to fajr, and the twilights between them.")
                  : i18n("Uses the theme's background, or the custom background below.")
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
            text: i18n("Use a custom color")
        }

        KQControls.ColorButton {
            id: textColorButton
            Kirigami.FormData.label: i18n("Custom text color:")
            enabled: customTextColorCheck.checked
            showAlphaChannel: false
        }

        QQC2.CheckBox {
            id: customAccentColorCheck
            Kirigami.FormData.label: i18n("Next-prayer accent:")
            text: i18n("Use a custom color")
        }

        KQControls.ColorButton {
            id: accentColorButton
            Kirigami.FormData.label: i18n("Custom accent color:")
            enabled: customAccentColorCheck.checked
            showAlphaChannel: false
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
            // The Sky and the Horizon layout are cut to this radius too
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
                  ? i18n("The Horizon layout draws its own sky; the custom background applies again with another layout.")
                  : page.skyShown
                  ? i18n("The Sundial's Sky background is in use; the custom background applies again with the Classic layout or the Theme background.")
                  : page.inPanel
                  ? i18n("A custom background replaces the popup's theme frame, behind the prayer times. The popup keeps the theme's corner shape.")
                  : i18n("A custom background replaces the widget's theme frame, behind the prayer times.")
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            opacity: 0.7
            wrapMode: Text.WordWrap
        }
    }
}
