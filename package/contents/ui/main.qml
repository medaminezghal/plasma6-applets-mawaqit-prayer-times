import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
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

    /* ----------------------- appearance (config) ----------------------- */
    // Resolved once here so the representations stay declarative and don't
    // each re-implement the "custom value or fall back to the theme" logic.
    readonly property string appFontFamily: Plasmoid.configuration.fontFamily !== ""
                                            ? Plasmoid.configuration.fontFamily
                                            : Kirigami.Theme.defaultFont.family
    readonly property real appFontScale: Plasmoid.configuration.fontScale
    readonly property bool appBoldNext: Plasmoid.configuration.boldNextPrayer

    // Some families ship no bold face and the system does not always
    // synthesise one, so "bold" silently renders as regular. Detect that by
    // measuring: if the bold run is exactly as wide as the regular one the
    // request was ignored, and the labels fall back to Text.Raised in their
    // own colour: a second copy one pixel offset, the classic double-strike
    // fake bold, which reads as bold without the blur of an outline.
    TextMetrics {
        id: boldProbeRegular
        font.family: root.appFontFamily
        font.pixelSize: 100
        font.weight: Font.Normal
        text: "0123456789 ABCDEF"
    }
    TextMetrics {
        id: boldProbeBold
        font.family: root.appFontFamily
        font.pixelSize: 100
        font.weight: Font.Bold
        text: boldProbeRegular.text
    }
    readonly property bool fontLacksBold:
        Math.abs(boldProbeBold.advanceWidth - boldProbeRegular.advanceWidth) < 0.5
    readonly property bool appFakeBold: appBoldNext && fontLacksBold
    readonly property color appTextColor: Plasmoid.configuration.customTextColor
                                          ? Plasmoid.configuration.textColor
                                          : Kirigami.Theme.textColor
    readonly property color appAccentColor: Plasmoid.configuration.customAccentColor
                                            ? Plasmoid.configuration.accentColor
                                            : Kirigami.Theme.highlightColor
    readonly property bool appCustomBackground: Plasmoid.configuration.customBackground
    readonly property color appBackgroundColor: Qt.rgba(
                                            Plasmoid.configuration.backgroundColor.r,
                                            Plasmoid.configuration.backgroundColor.g,
                                            Plasmoid.configuration.backgroundColor.b,
                                            Plasmoid.configuration.backgroundOpacity / 100)
    readonly property int appBackgroundRadius: Plasmoid.configuration.backgroundRadius

    property var calendar: null
    property var todayTimes: null      // [fajr, shuruq, dhuhr, asr, maghrib, isha]
    property var next: null            // {index, time, date, tomorrow, estimated?}
    property string countdown: ""
    property string countdownHM: ""
    property string countdownMin: ""
    property string hijriDateText: ""
    property string hijriDateNumeric: ""
    property bool fetching: false
    property string errorMessage: ""
    property bool calendarFromPreviousYear: false
    // Outstanding request plus a token identifying it. QML's XMLHttpRequest
    // has no timeout (QTBUG-38096), so a connection that is accepted and then
    // stalls - captive portal, half-open socket after a resume - would leave
    // "fetching" true for good, disabling Refresh and short-circuiting every
    // later refetch() at its guard. The watchdog below aborts it; the token
    // makes the late callback a no-op.
    property var pendingRequest: null
    property int fetchToken: 0
    // Year/month/day packed into one int. Comparing getDate() alone missed a
    // rollover onto the same day number - suspend on 14 Sept, resume on
    // 14 Oct and the widget kept September's row and hijri date until the
    // next midnight.
    property int lastComputedDay: -1
    function dayKey(d) {
        return d.getFullYear() * 10000 + d.getMonth() * 100 + d.getDate();
    }

    readonly property var names: Mawaqit.prayerNames(Plasmoid.configuration.labelLanguage)
    readonly property bool rtl: Mawaqit.isArabic(Plasmoid.configuration.labelLanguage)
    readonly property string nextName: next ? names[next.index] : ""
    readonly property string nextTimeFormatted: next ? Mawaqit.formatTime(next.time, use24h) : ""

    Plasmoid.icon: Qt.resolvedUrl("../icons/mosque.svg").toString()

    // When the user opts into a custom background, drop the theme frame so our
    // own rounded rectangle is the only thing drawn behind the content.
    Plasmoid.backgroundHints: appCustomBackground
                              ? PlasmaCore.Types.NoBackground
                              : (PlasmaCore.Types.DefaultBackground
                                 | PlasmaCore.Types.ConfigurableBackground)

    /* --------------------------- cache / fetch -------------------------- */

    function loadFromCache() {
        calendar = null;
        calendarFromPreviousYear = false;
        var cached = Plasmoid.configuration.cachedCalendar;
        if (cached !== "") {
            try {
                calendar = JSON.parse(cached);
                // A calendar from an earlier year is still far better than
                // nothing: prayer times move by a couple of minutes year to
                // year, so on 1 January with no network the widget shows
                // near-correct times instead of an error over a full year of
                // usable data. recomputeDay() already refetches on a year
                // mismatch, so this is only what gets shown until that
                // succeeds. Same instinct as nextPrayer()'s Dec-31 estimate.
                calendarFromPreviousYear =
                    Plasmoid.configuration.cachedYear !== new Date().getFullYear();
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
        var token = ++fetchToken;
        fetchWatchdog.restart();
        pendingRequest = Mawaqit.fetchConf(slug, function (conf) {
            if (token !== root.fetchToken) {
                return; // superseded or timed out
            }
            fetchWatchdog.stop();
            pendingRequest = null;
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
            calendarFromPreviousYear = false;
            Plasmoid.configuration.lastFetch = new Date().toISOString();
            Plasmoid.configuration.cachedHijriAdjustment = conf.hijriAdjustment;
            Plasmoid.configuration.cachedHijriForce30 = conf.hijriForce30;
            if (conf.name && conf.name !== slug) {
                fetchedName = conf.name;
                Plasmoid.configuration.mosqueName = conf.name;
            }
            recomputeDay(true);
        }, function (err) {
            if (token !== root.fetchToken) {
                return; // superseded or timed out
            }
            fetchWatchdog.stop();
            pendingRequest = null;
            fetching = false;
            errorMessage = err; // keep serving the cache on transient errors
        });
    }

    Timer {
        id: fetchWatchdog
        interval: 30000
        onTriggered: {
            root.fetchToken++; // any late callback is now ignored
            if (root.pendingRequest !== null) {
                root.pendingRequest.abort();
                root.pendingRequest = null;
            }
            root.fetching = false;
            root.errorMessage = i18n("mawaqit.net did not respond in time");
        }
    }

    /* ---------------------- per-day / per-second ------------------------ */

    function recomputeDay(force) {
        var now = new Date();
        if (force || dayKey(now) !== lastComputedDay) {
            lastComputedDay = dayKey(now);
            // The cached "next" belongs to the day that just ended. After
            // Isha it carries tomorrow: true, and at midnight that tomorrow
            // has become today - but tick() only recomputes when
            // now >= next.date, which is still hours away, so the stale
            // object would survive until Fajr and keep saying "tomorrow".
            next = null;
            todayTimes = Mawaqit.timesForDate(calendar, now);
            hijriDateText = Mawaqit.formatHijri(
                now,
                Plasmoid.configuration.cachedHijriAdjustment,
                Plasmoid.configuration.cachedHijriForce30,
                Plasmoid.configuration.labelLanguage);
            hijriDateNumeric = Mawaqit.formatHijriNumeric(
                now,
                Plasmoid.configuration.cachedHijriAdjustment,
                Plasmoid.configuration.cachedHijriForce30);
            if (calendar !== null
                    && Plasmoid.configuration.cachedYear !== now.getFullYear()) {
                refetch(true); // year rollover
            }
        }
        tick();
    }

    function tick() {
        var now = new Date();
        if (dayKey(now) !== lastComputedDay) {
            recomputeDay(false);
            return;
        }
        if (calendar === null) {
            next = null;
            countdown = "";
            countdownMin = "";
            return;
        }
        if (next === null || now >= next.date) {
            next = Mawaqit.nextPrayer(calendar, now);
        }
        countdown = next
            ? Mawaqit.formatCountdown(next.date - now, Plasmoid.configuration.labelLanguage)
            : "";
        countdownHM = next ? Mawaqit.formatCountdownHM(next.date - now) : "";
        countdownMin = next ? Mawaqit.formatCountdownMin(next.date - now) : "";
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
            // mosqueName prefers fetchedName over everything else, so leaving
            // it set made a failed switch keep showing the previous mosque's
            // name in the header and tooltip next to "Couldn't load prayer
            // times" - as if the right mosque were selected.
            root.fetchedName = "";
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
            var sub = hijriDateText + "\n"
                 + nextName + " " + nextTimeFormatted + " — "
                 + Mawaqit.inCountdown(countdown, Plasmoid.configuration.labelLanguage);
            if (calendarFromPreviousYear) {
                sub += "\n" + i18n("Estimated from last year's calendar");
            }
            return sub;
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
