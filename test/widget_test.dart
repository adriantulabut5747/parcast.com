import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import 'package:agosalert/data/demo_data.dart';
import 'package:agosalert/main.dart';
import 'package:agosalert/screens/assistance_tab.dart';
import 'package:agosalert/screens/evacuation_centers_screen.dart';
import 'package:agosalert/screens/home_shell.dart';
import 'package:agosalert/screens/info_screens.dart';
import 'package:agosalert/screens/login_screen.dart';
import 'package:agosalert/screens/map_tab.dart';
import 'package:agosalert/screens/reports_tab.dart';
import 'package:agosalert/screens/report_incident_screen.dart';
import 'package:agosalert/screens/settings_screen.dart';
import 'package:agosalert/screens/weather_tab.dart';
import 'package:agosalert/services/auth.dart';
import 'package:agosalert/services/reports.dart';
import 'package:agosalert/services/weather.dart';
import 'package:agosalert/widgets/check_in.dart';
import 'package:agosalert/theme.dart';
import 'package:agosalert/widgets/agos_icons.dart';
import 'package:agosalert/widgets/agos_map.dart';
import 'package:agosalert/widgets/barangay_search.dart';
import 'package:agosalert/widgets/common.dart';
import 'package:agosalert/widgets/flood_depth.dart';
import 'package:agosalert/widgets/skeleton.dart';

/// Shows [page] on a phone-sized screen (390 x 844, like an iPhone).
/// Pass [size] to try another screen, e.g. a desktop browser window.
Future<void> pumpPhone(
  WidgetTester tester,
  Widget page, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: buildDarkTheme(), home: page));
  // pump() not pumpAndSettle(): several animations repeat forever,
  // so the app never "settles".
  await tester.pump(const Duration(seconds: 1));
}

/// The logged-in user in tests (no Supabase here: `me` is set directly).
const kTestUser = AppUser(
  userId: 'test',
  fullName: 'AC Parcore',
  email: 'test@example.com',
  barangay: 'Dau',
);

/// A flood report posted by someone else (no Supabase in tests: the
/// list is set directly). Dau, 65 cm, photo taken 5 hours ago.
FloodReport testReport({
  Duration photoAge = const Duration(hours: 5),
  int depthCm = 65,
  String barangay = 'Dau',
  String userId = 'someone-else',
  int upVotes = 0,
  int downVotes = 0,
}) {
  final taken = DateTime.now().subtract(photoAge);
  return FloodReport(
    reportId: 1,
    userId: userId,
    incidentType: 'flooding',
    severity: 'high',
    depthCm: depthCm,
    barangay: barangay,
    latitude: kBarangayPoints[barangay]!.latitude,
    longitude: kBarangayPoints[barangay]!.longitude,
    note: 'Low-lying streets near the creek are flooded above the knee.',
    photoTakenAt: taken,
    expiresAt: taken.add(kPinLifetime),
    createdAt: taken,
    posterName: 'Test Poster',
    posterBarangay: 'Dau',
    upVotes: upVotes,
    downVotes: downVotes,
  );
}

void main() {
  setUp(() {
    // shared_preferences has no browser in tests: give it empty fake storage.
    SharedPreferences.setMockInitialValues({});
    // Most tests use the app logged in; guest tests set `me = null`.
    me = kTestUser;
    floodReports.value = [testReport()];
    reportsState.value = LoadState.ready;
  });

  // Every step of the Before / During / After timeline fits on a phone
  // (During adds the water-depth diagram).
  testWidgets('Help: every Be ready step renders', (tester) async {
    await pumpPhone(tester, const Scaffold(body: AssistanceTab()));
    for (final step in ['During', 'After', 'Before']) {
      await tester.scrollUntilVisible(find.text(step), 300);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text(step));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.tap(find.text('During'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Moving water is stronger than it looks'), findsOneWidget);
  });

  // The go-bag ticks are saved, so they come back after a reload.
  testWidgets('Help: go-bag ticks survive a reload', (tester) async {
    await pumpPhone(tester, const Scaffold(body: AssistanceTab()));
    final item = find.text('Whistle');
    // The list builds lazily: scroll until the item exists and shows.
    await tester.scrollUntilVisible(item, 300);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(item);
    await tester.pump();
    // A fresh tab = what a reload does.
    await tester.pumpWidget(const SizedBox());
    await pumpPhone(tester, const Scaffold(body: AssistanceTab()));
    await tester.scrollUntilVisible(find.text('Pack a go-bag'), 300);
    expect(find.text('1/9'), findsOneWidget);
  });

  // Logged out (and no ?as=guest), the app opens on the login screen.
  testWidgets('Logged out: app starts on Login', (tester) async {
    me = null;
    await tester.pumpWidget(const AgosAlertApp());
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(HomeShell), findsNothing);
  });

  // Both modes fit on a phone, and a missing field is caught before
  // anything is sent to Supabase (there's no Supabase in tests).
  testWidgets('Login screen: both modes render, empty form is caught', (
    tester,
  ) async {
    me = null;
    await pumpPhone(tester, const LoginScreen());
    await tester.tap(find.text('Log in').last);
    await tester.pump();
    expect(
      find.textContaining('Type your email first.'),
      findsOneWidget,
    ); // Tugak says it
    await tester.pump(
      const Duration(seconds: 1),
    ); // his bubble grows and scrolls into view

    final toSignUp = find.textContaining(
      'Create an account',
      findRichText: true,
    );
    await tester.ensureVisible(toSignUp);
    await tester.pump();
    await tester.tap(toSignUp);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Choose your barangay'), findsOneWidget);
    await tester.tap(find.text('Create account').last);
    await tester.pump();
    expect(find.textContaining('I need your full name first.'), findsOneWidget);
  });

  // Tugak's login lines go by Supabase's error code; no connection = not an AuthException.
  test('Login errors: Tugak names the problem', () {
    String line(String code) => tugakAuthLine(AuthException('x', code: code));
    expect(line('invalid_credentials'), startsWith('Wrong email or password.'));
    expect(
      line('email_exists'),
      startsWith('That email already has an account.'),
    );
    expect(line('over_request_rate_limit'), startsWith('Too many tries'));
    expect(
      tugakAuthLine(
        const AuthException(
          'This account is suspended. Contact the AgosAlert admin.',
          code: 'account_suspended',
        ),
      ),
      'This account is suspended. Contact the AgosAlert admin.', // serious: no joke
    );
    expect(
      tugakAuthLine(Exception('offline')),
      contains('Check your connection'),
    );
  });

  test('Avatar initials', () {
    expect(kTestUser.initials, 'AP');
    expect(
      const AppUser(
        userId: '',
        fullName: 'tugak',
        email: '',
        barangay: '',
      ).initials,
      'T',
    );
  });

  // Logged in, the app opens on Weather.
  testWidgets('App starts on Weather', (WidgetTester tester) async {
    await tester.pumpWidget(const AgosAlertApp());
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.byType(WeatherTab), findsOneWidget);
  });

  // Each tab and screen should build on a phone without layout errors
  // (a "RenderFlex overflowed" error makes the test fail).
  testWidgets('All tabs render on a phone', (tester) async {
    await pumpPhone(tester, const HomeShell());
    for (final tab in ['Map', 'Reports', 'Help', 'Weather']) {
      // Only the open tab shows its name; every tile has it as a tooltip.
      await tester.tap(find.byTooltip(tab));
      await tester.pump(const Duration(seconds: 1));
    }
  });

  // Website layout: nav at the top, every tab renders without overflow.
  for (final (name, size) in [
    ('Desktop', const Size(1440, 900)),
    ('Small laptop', const Size(1024, 700)),
    ('Tablet', const Size(800, 1100)),
  ]) {
    testWidgets('$name: top nav and every tab render', (tester) async {
      await pumpPhone(tester, const HomeShell(), size: size);
      for (final tab in ['Map', 'Reports', 'Help', 'Weather']) {
        await tester.tap(
          size.width >= 1024 ? find.text(tab).first : find.byTooltip(tab),
        );
        await tester.pump(const Duration(seconds: 1));
      }
    });
  }

  testWidgets('Desktop: clicking a pin in the side list opens it', (
    tester,
  ) async {
    await pumpPhone(
      tester,
      const Scaffold(body: MapTab()),
      size: const Size(1440, 900),
    );
    await tester.tap(find.text('Brgy. Dau'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Was this report helpful?'), findsOneWidget);
  });

  testWidgets('Desktop: the profile menu has Settings and Log out', (
    tester,
  ) async {
    me = kTestUser;
    await pumpPhone(tester, const HomeShell(), size: const Size(1440, 900));
    await tester.tap(find.byTooltip('Account'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Dark mode'), findsOneWidget);
    expect(find.text('My barangay'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);
    expect(find.text('Votes on your uploads'), findsOneWidget);
  });

  // Regression test: switching tabs must hide the previous tab
  // (it once stayed visible on top of the new one).
  testWidgets('Switching tabs hides the previous tab', (tester) async {
    await pumpPhone(tester, const HomeShell());
    await tester.tap(find.byTooltip('Help'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byTooltip('Weather'));
    await tester.pump(); // rebuild: the fade starts here
    await tester.pump(const Duration(seconds: 1)); // let it finish

    // Each tab sits in a _TabLayer; its Opacity is the first one inside it.
    double opacityOf(String text) {
      final layer = find
          .ancestor(
            of: find.text(text),
            matching: find.byWidgetPredicate(
              (w) => w.runtimeType.toString() == '_TabLayer',
            ),
          )
          .first;
      return tester
          .widget<Opacity>(
            find.descendant(of: layer, matching: find.byType(Opacity)).first,
          )
          .opacity;
    }

    expect(opacityOf('Request rescue'), 0); // Help tab is hidden
    expect(
      opacityOf(
        'Weather by Open-Meteo · Sections marked SAMPLE use demo data · Unofficial demo',
      ),
      1,
    ); // Weather tab is visible
  });

  // The map must stay inside Mabalacat City, however far you drag it.
  testWidgets('Map cannot be dragged outside Mabalacat', (tester) async {
    await pumpPhone(tester, const Scaffold(body: MapTab()));
    for (final drag in [
      const Offset(0, 2000), // far north
      const Offset(0, -4000), // far south
      const Offset(3000, 0), // far west
      const Offset(-6000, 0), // far east
    ]) {
      await tester.drag(find.byType(FlutterMap), drag);
      await tester.pump(const Duration(seconds: 1));
      final view = MapCamera.of(tester.element(find.byType(TileLayer).first))
          .visibleBounds;
      const margin = 0.001; // rounding
      expect(view.north, lessThanOrEqualTo(kCityLatLngBounds.north + margin));
      expect(
        view.south,
        greaterThanOrEqualTo(kCityLatLngBounds.south - margin),
      );
      expect(view.west, greaterThanOrEqualTo(kCityLatLngBounds.west - margin));
      expect(view.east, lessThanOrEqualTo(kCityLatLngBounds.east + margin));
    }
  });

  testWidgets('Tapping a flood pin shows its depth', (tester) async {
    floodReports.value = [testReport(depthCm: 40, barangay: 'Tabun')];
    await pumpPhone(tester, const Scaffold(body: MapTab()));
    // Pins are keyed by their id ('report-' + report_id); the text '40 cm'
    // is on both the pin and its card in the bottom panel.
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('pin-report-1')),
        matching: find.byIcon(AgosIcons.flood),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Brgy. Tabun'), findsOneWidget);
    expect(find.text('Knee-deep'), findsOneWidget);
    expect(find.text('≈ 1.3 ft'), findsOneWidget);
    expect(find.text('Too deep for cars'), findsOneWidget);
  });

  // Opens Dau's pin the way "View on map" on the Reports feed does: by
  // setting focusedReport.
  Future<void> openDau(WidgetTester tester) async {
    await pumpPhone(tester, const Scaffold(body: MapTab()));
    focusedReport.value = floodReports.value.first;
    await tester.pump(const Duration(seconds: 1));
    // The first pump starts the sheet's slide-in; this one finishes it.
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> tapThumb(WidgetTester tester, IconData icon) async {
    await tester.ensureVisible(find.byIcon(icon));
    await tester.pump();
    await tester.tap(find.byIcon(icon));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('Logged-in user can vote once, switch, and undo', (tester) async {
    me = kTestUser;
    myVotes.value = {};
    final saved = <Vote?>[];
    saveVote = (r, old, vote) async => saved.add(vote);
    addTearDown(() => saveVote = (r, old, vote) async {});
    await openDau(tester);
    await tapThumb(tester, CupertinoIcons.hand_thumbsup_fill);
    expect(myVotes.value, {'1': Vote.up});
    expect(find.text('1'), findsOneWidget);
    // Switching moves the vote.
    await tapThumb(tester, CupertinoIcons.hand_thumbsdown_fill);
    expect(myVotes.value, {'1': Vote.down});
    expect(find.text('1'), findsOneWidget);
    // Tapping the same thumb again takes the vote back.
    await tapThumb(tester, CupertinoIcons.hand_thumbsdown_fill);
    expect(find.text('1'), findsNothing);
    expect(myVotes.value, isEmpty);
    expect(saved, [Vote.up, Vote.down, null]);
  });

  testWidgets('A vote that fails to save is put back', (tester) async {
    me = kTestUser;
    myVotes.value = {};
    saveVote = (r, old, vote) async => throw Exception('offline');
    addTearDown(() => saveVote = (r, old, vote) async {});
    await openDau(tester);
    await tapThumb(tester, CupertinoIcons.hand_thumbsup_fill);
    expect(myVotes.value, isEmpty);
    expect(find.textContaining("wasn't saved"), findsOneWidget);
  });

  testWidgets('Guests get a login popup instead of voting', (tester) async {
    me = null;
    myVotes.value = {};
    addTearDown(() => me = kTestUser);
    await openDau(tester);
    await tapThumb(tester, CupertinoIcons.hand_thumbsup_fill);
    expect(find.text('Log in to vote'), findsOneWidget);
    expect(myVotes.value, isEmpty);
  });

  testWidgets('Swiping a pin sheet down closes it', (tester) async {
    await openDau(tester);
    await tester.drag(find.text('Brgy. Dau'), const Offset(0, 300));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Brgy. Dau'), findsNothing);
  });

  testWidgets('Pin sheet shows the photo date and removal countdown', (
    tester,
  ) async {
    await openDau(tester); // photo taken 5 hours ago
    expect(find.textContaining('Photo taken'), findsOneWidget);
    expect(find.text('Pin will be removed in 13 days'), findsOneWidget);
  });

  test('Reports older than 14 days are hidden', () {
    final old = testReport(photoAge: const Duration(days: 15));
    floodReports.value = [testReport(), old];
    expect(old.expired, isTrue);
    expect(activeFloodReports.length, 1);
  });

  testWidgets('Your own report shows a delete button, not the thumbs', (
    tester,
  ) async {
    final r = testReport();
    final mine = FloodReport(
      reportId: 2,
      userId: kTestUser.userId,
      incidentType: 'landslide',
      severity: 'moderate',
      barangay: 'Dau',
      latitude: r.latitude,
      longitude: r.longitude,
      photoTakenAt: r.photoTakenAt,
      expiresAt: r.expiresAt,
      createdAt: r.createdAt,
      posterName: kTestUser.fullName,
      posterBarangay: 'Dau',
    );
    await pumpPhone(tester, ReportPost(zone: mine));
    expect(find.byIcon(CupertinoIcons.trash), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.hand_thumbsup_fill), findsNothing);
    // No depth for a landslide: the type shows instead of "Dry".
    expect(find.text('Landslide'), findsOneWidget);
  });

  // The + above the phone nav opens the form; guests get the login popup.
  testWidgets('Report +: guests get a login popup', (tester) async {
    me = null;
    addTearDown(() => me = kTestUser);
    await pumpPhone(tester, const HomeShell());
    await tester.tap(find.byTooltip('Reports'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byTooltip('Report flooding'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Log in to report'), findsOneWidget);
  });

  test('Reports search matches names, notes, barangays and types', () {
    final r = testReport();
    final name = r.posterName.split(' ').first.toLowerCase();
    expect(reportMatches(r, name), isTrue);
    expect(reportMatches(r, r.barangay.toUpperCase()), isTrue);
    expect(reportMatches(r, r.typeLabel), isTrue);
    expect(reportMatches(r, 'zzz-nothing'), isFalse);
    expect(reportMatches(r, '  '), isTrue);
  });

  test('Barangay search: starts-with first, then contains', () {
    expect(barangayMatches('san').take(2), ['San Francisco', 'San Joaquin']);
    expect(barangayMatches('maria'), ['Santa Maria']);
    expect(barangayMatches('Paris'), isEmpty);
  });

  // Submit is always tappable; with nothing filled in it points at the
  // first missing part instead of sending.
  testWidgets('Report: Submit with nothing filled shows what is missing', (
    tester,
  ) async {
    await pumpPhone(tester, const ReportIncidentScreen());
    await tester.scrollUntilVisible(
      find.text('Submit report'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Submit report'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Choose what happened first.'), findsOneWidget);
    expect(find.text('Set the spot: tap the map below.'), findsOneWidget);
    // Picking a type clears that hint only.
    await tester.tap(find.text('Flooding'));
    await tester.pump();
    expect(find.text('Choose what happened first.'), findsNothing);
    expect(find.text('Set the spot: tap the map below.'), findsOneWidget);
  });

  testWidgets('Phone avatar menu: votes received, but not for guests', (
    tester,
  ) async {
    me = kTestUser;
    // The counts are the database's, on the user's own reports only.
    floodReports.value = [
      testReport(userId: kTestUser.userId, upVotes: 7, downVotes: 2),
      testReport(upVotes: 40),
    ];
    await pumpPhone(tester, const HomeShell());
    await tester.tap(find.byTooltip('Account'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('7'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Dark mode'), findsOneWidget);
    me = null;
    addTearDown(() => me = kTestUser);
    // A new key makes Flutter build the shell again with the new isGuest.
    await pumpPhone(tester, const HomeShell(key: ValueKey(1)));
    await tester.tap(find.byTooltip('Account'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Guest'), findsWidgets);
    expect(find.text('Votes on your uploads'), findsNothing);
  });

  test('"I\'m safe" message names the user and their barangay', () {
    me = kTestUser;
    myBarangay.value = 'Dau';
    addTearDown(() => myBarangay.value = null);
    final m = imSafeMessage(DateTime(2026, 11, 12, 15, 40));
    expect(
      m,
      startsWith(
        'I\'m safe. — ${kTestUser.fullName}, Brgy. Dau · Thu, Nov 12, 3:40 PM',
      ),
    );
  });

  testWidgets('Reports: "Still flooded?" saves only your answer, and undo', (
    tester,
  ) async {
    me = kTestUser;
    stillFlooded.value = {};
    await pumpPhone(tester, ReportPost(zone: testReport()));
    await tester.tap(find.text('Yes'));
    await tester.pump();
    expect(stillFlooded.value, {'1': true});
    expect(find.textContaining('still flooded'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pump();
    expect(stillFlooded.value, isEmpty);
  });

  testWidgets('Map: the bottom bar opens into the reports list', (
    tester,
  ) async {
    await pumpPhone(tester, const Scaffold(body: MapTab()));
    await tester.tap(find.textContaining('shelters open'));
    await tester.pump(); // starts the sheet's slide up
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Brgy. Dau'), findsOneWidget);
    expect(tester.getSize(find.text('Brgy. Dau')).height, greaterThan(0));
  });

  testWidgets('Report: dragging the water sets depth and severity', (
    tester,
  ) async {
    await pumpPhone(tester, const ReportIncidentScreen());
    expect(find.byType(DepthGauge), findsNothing);
    await tester.tap(find.text('Flooding'));
    // Two pumps: the first starts the card's open animation, the second
    // finishes it (one long pump would only draw its first frame).
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Not set'), findsOneWidget);

    // Tap near the bottom of the gauge (shallow water), then drag up.
    final gauge = find.byType(DepthGauge);
    final shallow = tester.getBottomLeft(gauge) + const Offset(80, -40);
    await tester.tapAt(shallow);
    await tester.pump();
    expect(find.text('Ankle-deep'), findsOneWidget);
    await tester.dragFrom(shallow, const Offset(0, -80));
    await tester.pump();
    expect(find.text('Waist-deep'), findsOneWidget);
    expect(find.text('No vehicles should pass'), findsOneWidget);
  });

  for (final (name, page) in [
    ('Evacuation centers', const EvacuationCentersScreen()),
    ('Report incident', const ReportIncidentScreen()),
    ('Settings', const SettingsScreen()),
    ('About', const AboutScreen()),
    ('Help', const HelpScreen()),
  ]) {
    testWidgets('$name screen renders on a phone', (tester) async {
      await pumpPhone(tester, page);
    });
  }

  // The Weather tab with real weather and air quality (the saved
  // fixtures): the live card shows the weather now, and a conditions tile
  // flips to its explanation. Phone first, then the same page at desktop
  // size (the room beside the live card).
  testWidgets('Weather: live card, a tile flips', (tester) async {
    final weather = File('test/fixtures/weather.json').readAsStringSync();
    final air = File('test/fixtures/air_quality.json').readAsStringSync();
    final client = MockClient(
      (req) async => http.Response(
        req.url.host.startsWith('air-quality') ? air : weather,
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    await http.runWithClient(() async {
      MabalacatWeather.load(refresh: true);
      AirQuality.load(refresh: true);
      await pumpPhone(tester, const Scaffold(body: WeatherTab()));
    }, () => client);
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.text('MABALACAT CITY · LIVE', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('Right now', skipOffstage: false), findsOneWidget);

    // Tap the UV tile: it flips to what the number means.
    await tester.scrollUntilVisible(find.text('UV INDEX'), 300);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('UV INDEX'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Sunburn strength'), findsOneWidget);

    await pumpPhone(
      tester,
      const Scaffold(body: WeatherTab()),
      size: const Size(1440, 900),
    );
  });

  // Keep this test LAST. After it, a deferred tab that a later test opens
  // for the first time never finishes loading (a quirk of how the test
  // runner handles deferred code, not an app bug: it was the More tab in
  // "Switching tabs hides the previous tab").
  // (Reports, not Map: the Map tab starts real tile downloads.)
  // Phones: swiping moves between neighbouring tabs; past the last tab it
  // only rubber-bands. (From Help and Reports: the Map starts real tile
  // downloads, so the test never swipes onto it.)
  testWidgets('Swiping moves between tabs, not past the last one', (
    tester,
  ) async {
    await pumpPhone(tester, const HomeShell(initialTab: 3));
    await tester.pump(const Duration(seconds: 1));
    bool showing(String text) =>
        find.text(text).hitTestable().evaluate().isNotEmpty;
    expect(showing('Request rescue'), isTrue); // on Help

    // Flick left on the last tab: it gives a little, then springs back.
    await tester.fling(
      find.text('Request rescue'),
      const Offset(-300, 0),
      1500,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(showing('Request rescue'), isTrue);

    // Flick right: Reports slides in from the left.
    await tester.fling(find.text('Request rescue'), const Offset(300, 0), 1500);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(showing('Request rescue'), isFalse);
    expect(showing('Tap the + down there to start.'), isTrue);
  });

  testWidgets('HomeShell can open on another tab', (tester) async {
    await pumpPhone(tester, const HomeShell(initialTab: 2));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(ListPageSkeleton), findsNothing); // Reports loaded
    expect(find.byType(WeatherTab), findsNothing); // Weather never built
  });

  test('Spring curves settle before their time is up (no jump at the end)', () {
    for (final curve in [kSnappyCurve, kBouncyCurve]) {
      expect(curve.transform(0.98), closeTo(1, 0.01));
    }
  });
}
