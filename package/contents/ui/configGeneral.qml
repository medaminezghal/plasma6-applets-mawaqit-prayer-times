import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
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
    property alias cfg_showHijriInPanel: hijriCheck.checked
    property alias cfg_numericHijriInPanel: numericHijriCheck.checked
    property alias cfg_usePrayerIconsInPanel: iconsCheck.checked
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
        cfg_mosqueSlug = Mawaqit.normalizeSlug(cfg_mosqueSlug);
        var switching = cfg_mosqueSlug !== live.mosqueSlug;
        // A slug typed or pasted without picking a result leaves the
        // previous mosque's name behind; the widget fetches the real one
        if (switching && cfg_mosqueName === live.mosqueName) {
            cfg_mosqueName = "";
        }
        cfg_cachedCalendar = switching ? "" : live.cachedCalendar;
        cfg_cachedYear = switching ? 0 : live.cachedYear;
        cfg_lastFetch = switching ? "" : live.lastFetch;
        cfg_cachedHijriAdjustment = switching ? 0 : live.cachedHijriAdjustment;
        cfg_cachedHijriForce30 = switching ? false : live.cachedHijriForce30;
    }

    /* --------------------------- state ------------------------------ */
    property bool locating: false
    property bool searching: false
    property string statusText: ""
    property bool statusIsError: false
    property var searchResults: []
    // Paging: the API returns Mawaqit.SEARCH_PAGE_SIZE results per page.
    // searchQuery is the query behind the current list ("" = none);
    // searchToken makes responses from an older search a no-op.
    property string searchQuery: ""
    property int searchPageLoaded: 0
    property bool searchHasMore: false
    property bool loadingMore: false
    property int searchToken: 0
    // What the current list is, so its status line can be rebuilt with the
    // new count after "Show more mosques": a "word" or "nearby" search, and
    // whether it rests on an approximate (internet provider) location -
    // for a word search, the approximate city that was searched
    property string resultsKind: ""
    property bool resultsApproximate: false
    property string resultsApproxCity: ""
    // Same idea for location detection, whose steps (GeoClue, IP lookup,
    // reverse geocoding) are all asynchronous
    property int locateToken: 0
    property var gpsSource: null
    // City filled in by location detection when the fix was only
    // approximate; consumed by the next doSearch()
    property string pendingApproximateCity: ""

    property string lastVerifiedSlug: ""

    // A GeoClue fix less accurate than this (metres) is treated like an IP
    // lookup: good for the country, not for the city
    readonly property real preciseAccuracyMeters: 3000

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

    // Whatever starts a new search or detection cancels the other one and
    // clears its busy flag itself. A superseded callback only returns, so
    // without this its flag stayed set for good: starting a detection
    // while a search was running left the Search button disabled, and
    // searching while detecting left "Detect my location" disabled.
    function cancelSearch() {
        searchToken++;
        searching = false;
        loadingMore = false;
    }

    function cancelDetection() {
        locateToken++;
        stopGps();
        gpsTimeout.stop();
        locating = false;
    }

    function detectLocation() {
        cancelSearch();
        locateToken++;
        locating = true;
        setStatus(i18n("Detecting your location…"), false);
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
                    onCoordinates(c.latitude, c.longitude, "", approximate);
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

    function ipFallback() {
        var token = locateToken;
        setStatus(i18n("Locating via your IP address…"), false);
        Mawaqit.ipLocate(function (loc) {
            if (token !== page.locateToken) {
                return;
            }
            onCoordinates(loc.lat, loc.lon, loc.city, true);
        }, function (err) {
            if (token !== page.locateToken) {
                return;
            }
            locating = false;
            setStatus(i18n("Location detection failed (%1). Type your city above, or paste your mosque's mawaqit.net address below.", err), true);
        });
    }

    function detectedStatus(city, approximate) {
        return approximate
            ? i18n("Approximate location from your internet provider: %1. If this isn't your city, type yours above.", city)
            : i18n("Detected: %1", city);
    }

    // Start a new result list for query. Returns the token the callbacks
    // must check before touching the list.
    function beginResults(query) {
        searchToken++;
        searchQuery = query;
        searchPageLoaded = 0;
        searchHasMore = false;
        loadingMore = false;
        searchResults = [];
        return searchToken;
    }

    function countStatus(n) {
        if (resultsKind === "nearby") {
            return resultsApproximate
                ? i18np("%1 mosque found near your approximate location (from your internet provider). If it isn't near you, search your city above.",
                        "%1 mosques found near your approximate location (from your internet provider). If none is near you, search your city above.", n)
                : i18np("%1 mosque found near you — pick yours",
                        "%1 mosques found near you — pick yours", n);
        }
        return resultsApproximate
            ? i18np("%2 is an approximate location from your internet provider. %1 mosque found there — if this isn't your city, type yours above.",
                    "%2 is an approximate location from your internet provider. %1 mosques found there — if this isn't your city, type yours above.",
                    n, resultsApproxCity)
            : i18np("%1 mosque found — pick yours", "%1 mosques found — pick yours", n);
    }

    function setFirstPage(results) {
        searchResults = results;
        searchPageLoaded = 1;
        searchHasMore = results.length >= Mawaqit.SEARCH_PAGE_SIZE;
    }

    function loadMore() {
        if (searchQuery === "" || !searchHasMore || loadingMore) {
            return;
        }
        loadingMore = true;
        var token = searchToken;
        var nextPage = searchPageLoaded + 1;
        Mawaqit.searchPage(searchQuery, nextPage, function (results) {
            if (token !== page.searchToken) {
                return;
            }
            loadingMore = false;
            var seen = {};
            var merged = searchResults.slice();
            for (var i = 0; i < merged.length; i++) {
                seen[merged[i].slug] = true;
            }
            for (var j = 0; j < results.length; j++) {
                if (!seen[results[j].slug]) {
                    seen[results[j].slug] = true;
                    merged.push(results[j]);
                }
            }
            searchResults = merged;
            searchPageLoaded = nextPage;
            searchHasMore = results.length >= Mawaqit.SEARCH_PAGE_SIZE;
            setStatus(countStatus(merged.length), false);
        }, function (err) {
            if (token !== page.searchToken) {
                return;
            }
            loadingMore = false;
            setStatus(i18n("Couldn't load more mosques (%1)", err), true);
        });
    }

    function onCoordinates(lat, lon, cityHint, approximate) {
        var locToken = locateToken;
        setStatus(i18n("Searching for mosques near you…"), false);
        var token = beginResults(Mawaqit.coordsQuery(lat, lon));
        Mawaqit.searchPage(page.searchQuery, 1, function (results) {
            if (token !== page.searchToken) {
                return;
            }
            locating = false;
            setFirstPage(results);
            resultsKind = "nearby";
            resultsApproximate = approximate === true;
            resultsApproxCity = "";
            if (results.length === 0) {
                setStatus(i18n("No mosques found near you. Try searching by name above."), true);
            } else {
                setStatus(countStatus(results.length), false);
            }
        }, function () {
            if (token !== page.searchToken) {
                return;
            }
            if (cityHint !== "") {
                locating = false;
                searchField.text = cityHint;
                // doSearch() replaces the status once results arrive, so the
                // approximate warning is carried into the results message
                page.pendingApproximateCity = approximate ? cityHint : "";
                setStatus(detectedStatus(cityHint, approximate), false);
                doSearch();
            } else {
                Mawaqit.reverseGeocode(lat, lon, function (city) {
                    if (locToken !== page.locateToken) {
                        return;
                    }
                    locating = false;
                    searchField.text = city;
                    page.pendingApproximateCity = approximate ? city : "";
                    setStatus(detectedStatus(city, approximate), false);
                    doSearch();
                }, function (err) {
                    if (locToken !== page.locateToken) {
                        return;
                    }
                    console.log("[mawaqit] reverse geocode failed: " + err);
                    ipFallback();
                });
            }
        });
    }

    Timer {
        id: gpsTimeout
        interval: 8000
        onTriggered: page.gpsFailed()
    }

    /* ------------------------- search flow -------------------------- */

    function doSearch() {
        var word = searchField.text.trim();
        if (word === "") {
            return;
        }
        // A search the user starts wins over a detection still running;
        // when detection itself falls back to a city search it has already
        // finished, so this changes nothing there
        cancelDetection();
        // Only a search started by detection keeps the approximate warning;
        // a search the user typed is taken at face value
        var approximateCity = page.pendingApproximateCity;
        page.pendingApproximateCity = "";
        if (approximateCity !== "" && approximateCity !== word) {
            approximateCity = "";
        }
        searching = true;
        var token = beginResults(Mawaqit.wordQuery(word));
        Mawaqit.searchPage(page.searchQuery, 1, function (results) {
            if (token !== page.searchToken) {
                return;
            }
            searching = false;
            setFirstPage(results);
            resultsKind = "word";
            resultsApproximate = approximateCity !== "";
            resultsApproxCity = approximateCity;
            setStatus(results.length > 0
                ? countStatus(results.length)
                : i18n("No mosques found for “%1”. You can paste your mosque's mawaqit.net address below instead.", word),
                results.length === 0);
        }, function (err) {
            if (token !== page.searchToken) {
                return;
            }
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

    // Prayer names in the configured language, for the icon legend below
    readonly property var prayerLabels: Mawaqit.prayerNames(page.cfg_labelLanguage)

    /* ============================= UI ================================ */

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        Kirigami.FormLayout {
            Layout.fillWidth: true
            // Section rules span the whole form, so leave a gutter wide
            // enough that they stop short of the scrollbar instead of
            // running underneath it
            Layout.rightMargin: Kirigami.Units.gridUnit

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
                    // Enter runs the search and is swallowed here, so it does
                    // not fall through to the dialog's default (OK) button
                    Keys.onReturnPressed: (event) => { page.doSearch(); event.accepted = true; }
                    Keys.onEnterPressed: (event) => { page.doSearch(); event.accepted = true; }
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

            QQC2.Label {
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 22
                text: i18n("Detection usually relies on your internet provider's location, which can be in another city (often the capital) on any connection, including mobile data. Searching your city by name is more reliable.")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.7
                wrapMode: Text.WordWrap
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

        // Mawaqit returns results a page at a time, so a city with many
        // mosques needs this to reach the ones past the first page
        RowLayout {
            visible: page.searchHasMore && page.searchResults.length > 0
            QQC2.Button {
                icon.name: "go-down"
                text: i18n("Show more mosques")
                enabled: !page.loadingMore
                onClicked: page.loadMore()
            }
            QQC2.BusyIndicator {
                visible: page.loadingMore
                running: visible
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: Kirigami.Units.iconSizes.small
            }
        }

        Kirigami.FormLayout {
            Layout.fillWidth: true
            // Section rules span the whole form, so leave a gutter wide
            // enough that they stop short of the scrollbar instead of
            // running underneath it
            Layout.rightMargin: Kirigami.Units.gridUnit

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
                // Enter applies + verifies the slug in place; swallow it so it
                // does not fall through to the dialog's OK button and close it
                Keys.onReturnPressed: (event) => { page.applySlugInput(); event.accepted = true; }
                Keys.onEnterPressed: (event) => { page.applySlugInput(); event.accepted = true; }
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

            // Only meaningful in a horizontal panel: it switches the inline
            // panel strip between all prayers and the next one. The desktop
            // widget always shows the full table and a vertical panel shows
            // the next prayer's glyph, so the option is hidden in both.
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
            // of the page keeps the system direction.
            RowLayout {
                visible: Plasmoid.formFactor === PlasmaCore.Types.Horizontal
                         || Plasmoid.formFactor === PlasmaCore.Types.Vertical
                LayoutMirroring.enabled: Mawaqit.isArabic(page.cfg_labelLanguage)
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
