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
    // The strip in the panel itself; only exists in a panel
    ConfigCategory {
        name: i18n("Panel")
        icon: "preferences-desktop-theme"
        source: "configPanel.qml"
        visible: configModel.inPanel
    }
    // The expanded view: the popup in a panel, the widget on the desktop
    ConfigCategory {
        name: configModel.inPanel ? i18n("Popup") : i18n("Appearance")
        icon: "preferences-desktop-color"
        source: "configAppearance.qml"
    }
}
