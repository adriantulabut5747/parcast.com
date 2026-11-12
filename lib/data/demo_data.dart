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

/// The flood_*.jpg photos are from the Aug 2023 floods in Apalit,
/// Pampanga (not the barangays they're shown for), by Wikimedia Commons
/// user E911a, licensed CC BY-SA 4.0. The license requires this credit.
const String kFloodPhotoCredit =
    'Sample photo · Apalit, Pampanga, 2023 · E911a, CC BY-SA 4.0';

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

/// The demo account shown in the profile menu and on the More tab.
const String kDemoUserName = 'AC Parcore';
const String kDemoUserEmail = 'ac.parcore@mcc.edu.ph';
const String kDemoUserInitials = 'AP';

class FloodZone {
  final String barangay;
  final LatLng point;
  final RiskLevel risk;
  final double depthCm; // estimated street flood depth
  final String note;
  final String updated;
  // Thumbs up/down from other users (sample numbers). The user's own
  // vote is NOT included; it lives in [myVotes].
  final int upVotes;
  final int downVotes;
  // How long ago the pin's photo was taken. Pins are removed
  // [kPinLifetime] after that.
  final Duration photoAge;
  // Who posted this report (shown in the pin popup and the Home feed):
  // their position in [kUploaders].
  final int uploaderIndex;
  Uploader get uploader => kUploaders[uploaderIndex];
  const FloodZone(
    this.barangay,
    this.point,
    this.risk,
    this.depthCm,
    this.note,
    this.updated, {
    this.upVotes = 0,
    this.downVotes = 0,
    this.photoAge = Duration.zero,
    this.uploaderIndex = 0,
  });

  /// Optional photo, e.g. assets/images/flood_dau.jpg or
  /// flood_santa_ines.jpg. Missing files show a placeholder.
  String get photo =>
      'assets/images/flood_${barangay.toLowerCase().replaceAll(' ', '_')}.jpg';

  // Worked out from "now" each time, so the sample dates stay recent.
  DateTime get photoTakenAt => DateTime.now().subtract(photoAge);
  Duration get timeLeft => kPinLifetime - photoAge;
  bool get expired => timeLeft <= Duration.zero;
}

/// A resident who posts flood reports. Sample people (made-up names).
class Uploader {
  final String name;
  final String barangay;
  final int reports; // how many reports they've posted
  final int upVotes; // thumbs up on all their reports
  final int downVotes;
  const Uploader(
    this.name,
    this.barangay,
    this.reports,
    this.upVotes,
    this.downVotes,
  );

  /// "Rafael Dizon" -> "RD".
  String get initials => name
      .split(' ')
      .where((w) => w.isNotEmpty)
      .take(2)
      .map((w) => w[0])
      .join();
}

const List<Uploader> kUploaders = [
  Uploader('Rafael Dizon', 'Dau', 14, 212, 9),
  Uploader('Maricel Manalang', 'Tabun', 6, 88, 4),
  Uploader('Jerome David', 'Mabiga', 9, 131, 7),
  Uploader('Kristine Pangilinan', 'Duquit', 3, 27, 2),
  Uploader('Paolo Lansangan', 'Dolores', 5, 46, 1),
  Uploader('Andrea Tolentino', 'Camachiles', 8, 97, 6),
];

/// Set by "View on map" (Home feed): the Map tab opens this pin, then
/// sets it back to null.
final ValueNotifier<FloodZone?> focusedZone = ValueNotifier(null);

/// Pins users post are deleted this long after their photo was taken, so
/// old photos don't look like what's happening now.
const Duration kPinLifetime = Duration(days: 14);

/// Sample pins. Use [activeFloodZones] to show them: it skips old ones.
const List<FloodZone> kFloodZones = [
  FloodZone(
    'Dau',
    LatLng(15.1761, 120.5887),
    RiskLevel.high,
    65,
    'Low-lying streets near the creek are flooded above the knee.',
    '12 min ago',
    upVotes: 42,
    downVotes: 3,
    photoAge: Duration(hours: 5),
    uploaderIndex: 0,
  ),
  FloodZone(
    'Tabun',
    LatLng(15.2477, 120.5659),
    RiskLevel.moderate,
    40,
    'Water rising near the Sacobia riverbank.',
    '25 min ago',
    upVotes: 27,
    downVotes: 5,
    photoAge: Duration(days: 1, hours: 3),
    uploaderIndex: 1,
  ),
  FloodZone(
    'Mabiga',
    LatLng(15.2133, 120.5799),
    RiskLevel.moderate,
    30,
    'Some roads have ankle-to-knee deep water.',
    '18 min ago',
    upVotes: 19,
    downVotes: 2,
    photoAge: Duration(days: 3, hours: 7),
    uploaderIndex: 2,
  ),
  FloodZone(
    'Duquit',
    LatLng(15.1779, 120.6014),
    RiskLevel.normal,
    0,
    'No flooding reported.',
    '1 hr ago',
    upVotes: 8,
    downVotes: 1,
    photoAge: Duration(days: 9, hours: 2),
    uploaderIndex: 3,
  ),
  FloodZone(
    'Dolores',
    LatLng(15.2161, 120.5589),
    RiskLevel.normal,
    5,
    'Minor puddles only.',
    '40 min ago',
    upVotes: 11,
    downVotes: 0,
    photoAge: Duration(days: 12, hours: 20),
    uploaderIndex: 4,
  ),
  FloodZone(
    'Camachiles',
    LatLng(15.1924, 120.5861),
    RiskLevel.moderate,
    25,
    'Drainage is slow along the main road.',
    '30 min ago',
    upVotes: 15,
    downVotes: 4,
    photoAge: Duration(days: 6),
    uploaderIndex: 5,
  ),
];

/// Flood pins that haven't reached [kPinLifetime] yet.
Iterable<FloodZone> get activeFloodZones =>
    kFloodZones.where((z) => !z.expired);

class EvacuationCenter {
  final String name;
  final String barangay;
  final LatLng point;
  final int capacity;
  final int occupants;
  final bool open;
  final double distanceKm;
  final IconData icon;
  final String image; // optional photo in assets/images/
  const EvacuationCenter(
    this.name,
    this.barangay,
    this.point,
    this.capacity,
    this.occupants,
    this.open,
    this.distanceKm,
    this.icon,
    this.image,
  );

  double get fill => occupants / capacity;
}

const List<EvacuationCenter> kEvacCenters = [
  EvacuationCenter(
    'Mabalacat City Sports Complex',
    'Mabiga',
    LatLng(15.2100, 120.5760),
    500,
    186,
    true,
    2.1,
    CupertinoIcons.sportscourt_fill,
    'assets/images/evac_sports_complex.jpg',
  ),
  EvacuationCenter(
    'Mabalacat City Hall Grounds',
    'Poblacion',
    LatLng(15.2230, 120.5735),
    350,
    92,
    true,
    3.0,
    CupertinoIcons.building_2_fill,
    'assets/images/evac_city_hall.jpg',
  ),
  EvacuationCenter(
    'Dau Elementary School',
    'Dau',
    LatLng(15.1790, 120.5860),
    280,
    241,
    true,
    1.4,
    CupertinoIcons.book_fill,
    'assets/images/evac_dau_school.jpg',
  ),
  EvacuationCenter(
    'Dolores Covered Court',
    'Dolores',
    LatLng(15.2150, 120.5600),
    200,
    0,
    false,
    3.6,
    CupertinoIcons.house_alt_fill,
    'assets/images/evac_dolores_court.jpg',
  ),
];

enum AlertCategory {
  flood('Flood', AgosIcons.flood),
  weather('Weather', CupertinoIcons.cloud_bolt_rain_fill),
  road('Road', CupertinoIcons.car_fill),
  shelter('Shelter', CupertinoIcons.house_alt_fill);

  final String label;
  final IconData icon;
  const AlertCategory(this.label, this.icon);
}

class AppAlert {
  final String id;
  final AlertCategory category;
  final RiskLevel severity;
  final String title;
  final String summary;
  final String details;
  final List<String> actions;
  final String area;
  final String source;
  final Duration ago;
  const AppAlert({
    required this.id,
    required this.category,
    required this.severity,
    required this.title,
    required this.summary,
    required this.details,
    required this.actions,
    required this.area,
    required this.source,
    required this.ago,
  });
}

/// Who posts the app's own alerts. The admins aren't confirmed yet (they
/// may be Mabalacat officials later), so nothing claims to be official.
const String kAdminSource = 'Admin (unofficial demo)';

const List<AppAlert> kAlerts = [
  AppAlert(
    id: 'a1',
    category: AlertCategory.flood,
    severity: RiskLevel.high,
    title: 'Flooding in Brgy. Dau',
    summary: 'Knee-deep water on low-lying streets near the creek.',
    details: 'Water levels in Brgy. Dau have reached around 1.8 m in low-lying areas near the creek. Residents in the affected streets are advised to prepare for possible evacuation.',
    actions: [
      'Move valuables and appliances to higher places',
      'Prepare your go-bag',
      'Evacuate to Dau Elementary School if water keeps rising',
    ],
    area: 'Brgy. Dau',
    source: kAdminSource,
    ago: Duration(minutes: 12),
  ),
  AppAlert(
    id: 'a2',
    category: AlertCategory.weather,
    severity: RiskLevel.moderate,
    title: 'Heavy Rainfall Advisory',
    summary: 'Continuous moderate to heavy rain for the next 3 hours.',
    details: 'Moderate to heavy rainfall is expected over Pampanga, including Mabalacat City, within the next 3 hours. Flooding is possible in low-lying areas and near rivers.',
    actions: [
      'Avoid crossing rivers and flooded roads',
      'Keep your phone charged',
      'Monitor updates in AgosAlert',
    ],
    area: 'Mabalacat City',
    source: 'PAGASA',
    ago: Duration(hours: 1, minutes: 5),
  ),
  AppAlert(
    id: 'a3',
    category: AlertCategory.road,
    severity: RiskLevel.moderate,
    title: 'MacArthur Hwy (Dau) not passable',
    summary: 'Light vehicles should take an alternate route.',
    details: 'A section of MacArthur Highway near Dau is flooded and not passable to light vehicles. Traffic is being rerouted.',
    actions: ['Use an alternate route', 'Follow traffic enforcers on site'],
    area: 'Brgy. Dau',
    source: kAdminSource,
    ago: Duration(hours: 2, minutes: 20),
  ),
  AppAlert(
    id: 'a4',
    category: AlertCategory.shelter,
    severity: RiskLevel.normal,
    title: 'Evacuation center now open',
    summary: 'Mabalacat City Sports Complex is accepting evacuees.',
    details: 'The Mabalacat City Sports Complex in Brgy. Mabiga is now open as an evacuation center. Bring your go-bag, IDs, and medicines.',
    actions: [
      'Bring IDs and medicines',
      'Register at the help desk on arrival',
    ],
    area: 'Brgy. Mabiga',
    source: kAdminSource,
    ago: Duration(hours: 4),
  ),
  AppAlert(
    id: 'a5',
    category: AlertCategory.flood,
    severity: RiskLevel.normal,
    title: 'Water subsiding in Brgy. Duquit',
    summary: 'Streets are passable again.',
    details: 'Floodwater in Brgy. Duquit has fully subsided. Roads are now passable. Watch out for debris and mud.',
    actions: ['Watch out for debris', 'Do not touch fallen power lines'],
    area: 'Brgy. Duquit',
    source: kAdminSource,
    ago: Duration(days: 1, hours: 2),
  ),
];

/// IDs of alerts the user has opened (shared by the Alerts tab and the bell).
/// Starts with 'a5' already read, so the demo shows both read and unread
/// alerts. It lives only in memory: reloading the page resets it.
///
/// A ValueNotifier holds a value and tells every ValueListenableBuilder
/// watching it to rebuild when `.value` is set to something NEW. So to
/// mark an alert as read, set a new Set, e.g.
///   readAlerts.value = {...readAlerts.value, alert.id};
/// Calling readAlerts.value.add(id) would change the set without
/// notifying anyone, and the bell badge wouldn't update.
final ValueNotifier<Set<String>> readAlerts = ValueNotifier({'a5'});

/// How many alerts aren't in [readAlerts] yet (the number on the bell).
int get unreadAlertCount =>
    kAlerts.where((a) => !readAlerts.value.contains(a.id)).length;

/// True after "Continue as guest". Guests can look around but can't vote
/// or upload. Set by the login screen; there are no real accounts yet.
bool isGuest = false;

enum Vote { up, down }

/// The user's thumbs up/down on flood pins, by barangay. Missing = no
/// vote. Like [readAlerts]: set a NEW map to change it, and it resets
/// when the page reloads.
final ValueNotifier<Map<String, Vote>> myVotes = ValueNotifier({});

/// The user's own barangay, picked in the profile menu ("My barangay").
/// null = not picked yet. Weather and Reports put it first, and the bell
/// marks alerts for it. Memory only for now (resets on reload); it becomes
/// a column on the user's row once Supabase is connected.
final ValueNotifier<String?> myBarangay = ValueNotifier(null);

/// The user's answer to "Still flooded?" on each report, by barangay:
/// true = still flooded, false = the water's gone. Only the user's OWN
/// answers (no made-up totals). Memory only, like [myVotes].
final ValueNotifier<Map<String, bool>> stillFlooded = ValueNotifier({});

/// Thumbs up/down other users gave on this user's uploads (the profile
/// card). Sample numbers until there's a server.
const int kMyUpVotesReceived = 128;
const int kMyDownVotesReceived = 6;

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
    'Open the Assistance tab and tap any hotline. Your phone will ask you to confirm before calling.',
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
