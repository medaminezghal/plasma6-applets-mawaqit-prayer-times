import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

/* The Appearance page of a panel widget. With the popup off (the default)
 * it is just the panel strip's settings (ConfigPanel.qml), with no tabs.
 * Once "Open the popup" is ticked, a tab bar appears on top: Panel for
 * those settings and Popup for the popup a click opens
 * (ConfigAppearance.qml, the same page a desktop widget gets as its
 * Appearance tab). It follows the checkbox at once, before Apply.
 *
 * The settings dialog reads and writes the cfg_* properties of the page it
 * shows (AppletConfiguration.qml in plasma-desktop), so every key of both
 * sub-pages is forwarded here by an alias. */
KCM.AbstractKCM {
    id: page

    framedView: false
    headerPaddingEnabled: false

    /* ------------------------- Panel tab --------------------------- */
    property alias cfg_panelPopupEnabled: panelPage.cfg_panelPopupEnabled
    property alias cfg_displayMode: panelPage.cfg_displayMode
    property alias cfg_verticalShowAllPrayers: panelPage.cfg_verticalShowAllPrayers
    property alias cfg_verticalShowHijri: panelPage.cfg_verticalShowHijri
    property alias cfg_showCountdownInPanel: panelPage.cfg_showCountdownInPanel
    property alias cfg_showHijriInPanel: panelPage.cfg_showHijriInPanel
    property alias cfg_numericHijriInPanel: panelPage.cfg_numericHijriInPanel
    property alias cfg_usePrayerIconsInPanel: panelPage.cfg_usePrayerIconsInPanel
    property alias cfg_panelFontFamily: panelPage.cfg_panelFontFamily
    property alias cfg_panelScale: panelPage.cfg_panelScale
    property alias cfg_panelBoldNextPrayer: panelPage.cfg_panelBoldNextPrayer
    property alias cfg_panelCustomTextColor: panelPage.cfg_panelCustomTextColor
    property alias cfg_panelTextColor: panelPage.cfg_panelTextColor
    property alias cfg_panelCustomAccentColor: panelPage.cfg_panelCustomAccentColor
    property alias cfg_panelAccentColor: panelPage.cfg_panelAccentColor

    /* ------------------------- Popup tab --------------------------- */
    property alias cfg_fontFamily: popupPage.cfg_fontFamily
    property alias cfg_fontScale: popupPage.cfg_fontScale
    property alias cfg_boldNextPrayer: popupPage.cfg_boldNextPrayer
    property alias cfg_customTextColor: popupPage.cfg_customTextColor
    property alias cfg_textColor: popupPage.cfg_textColor
    property alias cfg_customAccentColor: popupPage.cfg_customAccentColor
    property alias cfg_accentColor: popupPage.cfg_accentColor
    property alias cfg_customBackground: popupPage.cfg_customBackground
    property alias cfg_backgroundColor: popupPage.cfg_backgroundColor
    property alias cfg_backgroundOpacity: popupPage.cfg_backgroundOpacity
    property alias cfg_backgroundRadius: popupPage.cfg_backgroundRadius
    property alias cfg_layout: popupPage.cfg_layout
    property alias cfg_horizonMosque: popupPage.cfg_horizonMosque

    // With a single page there is nothing to switch between, so no bar;
    // hidden, it takes no room (AbstractKCM collapses an invisible header)
    header: QQC2.TabBar {
        id: tabs
        visible: page.cfg_panelPopupEnabled

        // Each tab takes half the bar, which spans the page. The KDE desktop
        // style sizes tab buttons to their label (width: implicitWidth in
        // qqc2-desktop-style's TabButton.qml), so the width is set here.
        QQC2.TabButton {
            width: Math.round(tabs.width / tabs.count)
            text: i18n("Panel")
        }
        QQC2.TabButton {
            width: tabs.width - Math.round(tabs.width / tabs.count)
            text: i18n("Popup")
        }
    }

    // Disabling the popup while its tab is shown goes back to the panel page
    Connections {
        target: page
        function onCfg_panelPopupEnabledChanged() {
            if (!page.cfg_panelPopupEnabled) {
                tabs.currentIndex = 0;
            }
        }
    }

    StackLayout {
        anchors.fill: parent
        currentIndex: tabs.currentIndex

        ConfigPanel {
            id: panelPage
        }
        ConfigAppearance {
            id: popupPage
        }
    }
}
