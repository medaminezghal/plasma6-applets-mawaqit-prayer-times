import QtCore
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import "../code/mawaqit.js" as Mawaqit
import "../code/countries.js" as Countries

KCM.SimpleKCM {
    id: page

    /* ------------------- bound configuration keys ------------------- */
    property string cfg_mosqueSlug
    property string cfg_mosqueName
    property string cfg_labelLanguage
    property alias cfg_use24h: use24hCheck.checked
    property alias cfg_showSunrise: sunriseCheck.checked
    property alias cfg_refreshDays: refreshSpin.value

    // Cache keys: declared so the dialog doesn't warn about unknown initial
    // properties. Plasma writes every declared cfg_ key back on Apply/OK,
    // so saveConfig() below refreshes them first; otherwise the snapshot
    // taken when the page opened would overwrite the widget's live cache.
    property string cfg_cachedCalendar
    property int cfg_cachedYear
    property string cfg_lastFetch
    property int cfg_cachedHijriAdjustment
    property bool cfg_cachedHijriForce30

    // Called by Plasma's config dialog before it writes the cfg_ keys back.
    // Keys are written in main.xml order, mosqueSlug first: switching
    // mosque makes the widget clear its cache right then, and a stale
    // snapshot written after it would restore the previous mosque's
    // calendar under the new mosque. So on a switch the cache keys go out
    // empty; otherwise they carry the live values, making the write-back a
    // no-op even if the widget refetched while the dialog was open.
    function saveConfig() {
        var live = Plasmoid.configuration;
        // Normally done when the field loses focus; repeated here in case
        // the dialog is confirmed without that happening
        cfg_mosqueSlug = Mawaqit.normalizeMosque(cfg_mosqueSlug);
        var switching = cfg_mosqueSlug !== live.mosqueSlug;
        // A slug confirmed before its check finished leaves the previous
        // mosque's name behind; the widget fetches the real one
        if (switching && cfg_mosqueName === live.mosqueName) {
            cfg_mosqueName = "";
        }
        cfg_cachedCalendar = switching ? "" : live.cachedCalendar;
        cfg_cachedYear = switching ? 0 : live.cachedYear;
        cfg_lastFetch = switching ? "" : live.lastFetch;
        cfg_cachedHijriAdjustment = switching ? 0 : live.cachedHijriAdjustment;
        cfg_cachedHijriForce30 = switching ? false : live.cachedHijriForce30;
    }

    // Keep the cache keys in step with the widget while the dialog is open.
    // Plasma enables Apply (and asks about unsaved changes on close) when
    // any declared cfg_ key differs from the live config, so a fetch while
    // the dialog was open - e.g. right after picking a mosque and pressing
    // Apply - made an untouched dialog look modified.
    Connections {
        target: Plasmoid.configuration
        function onCachedCalendarChanged() { page.cfg_cachedCalendar = Plasmoid.configuration.cachedCalendar; }
        function onCachedYearChanged() { page.cfg_cachedYear = Plasmoid.configuration.cachedYear; }
        function onLastFetchChanged() { page.cfg_lastFetch = Plasmoid.configuration.lastFetch; }
        function onCachedHijriAdjustmentChanged() { page.cfg_cachedHijriAdjustment = Plasmoid.configuration.cachedHijriAdjustment; }
        function onCachedHijriForce30Changed() { page.cfg_cachedHijriForce30 = Plasmoid.configuration.cachedHijriForce30; }
    }

    /* --------------------------- state ------------------------------ */
    property string statusText: ""
    property bool statusIsError: false

    property string lastVerifiedSlug: ""

    /* ------------------------- mosque finder ------------------------- *
     * Searches the mosques Mawaqit's map lists for one country (see
     * fetchCountryMosques in mawaqit.js): nothing is downloaded until the
     * user searches, then the whole country once, and every search after
     * that runs here. */

    // Most results listed; the status says when there are more
    readonly property int finderLimit: 50
    // Country picked in the combo box (alpha-2 code, "" = none)
    property string finderCountry: ""
    // Country whose mosques are in finderMosques
    property string finderLoadedCountry: ""
    property var finderMosques: []
    property var finderResults: []
    property bool finderLoading: false
    property string finderStatus: ""
    property bool finderStatusIsError: false
    // Responses from an older download are a no-op
    property int finderToken: 0
    property var finderRequest: null
    // Where "Near me" found the user: { lat, lon, approximate }, or null.
    // Kept for later searches, so results show their distance.
    property var finderOrigin: null

    property bool locating: false
    // Location detection runs through several asynchronous steps (GeoClue,
    // IP lookup, reverse geocoding); a newer detection or a search the user
    // starts makes the older callbacks a no-op
    property int locateToken: 0
    property var gpsSource: null
    // A GeoClue fix less accurate than this (metres) is treated like an IP
    // lookup: good for the country, not for the city
    readonly property real preciseAccuracyMeters: 3000

    // The configured slug when the link field shows it shortened by
    // Mawaqit.displaySlug(), "" when the field shows it as it is. Text in
    // the field equal to the shortened form stands for this slug.
    property string hiddenSlug: ""

    // Show slug in the link field, shortened if it has to be
    function showSlug(slug) {
        var shown = Mawaqit.displaySlug(slug);
        hiddenSlug = shown !== slug ? slug : "";
        if (slugField.text !== shown) {
            slugField.text = shown;
        }
    }

    // The slug the link field's text stands for
    function fieldSlug(text) {
        return hiddenSlug !== "" && text === Mawaqit.displaySlug(hiddenSlug) ? hiddenSlug : text;
    }

    onCfg_mosqueSlugChanged: {
        // Never rewrite the field while the user is typing in it — that
        // moves the cursor and makes the page appear to refresh
        if (!slugField.activeFocus && fieldSlug(slugField.text) !== cfg_mosqueSlug) {
            showSlug(cfg_mosqueSlug);
        }
    }

    function setStatus(text, isError) {
        statusText = text;
        statusIsError = isError === true;
    }

    /* ------------------------- mosque finder ------------------------- */

    function setFinderStatus(text, isError) {
        finderStatus = text;
        finderStatusIsError = isError === true;
    }

    // The territory of the system locale ("ar_TN" -> "TN"), the country
    // preselected before the user picks one
    function localeCountry() {
        var m = /_([A-Z]{2})/.exec(Qt.locale().name);
        return m && Countries.indexOf(m[1]) >= 0 ? Countries.canonical(m[1]) : "";
    }

    function countryName(code) {
        var i = Countries.indexOf(code);
        return i >= 0 ? Countries.COUNTRIES[i].name : code;
    }

    function selectCountry(code) {
        finderCountry = code;
        countryCombo.currentIndex = Countries.indexOf(code);
    }

    function cancelFinderRequest() {
        finderToken++;
        finderLoading = false;
        if (finderRequest !== null) {
            var request = finderRequest;
            finderRequest = null;
            // abort() runs the callback, which the token change made a no-op
            request.abort();
        }
    }

    // A search the user starts wins over a detection still running
    function userSearch() {
        searchDelay.stop();
        cancelDetection();
        runSearch();
    }

    function runSearch() {
        var query = searchField.text.trim();
        if (finderCountry === "") {
            finderResults = [];
            setFinderStatus(query !== "" ? i18n("Choose your country first.") : "", query !== "");
            return;
        }
        if (query === "" && finderOrigin === null) {
            finderResults = [];
            setFinderStatus("", false);
            return;
        }
        if (finderLoadedCountry !== finderCountry) {
            loadCountry(finderCountry);
            return;
        }
        showResults(query);
    }

    function loadCountry(code) {
        cancelFinderRequest();
        var token = finderToken;
        finderResults = [];
        finderLoading = true;
        setFinderStatus(i18n("Downloading the mosques of %1…", countryName(code)), false);
        finderRequest = Mawaqit.fetchCountryMosques(Countries.mapCodes(code), function (mosques) {
            if (token !== page.finderToken) return;
            page.finderRequest = null;
            page.finderLoading = false;
            page.finderMosques = mosques;
            page.finderLoadedCountry = code;
            // The user may have changed the country or the text meanwhile
            page.runSearch();
        }, function (err) {
            if (token !== page.finderToken) return;
            page.finderRequest = null;
            page.finderLoading = false;
            page.setFinderStatus(i18n("The mosque search is unavailable (%1). Use “Search the web” below, or paste your mosque's link.", err), true);
        });
    }

    function showResults(query) {
        var country = countryName(finderCountry);
        if (finderMosques.length === 0) {
            finderResults = [];
            setFinderStatus(i18n("Mawaqit's map lists no mosques in %1. Use “Search the web” below, or paste your mosque's link.", country), true);
            return;
        }
        var found = Mawaqit.findMosques(finderMosques, query, finderOrigin, finderLimit);
        finderResults = found.results;
        if (found.total === 0) {
            setFinderStatus(i18n("No mosque found for “%1” in %2. Use “Search the web” below, or paste your mosque's link.", Mawaqit.hideWord(query), country), true);
        } else if (query === "") {
            setFinderStatus(finderOrigin.approximate
                ? i18n("Mosques nearest to your approximate location, from your internet provider. If none is near you, type your city or your mosque's name.")
                : i18n("Mosques nearest to you — pick yours"), false);
        } else if (found.total > found.results.length) {
            setFinderStatus(i18n("%1 mosques found, showing the first %2. Type more to narrow them down.", found.total, found.results.length), false);
        } else {
            setFinderStatus(i18np("%1 mosque found — pick yours", "%1 mosques found — pick yours", found.total), false);
        }
        resultsList.positionViewAtBeginning();
    }

    function pickMosque(mosque) {
        var name = Mawaqit.cleanMosqueName(mosque.name);
        showSlug(mosque.slug);
        page.cfg_mosqueSlug = mosque.slug;
        page.cfg_mosqueName = name;
        page.lastVerifiedSlug = mosque.slug;
        setStatus(i18n("Selected: %1", name), false);
    }

    function formatDistance(km) {
        return km < 10 ? i18nc("distance", "%1 km", km.toFixed(1))
                       : i18nc("distance", "%1 km", Math.round(km));
    }

    Timer {
        id: searchDelay
        interval: 250
        onTriggered: page.userSearch()
    }

    /* ------------------------ location flow ------------------------- */

    function cancelDetection() {
        locateToken++;
        stopGps();
        gpsTimeout.stop();
        locating = false;
    }

    function detectLocation() {
        cancelDetection();
        locating = true;
        setFinderStatus(i18n("Detecting your location…"), false);
        try {
            // Created at runtime so Qt Positioning stays an optional
            // dependency. On Plasma, GeoClue usually refuses the request
            // (its default config wants a location agent Plasma doesn't
            // run); failed() lets us fall back right away instead of
            // waiting for the timeout.
            gpsSource = Qt.createQmlObject(
                'import QtPositioning; PositionSource {'
                + ' signal failed();'
                + ' readonly property bool hasError: sourceError !== PositionSource.NoError;'
                + ' active: true; updateInterval: 1000;'
                + ' onSourceErrorChanged: if (hasError) failed()'
                + ' }',
                page, "gpsSource");
            // Errors can already be set during creation (e.g. no GeoClue on
            // D-Bus), before failed() can be connected
            if (!gpsSource.valid || gpsSource.hasError) {
                console.log("[mawaqit] positioning unavailable (valid: "
                            + gpsSource.valid + ", error: " + gpsSource.sourceError + ")");
                gpsFailed();
                return;
            }
            gpsSource.failed.connect(function () {
                console.log("[mawaqit] positioning source error " + gpsSource.sourceError);
                gpsFailed();
            });
            gpsSource.positionChanged.connect(function () {
                if (gpsSource === null) {
                    return;
                }
                var p = gpsSource.position;
                var c = p.coordinate;
                if (c && !isNaN(c.latitude)) {
                    // GeoClue on a wired machine only has its own IP-based
                    // source, which is no better than our IP lookup
                    var approximate = !p.horizontalAccuracyValid
                        || p.horizontalAccuracy > page.preciseAccuracyMeters;
                    stopGps();
                    gpsTimeout.stop();
                    gpsFix(c.latitude, c.longitude, approximate);
                }
            });
            gpsTimeout.restart();
        } catch (e) {
            console.log("[mawaqit] QtPositioning unavailable: " + e);
            gpsSource = null;
            ipFallback();
        }
    }

    function gpsFailed() {
        if (gpsSource === null) {
            return;
        }
        stopGps();
        gpsTimeout.stop();
        ipFallback();
    }

    function stopGps() {
        if (gpsSource !== null) {
            gpsSource.active = false;
            gpsSource.destroy();
            gpsSource = null;
        }
    }

    // A GeoClue fix has no country; ask for it, or fall back to the IP
    // lookup, which has one
    function gpsFix(lat, lon, approximate) {
        var token = locateToken;
        Mawaqit.reverseCountry(lat, lon, function (country) {
            if (token !== page.locateToken) return;
            onLocated(lat, lon, country, approximate);
        }, function (err) {
            if (token !== page.locateToken) return;
            console.log("[mawaqit] " + err);
            ipFallback();
        });
    }

    function ipFallback() {
        var token = locateToken;
        setFinderStatus(i18n("Locating via your IP address…"), false);
        Mawaqit.ipLocate(function (loc) {
            if (token !== page.locateToken) return;
            onLocated(loc.lat, loc.lon, loc.country, true);
        }, function (err) {
            if (token !== page.locateToken) return;
            page.locating = false;
            page.setFinderStatus(i18n("Location detection failed (%1). Choose your country and type your city or your mosque's name.", err), true);
        });
    }

    function onLocated(lat, lon, country, approximate) {
        locating = false;
        finderOrigin = { lat: lat, lon: lon, approximate: approximate === true };
        if (Countries.indexOf(country) >= 0) {
            selectCountry(Countries.canonical(country));
        }
        // The nearest mosques, whatever was typed before
        searchField.text = "";
        runSearch();
    }

    Timer {
        id: gpsTimeout
        interval: 8000
        onTriggered: page.gpsFailed()
    }

    /* ------------------------- mosque page -------------------------- */

    function applySlugInput() {
        var normalized = Mawaqit.normalizeMosque(fieldSlug(slugField.text));
        showSlug(normalized);
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

    /* -------------------------- update check -------------------------- *
     * Compares the installed version with the KDE Store's, only while this
     * page is open. Silent unless a newer version exists: a failed check
     * shows nothing. */

    // Newer KDE Store version, or "" when up to date or unknown
    property string newerVersion: ""
    property var updateRequest: null
    property int updateToken: 0

    // A copy under the user's data directory (~/.local/share/plasma/
    // plasmoids) came from the KDE Store or kpackagetool6; anything else
    // (/usr/share/...) belongs to a system package.
    readonly property bool localInstall: {
        var dataDir = StandardPaths.writableLocation(StandardPaths.GenericDataLocation).toString();
        return Qt.resolvedUrl(".").toString().indexOf(dataDir + "/plasma/plasmoids/") === 0;
    }

    function checkForUpdate() {
        cancelUpdateCheck();
        var token = updateToken;
        var installed = Plasmoid.metaData.version;
        updateRequest = Mawaqit.fetchStoreVersion(function (version) {
            if (token !== page.updateToken) return;
            updateWatchdog.stop();
            page.updateRequest = null;
            page.newerVersion = Mawaqit.compareVersions(version, installed) > 0 ? version : "";
        }, function (message) {
            if (token !== page.updateToken) return;
            updateWatchdog.stop();
            page.updateRequest = null;
            console.log("[mawaqit] update check: " + message);
        });
        updateWatchdog.restart();
    }

    // Drop the outstanding request: its callback becomes a no-op
    function cancelUpdateCheck() {
        updateToken++;
        updateWatchdog.stop();
        if (updateRequest !== null) {
            var request = updateRequest;
            updateRequest = null;
            request.abort();
        }
    }

    Timer {
        id: updateWatchdog
        interval: 15000
        onTriggered: page.cancelUpdateCheck()
    }

    Component.onDestruction: {
        cancelDetection();
        cancelFinderRequest();
        cancelUpdateCheck();
    }
    Component.onCompleted: {
        showSlug(cfg_mosqueSlug);
        selectCountry(localeCountry());
        checkForUpdate();
    }

    /* ============================= UI ================================ */

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        // Only shown when the KDE Store has a newer version
        QQC2.Label {
            Layout.fillWidth: true
            Layout.rightMargin: Kirigami.Units.gridUnit
            visible: page.newerVersion !== ""
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: page.localInstall
                ? i18n("Version %1 is available. To update, open “Add Widgets…” → “Get New Widgets…” → “Download New Plasma Widgets”, set the filter to “Updateable” and update Mawaqit Prayer Times.", page.newerVersion)
                : i18n("Version %1 is available. Update it with your system package manager; it may take some time to reach your package manager.", page.newerVersion)
        }

        Kirigami.FormLayout {
            id: finderForm
            Layout.fillWidth: true
            // Section rules span the whole form, so leave a gutter wide
            // enough that they stop short of the scrollbar instead of
            // running underneath it
            Layout.rightMargin: Kirigami.Units.gridUnit
            // Same label column as the form under the results
            twinFormLayouts: [mainForm]

            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Mosque")
            }

            QQC2.ComboBox {
                id: countryCombo
                Kirigami.FormData.label: i18n("Country:")
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 18
                model: Countries.COUNTRIES
                textRole: "name"
                valueRole: "code"
                currentIndex: -1
                displayText: currentIndex < 0 ? i18n("Choose your country…") : currentText
                onActivated: {
                    page.finderCountry = currentValue;
                    // A location from "Near me" is in the country it found;
                    // distances from it mean nothing in another one
                    page.finderOrigin = null;
                    page.userSearch();
                }
            }

            RowLayout {
                Kirigami.FormData.label: i18n("Find your mosque:")
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 22

                QQC2.TextField {
                    id: searchField
                    Layout.fillWidth: true
                    placeholderText: i18n("Mosque name, city or address…")
                    // Results follow the typing; the country is
                    // downloaded once, then searched locally
                    onTextEdited: searchDelay.restart()
                    // Enter searches right away and is swallowed here, so it
                    // does not fall through to the dialog's OK button
                    Keys.onReturnPressed: (event) => { page.userSearch(); event.accepted = true; }
                    Keys.onEnterPressed: (event) => { page.userSearch(); event.accepted = true; }
                }

                QQC2.Button {
                    icon.name: "mark-location"
                    text: i18n("Near me")
                    enabled: !page.locating
                    onClicked: page.detectLocation()
                }
            }

            QQC2.Label {
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 22
                text: i18n("“Near me” usually relies on your internet provider's location, which can be in another city. Typing your city or your mosque's name is more reliable.")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.7
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 22
                visible: page.finderStatus !== "" || page.locating || page.finderLoading
                QQC2.BusyIndicator {
                    visible: page.locating || page.finderLoading
                    running: visible
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: Kirigami.Units.iconSizes.small
                }
                QQC2.Label {
                    Layout.fillWidth: true
                    text: page.finderStatus
                    wrapMode: Text.WordWrap
                    color: page.finderStatusIsError
                           ? Kirigami.Theme.negativeTextColor
                           : Kirigami.Theme.textColor
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    opacity: 0.9
                }
            }
        }

        /* ------------------------ finder results ------------------------ */
        QQC2.ScrollView {
            Layout.fillWidth: true
            Layout.rightMargin: Kirigami.Units.gridUnit
            Layout.preferredHeight: Kirigami.Units.gridUnit * 10
            visible: page.finderResults.length > 0

            ListView {
                id: resultsList
                clip: true
                model: page.finderResults

                delegate: QQC2.ItemDelegate {
                    required property var modelData
                    required property int index

                    width: resultsList.width
                    highlighted: page.cfg_mosqueSlug === modelData.slug

                    contentItem: ColumnLayout {
                        spacing: 0
                        QQC2.Label {
                            Layout.fillWidth: true
                            text: modelData.name
                            elide: Text.ElideRight
                        }
                        QQC2.Label {
                            Layout.fillWidth: true
                            text: modelData.distance >= 0
                                  ? (modelData.place !== ""
                                     ? i18nc("mosque address, distance", "%1 · %2", modelData.place, page.formatDistance(modelData.distance))
                                     : page.formatDistance(modelData.distance))
                                  : modelData.place
                            visible: text !== ""
                            elide: Text.ElideRight
                            opacity: 0.6
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                        }
                    }

                    onClicked: page.pickMosque(modelData)
                }
            }
        }

        Kirigami.FormLayout {
            id: mainForm
            Layout.fillWidth: true
            Layout.rightMargin: Kirigami.Units.gridUnit
            twinFormLayouts: [finderForm]

            QQC2.TextField {
                id: slugField
                Kirigami.FormData.label: i18n("Mosque link:")
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 18
                placeholderText: i18n("Paste your mosque's mawaqit.net link…")
                // Dirty the config on every keystroke so Apply enables
                // immediately; normalization and verification wait for
                // Enter or focus leaving the field
                onTextEdited: page.cfg_mosqueSlug = page.fieldSlug(text)
                onEditingFinished: page.applySlugInput()
                // Enter applies + verifies the slug in place; swallow it so it
                // does not fall through to the dialog's OK button and close it
                Keys.onReturnPressed: (event) => { page.applySlugInput(); event.accepted = true; }
                Keys.onEnterPressed: (event) => { page.applySlugInput(); event.accepted = true; }
            }

            QQC2.Label {
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 22
                visible: page.statusText !== ""
                text: page.statusText
                wrapMode: Text.WordWrap
                color: page.statusIsError
                       ? Kirigami.Theme.negativeTextColor
                       : Kirigami.Theme.textColor
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.9
            }

            QQC2.Label {
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 22
                text: i18n("Not in the list? “Search the web” looks for your mosque's page on mawaqit.net, using what you typed above. Open the page and paste its address here.")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.7
                wrapMode: Text.WordWrap
            }

            QQC2.Button {
                icon.name: "internet-web-browser"
                text: i18n("Search the web")
                onClicked: Qt.openUrlExternally(Mawaqit.webSearchUrl(
                    searchField.text.trim(),
                    page.finderCountry !== "" ? page.countryName(page.finderCountry) : ""))
            }

            QQC2.Label {
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 22
                text: i18n("In the Mawaqit app, open your mosque, tap Share and paste only the link from the message, e.g. https://mawaqit.net/ar/id/12345. A mosque page address such as mawaqit.net/fr/your-mosque, or its last part, works too.")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.7
                wrapMode: Text.WordWrap
            }

            /* ----------------------- Display ------------------------ */
            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Display")
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
                text: i18n("Show sunrise (Shuruq)")
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
                Layout.maximumWidth: Kirigami.Units.gridUnit * 22
                text: i18n("The whole year is cached locally, so the widget works offline. Re-downloading only picks up schedule corrections and the mosque's Hijri date adjustment.")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.7
                wrapMode: Text.WordWrap
            }
        }
    }
}
