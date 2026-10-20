import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.configuration

ConfigModel {
    id: configModel

    readonly property bool inPanel: Plasmoid.formFactor === PlasmaCore.Types.Horizontal
                                    || Plasmoid.formFactor === PlasmaCore.Types.Vertical

    ConfigCategory {
        name: i18n("General")
        icon: "preferences-system-time"
        source: "configGeneral.qml"
    }
    // In a panel: the strip and, while enabled, the popup, as two
    // sub-tabs of one page
    ConfigCategory {
        name: i18n("Appearance")
        icon: "preferences-desktop-color"
        source: "configPanelAppearance.qml"
        visible: configModel.inPanel
    }
    // On the desktop: the widget itself
    ConfigCategory {
        name: i18n("Appearance")
        icon: "preferences-desktop-color"
        source: "ConfigAppearance.qml"
        visible: !configModel.inPanel
    }
}
