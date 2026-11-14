# AgosAlert

Flutter flood-monitoring app for Mabalacat City, Pampanga. A school group
project: Adrian writes all the code, his groupmates only do the paperwork.

**Two builds of the same system (Nov 2026).** The project counts for two
subjects, so the whole app gets built twice: this Flutter app first, then
a Laravel copy of everything, done only after the Flutter one is finished.
Both will share one **Supabase** database. Work on Flutter only for now,
but keep data shapes simple and named the way a database table would be,
so the Laravel build and Supabase can mirror them.

**Database (Nov 13 2026, accounts first).** The research paper
(`C:\Users\adrian\Downloads\AgosAlert-PAPEL.docx`, Ch. 3 Tables 14-22) is
the spec for every table, column and rule: follow its names. Tables are
added one feature at a time as numbered SQL files in `supabase/`
(`01_users.sql`, then `02_...`), which Adrian pastes into the Supabase SQL
Editor (no CLI). Done: `users`, `flood_reports` (+ the
`report-photos` Storage bucket, the `flood_report_feed` view, an hourly
pg_cron delete), `report_votes` (03), `alerts` + `alert_reads` (04;
no admin screen yet, admins post with the INSERT example at the top of
the file). Still sample data / memory only: rescue_requests,
flagged_numbers, evacuation_centers, device_tokens. Evacuation centers
show NO capacity / evacuee numbers (Nov 13 2026, Adrian: nobody can
know them), so the paper's Table 21 must drop `capacity` and
`current_evacuees` too. RLS is the real security (NFR-3): the
app only shows/hides. The Laravel build must log in through Supabase Auth's
API, never its own users/password table.

## Layout

- `lib/main.dart` only starts the app. `lib/theme.dart` has the colors,
  fonts and `RiskLevel`. Fonts: Inter for text, **Inter Display** for titles
  and big numbers (`kDisplayFont`; Nov 13 2026 Apple pass, replaced Inter
  Tight, which read crushed). Inter Display = Inter's opsz-32 cut, the
  open match for SF Pro Display (real SF can't ship in a web app: Apple's
  licence). Latin-only static cuts in `assets/fonts/`, made with fontTools
  (`instancer` opsz=32 on Google Fonts' Inter[opsz,wght], then subset);
  Light 300 is only for the big weather numbers (Apple Weather's thin
  numerals). **Apple type rules:** sizes only from Apple's scale (11, 12,
  13, 15, 17, 20, 22, 28, 34; 11 is the floor), page titles = Large Title
  34 bold (`PageHeader`), display text bold 700 (never 800) with
  `letterSpacing: displayTracking(size)` (size-specific tracking, never a
  fixed value). Risk colors as TEXT go through `c.readable(...)` (Apple's
  darker accessible variants on light pages).
- **Tabs (Nov 2026 redesign): Weather · Map · Reports · Help.**
  **Phone bottom nav (Nov 12 2026):** the floating glass pill, with a
  behavior borrowed from Clash Royale: the open tab grows wider, its icon
  gets bigger and pops up out of the pill, with its name and ‹ › marks
  (decoration only); closed tabs show only their icon, slightly faded.
  (A full Clash Royale restyle was tried and dropped the same day: Adrian
  kept the glass / iOS look.) The icons are drawn 2D illustrations, iOS style
  (soft gradients, no outlines, not cartoonish). Nov 13 2026 redraw, in
  the style of Apple's own app icons (bold shapes that read at ~30 px, no
  thin shine strokes): same subjects as the desktop nav (cloud + sun, folded
  map with a blue pin, stacked photo posts, a red/white lifebuoy for Help);
  no green (it means "safe"). In `tools/nav_icons.js`,
  rendered by `python tools/nav_icons.py [--preview]` to
  `assets/images/nav_*.png`: edit the JS, never the PNGs. The tablet /
  desktop top nav is an Apple **segmented control** (`_segmentedNav`): a
  glass track and a raised glass thumb that slides to the open tab and
  stretches a little while travelling (iOS 26 liquid thumb).
  **Moving between tabs (Nov 13 2026, Apple "fluid interfaces"):** one
  number, `_slide` in home_shell.dart, drives the pages, the phone pill
  and the segmented thumb (`_livePage`), so they always agree. Phones: a
  real pager, swipe left/right between neighbouring tabs, 1:1 with the
  finger, momentum projected on release (Apple's formula, rate 0.99),
  critically damped spring carrying the finger's speed, rubber-band past
  the first/last tab, and NO swipe on the Map (a drag there pans the
  map; swiping INTO the Map from Weather/Reports works). Inner horizontal
  drags (scrubber, rain bars, chip rows) win because Flutter gives the
  touch to the innermost one. Wider screens: taps only, a 64 px
  directional cross-fade. Interruptible: grab or tap mid-move.
  `lib/screens/`: `home_shell.dart` (top bar: logo, bell, avatar menu;
  the bottom nav; the old + fan is gone (Nov 13 2026). Reporting (Nov 14
  2026, the composer was dropped, Adrian disliked it): phones = a round
  kBlue + (`ReportFab`, deferred_screens.dart) above the nav's right end
  on Reports (in the shell, fades with the swipe) and on the Map (drawn
  by map_tab beside the closed sheet, hidden while it's open); tablets /
  desktop = a "Report flooding" button under Tugak atop Reports (desktop
  Map keeps its side-panel button). SOS / I'm safe live in Help),
  `weather_tab.dart` (Nov 12 2026 redesign after the
  teacher called the card stack generic: greeting, high-alert strip, the
  **sky card scrubbable through the next 24 h** (drag the strip = rain bars
  + temperature line; sky color, rain/stars, numbers and Tugak all switch
  to that hour; water at the bottom rises with the rain adding up, full at
  30 mm = the high-outlook rule; NOTE Nov 14 2026: that strip is gone
  from the page, `_hour` stays 0), **Tugak's 3D stage = the "now"
  card (Nov 14 2026, Adrian: the big box was "useless")**: `_NowReadout`
  (live dot, temp, sky, H/L/feels, next 2 h, 3 stats; dark colors, the
  stage is navy in both themes) drawn ON the stage, left half on wide
  stages / across the top on phones (< 560 px); `StageReserve` tells
  scene.js which part it covers (`setReserve`: `camera.setViewOffset`
  frames Tugak in the rest, the bubble goes bottom left with a tail
  right, or across the bottom with a tail up). Desktop: stage beside
  greeting + 5 days (stage height = that column, min 440). **The flood
  watch card was dropped Nov 14 2026 (Adrian)**; Flood reports runs full
  width under the stage. Then (Nov 13 2026 dashboard redesign,
  `weather_dashboard.dart`) 8 **conditions tiles** that follow the
  scrubbed hour and flip to a plain explanation on tap (wind compass,
  feels like + PAGASA heat index, humidity, UV, air quality from
  Open-Meteo's Air Quality API, visibility, pressure sparkline, sun arc),
  **Rain, 48 hours** (last 24 h + next 24 h against the 30 mm line,
  draggable bars), **On the map now** (`FloodOpsCard`, Nov 14 2026
  redesign, Adrian disliked the red depth bars: the live reports newest
  first as quiet rows, type icon in a kBlue tile, "type · barangay",
  depth + level only when the report has one (no "0 cm"), verified,
  time; risk = a 7 px dot only; 2 columns >= 720 px, 3 rows max, "See
  all N in Reports" only when some don't fit; tap = map on that pin), and the 5-day forecast (on phones too it sits right under the live card, Nov 14 2026) with full-color
  `WeatherGlyph`s (`lib/widgets/weather_glyph.dart`, drawn in code:
  yellow sun, white clouds, blue rain, yellow bolt; gently animated) and
  temperature-colored range bars (`tempColor`). Conditions tiles each
  have their own tint (icon + a soft wash, never risk green/orange/red). The sky card is
  navy only (`weatherGradient`), clouds always drift across it
  (`DriftingClouds`, Adrian's call), no rising water any more. "Your
  city right now" was removed (Adrian disliked it). The old 24 h rain card and
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
  back rainbow icon colors or per-section entrance animations), `notifications.dart` (the bell's sheet: the
  `alerts` table via `lib/services/alerts.dart`, read-marks in
  `alert_reads` for users / memory for guests; empty until an admin
  posts), plus evacuation centers, report incident,
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
- Optional photos: `assets/images/evac_*.jpg` (names in demo_data.dart).
  Missing files fall back to a placeholder. Flood report photos are
  uploaded by users (Supabase Storage), see Flood reports below.
- `PageBackground` (common.dart) draws the background under every tab.
  **Dark = the landing page's night (Nov 14 2026, Adrian wanted the app
  to match the landing):** navy glows + still stars (painted once, fewer
  and dimmer than the landing's because the cards are see-through; no
  twinkle / shooting stars: loops cost CPU, see below). Light (Nov 14
  2026 pass): cool neutral `#F2F3F6`, one faint kBlue glow, faint blue
  water lines, solid white cards with a 2-layer shadow
  (`kLightCardShadow`), no stars. Desktop Map side panel is opaque white
  on light (`_glass(solid: true)`): see-through, the map mixed with it. The loading screen
  (`web/index.html`) and Tugak's stage (`STAGE`/`POOL` in scene.js: the
  landing hero's navy + kBlue pool) match it. **Tugak around the app
  (Nov 14 2026, phase 2):** `TugakSay` (tugak.dart) = the landing's
  `.say` bubble (blue TUGAK label, tail down / left / none): navy on dark,
  WHITE on light (Nov 14 2026, Adrian; the 3D stage's HTML bubble too,
  `.tg-light` in scene.js); `TugakBeside` = pose + bubble in a row;
  `TugakImage(pose: ...)` = a landing pose from `assets/images/tugak/`
  (phone, think, handset, tip; copied there by `tugak3d.py --poses`,
  APP_POSES). Used on: login (a mini landing hero: hat tip in a kBlue
  pool, bubble above; beside the form at >= 900 px; no logo there any
  more; **login errors are Tugak's lines**, no red line: `tugakAuthLine`
  matches Supabase's error CODES, fix first then a dry joke, no joke
  for suspended / sign-ups closed; he switches to the think pose and the
  bubble scrolls into view), Reports empty (phone / think when filtered), notifications
  empty, Help & FAQ top (think), Help's Be ready (handset, no jokes),
  the "I'm safe" sheet (tip). Never near SOS or on the Map. **Performance (Nov 13 2026):** on
  the web any running animation redraws the WHOLE screen every frame, so
  nothing loops forever on a resting page: icons, the flood post's water
  and the live dot play once; the clouds redraw 15x a second from a
  Timer; rain streaks loop only while it rains. The film grain was removed
  (it made every frame ~40% slower). Measure idle CPU before adding a loop.
- Phone / tablet / desktop layouts: `lib/widgets/responsive.dart`
  (breakpoints 600 and 1024, `pagePadding`, `TwoColumns`). Phones keep
  the bottom nav; tablets and desktops get a top nav (icons only on
  tablets), and
  `showAppSheet` opens a centered popup instead of a bottom sheet.
  Desktop has its own layouts for Weather (two columns), Map (side panel),
  Reports (one centered feed column, like Facebook) and Help (two
  columns).
- **Reports tab (Nov 13 2026)**: Tugak (phone pose) with two chat
  bubbles (`TugakBeside(more: ...)`; only the last bubble has a tail),
  a search field (poster name, note, barangay, type: `reportMatches`)
  with a Filter button that shows the hidden filters (sort, risk, type,
  my barangay, verified). Posts are Facebook-style (`ReportPost`):
  poster + time + barangay on top, the note, type + risk tags, the photo
  edge to edge (no photo = no gray box), depth, "Still flooded?", thumbs
  + Map at the bottom. Avatars get a color from the user id.
- **Map pins per type**: `kIncidentTypes` (reports.dart) is the one
  list of (icon, label) for the form, pins and posts. Blocked road =
  `AgosIcons.roadBlock` (a barricade, make_icons.py).
- **Barangay search** (`lib/widgets/barangay_search.dart`, barangays
  only, Adrian's call) on the Map tab and in the report form's pin
  picker. The form's map preview is not draggable: tap it (or "Edit
  pin") for the full-screen `_SpotPicker`. Submit is always tappable;
  with something missing (type, or the pin not set) it scrolls there,
  outlines it red with a hint and shakes it (`_Attention`). Photo stays
  optional.
- **Stale-build fix**: a deferred page that fails to download retries
  once; on the web "Try again" reloads the page (`reloadPage`), because
  a deploy while a tab is open makes the old app ask for part files that
  no longer exist (that was the Nov 13 "Help & FAQ couldn't load").
- Style "Graphite" (Nov 2026 redesign; Adrian: "no rules, make it feel
  PREMIUM, not a hackers' hideout"): dark = the landing's night navy
  (`#05060C`, default, since Nov 14 2026; was graphite `#111113`) and cool light (`#F2F3F6`); iOS blue
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
  **Apple controls only (Nov 13 2026):** iOS bounce scrolling everywhere
  (`_AppleScroll` in main.dart; sheets keep clamping physics because
  swipe-down-to-close reads overscroll), Cupertino pull-to-refresh,
  activity spinner and switch; buttons are `PrimaryButton` (main),
  `SecondaryButton` (gray capsule: Cancel / Not now), `TintedButton`
  (small accent capsule: Retry, Call). No Material FilledButton /
  TextButton / SwitchListTile / RefreshIndicator. Changing numbers roll
  (`RollingText`, iOS numeric transition); cards arrive with
  `FadeSlideIn` (fade + 14 px rise + 98.5% scale, off with reduced
  motion). Status colors are Apple's system green/orange/red; open
  shelters are indigo (`kShelter`), never green (green = safe/dry zone).
- **Tugak** (Kapampangan for frog), the mascot. Nov 12 2026 redraw in
  iOS / Animoji style, because the old comic look (black outlines, cel
  shading, shades on his head) clashed with the glass UI: soft shading,
  NO outlines, one light from the top left (same as GlassEdgePainter),
  warm bronze skin, glossy gold eyes with a toad's horizontal pupils,
  calm half-lidded look, navy rescue jacket; hood up in rain/storm, cool
  moonlight at night. No shades any more. Adrian wants him cool /
  grown-up, NOT cute or kiddy (rejected: round blushing frog, bright
  green, a visor hiding the eyes, the Pepe look, and a flat SF-Symbol
  line frog that read as a kids' app). Nov 13 2026 redraw as a portrait
  for the 40 px avatar: head centered for a circle crop, toad anatomy
  (brow ridges, glands behind the eyes, broad flat head), lozenge pupils,
  a standing jacket collar with a reflective band; `TugakBrief` zooms the
  image 1.4x on the face. Drawn in `tools/tugak.js` (SVG),
  rendered by `python tools/tugak.py` to
  `assets/images/tugak_{fine,rain,storm,night}.png` in full color (a
  256-color palette bands the gradients; `--preview` for a sheet): edit
  the JS and rerun, never the PNGs. `lib/widgets/tugak.dart`:
  mood + line from REAL weather / the latest high alert (`tugakMoodFor`,
  `tugakLine`; per forecast hour `tugakMoodAt`, `tugakLineAt`), tap = hop
  + a tip. Nov 13 2026: no big figure or bubble any more; he's a small
  round avatar + one-line briefing row on the sky card (`TugakBrief`),
  because the full figure felt out of place on the dashboard. Voice: deadpan, what to do first, a dry
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
- **Accounts (Nov 13 2026): Supabase Auth, email + password** (Google
  sign-in later: needs a Google Cloud OAuth client). "Confirm email" is
  OFF in the dashboard (Supabase's built-in mailer only reaches team
  members). Login lives IN the app (`lib/screens/login_screen.dart`: Log
  in / Create account / Continue as guest), so the Android build works
  too. `lib/services/auth.dart`: `initAuth()` in main() before runApp
  (picks up the login Supabase saved in the browser), `me` = the user's
  `users` row (`AppUser`), `isGuest` = `me == null`. Sign-up sends name +
  barangay as metadata; the trigger in `01_users.sql` makes the row.
  Suspended accounts are signed out with a message. Project URL +
  publishable key in `lib/services/supabase_config.dart` (never the
  secret key). Admins: set `role = 'admin'` in the Table Editor (no admin
  UI yet). The landing page's "Open the app" popup opens `app/` (login
  screen) or `app/?as=guest` (`lib/services/session.dart`); the old
  `?as=user` is ignored on purpose. Log out = sign out + login screen.
- Roles: Admin, Registered User, Guest. When a guest taps something they
  can't do, call `showLoginRequired` (account.dart). "My barangay" is the
  `barangay` column when logged in (saved on pick, can't be cleared);
  guests keep it in memory. Votes on flood pins (`myVotes`) and "Still
  flooded?" answers (`stillFlooded`) are still memory only until their
  tables exist; only the user's OWN answers, never made-up totals.
  Tests set `me` directly (`kTestUser` in widget_test.dart): no Supabase
  in tests, so never call it from a widget's build.
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
- **Flood reports (Nov 13 2026): real, through Supabase**
  (`supabase/02_flood_reports.sql`, `lib/services/reports.dart`). The 6
  sample pins and their Apalit photos are gone (Adrian: real data only),
  so the feed/map are empty until someone posts. `floodReports` is the
  one list every screen reads (Map, Reports, Weather's two cards), loaded
  in main() by `startReports()` and refreshed by Supabase Realtime. The
  app reads the `flood_report_feed` VIEW (active reports + poster's
  name), because the users table only lets you read your own row. The
  database sets user_id, status, expires_at (photo_taken_at + 14 days)
  and created_at itself (trigger), and refuses photos older than 14 days.
  Photo is optional (Adrian's call; the paper's use case says always):
  no photo = photo_taken_at is the posting time. The form
  (report_incident_screen.dart): photo date from EXIF
  DateTimeOriginal, else the file's date, camera = now; on the web the
  original is picked and shrunk to 1600 px JPEG by a canvas
  (`services/photo_web.dart`, also strips EXIF/GPS); location = drag the
  map under a fixed pin (`AgosMapController.center`, from MapLibre's
  `moveend`) or "Use my location" (geolocator), barangay = nearest
  barangay center, changeable. Your own report shows a trash button
  (`DeleteReportButton`) instead of thumbs. Admins verify/remove in the
  Table Editor (`status`). shortcut: photo files of auto-deleted reports
  stay in Storage (SQL can't delete them); the paper's scheduled Edge
  Function fixes that later.
- **Votes (Nov 13 2026): real** (`supabase/03_report_votes.sql`). The
  feed view adds `up_votes`, `down_votes` and `my_vote` (the asker's,
  via auth.uid()); `loadReports` fills `myVotes` from `my_vote` and
  reloads on any vote change (Realtime) and on log in/out. `VoteBar`
  shows the tap at once, saves through `saveVote` (tests swap it), and
  puts the thumbs back if saving fails. Votes are public (Realtime needs
  that); you can't vote on your own report. Profile menu + profile card
  sum the votes on the user's active reports. "Still flooded?"
  (`stillFlooded`) is still memory only.
  `VoteBar`, `PostedBy` / `showUserProfile` are shared by the posts and
  the pin popup. "View on map" sets `focusedReport`, which the Map tab
  listens to. Tests set `floodReports` directly (`testReport()`).
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
  zoom (checked Nov 12 2026). `test/fixtures/weather.json` (and `air_quality.json`) are saved
  real responses: re-save them when a request changes.

## Running

- Local (home PC): `flutter run -d chrome`, `r` in the terminal to hot reload.
- Codespace (school, browser only): `flutter run -d web-server --web-port 8080`,
  then the Ports tab → port 8080.
- Add `--release` to preview at real size (~4 MB instead of ~100 MB for
  debug), but then there's no hot reload.
- Logo (Nov 13 2026, "A + current"; replaced the "!" with a wave dot):
  the A of AgosAlert whose crossbar is a kBlue wave running past both
  legs (that overhang keeps the blue visible at 16 px), the A cut around
  the wave by a thin gap; wordmark = mark + "agosalert." (Inter
  ExtraBold, outlined) with a blue dot. App icon = the mark on a black rounded square. SVG
  masters + usage guide in `brand/`. All logo files (brand SVGs, app,
  favicon, PWA icons, landing copies) come from `python tools/make_logo.py`
  (needs Chrome, Pillow, fontTools, skia-pathops): edit the script, never the outputs.
  `brand/board.html` + `board/slide-*.png` are NOT generated and still show
  the old "!" mark.
- The loading screen (the app icon: the A fills with blue water from the
  bottom, clipped to the A's shape; bubbles, faint wave lines; follows
  `?theme=light`; its mark is written by make_logo.py between the
  LOGO:START / LOGO:END markers) is plain
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

- **Nov 14 2026 redesign** (Adrian's reference: discord.com, made darker
  and starry). **Dark only** (the theme toggle and light screenshots are
  gone: stars don't work on off-white). A fixed night sky behind the whole
  page (`.sky`: star box-shadows drawn once by landing.js, sparkles, a
  shooting star). **Tugak explains every section**: hero = the LIVE 3D
  Tugak (`landing/tugak.js`, loads three.js + `tugak.glb` from
  `app/tugak/`, i.e. web/tugak/, so one copy; eyes follow the pointer,
  click = hat tip, mouth moves while his bubble types; the still
  `img/tugak/hero.webp` shows until it's ready and if it fails), his line
  from real weather (`tugakLine` in landing.js, ported from tugak.dart).
  **Hero (Nov 14 2026 de-clutter):** title is always exactly 3 lines (one
  span per line); the two buttons sit under the copy, the store badges +
  "Unofficial demo" centered under the whole hero (Adrian likes them
  there); the art has one thing per corner: bubble top left, ONE map
  phone tilted in CSS 3D top right (`.hp-3d`), Tugak bottom left, live
  weather card + outlook chip bottom right. No floating props, no second
  phone. Map shots (`img/map-3d.webp` = Poblacion market block by Our
  Lady of Grace church, `img/map-3d-dau.webp` = Dau) are the Map tab
  after `set3d(true)` with pins + flood zones hidden (`setHidden`): no
  red/amber zones next to the page's blues (Adrian). The SOS badge in 03
  is gone (it covered the phone, whose screenshot already shows SOS).
  **Scroll animation:** text and panels never animate in; only small
  things (`.pop`: row Tugaks, the 4 phones, SOS badge, the map dots)
  pop the moment they enter the screen. Don't bring back whole-section
  fades (Adrian: too late). Then a crossed
  kBlue / outlined barangay marquee, "Four tabs" (4 phones), and rows
  that alternate sides, each with a pose rendered by
  `tools/tugak3d.py -- --poses` into `landing/img/tugak/*.webp`: 01
  Weather (umbrella, right), 02 Reports (phone showing the map, left),
  the floating "pins" there are rendered upside down so they read as
  falling drops (Adrian), rainy photo marquee (Dexter Pimentel's photos, credited, `rain-*.webp`
  from his `photo-*.jpg`), 03 Help & hotlines (handset, right, no jokes),
  04 Coverage (map pin, left), 05 FAQ (hand to chin, right), finale (hat
  tip). Poses/props are code in the script's `--poses` block: edit that
  and rerun, never the webp (`--only umbrella,phone` renders just those).
  Poses that hold something swap in a fingerless arm + a small `fist()`
  of 3 short curled fingers round the prop (Adrian: the flat, spread
  fingers didn't read as holding and were too big for a toad). Same for
  the hat tip (fist on the brim; his head is tall, so the hat tilts down
  to the hand round its own middle and the arm bows out at the elbow and
  stretches a little: `reach_to(..., stretch=)` asserts instead of
  silently stopping short) and the thinker (fist under the chin). Glows/shapes use kBlue + iOS tile indigo /
  teal / purple only (the barangay marquee band is a darker `#0B4A9C`:
  full kBlue was too loud); green/amber/red stay risk + SOS.
- Phone mockups = CSS frames with real app screenshots in `landing/img/`
  (390x795 at DPR 2, CDP, webp q80, guest, from the local build). "Four
  tabs" = Weather (`phone-weather`: scrolled so the live card is at the
  top, the 5-day card under it), Map (`map-3d-dau`), Reports
  (`phone-reports`: top of the feed), Help (`phone-help`, keep).
  The 01 Weather and 03 Help rows have no phone (Adrian, Nov 14 2026):
  just Tugak; 01 shows the live readings + the three rules, no heading.
- **Same look as the app (Nov 13 2026 trust pass):** the page uses the
  app's Graphite colors (tokens in landing.css `:root`, commented with
  the theme.dart names), the system font first (`-apple-system`: real SF
  on Apple devices, never hosted) then Inter with optical sizes,
  PrimaryButton-style
  buttons (white on dark, black on light, no colored glow), the app's
  navy `weatherGradient`, and the app's CupertinoIcons, cut down by
  `python tools/make_landing_icons.py` into `landing/fonts/cupertino.woff`
  + `landing/icons.css` (edit the script's ICONS list, never the outputs;
  markup is `<span class="ms" data-i="cloud_fill"></span>`). Hotline icons
  are neutral gray with red only for 911, like the Help tab. Don't bring
  back the old navy/cyan/yellow palette, Plus Jakarta / JetBrains Mono, or
  Material Symbols: a landing page that looks unlike the app it opens
  reads as a different (less trustworthy) product.
- Trust rules: every live number says where it's from and when; if
  Open-Meteo fails, every value says so (no `--` left hanging); the
  footer names who made it and links the public GitHub repo + issues.
- The weather card and flood outlook chip popping out of the front phone
  are live (Open-Meteo, same request and rules as weather.dart, ported to
  landing.js). So are the numbers in "How it works" cards 1-2. Keep the
  outlook rule in sync with `floodOutlook` in weather.dart.
- Hotlines = the same numbers as kHotlines, plus a "save all" .vcf
  download. Coverage = SVG map from OpenStreetMap (city boundary + all 27
  barangays, drawn once with Python, not live). Every photo carries its
  credit on the page and in the footer.
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
