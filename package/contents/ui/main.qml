import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import "../code/mawaqit.js" as Mawaqit

PlasmoidItem {
    id: root

    /* ------------------------------ state ------------------------------ */

    readonly property string mosqueSlug: Plasmoid.configuration.mosqueSlug
    // Fetched name survives the config dialog writing back a stale empty
    // mosqueName snapshot over the value stored during an in-flight fetch
    property string fetchedName: ""
    readonly property string mosqueName: Mawaqit.cleanMosqueName(
                                             fetchedName !== "" ? fetchedName
                                             : Plasmoid.configuration.mosqueName !== ""
                                             ? Plasmoid.configuration.mosqueName
                                             : Plasmoid.configuration.mosqueSlug)
    readonly property bool configured: mosqueSlug !== ""
    readonly property bool use24h: Plasmoid.configuration.use24h
    readonly property string displayMode: Plasmoid.configuration.displayMode

    property var calendar: null
    property var todayTimes: null      // [fajr, shuruq, dhuhr, asr, maghrib, isha]
    property var next: null            // {index, time, date, tomorrow, estimated?}
    property string countdown: ""
    property string countdownHM: ""
    property string hijriDateText: ""
    property bool fetching: false
    property string errorMessage: ""
    property int lastComputedDay: -1

    readonly property var names: Mawaqit.prayerNames(Plasmoid.configuration.labelLanguage)
    readonly property bool rtl: Mawaqit.isArabic(Plasmoid.configuration.labelLanguage)
    readonly property string nextName: next ? names[next.index] : ""
    readonly property string nextTimeFormatted: next ? Mawaqit.formatTime(next.time, use24h) : ""

    Plasmoid.icon: Qt.resolvedUrl("../icons/mosque.svg").toString()

    /* --------------------------- cache / fetch -------------------------- */

    function loadFromCache() {
        calendar = null;
        var cached = Plasmoid.configuration.cachedCalendar;
        if (cached !== "" && Plasmoid.configuration.cachedYear === new Date().getFullYear()) {
            try {
                calendar = JSON.parse(cached);
            } catch (e) {
                calendar = null;
            }
        }
        recomputeDay(true);
    }

    function cacheIsStale() {
        if (calendar === null) {
            return true;
        }
        var last = Plasmoid.configuration.lastFetch;
        if (last === "") {
            return true;
        }
        var ageDays = (Date.now() - Date.parse(last)) / 86400000;
        return ageDays >= Plasmoid.configuration.refreshDays;
    }

    function refetch(force) {
        if (!configured || fetching) {
            return;
        }
        if (!force && !cacheIsStale()) {
            return;
        }
        fetching = true;
        var slug = mosqueSlug;
        Mawaqit.fetchConf(slug, function (conf) {
            fetching = false;
            if (slug !== root.mosqueSlug) {
                return; // config changed mid-flight
            }
            if (!conf.calendar) {
                errorMessage = i18n("This mosque does not publish a calendar on Mawaqit");
                return;
            }
            errorMessage = "";
            calendar = conf.calendar;
            Plasmoid.configuration.cachedCalendar = JSON.stringify(conf.calendar);
            Plasmoid.configuration.cachedYear = new Date().getFullYear();
            Plasmoid.configuration.lastFetch = new Date().toISOString();
            Plasmoid.configuration.cachedHijriAdjustment = conf.hijriAdjustment;
            Plasmoid.configuration.cachedHijriForce30 = conf.hijriForce30;
            if (conf.name && conf.name !== slug) {
                fetchedName = conf.name;
                Plasmoid.configuration.mosqueName = conf.name;
            }
            recomputeDay(true);
        }, function (err) {
            fetching = false;
            errorMessage = err; // keep serving the cache on transient errors
        });
    }

    /* ---------------------- per-day / per-second ------------------------ */

    function recomputeDay(force) {
        var now = new Date();
        if (force || now.getDate() !== lastComputedDay) {
            lastComputedDay = now.getDate();
            todayTimes = Mawaqit.timesForDate(calendar, now);
            hijriDateText = Mawaqit.formatHijri(
                now,
                Plasmoid.configuration.cachedHijriAdjustment,
                Plasmoid.configuration.cachedHijriForce30,
                Plasmoid.configuration.labelLanguage);
            if (calendar !== null
                    && Plasmoid.configuration.cachedYear !== now.getFullYear()) {
                refetch(true); // year rollover
            }
        }
        tick();
    }

    function tick() {
        var now = new Date();
        if (now.getDate() !== lastComputedDay) {
            recomputeDay(false);
            return;
        }
        if (calendar === null) {
            next = null;
            countdown = "";
            return;
        }
        if (next === null || now >= next.date) {
            next = Mawaqit.nextPrayer(calendar, now);
        }
        countdown = next
            ? Mawaqit.formatCountdown(next.date - now, Plasmoid.configuration.labelLanguage)
            : "";
        countdownHM = next ? Mawaqit.formatCountdownHM(next.date - now) : "";
    }

    Timer {
        interval: 1000
        running: root.configured && root.calendar !== null
        repeat: true
        onTriggered: root.tick()
    }

    Timer {
        interval: 3600 * 1000  // staleness check + retry-on-error, hourly
        running: root.configured
        repeat: true
        onTriggered: root.refetch(false)
    }

    Connections {
        target: Plasmoid.configuration
        function onLabelLanguageChanged() {
            root.recomputeDay(true);
        }
        function onMosqueSlugChanged() {
            root.errorMessage = "";
            root.next = null;
            Plasmoid.configuration.cachedCalendar = "";
            Plasmoid.configuration.cachedYear = 0;
            Plasmoid.configuration.lastFetch = "";
            root.calendar = null;
            root.loadFromCache();
            root.refetch(true);
        }
    }

    Component.onCompleted: {
        loadFromCache();
        // Force a fetch when the stored name is missing (e.g. clobbered by
        // the config dialog), so the real name appears without manual refresh
        refetch(configured && Plasmoid.configuration.mosqueName === "");
    }

    /* --------------------------- representations ------------------------ */

    preferredRepresentation: Plasmoid.formFactor === PlasmaCore.Types.Horizontal
                             || Plasmoid.formFactor === PlasmaCore.Types.Vertical
                             ? compactRepresentation
                             : fullRepresentation

    compactRepresentation: CompactRepresentation {}
    fullRepresentation: FullRepresentation {}

    toolTipMainText: configured ? mosqueName : i18n("Mawaqit Prayer Times")
    toolTipSubText: {
        if (!configured) {
            return i18n("Right-click → Configure to choose a mosque");
        }
        if (next) {
            return hijriDateText + "\n"
                 + nextName + " " + nextTimeFormatted + " — "
                 + Mawaqit.inCountdown(countdown, Plasmoid.configuration.labelLanguage);
        }
        return errorMessage !== "" ? errorMessage : i18n("Loading prayer times…");
    }

    Plasmoid.busy: fetching

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Refresh prayer times")
            icon.name: "view-refresh"
            enabled: root.configured && !root.fetching
            onTriggered: root.refetch(true)
        }
    ]
}
