<p align="center">
  <img src="assets/mawaqit-logo-512.png" width="140" alt="Mawaqit Prayer Times logo">
</p>

<h1 align="center">Mawaqit Prayer Times — KDE Plasma 6 Widget</h1>

A Plasma 6 plasmoid that shows prayer times for **your** mosque, using the
exact timetable your mosque publishes on [mawaqit.net](https://mawaqit.net)
— not astronomical approximations.

## Features

- **Panel-friendly compact view**: next prayer + live countdown in a horizontal
  panel; in a vertical panel, the next prayer's own icon with the minutes left
  underneath. Click either to expand the full table
- **Two display modes**: full daily timetable, or only the next prayer
- **Icons instead of names**: the horizontal strip can swap each prayer name
  for its own glyph — first light, sunrise, zenith, shadow, sunset, night —
  which frees up a lot of panel width. The settings show the six icons with
  their names so nothing has to be guessed
- **Hijri date**: shown in the popup, and optionally in the panel as either
  the spelled-out form (2 ربيع الثاني 1448 هـ) or plain digits (02/04/1448)
- **Appearance customization**: pick a custom font, scale the desktop widget
  or panel popup (panel text follows the panel's thickness), override the
  text and next-prayer accent colors, and give the widget a custom background
  with adjustable color, opacity, and corner radius — every option is opt-in
  and falls back to your Plasma theme. "Show the next prayer in bold" needs a
  font that has a bold style; with fonts that don't, it has no effect
- **Mosque finder in settings**: search Mawaqit for mosques in your city
  and pick yours from the list, or let the widget guess your city (see
  [About location detection](#about-location-detection))
- **Offline-first**: the entire year's calendar is cached locally after a
  single download — the widget keeps working with no network, and
  re-downloads only every few days to pick up schedule corrections
- **Localized prayer names**: English, العربية, Français, or follow the
  system language
- 12/24-hour format, optional sunrise (Shuruq) row

## How it works

Each mosque page on mawaqit.net embeds a `confData` JSON object containing
the full annual prayer calendar. The widget downloads your mosque's page
once, extracts that object with a string-aware brace-balanced parser, and
caches the calendar in the widget configuration. Everything else — today's
times, the next prayer, the countdown — is computed locally.

The Hijri date is computed with the same arithmetic calendar Mawaqit itself
uses, and the `hijriAdjustment` your mosque publishes is applied on top of
it. That matters because your mosque's admin calibrates that adjustment
against what Mawaqit displays — so the widget shows the date on your
mosque's own screens rather than a calendar that quietly disagrees with it.

No account, no API key, no third-party server. Each installation talks
directly to mawaqit.net roughly once a week, and once a day around the end
of each Hijri month, so a new adjustment after the moon sighting shows up
the next day.

### If the Hijri date is off by a day

The widget cannot know when a new month begins in your community — it
shows exactly what your mosque publishes. If the date is wrong, it is wrong
on Mawaqit too, and only **your mosque's administrators** can fix it: ask
them to update the Hijri date adjustment in their Mawaqit settings. The
widget picks up the change on its next refresh, or right away with
right-click → **Refresh prayer times**.

> **Note:** "Detect my location" asks Mawaqit's public search for the
> mosques closest to the detected coordinates, and falls back to searching
> the detected city by name. Mawaqit returns results ten at a time, so use
> **Show more mosques** if yours isn't in the first list. You can always
> paste your mosque's mawaqit.net address instead.

### About location detection

On KDE Plasma, **"Detect my location" almost always works from your IP
address**. That gives the location of your internet provider, not your own:
it is usually right about the country, but it often points to a major city
(such as the capital) instead of yours. This is the same on DSL, fibre,
mobile data and phone hotspots — a hotspot is just another internet
provider. The settings tell you when the detected city is only approximate.

**The reliable way to find your mosque is to type your city name in the
search box, or paste your mosque's mawaqit.net address.**

Precise detection needs both of these:

1. **GeoClue must accept the widget.** With GeoClue's default configuration,
   apps need a location agent to approve them, and Plasma doesn't provide
   one of the agents GeoClue accepts, so the request is refused and the
   widget falls back to the IP lookup. (You can see this with
   `journalctl -u geoclue -f` while clicking "Detect my location".)
2. **Your computer needs a real location source**: a WiFi adapter within
   range of access points known to [BeaconDB](https://beacondb.net)
   (GeoClue's default server), a GPS, or a mobile-broadband modem. A wired
   desktop only gets GeoClue's own IP-based estimate, which is no better
   than the widget's.

## Installation

### KDE Store (Get New Widgets)

Install straight from Plasma — no terminal needed: right-click your panel or
desktop → **Add Widgets…** → **Get New Widgets…** → **Download New Plasma
Widgets**, then search for *Mawaqit Prayer Times* and install.

Or open the store page directly:
[store.kde.org](https://store.kde.org/p/2365203) ·
[opendesktop.org](https://www.opendesktop.org/p/2365203)

### Arch Linux

Install [`plasma6-applets-mawaqit-prayer-times`](https://aur.archlinux.org/packages/plasma6-applets-mawaqit-prayer-times)
from the AUR with your preferred helper:

```sh
yay -S plasma6-applets-mawaqit-prayer-times
```

```sh
paru -S plasma6-applets-mawaqit-prayer-times
```

### From source

```sh
kpackagetool6 --type Plasma/Applet --install package
# upgrade later with:
kpackagetool6 --type Plasma/Applet --upgrade package
```

### Optional dependency

Qt Positioning (`qt6-positioning` on Arch) with a running GeoClue service
lets the widget use a precise location when one is available (see
[About location detection](#about-location-detection) for when that is).
Without it, the widget uses IP-based detection, which only gives an
approximate city.

## Privacy

- Location detection runs **only** when you click "Detect my location" in
  the settings, and the result is used once to pre-fill the search box.
  Nothing is stored or transmitted beyond that single lookup. The services
  involved are:
  - IP lookup: `ipwho.is`, then `ipapi.co`, then `ip-api.com` (each is tried
    only if the previous one fails; `ip-api.com` is queried over plain HTTP,
    as its free tier has no HTTPS)
  - GeoClue, if installed, may query [BeaconDB](https://beacondb.net) with
    nearby WiFi networks
  - Reverse geocoding: `nominatim.openstreetmap.org`
- At runtime the widget contacts only `mawaqit.net`.

## License

GPL-3.0-or-later
