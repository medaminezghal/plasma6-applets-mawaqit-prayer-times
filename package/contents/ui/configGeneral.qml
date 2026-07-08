import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import "../code/mawaqit.js" as Mawaqit

KCM.SimpleKCM {
    id: page

    /* ------------------- bound configuration keys ------------------- */
    property string cfg_mosqueSlug
    property string cfg_mosqueName
    property string cfg_displayMode
    property string cfg_labelLanguage
    property alias cfg_use24h: use24hCheck.checked
    property alias cfg_showSunrise: sunriseCheck.checked
    property alias cfg_showCountdownInPanel: countdownCheck.checked
    property alias cfg_refreshDays: refreshSpin.value

    // Cache keys: declared so the dialog doesn't warn; never touched here
    property string cfg_cachedCalendar
    property int cfg_cachedYear
    property string cfg_lastFetch
    property int cfg_cachedHijriAdjustment
    property bool cfg_cachedHijriForce30

    /* --------------------------- state ------------------------------ */
    property bool locating: false
    property bool searching: false
    property string statusText: ""
    property bool statusIsError: false
    property var searchResults: []
    property var gpsSource: null

    property string lastVerifiedSlug: ""

    onCfg_mosqueSlugChanged: {
        // Never rewrite the field while the user is typing in it — that
        // moves the cursor and makes the page appear to refresh
        if (!slugField.activeFocus && slugField.text !== cfg_mosqueSlug) {
            slugField.text = cfg_mosqueSlug;
        }
    }

    function setStatus(text, isError) {
        statusText = text;
        statusIsError = isError === true;
    }

    /* ------------------------ location flow ------------------------- */

    function detectLocation() {
        locating = true;
        setStatus(i18n("Detecting your location…"), false);
        try {
            gpsSource = Qt.createQmlObject(
                'import QtPositioning; PositionSource { active: true; updateInterval: 1000 }',
                page, "gpsSource");
            gpsSource.positionChanged.connect(function () {
                var c = gpsSource.position.coordinate;
                if (c && !isNaN(c.latitude)) {
                    stopGps();
                    gpsTimeout.stop();
                    onCoordinates(c.latitude, c.longitude, "");
                }
            });
            gpsTimeout.restart();
        } catch (e) {
            console.log("[mawaqit] QtPositioning unavailable: " + e);
            ipFallback();
        }
    }

    function stopGps() {
        if (gpsSource !== null) {
            gpsSource.active = false;
            gpsSource.destroy();
            gpsSource = null;
        }
    }

    function ipFallback() {
        setStatus(i18n("Locating via your IP address…"), false);
        Mawaqit.ipLocate(function (loc) {
            onCoordinates(loc.lat, loc.lon, loc.city);
        }, function (err) {
            locating = false;
            setStatus(i18n("Location detection failed (%1). Type your city above, or paste your mosque's mawaqit.net address below.", err), true);
        });
    }

    function onCoordinates(lat, lon, cityHint) {
        setStatus(i18n("Searching for mosques near you…"), false);
        Mawaqit.searchMosquesByCoords(lat, lon, function (results) {
            locating = false;
            searchResults = results;
            setStatus(results.length > 0
                ? i18np("%1 mosque found near you — pick yours",
                        "%1 mosques found near you — pick yours", results.length)
                : i18n("No mosques found near you. Try searching by name above."),
                results.length === 0);
        }, function () {
            if (cityHint !== "") {
                locating = false;
                searchField.text = cityHint;
                setStatus(i18n("Detected: %1", cityHint), false);
                doSearch();
            } else {
                Mawaqit.reverseGeocode(lat, lon, function (city) {
                    locating = false;
                    searchField.text = city;
                    setStatus(i18n("Detected: %1", city), false);
                    doSearch();
                }, function (err) {
                    console.log("[mawaqit] reverse geocode failed: " + err);
                    ipFallback();
                });
            }
        });
    }

    Timer {
        id: gpsTimeout
        interval: 8000
        onTriggered: {
            page.stopGps();
            page.ipFallback();
        }
    }

    /* ------------------------- search flow -------------------------- */

    function doSearch() {
        var word = searchField.text.trim();
        if (word === "") {
            return;
        }
        searching = true;
        searchResults = [];
        Mawaqit.searchMosques(word, function (results, via) {
            searching = false;
            searchResults = results;
            console.log("[mawaqit] search via " + via + ": " + results.length + " results");
            setStatus(results.length > 0
                ? i18np("%1 mosque found — pick yours", "%1 mosques found — pick yours", results.length)
                : i18n("No mosques found for “%1”. You can paste your mosque's mawaqit.net address below instead.", word),
                results.length === 0);
        }, function (err) {
            searching = false;
            setStatus(i18n("Search failed (%1). You can paste your mosque's mawaqit.net address below instead.", err), true);
        });
    }

    function applySlugInput() {
        var normalized = Mawaqit.normalizeSlug(slugField.text);
        if (normalized !== slugField.text) {
            slugField.text = normalized;
        }
        if (page.cfg_mosqueSlug !== normalized) {
            page.cfg_mosqueSlug = normalized;
            page.cfg_mosqueName = "";
        }
        if (normalized === "" || normalized === page.lastVerifiedSlug) {
            return;
        }
        page.lastVerifiedSlug = normalized;
        // Resolve the mosque name right away, so the dialog stores it and
        // the user gets confirmation the slug is valid
        setStatus(i18n("Checking mosque…"), false);
        Mawaqit.fetchConf(normalized, function (conf) {
            if (page.cfg_mosqueSlug !== normalized) {
                return;
            }
            page.cfg_mosqueName = conf.name;
            setStatus(i18n("Selected: %1", Mawaqit.cleanMosqueName(conf.name)), false);
        }, function (err) {
            if (page.cfg_mosqueSlug !== normalized) {
                return;
            }
            setStatus(i18n("Couldn't verify this mosque (%1)", err), true);
        });
    }

    Component.onDestruction: stopGps()
    Component.onCompleted: slugField.text = cfg_mosqueSlug

    /* ============================= UI ================================ */

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        Kirigami.FormLayout {
            Layout.fillWidth: true

            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Mosque")
            }

            RowLayout {
                Kirigami.FormData.label: i18n("Find your mosque:")

                QQC2.TextField {
                    id: searchField
                    Layout.fillWidth: true
                    placeholderText: i18n("City or mosque name…")
                    onAccepted: page.doSearch()
                }

                QQC2.Button {
                    icon.name: "search"
                    text: i18n("Search")
                    enabled: !page.searching && searchField.text.trim() !== ""
                    onClicked: page.doSearch()
                }
            }

            QQC2.Button {
                icon.name: "mark-location"
                text: i18n("Detect my location")
                enabled: !page.locating
                onClicked: page.detectLocation()
            }

            RowLayout {
                visible: page.statusText !== "" || page.locating || page.searching
                QQC2.BusyIndicator {
                    visible: page.locating || page.searching
                    running: visible
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: Kirigami.Units.iconSizes.small
                }
                QQC2.Label {
                    Layout.fillWidth: true
                    Layout.maximumWidth: Kirigami.Units.gridUnit * 22
                    text: page.statusText
                    wrapMode: Text.WordWrap
                    color: page.statusIsError
                           ? Kirigami.Theme.negativeTextColor
                           : Kirigami.Theme.textColor
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    opacity: 0.9
                }
            }
        }

        /* --------------------- search results ----------------------- */
        QQC2.ScrollView {
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 10
            visible: page.searchResults.length > 0

            ListView {
                id: resultsList
                clip: true
                model: page.searchResults

                delegate: QQC2.ItemDelegate {
                    required property var modelData
                    required property int index

                    width: resultsList.width
                    highlighted: slugField.text === modelData.slug

                    contentItem: ColumnLayout {
                        spacing: 0
                        QQC2.Label {
                            Layout.fillWidth: true
                            text: modelData.label
                            elide: Text.ElideRight
                        }
                        QQC2.Label {
                            Layout.fillWidth: true
                            text: "mawaqit.net/fr/" + modelData.slug
                            elide: Text.ElideRight
                            opacity: 0.6
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                        }
                    }

                    onClicked: {
                        slugField.text = modelData.slug;
                        page.cfg_mosqueSlug = modelData.slug;
                        page.cfg_mosqueName = modelData.label;
                        page.lastVerifiedSlug = modelData.slug;
                        page.setStatus(i18n("Selected: %1", modelData.label), false);
                    }
                }
            }
        }

        Kirigami.FormLayout {
            Layout.fillWidth: true

            QQC2.TextField {
                id: slugField
                Kirigami.FormData.label: i18n("Mosque page or slug:")
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 18
                placeholderText: i18n("Paste mawaqit.net URL or slug…")
                // Dirty the config on every keystroke so Apply enables
                // immediately; normalization and verification wait for
                // Enter or focus leaving the field
                onTextEdited: page.cfg_mosqueSlug = text
                onEditingFinished: page.applySlugInput()
            }

            QQC2.Label {
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 22
                text: i18n("You can paste the full address, e.g. mawaqit.net/fr/your-mosque")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.7
                wrapMode: Text.WordWrap
            }

            /* ----------------------- Display ------------------------ */
            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Display")
            }

            QQC2.RadioButton {
                Kirigami.FormData.label: i18n("Widget shows:")
                text: i18n("All prayer times of the day")
                checked: page.cfg_displayMode === "full"
                onToggled: page.cfg_displayMode = "full"
            }

            QQC2.RadioButton {
                text: i18n("Only the next prayer")
                checked: page.cfg_displayMode === "next"
                onToggled: page.cfg_displayMode = "next"
            }

            QQC2.ComboBox {
                id: langCombo
                Kirigami.FormData.label: i18n("Prayer names:")
                textRole: "text"
                valueRole: "value"
                model: [
                    { text: i18n("System language"), value: "auto" },
                    { text: "English", value: "en" },
                    { text: "العربية", value: "ar" },
                    { text: "Français", value: "fr" }
                ]
                onActivated: page.cfg_labelLanguage = currentValue
                Component.onCompleted: currentIndex = indexOfValue(page.cfg_labelLanguage)
            }

            QQC2.CheckBox {
                id: use24hCheck
                text: i18n("24-hour time format")
            }

            QQC2.CheckBox {
                id: sunriseCheck
                text: i18n("Show sunrise (shuruq)")
            }

            QQC2.CheckBox {
                id: countdownCheck
                text: i18n("Show countdown in the panel")
            }

            /* ----------------------- Updates ------------------------ */
            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Updates")
            }

            QQC2.SpinBox {
                id: refreshSpin
                Kirigami.FormData.label: i18n("Re-download calendar every:")
                from: 1
                to: 30
                textFromValue: function (value) {
                    return i18np("%1 day", "%1 days", value);
                }
            }

            QQC2.Label {
                Layout.fillWidth: true
                text: i18n("The whole year is cached locally, so the widget works offline. Re-downloading only picks up schedule corrections and the mosque's hijri date adjustment.")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.7
                wrapMode: Text.WordWrap
            }
        }
    }
}
