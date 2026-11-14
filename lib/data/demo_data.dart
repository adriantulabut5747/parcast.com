import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:latlong2/latlong.dart';

import '../theme.dart';
import '../widgets/agos_icons.dart';

/// ============================================================
/// DEMO DATA — all made-up numbers live here, so a real data
/// source can replace this one file later.
/// Barangay coordinates are real (from OpenStreetMap).
/// ============================================================

const LatLng kMabalacatCenter = LatLng(15.2236, 120.5717); // Poblacion

/// The box the map can't be dragged out of: Mabalacat City plus a little
/// margin. Same numbers as CITY in tools/make_map.py (the map data is only
/// downloaded for this area).
const kCityBounds = (
  south: 15.130,
  west: 120.490,
  north: 15.300,
  east: 120.670,
);

const List<String> kBarangays = [
  'Atlu-Bola',
  'Bical',
  'Bundagul',
  'Cacutud',
  'Calumpang',
  'Camachiles',
  'Dapdap',
  'Dau',
  'Dolores',
  'Duquit',
  'Lakandula',
  'Mabiga',
  'Macapagal Village',
  'Mamatitang',
  'Mangalit',
  'Marcos Village',
  'Mawaque',
  'Paralayunan',
  'Poblacion',
  'San Francisco',
  'San Joaquin',
  'Santa Ines',
  'Santa Maria',
  'Santo Rosario',
  'Sapang Balen',
  'Sapang Biabas',
  'Tabun',
];

/// Barangay centers found on OpenStreetMap, all 27 (the last 10 were
/// looked up for the landing page's map, Sept 2026).
const Map<String, LatLng> kBarangayPoints = {
  'Atlu-Bola': LatLng(15.2355, 120.5823),
  'Bical': LatLng(15.1949, 120.6198),
  'Bundagul': LatLng(15.2273, 120.6095),
  'Calumpang': LatLng(15.2205, 120.5326),
  'Macapagal Village': LatLng(15.2104, 120.5361),
  'Mangalit': LatLng(15.2266, 120.5782),
  'Marcos Village': LatLng(15.2094, 120.5301),
  'San Joaquin': LatLng(15.2307, 120.5714),
  'Santa Maria': LatLng(15.2270, 120.5922),
  'Santo Rosario': LatLng(15.2155, 120.5789),
  'Sapang Balen': LatLng(15.2504, 120.6005),
  'Cacutud': LatLng(15.2381, 120.5715),
  'Camachiles': LatLng(15.1924, 120.5861),
  'Dapdap': LatLng(15.2245, 120.6127),
  'Dau': LatLng(15.1761, 120.5887),
  'Dolores': LatLng(15.2161, 120.5589),
  'Duquit': LatLng(15.1779, 120.6014),
  'Lakandula': LatLng(15.1727, 120.5846),
  'Mabiga': LatLng(15.2133, 120.5799),
  'Mamatitang': LatLng(15.2301, 120.5726),
  'Mawaque': LatLng(15.2088, 120.5914),
  'Paralayunan': LatLng(15.2327, 120.6144),
  'Poblacion': LatLng(15.2236, 120.5717),
  'San Francisco': LatLng(15.2177, 120.5786),
  'Santa Ines': LatLng(15.2238, 120.5787),
  'Sapang Biabas': LatLng(15.1988, 120.6026),
  'Tabun': LatLng(15.2477, 120.5659),
};

/// A real photo of a local place, from Wikimedia Commons. [credit] must be
/// shown wherever the photo is (the licenses require it), and all of them
/// are listed on the About screen. Swap in the group's own photos later
/// by replacing the files (keep the names) and updating the credits.
class LocalPhoto {
  final String asset;
  final String place;
  final String credit;
  const LocalPhoto(this.asset, this.place, this.credit);
}

const kPhotoSacobia = LocalPhoto(
  'assets/images/photo_sacobia_river.jpg',
  'Sacobia River and Mt. Arayat, seen from Bamban',
  'Ralff Nestor Nacor, CC BY-SA 4.0',
);
const kPhotoSunset = LocalPhoto(
  'assets/images/photo_sunset.jpg',
  'Sunset in Mabalacat City',
  'Pancit Canton Media, CC0',
);
const kPhotoDauBridge = LocalPhoto(
  'assets/images/photo_dau_bridge.jpg',
  'Dau Bridge, MacArthur Highway',
  'Ralff Nestor Nacor, CC BY-SA 4.0',
);
const kPhotoMabuhayArch = LocalPhoto(
  'assets/images/photo_mabuhay_arch.jpg',
  'The old "Mabuhay" welcome arch of Mabalacat',
  'P199, CC BY-SA 3.0',
);
const List<LocalPhoto> kLocalPhotos = [
  kPhotoSacobia,
  kPhotoSunset,
  kPhotoDauBridge,
  kPhotoMabuhayArch,
];

/// Photos of an alert's area (of the PLACE, not of the flood itself).
const Map<String, LocalPhoto> kAreaPhotos = {'Brgy. Dau': kPhotoDauBridge};

/// Flood reports are deleted this long after their photo was taken, so
/// old photos don't look like what's happening now (FR-S1; the database
/// does the deleting, see supabase/02_flood_reports.sql).
const Duration kPinLifetime = Duration(days: 14);

class EvacuationCenter {
  final String name;
  final String barangay;
  final LatLng point;
  // No capacity / evacuee numbers (Nov 13 2026, Adrian): nobody can know
  // how many people are inside, so the app doesn't pretend to.
  final bool open;
  final double distanceKm;
  final IconData icon;
  final String image; // optional photo in assets/images/
  const EvacuationCenter(
    this.name,
    this.barangay,
    this.point,
    this.open,
    this.distanceKm,
    this.icon,
    this.image,
  );
}

const List<EvacuationCenter> kEvacCenters = [
  EvacuationCenter(
    'Mabalacat City Sports Complex',
    'Mabiga',
    LatLng(15.2100, 120.5760),
    true,
    2.1,
    CupertinoIcons.sportscourt_fill,
    'assets/images/evac_sports_complex.jpg',
  ),
  EvacuationCenter(
    'Mabalacat City Hall Grounds',
    'Poblacion',
    LatLng(15.2230, 120.5735),
    true,
    3.0,
    CupertinoIcons.building_2_fill,
    'assets/images/evac_city_hall.jpg',
  ),
  EvacuationCenter(
    'Dau Elementary School',
    'Dau',
    LatLng(15.1790, 120.5860),
    true,
    1.4,
    CupertinoIcons.book_fill,
    'assets/images/evac_dau_school.jpg',
  ),
  EvacuationCenter(
    'Dolores Covered Court',
    'Dolores',
    LatLng(15.2150, 120.5600),
    false,
    3.6,
    CupertinoIcons.house_alt_fill,
    'assets/images/evac_dolores_court.jpg',
  ),
];

enum Vote { up, down }

/// The user's thumbs up/down on flood reports, by report id. Missing = no
/// vote. Set a NEW map to change it. Filled from the feed's my_vote
/// (services/reports.dart) and saved in report_votes.
final ValueNotifier<Map<String, Vote>> myVotes = ValueNotifier({});

/// The user's own barangay, picked in the profile menu ("My barangay").
/// null = not picked yet. Weather and Reports put it first, and the bell
/// marks alerts for it. Logged in = the `barangay` column of the user's
/// row (services/auth.dart); guests keep it in memory only.
final ValueNotifier<String?> myBarangay = ValueNotifier(null);

/// The user's answer to "Still flooded?" on each report, by report id:
/// true = still flooded, false = the water's gone. Only the user's OWN
/// answers (no made-up totals). Memory only until its table exists.
final ValueNotifier<Map<String, bool>> stillFlooded = ValueNotifier({});

class Hotline {
  final String name;
  final String number;
  final IconData icon;
  final Color color;
  // Short label for the Help tab's one-tap call buttons.
  final String short;
  const Hotline(this.name, this.number, this.icon, this.color, this.short);
}

const List<Hotline> kHotlines = [
  Hotline(
    'National Emergency Hotline',
    '911',
    CupertinoIcons.phone_fill,
    kDanger,
    'Emergency',
  ),
  Hotline(
    'Mabalacat CDRRMO',
    '0998-999-4357',
    CupertinoIcons.exclamationmark_shield_fill,
    kTileTeal,
    'CDRRMO',
  ),
  Hotline(
    'Bureau of Fire Protection',
    '0933-990-9960',
    CupertinoIcons.flame_fill,
    kTilePurple,
    'Fire',
  ),
  Hotline(
    'Mabalacat Police (PNP)',
    '0998-598-5458',
    CupertinoIcons.shield_fill,
    kTileIndigo,
    'Police',
  ),
  Hotline(
    'Mabalacat City Hall',
    '(045) 649-8620',
    CupertinoIcons.building_2_fill,
    kTileBlue,
    'City Hall',
  ),
];

class SafetyTip {
  final IconData icon;
  final String title;
  final String body;
  const SafetyTip(this.icon, this.title, this.body);
}

/// Flood safety advice, grouped by when it matters (the Help tab shows one
/// group at a time). General guidance, not data.
const List<(String, List<SafetyTip>)> kSafetyPhases = [
  (
    'Before',
    [
      SafetyTip(
        CupertinoIcons.phone_fill,
        'Save the hotlines now',
        'Put CDRRMO and your barangay hall in your contacts before the rain starts.',
      ),
      SafetyTip(
        CupertinoIcons.house_alt_fill,
        'Know your evacuation center',
        'Find the nearest one and walk the route once while the roads are dry.',
      ),
    ],
  ),
  (
    'During',
    [
      SafetyTip(
        AgosIcons.landslide,
        'Go to higher ground',
        "Move early, before the water rises. Don't wait for it to reach your door.",
      ),
      SafetyTip(
        CupertinoIcons.bolt_slash_fill,
        'Switch off the power',
        'Turn off the main breaker if water may enter your home.',
      ),
      SafetyTip(
        CupertinoIcons.nosign,
        "Don't walk in floodwater",
        'It can hide open drains, sharp debris, strong currents, and live wires.',
      ),
    ],
  ),
  (
    'After',
    [
      SafetyTip(
        CupertinoIcons.checkmark_shield_fill,
        "Go home only when it's safe",
        'Wait until local officials say your area is clear.',
      ),
      SafetyTip(
        CupertinoIcons.bolt_fill,
        'Stay away from fallen wires',
        'Report them to the barangay or the power company. Never touch them.',
      ),
      SafetyTip(
        CupertinoIcons.drop_fill,
        'Boil water before drinking',
        'Floodwater can get into the water supply. Clean anything it touched.',
      ),
    ],
  ),
];

const List<(String, String)> kGoBagItems = [
  ('Drinking water (3 days)', 'At least 1 gallon per person per day'),
  ('Ready-to-eat food', 'Canned goods and biscuits'),
  ('Flashlight & batteries', ''),
  ('Power bank', 'Fully charged'),
  ('First aid kit & medicines', 'Include maintenance meds'),
  ('IDs & documents', 'In a waterproof pouch'),
  ('Cash', 'Small bills'),
  ('Whistle', 'To signal for help'),
  ('Extra clothes & raincoat', ''),
];

const List<(String, String)> kFaqs = [
  (
    'Where does the weather data come from?',
    'Live weather comes from Open-Meteo, a free weather service, using the coordinates of Mabalacat City.',
  ),
  (
    'Is the flood outlook an official warning?',
    'No. It is estimated from the rainfall forecast. Always follow official warnings from PAGASA and local authorities.',
  ),
  (
    'Are the flood reports and evacuation centers live?',
    'Not yet. Sections marked SAMPLE show demo data until reports and updates come from a real server. The weather is live.',
  ),
  (
    'How do I call a hotline?',
    'Open the Help tab and tap any hotline. Your phone will ask you to confirm before calling.',
  ),
  (
    'What should I do when a High alert appears?',
    'Follow the recommended actions in the alert, prepare your go-bag, and go to the nearest open evacuation center if told to evacuate.',
  ),
];

String timeAgo(Duration d) {
  if (d.inMinutes < 1) return 'Just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  return '${d.inDays}d ago';
}
