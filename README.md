# AgosAlert

Flood alerts for every barangay in Mabalacat City, Pampanga.

**Live site:** https://adriantulabut5747.github.io/parcast.com/
**Open the app:** https://adriantulabut5747.github.io/parcast.com/app/ (log in, or look around as a guest)

> Unofficial demo. AgosAlert is a school capstone project by BSIT students. It is not made by, or connected to, the Mabalacat City government. For official warnings, follow PAGASA and the Mabalacat CDRRMO.

## What it does

The app has four tabs:

- **Weather:** live Mabalacat weather, the next 5 days, rain over 48 hours, and a flood outlook estimated from the rain forecast. Tugak, the app's toad, says what to do first.
- **Map:** the whole city in 2D or 3D, with flood reports and evacuation centers.
- **Reports:** flood posts from residents, each with a photo, a pin and the water depth. Logged-in users can post and vote. A report disappears 14 days after its photo was taken.
- **Help:** hold-to-call SOS (911), local hotlines, the nearest shelter, an "I'm safe" message, and a before / during / after checklist.

Evacuation centers and alerts are still sample data, marked SAMPLE in the app.

## Built with

- [Flutter](https://flutter.dev) (web build), [Supabase](https://supabase.com) for accounts, reports, votes and alerts
- [MapLibre GL JS](https://maplibre.org) with map tiles from [Protomaps](https://protomaps.com) / [OpenStreetMap](https://www.openstreetmap.org/copyright)
- Weather and air quality from [Open-Meteo](https://open-meteo.com)
- The landing page (`landing/`) is plain HTML, CSS and JavaScript

## Run it locally

```sh
flutter pub get
flutter run -d chrome
```

Before committing: `flutter analyze` and `flutter test`.

Every push to `main` builds the app and publishes the landing page plus the app to GitHub Pages (`.github/workflows/deploy-pages.yml`).

## Credits

- Map data © [OpenStreetMap](https://www.openstreetmap.org/copyright) contributors
- Weather: [Open-Meteo.com](https://open-meteo.com)
- Landing page photos: John Dexter Pimentel
