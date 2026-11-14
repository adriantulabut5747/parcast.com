import 'package:flutter/material.dart';

import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'services/alerts.dart';
import 'services/auth.dart';
import 'services/reports.dart';
import 'services/session.dart';
import 'theme.dart';

// The app starts here. runApp() puts AgosAlertApp on the screen.
Future<void> main() async {
  // Needed before anything (like Supabase) touches the browser's storage
  // ahead of runApp.
  WidgetsFlutterBinding.ensureInitialized();
  // The theme picked on the landing page (services/session.dart).
  applyLaunchOptions();
  // Connect to Supabase and pick up a login saved in this browser. The
  // HTML loading screen stays up meanwhile (services/auth.dart).
  await initAuth();
  startAlerts(); // the bell's alerts + live updates (not awaited)
  startReports(); // the flood reports + live updates (not awaited: the app opens meanwhile)
  runApp(const AgosAlertApp());
}

class AgosAlertApp extends StatelessWidget {
  const AgosAlertApp({super.key});

  @override
  Widget build(BuildContext context) {
    // themeNotifier (theme.dart) holds the current mode: light or dark.
    // ValueListenableBuilder rebuilds the MaterialApp whenever it changes,
    // which is how the dark/light button in the top bar switches the
    // whole app at once. MaterialApp gets both themes and `themeMode`
    // picks which one to use; it animates the colors over 400 ms.
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) => MaterialApp(
        title: 'AgosAlert',
        debugShowCheckedModeBanner: false,
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: mode,
        themeAnimationDuration: const Duration(milliseconds: 400),
        scrollBehavior: const _AppleScroll(),
        // Logged in (or ?as=guest from the landing page): straight into
        // the app, usually on Weather. Otherwise the login screen.
        home: !isGuest || openAsGuest
            ? HomeShell(initialTab: launchTab)
            : const LoginScreen(),
      ),
    );
  }
}

/// iOS scrolling everywhere: lists rubber-band past their ends and spring
/// back, instead of Android's glow / stretch. (Sheets switch back to the
/// clamping kind: pulling one down to close reads its overscroll.)
class _AppleScroll extends MaterialScrollBehavior {
  const _AppleScroll();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: RangeMaintainingScrollPhysics());

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
