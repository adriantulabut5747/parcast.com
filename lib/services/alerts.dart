import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show IconData;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme.dart';
import '../widgets/agos_icons.dart';
import 'auth.dart';

/// ============================================================
/// ALERTS — the bell's notifications, through Supabase
/// ============================================================
///
/// Tables + rules: supabase/04_alerts.sql (paper, Tables 19-20). Admins
/// post alerts (SQL Editor / Table Editor for now); everyone reads them.
/// [alerts] updates by itself when one is posted, edited or deleted
/// (Realtime). [readAlerts] = the ids the user has opened: saved in
/// `alert_reads` when logged in, memory only for guests.

enum AlertCategory {
  flood('Flood', AgosIcons.flood),
  weather('Weather', CupertinoIcons.cloud_bolt_rain_fill),
  road('Road', CupertinoIcons.car_fill),
  shelter('Shelter', CupertinoIcons.house_alt_fill);

  final String label;
  final IconData icon;
  const AlertCategory(this.label, this.icon);
}

/// Who posts the app's alerts. The admins aren't confirmed yet (they may
/// be Mabalacat officials later), so nothing claims to be official.
const String kAdminSource = 'Admin (unofficial demo)';

/// One row of `alerts`. Field names follow the columns.
class AppAlert {
  final int alertId;
  final String title;
  final String summary;
  final String details;
  final AlertCategory category;
  final RiskLevel severity;
  final String area; // "Brgy. Dau" or "Mabalacat City"
  final List<String> actions;
  final DateTime createdAt;

  const AppAlert({
    required this.alertId,
    required this.title,
    required this.summary,
    required this.details,
    required this.category,
    required this.severity,
    required this.area,
    this.actions = const [],
    required this.createdAt,
  });

  AppAlert.fromRow(Map<String, dynamic> row)
    : alertId = row['alert_id'] as int,
      title = row['title'] as String,
      summary = row['summary'] as String,
      details = row['details'] as String,
      category = AlertCategory.values.byName(row['category'] as String),
      severity = switch (row['severity']) {
        'high' => RiskLevel.high,
        'moderate' => RiskLevel.moderate,
        _ => RiskLevel.normal,
      },
      area = row['area'] as String,
      actions = [...?(row['actions'] as List?)?.cast<String>()],
      createdAt = DateTime.parse(row['created_at'] as String).toLocal();

  Duration get ago => DateTime.now().difference(createdAt);
  String get source => kAdminSource;
}

/// Every alert, newest first. Tests set it directly.
final ValueNotifier<List<AppAlert>> alerts = ValueNotifier([]);

/// Ids of the alerts the user has opened. Set a NEW set to change it
/// (`{...readAlerts.value, id}`), or listeners (the bell) aren't told.
final ValueNotifier<Set<int>> readAlerts = ValueNotifier({});

/// How many alerts aren't read yet (the number on the bell).
int get unreadAlertCount =>
    alerts.value.where((a) => !readAlerts.value.contains(a.alertId)).length;

SupabaseClient get _db => Supabase.instance.client;

/// Loads the alerts and the user's read-marks, and listens for changes.
/// Called once in main().
void startAlerts() {
  loadAlerts();
  _db
      .channel('alerts')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'alerts',
        callback: (_) => loadAlerts(),
      )
      .subscribe();
  // Read-marks belong to whoever is logged in.
  _db.auth.onAuthStateChange.listen((_) => loadAlerts());
}

Future<void> loadAlerts() async {
  try {
    final rows = await _db
        .from('alerts')
        .select()
        .order('created_at', ascending: false);
    alerts.value = [for (final row in rows) AppAlert.fromRow(row)];
    if (!isGuest) {
      final reads = await _db.from('alert_reads').select('alert_id');
      readAlerts.value = {for (final r in reads) r['alert_id'] as int};
    }
  } catch (_) {
    // Keep what's on screen (empty at first: the bell shows no number).
  }
}

/// Marks [ids] as read: on screen at once, then saved for logged-in users.
/// A failed save only means they show as unread again next launch.
Future<void> markAlertsRead(Iterable<int> ids) async {
  final fresh = ids.where((id) => !readAlerts.value.contains(id)).toList();
  if (fresh.isEmpty) return;
  readAlerts.value = {...readAlerts.value, ...fresh};
  if (isGuest) return;
  try {
    await _db
        .from('alert_reads')
        .upsert(
          [
            for (final id in fresh) {'user_id': me!.userId, 'alert_id': id},
          ],
          onConflict: 'user_id,alert_id',
          ignoreDuplicates: true,
        );
  } catch (_) {}
}
