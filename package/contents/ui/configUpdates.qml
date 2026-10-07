import QtCore
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasmoid
import "../code/mawaqit.js" as Mawaqit

/* Installed version against the latest one on the KDE Store, with how to
 * update for the way the widget was installed. Plasma's own About page is
 * built from metadata.json and can't be extended, hence a page of its own.
 * The store is only contacted while this page is open. */
KCM.SimpleKCM {
    id: page

    readonly property string installedVersion: Plasmoid.metaData.version

    // A copy under the user's data directory (~/.local/share/plasma/
    // plasmoids) was installed from the KDE Store or with kpackagetool6;
    // anything else (/usr/share/...) belongs to a system package.
    readonly property bool localInstall: {
        var dataDir = StandardPaths.writableLocation(StandardPaths.GenericDataLocation).toString();
        return Qt.resolvedUrl(".").toString().indexOf(dataDir + "/plasma/plasmoids/") === 0;
    }

    // "checking", "upToDate", "available" or "error"
    property string checkStatus: "checking"
    property string latestVersion: ""
    property string errorText: ""
    property var request: null
    property int token: 0

    function check() {
        cancel();
        checkStatus = "checking";
        var myToken = ++token;
        request = Mawaqit.fetchStoreVersion(function (version) {
            if (myToken !== page.token) return;
            watchdog.stop();
            page.request = null;
            page.latestVersion = version;
            page.checkStatus = Mawaqit.compareVersions(version, page.installedVersion) > 0
                         ? "available" : "upToDate";
        }, function (message) {
            if (myToken !== page.token) return;
            watchdog.stop();
            page.request = null;
            page.errorText = message;
            page.checkStatus = "error";
        });
        watchdog.restart();
    }

    // Drop the outstanding request: its callback becomes a no-op
    function cancel() {
        token++;
        watchdog.stop();
        if (request !== null) {
            var r = request;
            request = null;
            r.abort();
        }
    }

    Timer {
        id: watchdog
        interval: 15000
        onTriggered: {
            page.cancel();
            page.errorText = i18n("the KDE Store did not respond in time");
            page.checkStatus = "error";
        }
    }

    Component.onCompleted: check()
    Component.onDestruction: cancel()

    Kirigami.FormLayout {
        Layout.fillWidth: true

        QQC2.Label {
            Kirigami.FormData.label: i18n("Installed version:")
            text: page.installedVersion
        }

        QQC2.Label {
            Kirigami.FormData.label: i18n("Latest version:")
            text: page.checkStatus === "checking" ? i18n("Checking…")
                : page.checkStatus === "error" ? i18n("Unknown")
                : page.latestVersion
        }

        QQC2.Label {
            Kirigami.FormData.label: i18n("Installed from:")
            text: page.localInstall ? i18n("KDE Store or local package")
                                    : i18n("System package")
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: page.checkStatus !== "checking"
            showCloseButton: false
            type: page.checkStatus === "available" ? Kirigami.MessageType.Information
                : page.checkStatus === "error" ? Kirigami.MessageType.Warning
                : Kirigami.MessageType.Positive
            text: page.checkStatus === "available"
                    ? (page.localInstall
                       ? i18n("Version %1 is available. To update, open “Add Widgets…” → “Get New Widgets…” → “Download New Plasma Widgets”, set the filter to “Updateable” and update Mawaqit Prayer Times. If you installed it with kpackagetool6, run “kpackagetool6 --type Plasma/Applet --upgrade” on the new package instead.", page.latestVersion)
                       : i18n("Version %1 is available. Update it with your system package manager; it may take some time to reach your package manager.", page.latestVersion))
                : page.checkStatus === "error"
                    ? i18n("Could not check for updates: %1", page.errorText)
                : i18n("You have the latest version.")
        }

        RowLayout {
            spacing: Kirigami.Units.smallSpacing

            QQC2.Button {
                text: i18n("Check Again")
                icon.name: "view-refresh"
                enabled: page.checkStatus !== "checking"
                onClicked: page.check()
            }

            QQC2.Button {
                text: i18n("Open Store Page")
                icon.name: "internet-services"
                onClicked: Qt.openUrlExternally(Mawaqit.STORE_PAGE)
            }
        }
    }
}
