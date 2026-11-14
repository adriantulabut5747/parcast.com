import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../services/auth.dart';
import '../widgets/common.dart';
import '../widgets/skeleton.dart';
import 'account.dart';
// "deferred as" = compiled into a separate file that's only downloaded the
// first time it's needed. The map package is big, so the Map tab and the
// Report incident screen (which has a map preview and photo picker) stay
// out of the first download. Always open them through this file.
import 'assistance_tab.dart' deferred as assistance;
import 'info_screens.dart' deferred as info;
import 'map_tab.dart' deferred as map_tab;
import 'notifications.dart' deferred as notifications;
import 'report_incident_screen.dart' deferred as report;
import 'reports_tab.dart' deferred as reports;
import 'settings_screen.dart' deferred as settings;

/// The Map tab, downloaded the first time the tab is opened.
///
/// `map_tab.loadLibrary` downloads the split-off file. Until it's done,
/// nothing inside `map_tab.` may be touched, which is why `builder` is a
/// function: DeferredView only calls it after loading finishes. (Also why
/// it's `map_tab.MapTab()` without `const`: Dart doesn't allow const for
/// deferred classes.)
Widget deferredMapTab() => DeferredView(
  load: map_tab.loadLibrary,
  builder: () => map_tab.MapTab(),
  placeholder: const MapSkeleton(),
);

/// Opens the Report incident screen (downloading it the first time).
/// Guests can only view, so they get the "log in" popup instead.
void openReportIncident(BuildContext context) {
  if (isGuest) {
    showLoginRequired(context, action: 'report');
    return;
  }
  Navigator.of(context).push(
    slideRoute(
      DeferredView(
        load: report.loadLibrary,
        builder: () => report.ReportIncidentScreen(),
        placeholder: const FormPageSkeleton(title: 'Report incident'),
      ),
    ),
  );
}

/// Phones: the round + above the bottom nav's right end (Reports and Map,
/// Nov 14 2026, replaced the Reports composer). Opens the report form.
/// Wider screens get a "Report flooding" button instead.
class ReportFab extends StatelessWidget {
  // Small and a deep blue so it doesn't shout over the feed (Adrian, Nov 14 2026).
  final double size;
  const ReportFab({this.size = 46, super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Report flooding',
      excludeSemantics: true,
      child: Tooltip(
        message: 'Report flooding',
        child: PressableScale(
          onTap: () => openReportIncident(context),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: const Color(
                0xFF0B4A9C,
              ), // kBlue darkened, same as the landing's marquee band
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: CustomPaint(
              foregroundPainter: GlassEdgePainter(radius: size / 2, dark: true),
              child: Icon(
                CupertinoIcons.add,
                color: Colors.white,
                size: size * 0.46,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Downloads the other tabs' code (Map, Reports, Help), the bell's
/// notifications and Report incident in the background, so they open
/// instantly later. Errors are ignored: if it fails, they'll
/// simply download when first opened, as before.
///
/// Calling loadLibrary() again later is fine: once a library has been
/// downloaded, it returns immediately.
/// `.then((_) {}, onError: ...)` swallows the error so a failed download
/// isn't reported as a crashhh.
Future<void> preloadDeferredScreens() async {
  await Future.wait([
    map_tab.loadLibrary().then((_) {}, onError: (Object _) {}),
    report.loadLibrary().then((_) {}, onError: (Object _) {}),
    reports.loadLibrary().then((_) {}, onError: (Object _) {}),
    assistance.loadLibrary().then((_) {}, onError: (Object _) {}),
    notifications.loadLibrary().then((_) {}, onError: (Object _) {}),
  ]);
}

// ------------------------------------------------------------
// Every other page is split off the same way, so the first download
// only has what's needed to log in and see Home. Each page downloads
// the first time it's opened (a skeleton shows meanwhile), and after
// that it opens instantly.
// ------------------------------------------------------------

Widget deferredReportsTab() => DeferredView(
  load: reports.loadLibrary,
  builder: () => reports.ReportsTab(),
  placeholder: const ListPageSkeleton(),
);

/// The Help tab (file: assistance_tab.dart).
Widget deferredHelpTab() => DeferredView(
  load: assistance.loadLibrary,
  builder: () => assistance.AssistanceTab(),
  placeholder: const HelpPageSkeleton(),
);

/// The bell: opens the notifications sheet (downloading it the first time;
/// it's small, so there's no skeleton, it just opens a moment later).
Future<void> openNotifications(BuildContext context) async {
  await notifications.loadLibrary();
  if (context.mounted) notifications.showNotifications(context);
}

/// The SOS sheet (hotlines + request rescue), from the + button.
Future<void> openSos(BuildContext context) async {
  await assistance.loadLibrary();
  if (context.mounted) assistance.showSosSheet(context);
}

void openSettings(BuildContext context) => _openPage(
  context,
  load: settings.loadLibrary,
  builder: () => settings.SettingsScreen(),
  title: 'Settings',
);

void openHelp(BuildContext context) => _openPage(
  context,
  load: info.loadLibrary,
  builder: () => info.HelpScreen(),
  title: 'Help & FAQ',
);

void openAbout(BuildContext context) => _openPage(
  context,
  load: info.loadLibrary,
  builder: () => info.AboutScreen(),
  title: 'About',
);

// Opens a split-off page on top of the current one.
void _openPage(
  BuildContext context, {
  required Future<void> Function() load,
  required Widget Function() builder,
  required String title,
}) {
  Navigator.of(context).push(
    slideRoute(
      DeferredView(
        load: load,
        builder: builder,
        placeholder: FormPageSkeleton(title: title),
      ),
    ),
  );
}
