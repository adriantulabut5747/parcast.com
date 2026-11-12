# AgosAlert

Flutter flood-monitoring app for Mabalacat City, Pampanga. A school group
project: Adrian writes all the code, his groupmates only do the paperwork.

**Two builds of the same system (Nov 2026).** The project counts for two
subjects, so the whole app gets built twice: this Flutter app first, then
a Laravel copy of everything, done only after the Flutter one is finished.
Both will share one **Supabase** database (not connected yet; demo data
until then). Work on Flutter only for now, but keep data shapes simple and
named the way a database table would be, so the Laravel build and Supabase
can mirror them.

## Layout

- `lib/main.dart` only starts the app. `lib/theme.dart` has the colors,
  fonts and `RiskLevel`. Fonts: Inter for text, Inter Tight for titles and
  big numbers (`kDisplayFont`); both Latin-only static cuts in
  `assets/fonts/`, made with fontTools (`instancer` for the variable Inter
  Tight, then `pyftsubset`). Add new title text with
  `fontFamily: kDisplayFont`.
- **Tabs (Nov 2026 redesign): Weather · Map · Reports · Help.**
  **Phone bottom nav (Nov 12 2026):** the floating glass pill, with a
  behavior borrowed from Clash Royale: the open tab grows wider, its icon
  gets bigger and pops up out of the pill, with its name and ‹ › marks
  (decoration only); closed tabs show only their icon, slightly faded.
  (A full Clash Royale restyle was tried and dropped the same day: Adrian
  kept the glass / iOS look.) The icons are drawn 2D illustrations, iOS style
  (soft gradients, no outlines, not cartoonish), in `tools/nav_icons.js`,
  rendered by `python tools/nav_icons.py [--preview]` to
  `assets/images/nav_*.png`: edit the JS, never the PNGs. The tablet /
  desktop top nav still uses CupertinoIcons.
  `lib/screens/`: `home_shell.dart` (top bar: logo, bell, avatar menu;
  the bottom nav; `showNewActions` = the + fan: Report flood, I'm safe,
  SOS, opened by `NewActionsButton`, which sits in the Reports tab's
  header), `weather_tab.dart` (Nov 12 2026 redesign after the
  teacher called the card stack generic: greeting, high-alert strip, the
  **sky card scrubbable through the next 24 h** (drag the strip = rain bars
  + temperature line; sky color, rain/stars, numbers and Tugak all switch
  to that hour; water at the bottom rises with the rain adding up, full at
  30 mm = the high-outlook rule), the **flood outlook** (rain forecast AND
  "reported now" side by side, so it never says "low risk" next to a
  flood alert), **"Your city right now"** (`lib/widgets/city_map.dart`:
  the landing's city outline + all 27 barangays drawn by hand, flooded
  ones pulsing; tap one for its report, "Make it mine", "View on map"),
  and the 5-day forecast with range bars. The old 24 h rain card and
  12-hour strip are gone: the scrubber replaced both), `map_tab.dart`, `reports_tab.dart` (the flood pins as posts,
  filters, "Still flooded?"), `assistance_tab.dart` (the **Help** tab, Nov 12 2026
  redesign: ONE focal point, the big hold-to-call-911 SOS, the only red
  on the page; every other icon is the neutral `_Glyph`, accent = kBlue,
  green only on "I'm safe". Then Hotlines (CDRRMO, Police, "All" sheet),
  nearest shelter, and "Be ready": a Before/During/After timeline with
  the go-bag under Before (ticks saved via shared_preferences) and the
  NWS "Turn Around, Don't Drown" depth diagram under During. Desktop =
  two full-width bands (SOS | hotlines + shelter at equal height, then
  Be ready with tips side by side and the go-bag in 3 columns), not two
  long columns, which ended uneven. Don't bring
  back rainbow icon colors or per-section entrance animations), `notifications.dart` (the old Alerts page,
  now the bell's sheet), plus evacuation centers, report incident,
  settings, about/help. **There is no More tab**: profile, My barangay,
  Dark mode, Settings, Help, About, Log out live in the avatar menu
  (`_ProfileMenu`, every screen size). `?tab=` takes weather | map |
  reports | help (old home / assistance still work).
- `lib/widgets/common.dart`: shared building blocks (AppCard,
  GradientButton, FadeSlideIn, AnimatedWaves, showAppSheet...). Reuse
  these instead of restyling from scratch. `lib/widgets/links.dart`:
  tap-to-call (always asks first) and Google Maps directions.
- `lib/services/weather.dart`: live Mabalacat weather from Open-Meteo (free,
  no key) and the rain-based flood outlook.
- `lib/data/demo_data.dart`: all made-up data (flood zones, alerts,
  evacuation centers). Shown with a SAMPLE badge in the UI. A real data
  source is coming later as a file from Adrian. Barangay coordinates are
  real (OpenStreetMap).
- Optional photos: `assets/images/evac_*.jpg` (names in demo_data.dart)
  and `assets/images/flood_<barangay>.jpg` for map pins (lowercase,
  spaces → `_`, e.g. `flood_dau.jpg`). Missing files fall back to a
  placeholder. The current flood photos are from Apalit, Pampanga
  (Wikimedia Commons, CC BY-SA 4.0): keep the credit (`kFloodPhotoCredit`
  in demo_data.dart, and the About screen) while they're used.
- Phone / tablet / desktop layouts: `lib/widgets/responsive.dart`
  (breakpoints 600 and 1024, `pagePadding`, `TwoColumns`). Phones keep
  the bottom nav; tablets and desktops get a top nav (icons only on
  tablets) with the + as a round button next to the bell, and
  `showAppSheet` opens a centered popup instead of a bottom sheet.
  Desktop has its own layouts for Weather (two columns), Map (side panel),
  Reports (3-column grid) and Help (two columns).
- Style "Graphite" (Nov 2026 redesign; Adrian: "no rules, make it feel
  PREMIUM, not a hackers' hideout"): warm graphite, not pure black (dark
  `#111113`, default) and warm off-white light (`#F4F3F0`); iOS blue
  `kBlue` accent; iOS tile colors for icons in lists and cards
  (`kTileBlue/Indigo/Teal/Purple/Gray`, used through `IconBadge(...,
  squircle: true)`, like the Settings app). Green / amber / red stay
  reserved for flood risk and emergencies, never decoration. The Weather
  tab's sky card follows the real sky (`weatherGradient`: blue day, slate
  rain, storm gray, indigo night) with rain streaks / stars. Cards are
  `AppCard` (see-through fill + `GlassEdgePainter` lit edge, no blur,
  since a blur over a plain background shows nothing). Real blur
  (`kGlassBlur`, `GlassCard`) only where sharp content moves behind:
  bottom nav, sheets, popups, map overlays (over the web map: `MapGlass`,
  see Known issues). Main buttons are `PrimaryButton` (white pill on dark,
  black on light; `color: kDanger` urgent, `kSafe` for "I'm safe").
  `GlassEdgePainter` lights each edge point by how much it faces a light
  at the top left (model learned from QuickLiquid's specular.ts). Real
  liquid-glass refraction is impossible here: Flutter web has no
  `ImageFilter.shader` (`isShaderFilterSupported` is false), so don't
  retry it. Taps: every pressable thing goes through `PressableScale`
  (spring squish, QuickLiquid's spring numbers: `kSpringSnappy/Bouncy`,
  `kSnappyCurve/kBouncyCurve`); no Material ripples (`NoSplash`).
- **Tugak** (Kapampangan for frog), the mascot. Nov 12 2026 redraw in
  iOS / Animoji style, because the old comic look (black outlines, cel
  shading, shades on his head) clashed with the glass UI: soft shading,
  NO outlines, one light from the top left (same as GlassEdgePainter),
  warm bronze skin, glossy gold eyes with a toad's horizontal pupils,
  calm half-lidded look, navy rescue jacket; hood up in rain/storm, cool
  moonlight at night. No shades any more. Adrian wants him cool /
  grown-up, NOT cute or kiddy (rejected: round blushing frog, bright
  green, a visor hiding the eyes, the Pepe look, and a flat SF-Symbol
  line frog that read as a kids' app). Drawn in `tools/tugak.js` (SVG),
  rendered by `python tools/tugak.py` to
  `assets/images/tugak_{fine,rain,storm,night}.png` in full color (a
  256-color palette bands the gradients; `--preview` for a sheet): edit
  the JS and rerun, never the PNGs. `lib/widgets/tugak.dart`:
  mood + line from REAL weather / the latest high alert (`tugakMoodFor`,
  `tugakLine`; per forecast hour `tugakMoodAt`, `tugakLineAt`), tap = hop
  + a tip. On the sky card he sits beside the temperature (`beside:`)
  with his bubble under both. Voice: deadpan, what to do first, a dry
  joke only when nothing is wrong; on a high alert no jokes at all, and
  only the steps (the red strip already names the alert).
  He may become the logo later.
- Icons (Nov 2026): `CupertinoIcons` (SF Symbols style) only, never
  Material `Icons.*`. Apple's real SF Symbols can't be used (license is
  Apple platforms only). Flood things Cupertino lacks (flood, waves,
  lifebuoy, boat, landslide) are `AgosIcons`, built by
  `python tools/make_icons.py` (needs fonttools + skia-pathops;
  `--preview out.png` shows them next to Cupertino to check weight).
  Edit the script, never `AgosIcons.ttf` / `agos_icons.dart`. The thin
  `WaterLines` pattern is the signature. Local identity: real local
  photos (`LocalPhoto` in demo_data.dart, credits shown on the photo and
  listed on About) and Kapampangan greetings (Weather tab, landing page;
  same hours: abak 5-11, ugtu 11-13, gatpanapun 13-18, bengi 18-5).
- **No login screen in the app.** Logging in happens on the landing page
  (`landing/`, plain HTML/CSS/JS), whose popup opens the app as
  `app/?as=user|guest&theme=light|dark` (optional `&tab=map` etc.).
  `lib/services/session.dart` reads that; on the published site, /app/
  without `as=` redirects to the landing page. Log in / Log out in the
  app go back to the landing page (`lib/screens/account.dart`).
- Roles: Admin, Registered User, Guest. For now only guest vs logged-in
  exists: `isGuest` (demo_data.dart, set from `?as=`). When a guest taps
  something they can't do, call `showLoginRequired` (account.dart).
  Votes on flood pins live in `myVotes`, "Still flooded?" answers in
  `stillFlooded`, the user's barangay in `myBarangay` (all memory only
  until Supabase; only the user's OWN answers, never made-up totals).
- "I'm safe" (`lib/widgets/check_in.dart`): shows the message, then the
  browser's share menu (`lib/services/share_web.dart`, Web Share API); no
  share menu (desktop, tests) = copy to clipboard. Front-end only.
- No real offices as the app's admin: the admins aren't confirmed yet, so
  the app says "Admin" (`kAdminSource`) and calls itself an unofficial demo.
  Real emergency hotlines (CDRRMO, PNP...) stay as they are.
- No river-level card: the only PhilSensors (DOST-ASTI) stations in
  Mabalacat are offline (water level #762 San Felipe Bridge, last reading
  2019; rain gauges #699 and #2908, last 2022). Don't fake live river
  data; only bring it back with a real, working source.
- Flood pins are removed 14 days after their photo was taken
  (`kPinLifetime`); the map only shows `activeFloodZones`.
- Each pin has an uploader (`kUploaders`, sample names). The Reports tab
  shows the pins as posts (`ReportPost`); `VoteBar` and
  `PostedBy` / `showUserProfile` (lib/widgets/) are shared by the posts
  and the pin popup. "View on map" sets `focusedZone`, which the Map tab
  listens to.
- `lib/widgets/flood_depth.dart`: flood depth levels (ankle → over head),
  cm/ft, the gauge drawing, and the depth → risk cut-offs (≤20 cm normal,
  ≤50 moderate, else high) that the map legend also shows.
- `test/widget_test.dart` checks the app opens on Weather and that every screen
  renders at phone size without overflow. Use `pump()`, not
  `pumpAndSettle()`: several animations repeat forever. After a tap that
  opens a popup or moves something, pump twice (`pump()` then
  `pump(1 s)`): an animation only starts counting at its first frame, and
  a popup ignores taps until it's fully open.
- Weather extras: the scrubber uses hourly `precipitation`, humidity and
  wind; Tugak's per-hour lines (`tugakLineAt`) use PAGASA's rain bands
  (2.5 / 7.5 mm per hour); "rain in
  the next 2 hours" uses Open-Meteo `minutely_15` (model data, not radar).
  No rain radar on the map: RainViewer's free tier is too coarse at city
  zoom (checked Nov 12 2026). `test/fixtures/weather.json` is a saved real
  response: re-save it when the weather request changes.

## Running

- Local (home PC): `flutter run -d chrome`, `r` in the terminal to hot reload.
- Codespace (school, browser only): `flutter run -d web-server --web-port 8080`,
  then the Ports tab → port 8080.
- Add `--release` to preview at real size (~4 MB instead of ~100 MB for
  debug), but then there's no hot reload.
- Logo (Nov 2026, "Current Alert"): an exclamation mark whose dot is a
  kBlue wave; wordmark = mark + "agosalert." (Inter ExtraBold, outlined)
  with a blue dot. App icon = the mark on a black rounded square. SVG
  masters + usage guide in `brand/`. All logo files (brand SVGs, app,
  favicon, PWA icons, landing copies) come from `python tools/make_logo.py`
  (needs Chrome, Pillow, fontTools): edit the script, never the outputs.
- The loading screen (the logo's drop filling with blue water, bubbles,
  faint wave lines; follows `?theme=light`) is plain
  HTML/CSS in `web/index.html` (Adrian wants no skeleton card there), driven by `web/flutter_bootstrap.js` (hidden on
  Flutter's `flutter-first-frame`). `index.html` also preloads
  `main.dart.js`, the fonts, and the asset manifests. If you add or rename
  a font, update those preload links too.
- Every page except Weather is deferred (downloaded on first use,
  with a skeleton meanwhile): Map, Reports, Help (assistance_tab.dart),
  the bell's notifications, SOS, Report, Settings, Help & FAQ, About.
  Always open them through `lib/screens/deferred_screens.dart` (never
  import those screen files from Weather, the shell, or shared widgets), and keep `image_picker`
  imports out of every other file, or it'll end up back in the first
  download. (`flutter_map` lives only in `agos_map_io.dart`/`map_tiles.dart`,
  which the web build never compiles; MapLibre's JS only loads when a map
  is first shown.)
- In-app loading placeholders live in `lib/widgets/skeleton.dart`.
- Check before committing: `flutter analyze` and `flutter test`.

## Deploying

Every push to `main` publishes, via `.github/workflows/deploy-pages.yml`:
- the landing page (`landing/`) at https://adriantulabut5747.github.io/AgosAlert/
- the Flutter app at https://adriantulabut5747.github.io/AgosAlert/app/
  (built with `--base-href /<repo name>/app/`, filled in by the workflow)
- The same code also goes to https://github.com/adriantulabut5747/parcast.com
  (remote `parcast`: `git push parcast glass:main`), live at
  https://adriantulabut5747.github.io/parcast.com/ once Pages is on there.

So a broken push to `main` breaks the live site his groupmates
screenshot — use a branch for risky changes.

## Landing page (`landing/`)

- Hero modeled on a dribbble-style app landing: two tilted CSS phones
  (Home in front, Map behind) with real app screenshots in
  `landing/img/{home,map}-{dark,light}.webp` (390 wide at 2x, taken with
  the status bar left out; the page draws its own), slightly blurred on
  purpose. Retake them when the Weather or Map tab changes visibly (the
  Map ones were retaken Nov 12 2026 in 3D; the `home-*` ones still show
  the pre-redesign Home and need retaking from the Weather tab).
- The weather card and flood outlook chip popping out of the front phone
  are live (Open-Meteo, same request and rules as weather.dart, ported to
  landing.js). So are the numbers in "How it works" cards 1-2. Keep the
  outlook rule in sync with `floodOutlook` in weather.dart.
- Sections below the hero: 01 How it works (4 cards, no phone mockups:
  Adrian asked for none), 02 Hotlines (same numbers as kHotlines, plus a
  "save all" .vcf download), 03 Coverage (SVG map from OpenStreetMap:
  city boundary + all 27 barangays, drawn once with Python, not live),
  04 FAQ. Every photo carries its credit in a caption and in the footer.
- "Coming soon" store badges on purpose: the app isn't on either store,
  and Adrian chose not to fake it. Same for the testimonial/award spots
  of the reference: replaced by a barangay coverage card and the
  unofficial-demo notice.
- Kapampangan greeting by Manila time: abak (5-11), ugtu (11-13),
  gatpanapun (13-18), bengi (18-5).
- Preview locally: serve the folder (`python -m http.server` in
  `landing/`). Login links go to `app/`, which only exists after the
  deploy's copy step (or a local `flutter build web --base-href /app/`
  copied into `landing/app/`, which is gitignored).

## Known issues

- **The map (Nov 12 2026) is MapLibre GL JS in the browser**, not
  flutter_map. `AgosMap` (`lib/widgets/agos_map.dart`) has two versions
  picked at compile time: `agos_map_web.dart` (puts a `<div>` on the page,
  `web/agos_map.js` draws the map in it: pins are DOM markers, flood rings,
  3D buildings + terrain that fade in with the tilt, the 3D button,
  compass) and `agos_map_io.dart` (flutter_map + Esri, flat; only for
  `flutter test` and phone builds). Opens flat; 3D = tilt.
- **All map files ship with the app** in `web/map/` (~30 MB: Mabalacat
  vector tiles from Protomaps/OpenStreetMap at zoom 8-15, Terrarium
  elevation tiles, Inter label glyphs, `style-{light,dark}.json`, pinned
  MapLibre 5.24). All generated by `python tools/make_map.py [step]`:
  edit the script (colors are in PALETTE), never the outputs. Rerun
  `tiles` now and then for new roads/buildings. To tweak the look
  visually, open a style in Maputnik, then copy values back into the
  script. Tile URLs must stay absolute in JS (`transformRequest`): tiles
  load in a Web Worker where relative URLs break.
- **Anything floating over the web map must be wrapped in `MapGlass`**
  (`lib/widgets/map_glass.dart`). The map is real HTML, so Flutter's blur
  can't see it and taps would also reach the map; MapGlass puts a CSS
  `backdrop-filter` div behind the widget that fixes both. The shell's
  bottom nav and the top bar use it while the Map tab is open. Chrome on
  1x screens loses the blur when Flutter places the div with a CSS
  transform, so MapGlass swaps that for left/top (`_untransform`).
- The Map tab fills the whole window, under the glass top bar (phone and
  web). HomeShell passes the bar's height down as MediaQuery top padding
  (other tabs just start below the bar), so map overlays use
  `MediaQuery.paddingOf(context).top`, and any ListView in the Map tab
  needs `padding: EdgeInsets.zero`. Desktop: the side panel, controls and
  legend all float on the map as glass. Behind sheets/popups the
  map blurs itself and stops taking input (`ModalRoute.isCurrent`); on a
  hidden tab it ignores taps (`TickerMode`).
- The Map tab is locked to `kCityBounds` (demo_data.dart, same box as
  `CITY` in make_map.py) with a minimum zoom of 13. A test checks the
  fallback map can't be dragged outside.
- Don't use CARTO (stamps "API KEY REQUIRED") or tile.openstreetmap.org
  (blocks web apps) for the fallback. When checking a tile source, look at
  the actual image, not just the HTTP status.
- Headless Chrome shots of the map: use CDP with real time and
  `--use-angle=swiftshader` (WebGL), not `--virtual-time-budget`.

## Working with Adrian

- His **c key is broken** and he types **k** instead ("kode" = code,
  "kould" = could). Read past it.
- He's new to Flutter and git — explain the why, not just the what.
- Ask before implementing when a request has more than one reading.
- Be blunt: if an idea is weak or has a real downside, say so plainly.
- Keep replies short.
