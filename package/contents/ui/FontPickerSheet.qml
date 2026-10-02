import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

/* ------------------------- font picker sheet ------------------------ *
 * A fonts-only chooser, shared by the Panel and Popup/Appearance pages.
 * The native font dialog always shows style/size/effects/writing-system
 * panels and can't be trimmed (QFontDialog exposes no option to hide
 * them), so we list families ourselves. Enumeration is deferred to first
 * open and pushed off the initial paint with Qt.callLater; a ListView is
 * virtualized, so unlike the earlier ComboBox this doesn't stall
 * plasmashell. */
Kirigami.OverlaySheet {
    id: fontSheet
    title: i18n("Select font")

    // The family currently set, highlighted in the list
    property string selected: ""
    signal picked(string family)

    property var allFonts: []
    property bool loaded: false
    property bool loading: false

    function load() {
        if (loaded || loading) {
            return;
        }
        loading = true;
        // One tick later, so the sheet paints before the (fast, but not
        // free) enumeration runs.
        Qt.callLater(function () {
            fontSheet.allFonts = Qt.fontFamilies();
            fontSheet.loaded = true;
            fontSheet.loading = false;
        });
    }

    onOpened: {
        fontSearch.text = "";
        load();
    }

    header: Kirigami.SearchField {
        id: fontSearch
        placeholderText: i18n("Search fonts…")
    }

    ListView {
        id: fontListView
        implicitWidth: Kirigami.Units.gridUnit * 18
        implicitHeight: Kirigami.Units.gridUnit * 20
        clip: true

        model: {
            var q = fontSearch.text.toLowerCase();
            if (q === "") {
                return fontSheet.allFonts;
            }
            return fontSheet.allFonts.filter(function (f) {
                return f.toLowerCase().indexOf(q) !== -1;
            });
        }

        delegate: QQC2.ItemDelegate {
            required property string modelData
            width: ListView.view.width
            text: modelData
            highlighted: modelData === fontSheet.selected
            onClicked: {
                fontSheet.picked(modelData);
                fontSheet.close();
            }
        }

        QQC2.BusyIndicator {
            anchors.centerIn: parent
            running: fontSheet.loading
            visible: running
        }

        Kirigami.PlaceholderMessage {
            anchors.centerIn: parent
            width: parent.width - Kirigami.Units.gridUnit * 4
            visible: fontSheet.loaded && fontListView.count === 0
            text: i18n("No fonts found")
        }
    }
}
