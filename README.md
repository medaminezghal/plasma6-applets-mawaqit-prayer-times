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
- **All prayers in a vertical panel, too**: optionally, a vertical panel
  stacks every prayer as its icon over its time — the hour, two dots and the
  minutes on lines of their own, so they fit even a thin panel, with the
  AM/PM marker underneath in 12-hour format. The next prayer stands out in
  the accent color (and bold), with the minutes left beneath it
- **Two display modes**: full daily timetable, or only the next prayer
- **Icons instead of names**: the horizontal strip can swap each prayer name
  for its own glyph — first light, sunrise, zenith, shadow, sunset, night —
  which frees up a lot of panel width. The settings show the six icons with
  their names so nothing has to be guessed
- **Six layouts for the desktop widget and the popup**: Classic, Sundial,
  Cards, Horizon (over al-Masjid al-Aqsa or al-Masjid an-Nabawi), Kaaba
  and Qalam — see the [Gallery](#gallery). Switching layout never resizes
  the widget. The panel itself keeps its compact view
- **Hijri date**: shown in the popup, and optionally in the panel as either
  the spelled-out form (2 ربيع الثاني 1448 هـ) or plain digits (02/04/1448)
- **Appearance customization**: pick a custom font, scale the desktop widget
  or panel popup (panel text follows the panel's thickness), override the
  text and next-prayer accent colors, and give the widget a custom background
  with adjustable color, opacity, and corner radius — every option is opt-in
  and falls back to your Plasma theme. Colors and background apply to the
  Classic and Cards layouts; the Sundial, Horizon, Kaaba and Qalam paint
  their own. "Show the next prayer in bold" needs a
  font that has a bold style; with fonts that don't, it has no effect
- **Set up from your mosque's link**: paste the link the Mawaqit app shares
  for your mosque, or its mawaqit.net address, in the settings (see
  [Choosing your mosque](#choosing-your-mosque))
- **Offline-first**: the entire year's calendar is cached locally after a
  single download — the widget keeps working with no network, and
  re-downloads only every few days to pick up schedule corrections
- **Localized prayer names**: English, العربية, Français, or follow the
  system language
- 12/24-hour format (with ص/م in Arabic), optional sunrise (Shuruq) row

## Gallery

All shown in Arabic with a dark Plasma theme, at 18:20 with Isha next.

### Desktop widget and popup layouts

Scroll sideways to see them all.

<table>
  <tr>
    <td align="center"><table><tr><td><img src="assets/screenshots/layout-classic.png" width="200" height="189" alt="Classic layout"></td></tr></table>Classic</td>
    <td align="center"><table><tr><td><img src="assets/screenshots/layout-sundial.png" width="186" height="189" alt="Sundial layout"></td></tr></table>Sundial</td>
    <td align="center"><table><tr><td><img src="assets/screenshots/layout-cards.png" width="200" height="189" alt="Cards layout"></td></tr></table>Cards</td>
    <td align="center"><table><tr><td><img src="assets/screenshots/layout-horizon-aqsa.png" width="186" height="189" alt="Horizon layout over al-Masjid al-Aqsa"></td></tr></table>Horizon, al-Aqsa Mosque</td>
    <td align="center"><table><tr><td><img src="assets/screenshots/layout-horizon-nabawi.png" width="186" height="189" alt="Horizon layout over the Prophet's Mosque"></td></tr></table>Horizon, Prophet's Mosque</td>
    <td align="center"><table><tr><td><img src="assets/screenshots/layout-kaaba.png" width="186" height="189" alt="Kaaba layout"></td></tr></table>Kaaba</td>
    <td align="center"><table><tr><td><img src="assets/screenshots/layout-qalam.png" width="186" height="189" alt="Qalam layout"></td></tr></table>Qalam</td>
  </tr>
</table>

### Panel

Scroll sideways to see them all.

<table>
  <tr>
    <td align="center"><table><tr><td><img src="assets/screenshots/panel-all-names.png" width="654" height="54" alt="Horizontal panel showing all prayer times with their names"></td></tr></table>All prayers, with names</td>
    <td align="center"><table><tr><td><img src="assets/screenshots/panel-all-icons.png" width="528" height="54" alt="Horizontal panel showing all prayer times with icons"></td></tr></table>All prayers, with icons</td>
    <td align="center"><table><tr><td><img src="assets/screenshots/panel-all-icons-numeric-hijri.png" width="464" height="54" alt="Horizontal panel showing all prayer times with icons and a numeric hijri date"></td></tr></table>All prayers, with icons and the hijri date as digits</td>
    <td align="center"><table><tr><td><img src="assets/screenshots/panel-next-name.png" width="486" height="54" alt="Horizontal panel showing the next prayer with its name"></td></tr></table>Next prayer, with its name</td>
    <td align="center"><table><tr><td><img src="assets/screenshots/panel-next-icon.png" width="440" height="54" alt="Horizontal panel showing the next prayer with its icon"></td></tr></table>Next prayer, with its icon</td>
    <td align="center"><table><tr><td><img src="assets/screenshots/panel-vertical.png" width="60" height="164" alt="Vertical panel showing the next prayer's icon and the minutes left"></td></tr></table>Vertical panel, next prayer</td>
    <td align="center"><table><tr><td><img src="assets/screenshots/panel-vertical-all.png" width="60" height="359" alt="Vertical panel showing every prayer's icon over its time, with the next prayer in the accent color and the minutes left beneath it"></td></tr></table>Vertical panel, all prayers</td>
  </tr>
</table>

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

## Choosing your mosque

1. In the Mawaqit app, search for your mosque, open it and tap **Share**.
2. The shared message contains a link like `https://mawaqit.net/ar/id/12345`.
   Copy **only that link**, not the whole message.
3. Open the widget's settings and paste it in **Mosque link**.

The address of the mosque's page on mawaqit.net (for example
`https://mawaqit.net/fr/your-mosque`) works too, and so does its last part,
the mosque's slug. The widget checks the link right away and shows the
mosque's name, so you know you picked the right one.

The settings used to search Mawaqit for mosques and detect your location.
Since 6 October 2026 Mawaqit's search API requires an account token, and
Mawaqit doesn't allow its API to be used outside its own applications, so
the widget no longer searches; it only reads your mosque's public page.

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

You need `git` and `qsb` from Qt Shader Tools (`qt6-shadertools` on Arch,
`qt6-shader-baker` on Debian/Ubuntu). `build-shaders.sh` compiles the widget's
shaders; without them the widget still works, but the Horizon layout's header
keeps a plain color instead of being lit by the sun and the moon.

```sh
git clone https://github.com/medaminezghal/plasma6-applets-mawaqit-prayer-times.git
cd plasma6-applets-mawaqit-prayer-times
./build-shaders.sh
kpackagetool6 --type Plasma/Applet --install package
```

To upgrade later, from the same folder:

```sh
git pull
./build-shaders.sh
kpackagetool6 --type Plasma/Applet --upgrade package
```

## Privacy

- At runtime the widget contacts only `mawaqit.net`.
- The **General** settings page asks the KDE Store (`api.kde-look.org`) for
  the latest version, only while that page is open.

## License

GPL-3.0-or-later
