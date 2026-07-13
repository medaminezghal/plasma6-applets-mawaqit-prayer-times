<p align="center">
  <img src="assets/mawaqit-logo-512.png" width="140" alt="Mawaqit Prayer Times logo">
</p>

<h1 align="center">Mawaqit Prayer Times — KDE Plasma 6 Widget</h1>

A Plasma 6 plasmoid that shows prayer times for **your** mosque, using the
exact timetable your mosque publishes on [mawaqit.net](https://mawaqit.net)
— not astronomical approximations.

## Features

- **Panel-friendly compact view**: next prayer + live countdown in your panel
  (horizontal and vertical panels supported); click to expand
- **Two display modes**: full daily timetable, or only the next prayer
- **Mosque finder in settings**: detect your location automatically
  (GeoClue/Qt Positioning, with IP-based fallback), search Mawaqit for
  mosques in your city, and pick yours from the list
- **Offline-first**: the entire year's calendar is cached locally after a
  single download — the widget keeps working with no network, and
  re-downloads only every few days to pick up schedule corrections
- **Localized prayer names**: English, العربية, Français, or follow the
  system language
- 12/24-hour format, optional sunrise (shuruq) row

## How it works

Each mosque page on mawaqit.net embeds a `confData` JSON object containing
the full annual prayer calendar. The widget downloads your mosque's page
once, extracts that object with a string-aware brace-balanced parser, and
caches the calendar in the widget configuration. Everything else — today's
times, the next prayer, the countdown — is computed locally.

No account, no API key, no third-party server. Each installation talks
directly to mawaqit.net roughly once a week.

> **Note:** Mawaqit's proximity-search API requires an account, so the
> "nearby mosques" feature uses Mawaqit's public keyword search seeded with
> your detected city instead. You can always paste your mosque's URL slug
> manually.

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

For GPS-accurate location detection install Qt Positioning
(`qt6-positioning` on Arch) and a running GeoClue service. Without it, the
widget falls back to IP-based city detection, which is good enough for
finding your city's mosques.

## Privacy

- Location detection runs **only** when you click "Detect my location" in
  the settings, and the result is used once to pre-fill the search box.
  Nothing is stored or transmitted beyond that single lookup
  (ipapi.co for IP lookup, nominatim.openstreetmap.org for reverse
  geocoding).
- At runtime the widget contacts only `mawaqit.net`.

## License

GPL-3.0-or-later
