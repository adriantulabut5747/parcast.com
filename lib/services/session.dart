import 'package:flutter/material.dart';

import '../theme.dart';

/// ============================================================
/// SESSION — options handed over in the web address
/// ============================================================
///
/// The landing page (`landing/`) opens the app with a few answers in the
/// web address:
///
///   .../AgosAlert/app/?theme=dark                 -> login screen
///   .../AgosAlert/app/?as=guest&theme=light&tab=map -> straight in as a guest
///
///   as     guest           skip the login screen (FR-G: look around)
///   theme  light | dark    so the app matches the landing page
///   tab    weather | map | reports | help   (optional; the old names
///          home / assistance still work)
///
/// Who is logged in is NOT in the address: Supabase keeps that
/// (services/auth.dart). The old `?as=user` is ignored on purpose, since
/// anyone could type it.

/// The web address's `?...` part. Uri.base is the page's address on the
/// web; in tests and on phones it's a file path with no query, so every
/// value below falls back to its default there.
Map<String, String> get _query => Uri.base.queryParameters;

/// The landing page's "Look around as a guest" (`?as=guest`).
bool get openAsGuest => _query['as'] == 'guest';

/// Reads the theme from the web address, before the app starts.
void applyLaunchOptions() {
  switch (_query['theme']) {
    case 'light':
      themeNotifier.value = ThemeMode.light;
    case 'dark':
      themeNotifier.value = ThemeMode.dark;
  }
}

/// Which tab to open first: 0 Weather, 1 Map, 2 Reports, 3 Help.
/// Old links from before the Nov 2026 redesign still land somewhere
/// sensible (home -> Weather, assistance -> Help; alerts and more are gone,
/// so they open Weather).
int get launchTab => switch (_query['tab']) {
  'map' => 1,
  'reports' => 2,
  'help' || 'assistance' => 3,
  _ => 0,
};
