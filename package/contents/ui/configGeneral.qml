import QtCore
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

    /* ------------------------- mosque page -------------------------- */

    function applySlugInput() {
        var normalized = Mawaqit.normalizeMosque(slugField.text);
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

    Component.onDestruction: cancelUpdateCheck()
    Component.onCompleted: {
        slugField.text = cfg_mosqueSlug;
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
            Layout.fillWidth: true
            // Section rules span the whole form, so leave a gutter wide
            // enough that they stop short of the scrollbar instead of
            // running underneath it
            Layout.rightMargin: Kirigami.Units.gridUnit

            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Mosque")
            }

            QQC2.TextField {
                id: slugField
                Kirigami.FormData.label: i18n("Mosque link:")
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 18
                placeholderText: i18n("Paste your mosque's mawaqit.net link…")
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
