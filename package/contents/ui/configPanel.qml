import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.kquickcontrols as KQControls
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import "../code/mawaqit.js" as Mawaqit

/* Appearance of the strip in the panel itself. Only listed in a panel
 * (see config/config.qml); the popup and the desktop widget are styled on
 * the other appearance page. The panel strip has no background of its own,
 * so there is nothing to set for it here. */
KCM.SimpleKCM {
    id: page

    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    // Bold and the accent color mark the next prayer among the others, so
    // they only mean something when the strip lists every prayer: a
    // horizontal panel in "All prayer times" mode. A vertical panel, or
    // "Only the next prayer", shows nothing but the next prayer.
    readonly property bool showsAllPrayers: !vertical && cfg_displayMode === "full"

    // Prayer names for the icon legend, in the prayer-name language saved on
    // the General page
    readonly property var prayerLabels: Mawaqit.prayerNames(Plasmoid.configuration.labelLanguage)

    /* ------------------- bound configuration keys ------------------- */
    property string cfg_displayMode
    property alias cfg_showCountdownInPanel: countdownCheck.checked
    property alias cfg_showHijriInPanel: hijriCheck.checked
    property alias cfg_numericHijriInPanel: numericHijriCheck.checked
    property alias cfg_usePrayerIconsInPanel: iconsCheck.checked

    property string cfg_panelFontFamily
    property alias cfg_panelScale: panelScaleSlider.value
    property alias cfg_panelBoldNextPrayer: panelBoldNextCheck.checked
    property alias cfg_panelCustomTextColor: panelTextColorCheck.checked
    property alias cfg_panelTextColor: panelTextColorButton.color
    property alias cfg_panelCustomAccentColor: panelAccentColorCheck.checked
    property alias cfg_panelAccentColor: panelAccentColorButton.color

    FontPickerSheet {
        id: fontSheet
        selected: page.cfg_panelFontFamily
        onPicked: (family) => page.cfg_panelFontFamily = family
    }

    Kirigami.FormLayout {
        Layout.fillWidth: true

        /* ------------------------ Display ------------------------- */
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Display")
        }

        // Only meaningful in a horizontal panel: it switches the inline
        // panel strip between all prayers and the next one. A vertical
        // panel always shows the next prayer's glyph, so it's hidden there
        // (and this whole page only exists in a panel).
        ColumnLayout {
            Kirigami.FormData.label: i18n("Panel shows:")
            visible: Plasmoid.formFactor === PlasmaCore.Types.Horizontal
            spacing: Kirigami.Units.smallSpacing

            QQC2.RadioButton {
                text: i18n("All prayer times of the day")
                checked: page.cfg_displayMode === "full"
                onToggled: page.cfg_displayMode = "full"
            }

            QQC2.RadioButton {
                text: i18n("Only the next prayer")
                checked: page.cfg_displayMode === "next"
                onToggled: page.cfg_displayMode = "next"
            }

            // Kept self-descriptive rather than trimmed to "Hijri date":
            // a screen reader announces the checkbox label on its own,
            // without the group label above it
            QQC2.CheckBox {
                id: hijriCheck
                Layout.topMargin: Kirigami.Units.smallSpacing
                text: i18n("Show Hijri date")
            }

            QQC2.CheckBox {
                id: numericHijriCheck
                Layout.leftMargin: Kirigami.Units.gridUnit
                enabled: hijriCheck.checked
                text: i18n("As digits (01/04/1448)")
            }

            QQC2.CheckBox {
                id: countdownCheck
                text: i18n("Show countdown")
            }

            QQC2.CheckBox {
                id: iconsCheck
                Layout.topMargin: Kirigami.Units.smallSpacing
                text: i18n("Use icons instead of prayer names")
            }
        }

        // Legend for the prayer glyphs. In a horizontal panel it explains
        // the option above, and is shown whether or not that option is on
        // so the glyphs can be understood before committing to them. In a
        // vertical panel the strip is always a glyph, so the legend stands
        // on its own with no option attached. Mirrored for RTL
        // prayer-name languages so the order matches the panel; the rest
        // of the page keeps the system direction. Follows the saved
        // prayer-name language (General page).
        RowLayout {
            LayoutMirroring.enabled: Mawaqit.isArabic(Plasmoid.configuration.labelLanguage)
            LayoutMirroring.childrenInherit: true
            Layout.leftMargin: Kirigami.Units.gridUnit
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.largeSpacing

            Repeater {
                model: ["fajr", "shuruq", "dhuhr",
                        "asr", "maghrib", "isha"]

                delegate: ColumnLayout {
                    id: legendCell
                    required property string modelData
                    required property int index
                    spacing: 0

                    Kirigami.Icon {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                        Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                        source: Qt.resolvedUrl("../icons/"
                                               + legendCell.modelData + ".svg")
                        isMask: true
                        color: Kirigami.Theme.textColor
                    }

                    QQC2.Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: page.prayerLabels[legendCell.index]
                        font: Kirigami.Theme.smallFont
                        opacity: 0.75
                    }
                }
            }
        }

        /* -------------------------- Size -------------------------- */
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Size")
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Panel size:")
            Layout.fillWidth: true

            QQC2.Slider {
                id: panelScaleSlider
                Layout.fillWidth: true
                Layout.preferredWidth: Kirigami.Units.gridUnit * 12
                from: 0.5
                to: 1.0
                stepSize: 0.05
            }
            QQC2.Label {
                text: i18n("%1%", Math.round(panelScaleSlider.value * 100))
                Layout.minimumWidth: Kirigami.Units.gridUnit * 3
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            text: i18n("100% fills the panel's thickness. Smaller sizes stay centered in the panel.")
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            opacity: 0.7
            wrapMode: Text.WordWrap
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
                text: page.cfg_panelFontFamily === ""
                      ? i18n("System default")
                      : page.cfg_panelFontFamily
            }

            QQC2.Button {
                text: i18n("Choose…")
                icon.name: "settings-configure"
                onClicked: fontSheet.open()
            }

            QQC2.Button {
                icon.name: "edit-clear"
                text: i18n("Reset")
                enabled: page.cfg_panelFontFamily !== ""
                onClicked: page.cfg_panelFontFamily = ""
                QQC2.ToolTip.text: i18n("Use the system default font")
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
        }

        QQC2.CheckBox {
            id: panelBoldNextCheck
            visible: page.showsAllPrayers
            text: i18n("Show the next prayer in bold")
        }

        // Bold is requested as a real font weight, so a family without a
        // bold face simply renders regular
        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            visible: page.showsAllPrayers && page.cfg_panelFontFamily !== ""
            text: i18n("Some fonts have no bold style. With those, “Show the next prayer in bold” has no effect; the next prayer is still marked by its accent color.")
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
            id: panelTextColorCheck
            Kirigami.FormData.label: i18n("Text color:")
            text: i18n("Use a custom color")
        }

        KQControls.ColorButton {
            id: panelTextColorButton
            Kirigami.FormData.label: i18n("Custom text color:")
            enabled: panelTextColorCheck.checked
            showAlphaChannel: false
        }

        QQC2.CheckBox {
            id: panelAccentColorCheck
            visible: page.showsAllPrayers
            Kirigami.FormData.label: i18n("Next-prayer accent:")
            text: i18n("Use a custom color")
        }

        KQControls.ColorButton {
            id: panelAccentColorButton
            visible: page.showsAllPrayers
            Kirigami.FormData.label: i18n("Custom accent color:")
            enabled: panelAccentColorCheck.checked
            showAlphaChannel: false
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            visible: !page.vertical && !page.showsAllPrayers
            text: i18n("Bold and the accent color mark the next prayer among the others, so they appear here when the panel shows all prayer times.")
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            opacity: 0.7
            wrapMode: Text.WordWrap
        }
    }
}
