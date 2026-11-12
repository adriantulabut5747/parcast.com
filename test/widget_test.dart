import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agosalert/data/demo_data.dart';
import 'package:agosalert/main.dart';
import 'package:agosalert/screens/evacuation_centers_screen.dart';
import 'package:agosalert/screens/home_shell.dart';
import 'package:agosalert/screens/info_screens.dart';
import 'package:agosalert/screens/map_tab.dart';
import 'package:agosalert/screens/more_tab.dart';
import 'package:agosalert/screens/report_incident_screen.dart';
import 'package:agosalert/screens/settings_screen.dart';
import 'package:agosalert/theme.dart';
import 'package:agosalert/widgets/agos_icons.dart';
import 'package:agosalert/widgets/agos_map.dart';
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

void main() {
  // Logging in happens on the landing page, so the app opens on Home.
  testWidgets('App starts on Home', (WidgetTester tester) async {
    await tester.pumpWidget(const AgosAlertApp());
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.text('Quick actions'), findsOneWidget);
  });

  // Each tab and screen should build on a phone without layout errors
  // (a "RenderFlex overflowed" error makes the test fail).
  testWidgets('All tabs render on a phone', (tester) async {
    await pumpPhone(tester, const HomeShell());
    for (final tab in ['Map', 'Alerts', 'Assistance', 'More', 'Home']) {
      await tester.tap(find.text(tab).last);
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
      // No More tab on wide screens (it's in the profile menu).
      expect(find.text('More'), findsNothing);
      for (final tab in ['Map', 'Alerts', 'Assistance', 'Home']) {
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
    isGuest = false;
    await pumpPhone(tester, const HomeShell(), size: const Size(1440, 900));
    await tester.tap(find.byTooltip('Account'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);
    expect(find.text('Votes on your uploads'), findsOneWidget);
  });

  // Regression test: switching tabs must hide the previous tab
  // (it once stayed visible on top of the new one).
  testWidgets('Switching tabs hides the previous tab', (tester) async {
    await pumpPhone(tester, const HomeShell());
    await tester.tap(find.text('More').last);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Home').last);
    await tester.pump(); // rebuild: the fade starts here
    await tester.pump(const Duration(seconds: 1)); // let it finish

    // The tab's fade is the nearest AnimatedOpacity above the text; read
    // the value it is actually drawing (from its inner FadeTransition).
    double opacityOf(String text) {
      final tabFade = find
          .ancestor(of: find.text(text), matching: find.byType(AnimatedOpacity))
          .first;
      return tester
          .widget<FadeTransition>(
            find
                .descendant(of: tabFade, matching: find.byType(FadeTransition))
                .first,
          )
          .opacity
          .value;
    }

    expect(opacityOf('Settings'), 0); // More tab is hidden
    expect(opacityOf('Quick actions'), 1); // Home tab is visible
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
    await pumpPhone(tester, const Scaffold(body: MapTab()));
    // Pins are keyed by their id ('zone-' + barangay); the text '40 cm' is
    // on both the pin and its card in the bottom panel.
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('pin-zone-Tabun')),
        matching: find.byIcon(AgosIcons.flood),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Brgy. Tabun'), findsOneWidget);
    expect(find.text('Knee-deep'), findsOneWidget);
    expect(find.text('≈ 1.3 ft'), findsOneWidget);
    expect(find.text('Too deep for cars'), findsOneWidget);
  });

  // Opens Dau's pin (42 up, 3 down) the way "View on map" on the Home
  // feed does: by setting focusedZone.
  Future<void> openDau(WidgetTester tester) async {
    await pumpPhone(tester, const Scaffold(body: MapTab()));
    focusedZone.value = kFloodZones.first;
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
    isGuest = false;
    myVotes.value = {};
    await openDau(tester);
    await tapThumb(tester, CupertinoIcons.hand_thumbsup_fill);
    expect(find.text('43'), findsOneWidget);
    // Switching moves the vote: up goes back to 42, down goes to 4.
    await tapThumb(tester, CupertinoIcons.hand_thumbsdown_fill);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    // Tapping the same thumb again takes the vote back.
    await tapThumb(tester, CupertinoIcons.hand_thumbsdown_fill);
    expect(find.text('3'), findsOneWidget);
    expect(myVotes.value, isEmpty);
  });

  testWidgets('Guests get a login popup instead of voting', (tester) async {
    isGuest = true;
    myVotes.value = {};
    addTearDown(() => isGuest = false);
    await openDau(tester);
    await tapThumb(tester, CupertinoIcons.hand_thumbsup_fill);
    expect(find.text('Log in to vote'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
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

  test('Pins older than 14 days are hidden', () {
    const old = FloodZone(
      'Dau',
      kMabalacatCenter,
      RiskLevel.normal,
      0,
      '',
      '',
      photoAge: Duration(days: 15),
    );
    expect(old.expired, isTrue);
    expect(activeFloodZones.length, kFloodZones.length);
  });

  testWidgets('Guests get a login popup from the map Report button', (
    tester,
  ) async {
    isGuest = true;
    addTearDown(() => isGuest = false);
    await pumpPhone(tester, const Scaffold(body: MapTab()));
    await tester.tap(find.text('Report'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Log in to report'), findsOneWidget);
  });

  testWidgets('Profile shows votes received, but not for guests', (
    tester,
  ) async {
    isGuest = false;
    await pumpPhone(tester, const Scaffold(body: MoreTab()));
    expect(find.text('$kMyUpVotesReceived'), findsOneWidget);
    isGuest = true;
    addTearDown(() => isGuest = false);
    // A new key makes Flutter build the tab again with the new isGuest.
    await pumpPhone(tester, const Scaffold(body: MoreTab(key: ValueKey(1))));
    expect(find.text('Guest'), findsOneWidget);
    expect(find.text('Votes on your uploads'), findsNothing);
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

  // Keep this test LAST. After it, a deferred tab that a later test opens
  // for the first time never finishes loading (a quirk of how the test
  // runner handles deferred code, not an app bug: it was the More tab in
  // "Switching tabs hides the previous tab").
  // (Alerts, not Map: the Map tab starts real tile downloads.)
  testWidgets('HomeShell can open on another tab', (tester) async {
    await pumpPhone(tester, const HomeShell(initialTab: 2));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(ListPageSkeleton), findsNothing); // Alerts loaded
    expect(find.text('Quick actions'), findsNothing); // Home never built
  });

  test('Spring curves settle before their time is up (no jump at the end)', () {
    for (final curve in [kSnappyCurve, kBouncyCurve]) {
      expect(curve.transform(0.98), closeTo(1, 0.01));
    }
  });
}
