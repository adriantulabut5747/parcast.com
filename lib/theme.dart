import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;

/// ============================================================
/// THEME — colors, text, and light/dark switching
/// ============================================================

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

const String kFontFamily = 'Inter'; // body text
// Titles, big numbers, tab names: Inter Tight (narrower, punchier cut of
// Inter). Use it with `fontFamily: kDisplayFont` on headings only.
const String kDisplayFont = 'InterTight';

// Palette "Graphite" (Nov 2026 redesign): warm graphite instead of pure
// black, iOS blue as the accent, plus a few iOS tile colors for icons in
// lists (like the Settings app). Risk colors (green / amber / red) are
// reserved for flood risk and emergencies; never use them as decoration.
const Color kInk = Color(0xFF1D1D1F); // near-black: light theme text, buttons
const Color kGraphite = Color(0xFF2C2C2E); // neutral fill under photos
const Color kGray = Color(0xFF8E8E93); // iOS system gray: neutral icons
const Color kBlue = Color(0xFF0A84FF); // the accent (iOS system blue)

// Icon tile colors (decorative). Never green, amber, or red: those mean risk.
const Color kTileBlue = kBlue;
const Color kTileIndigo = Color(0xFF5E5CE6);
const Color kTileTeal = Color(0xFF32ADE6);
const Color kTilePurple = Color(0xFFAF52DE);
const Color kTileGray = Color(0xFF8E8E93);

// Status colors (same in both themes)
const Color kSafe = Color(0xFF22C55E);
const Color kCaution = Color(0xFFF59E0B);
const Color kDanger = Color(0xFFEF4444);

// Dark theme (the default): warm graphite, not pure black, so the page
// feels deep instead of empty.
const Color kBgDark = Color(0xFF111113);
const Color kSurfaceDark = Color(0xFF1E1E21); // sheets, menus (opaque)
const Color kTextPrimaryDark = Color(0xFFF5F5F7);
const Color kTextSecondaryDark = Color(0xFF9A9AA1);

// Light theme: warm off-white page with white cards.
const Color kBgLight = Color(0xFFF4F3F0);
const Color kSurfaceLight = Color(0xFFFFFFFF);
const Color kTextPrimaryLight = kInk;
const Color kTextSecondaryLight = Color(0xFF6E6E73);

/// Picks the right color for the current theme, so screens don't have to
/// check dark/light themselves. Usage in a build method:
///   final c = AppColors(context);
///   Text('Hi', style: TextStyle(color: c.textPrimary));
/// Each `get` is a getter: it's used like a variable (c.surface) but runs
/// the `isDark ? darkColor : lightColor` check every time.
class AppColors {
  final BuildContext context;
  AppColors(this.context);

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  Color get background => isDark ? kBgDark : kBgLight;
  Color get surface => isDark ? kSurfaceDark : kSurfaceLight;
  // Wells inside cards (fields, stat rows). See-through, so they work on
  // a glass card, a sheet, or the page alike.
  Color get surfaceAlt => isDark
      ? Colors.white.withValues(alpha: 0.07)
      : Colors.black.withValues(alpha: 0.045);
  Color get textPrimary => isDark ? kTextPrimaryDark : kTextPrimaryLight;
  Color get textSecondary => isDark ? kTextSecondaryDark : kTextSecondaryLight;
  Color get border => isDark
      ? Colors.white.withValues(alpha: 0.09)
      : Colors.black.withValues(alpha: 0.07);
  Color get shadow => Colors.black.withValues(alpha: isDark ? 0.4 : 0.06);
  // Darker blue on white, so small blue text stays readable (4.5:1).
  Color get accent => isDark ? kBlue : const Color(0xFF0066CC);
  // Main buttons: white on black, black on white (like deckai / Apple).
  Color get inverse => isDark ? Colors.white : kInk;
  Color get onInverse => isDark ? Colors.black : Colors.white;
}

/// Flood / alert severity, shared by the map, alerts, and flood outlook.
/// An "enhanced enum": each level carries its own label, color, and icon,
/// so any screen can write `zone.risk.color` instead of repeating
/// "if high then red, if moderate then orange..." everywhere.
enum RiskLevel {
  normal('Normal', kSafe, CupertinoIcons.checkmark_circle_fill),
  moderate('Moderate', kCaution, CupertinoIcons.exclamationmark_circle_fill),
  high('High', kDanger, CupertinoIcons.exclamationmark_triangle_fill);

  final String label;
  final Color color;
  final IconData icon;
  const RiskLevel(this.label, this.color, this.icon);
}

/// Builds the Flutter theme for light or dark mode. One function for both
/// so the two themes can't drift apart; only the colors differ.
/// ColorScheme.fromSeed generates a full matching palette (for buttons,
/// switches, text fields...) from one "seed" color, our sky blue.
ThemeData _baseTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: kBlue,
    brightness: b,
    primary: dark ? kBlue : const Color(0xFF0066CC),
    surface: dark ? kSurfaceDark : kSurfaceLight,
  );
  return ThemeData(
    brightness: b,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? kBgDark : kBgLight,
    useMaterial3: true,
    fontFamily: kFontFamily,
    // iOS has no ripple: a pressed row just dims for a moment. This turns
    // every InkWell / ListTile / TextButton in the app into that.
    splashFactory: NoSplash.splashFactory,
    highlightColor: (dark ? Colors.white : Colors.black).withValues(
      alpha: dark ? 0.08 : 0.05,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? const Color(0xFF2C2C2E) : kInk,
      contentTextStyle: const TextStyle(
        fontFamily: kFontFamily,
        color: Colors.white,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerTheme: DividerThemeData(
      color: dark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.06),
    ),
  );
}

ThemeData buildDarkTheme() => _baseTheme(Brightness.dark);
ThemeData buildLightTheme() => _baseTheme(Brightness.light);
