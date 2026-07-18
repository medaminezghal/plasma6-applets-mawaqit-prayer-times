import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.kquickcontrols as KQControls

KCM.SimpleKCM {
    id: page

    /* ------------------- bound configuration keys ------------------- */
    // fontFamily is set by the native font dialog below (family only); "" =
    // system default.
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
    property alias cfg_backgroundRadius: bgRadiusSpin.value

    /* ----------------------- font picker sheet ---------------------- *
     * A fonts-only chooser. The native font dialog always shows style/size/
     * effects/writing-system panels and can't be trimmed (QFontDialog exposes
     * no option to hide them), so we list families ourselves. Enumeration is
     * deferred to first open and pushed off the initial paint with
     * Qt.callLater; a ListView is virtualized, so unlike the earlier ComboBox
     * this doesn't stall plasmashell. */
    Kirigami.OverlaySheet {
        id: fontSheet
        title: i18n("Select font")

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
                highlighted: modelData === page.cfg_fontFamily
                onClicked: {
                    page.cfg_fontFamily = modelData;
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

    /* ============================= UI ================================ */
    Kirigami.FormLayout {
        Layout.fillWidth: true

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

        RowLayout {
            Kirigami.FormData.label: i18n("Font size:")
            Layout.fillWidth: true

            QQC2.Slider {
                id: scaleSlider
                Layout.fillWidth: true
                Layout.preferredWidth: Kirigami.Units.gridUnit * 12
                from: 0.7
                to: 2.0
                stepSize: 0.05
            }
            QQC2.Label {
                text: i18n("%1%", Math.round(scaleSlider.value * 100))
                Layout.minimumWidth: Kirigami.Units.gridUnit * 3
            }
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
            text: i18n("Use a custom background")
        }

        KQControls.ColorButton {
            id: bgColorButton
            Kirigami.FormData.label: i18n("Color:")
            enabled: customBgCheck.checked
            showAlphaChannel: false
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Opacity:")
            enabled: customBgCheck.checked
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

        QQC2.SpinBox {
            id: bgRadiusSpin
            Kirigami.FormData.label: i18n("Corner radius:")
            enabled: customBgCheck.checked
            from: 0
            to: 40
            textFromValue: function (value) { return i18np("%1 px", "%1 px", value); }
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            text: i18n("A custom background replaces the widget's theme frame. On the desktop and in the panel popup it is drawn behind the prayer times; the panel strip itself is left untouched.")
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            opacity: 0.7
            wrapMode: Text.WordWrap
        }
    }
}
