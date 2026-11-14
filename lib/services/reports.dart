import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show IconData;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/demo_data.dart' show timeAgo, Vote, myVotes;
import '../theme.dart';
import '../widgets/agos_icons.dart';
import '../widgets/flood_depth.dart' show riskForDepth;
import 'auth.dart';

/// ============================================================
/// REPORTS — flood reports, through Supabase
/// ============================================================
///
/// Table + rules: supabase/02_flood_reports.sql. The app reads the
/// `flood_report_feed` view (active reports + the poster's name), posts
/// into `flood_reports`, and keeps photos in the `report-photos` bucket.
/// [floodReports] is the list every screen shows (map, Reports, Weather);
/// it updates by itself when anyone posts or deletes (Supabase Realtime).

/// One row of `flood_report_feed` (paper, Table 15, plus the poster's
/// name). Field names match the columns, so the Laravel build can mirror
/// them.
class FloodReport {
  final int reportId;
  final String userId;
  final String incidentType; // 'flooding', 'blocked road', ...
  final String severity; // 'minor', 'moderate', 'high' (the reporter's pick)
  final int? depthCm; // null for types without water (landslide...)
  final String barangay;
  final double latitude;
  final double longitude;
  final String note;
  final String? photoUrl;
  final DateTime photoTakenAt;
  final DateTime expiresAt;
  final String status; // 'unverified' or 'verified'
  final DateTime createdAt;
  final String posterName;
  final String posterBarangay;
  // Counted by the database (03_report_votes.sql), including [myVote].
  final int upVotes;
  final int downVotes;
  // This user's vote as the database last saw it; null = none or guest.
  final Vote? myVote;

  const FloodReport({
    required this.reportId,
    required this.userId,
    required this.incidentType,
    required this.severity,
    this.depthCm,
    required this.barangay,
    required this.latitude,
    required this.longitude,
    this.note = '',
    this.photoUrl,
    required this.photoTakenAt,
    required this.expiresAt,
    this.status = 'unverified',
    required this.createdAt,
    required this.posterName,
    required this.posterBarangay,
    this.upVotes = 0,
    this.downVotes = 0,
    this.myVote,
  });

  FloodReport.fromRow(Map<String, dynamic> row)
    : reportId = row['report_id'] as int,
      userId = row['user_id'] as String,
      incidentType = row['incident_type'] as String,
      severity = row['severity'] as String,
      depthCm = row['depth_cm'] as int?,
      barangay = row['barangay'] as String,
      latitude = (row['latitude'] as num).toDouble(),
      longitude = (row['longitude'] as num).toDouble(),
      note = row['note'] as String? ?? '',
      photoUrl = row['photo_url'] as String?,
      photoTakenAt = DateTime.parse(row['photo_taken_at'] as String).toLocal(),
      expiresAt = DateTime.parse(row['expires_at'] as String).toLocal(),
      status = row['status'] as String,
      createdAt = DateTime.parse(row['created_at'] as String).toLocal(),
      posterName = row['poster_name'] as String,
      posterBarangay = row['poster_barangay'] as String,
      // `?? 0`: still loads before 03_report_votes.sql has been run.
      upVotes = (row['up_votes'] as num? ?? 0).toInt(),
      downVotes = (row['down_votes'] as num? ?? 0).toInt(),
      myVote = switch (row['my_vote']) {
        1 => Vote.up,
        -1 => Vote.down,
        _ => null,
      };

  LatLng get point => LatLng(latitude, longitude);

  /// Has a water depth (flooding, blocked road, stranded people).
  bool get hasDepth => depthCm != null;

  /// The depth as a number for the gauges; 0 when there's none.
  double get depth => (depthCm ?? 0).toDouble();

  /// FR-S2: the risk comes from the depth; without one, from the
  /// reporter's own severity.
  RiskLevel get risk =>
      hasDepth ? riskForDepth(depth) : riskFromSeverity(severity);

  /// "Blocked road" (for titles).
  String get typeLabel =>
      incidentType[0].toUpperCase() + incidentType.substring(1);

  /// Its type's icon (map pin, post header).
  IconData get typeIcon => incidentIcon(incidentType);

  /// Key for this report in [myVotes] / [stillFlooded].
  String get key => '$reportId';

  Duration get photoAge => DateTime.now().difference(photoTakenAt);
  Duration get timeLeft => expiresAt.difference(DateTime.now());
  bool get expired => timeLeft <= Duration.zero;
  bool get mine => me?.userId == userId;

  /// "12m ago": when it was posted.
  String get updated => timeAgo(DateTime.now().difference(createdAt));

  Uploader get uploader => Uploader(userId, posterName, posterBarangay);
}

/// Who posted a report (the name opens their profile card).
class Uploader {
  final String userId;
  final String name;
  final String barangay;
  const Uploader(this.userId, this.name, this.barangay);

  Iterable<FloodReport> get _mine =>
      floodReports.value.where((r) => r.userId == userId);

  /// How many of the reports on screen are theirs.
  int get reports => _mine.length;

  /// Thumbs up / down other people gave their active reports.
  int get upVotes => _mine.fold(0, (n, r) => n + r.upVotes);
  int get downVotes => _mine.fold(0, (n, r) => n + r.downVotes);

  /// "Rafael Dizon" -> "RD".
  String get initials => name
      .split(' ')
      .where((w) => w.isNotEmpty)
      .take(2)
      .map((w) => w[0])
      .join()
      .toUpperCase();
}

/// What can be reported: (icon, label). The label, lowercased, is what
/// `incident_type` holds. One list for the form, the pins and the posts.
const kIncidentTypes = [
  (AgosIcons.flood, 'Flooding'),
  (AgosIcons.roadBlock, 'Blocked road'),
  (AgosIcons.landslide, 'Landslide'),
  (CupertinoIcons.bolt_fill, 'Fallen power line'),
  (CupertinoIcons.person_3_fill, 'Stranded people'),
  (CupertinoIcons.ellipsis, 'Other'),
];

IconData incidentIcon(String type) => kIncidentTypes
    .firstWhere(
      (t) => t.$2.toLowerCase() == type.toLowerCase(),
      orElse: () => kIncidentTypes.last,
    )
    .$1;

RiskLevel riskFromSeverity(String s) => switch (s) {
  'high' => RiskLevel.high,
  'moderate' => RiskLevel.moderate,
  _ => RiskLevel.normal,
};

String severityFromRisk(RiskLevel r) => switch (r) {
  RiskLevel.high => 'high',
  RiskLevel.moderate => 'moderate',
  RiskLevel.normal => 'minor',
};

enum LoadState { loading, ready, failed }

/// Every active report, newest first. Tests set it directly.
final ValueNotifier<List<FloodReport>> floodReports = ValueNotifier([]);

/// Whether [floodReports] has loaded yet, or failed to.
final ValueNotifier<LoadState> reportsState = ValueNotifier(LoadState.loading);

/// Reports whose 14 days aren't up (the server deletes the rest hourly).
Iterable<FloodReport> get activeFloodReports =>
    floodReports.value.where((r) => !r.expired);

SupabaseClient get _db => Supabase.instance.client;

/// Loads the reports and listens for changes. Called once in main().
void startReports() {
  loadReports();
  _db
      .channel('flood_reports')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'flood_reports',
        callback: (_) => loadReports(),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'report_votes',
        callback: (_) => loadReports(),
      )
      .subscribe();
  // my_vote depends on who's logged in: reload on log in / log out.
  _db.auth.onAuthStateChange.listen((_) => loadReports());
}

Future<void> loadReports() async {
  try {
    final rows = await _db
        .from('flood_report_feed')
        .select()
        .order('created_at', ascending: false);
    final reports = [for (final row in rows) FloodReport.fromRow(row)];
    floodReports.value = reports;
    myVotes.value = {
      for (final r in reports)
        if (r.myVote != null) r.key: r.myVote!,
    };
    reportsState.value = LoadState.ready;
  } catch (_) {
    // Keep what's on screen; only say "failed" if nothing ever loaded.
    if (reportsState.value != LoadState.ready) {
      reportsState.value = LoadState.failed;
    }
  }
}

/// Saves the user's vote on [r]: [old] = their vote before the tap,
/// [vote] = after (null = taken back). A variable so tests can swap it
/// (no Supabase in tests).
Future<void> Function(FloodReport r, Vote? old, Vote? vote) saveVote =
    _saveVote;

Future<void> _saveVote(FloodReport r, Vote? old, Vote? vote) async {
  final table = _db.from('report_votes');
  final value = vote == Vote.up ? 1 : -1;
  if (vote == null) {
    await table.delete().eq('report_id', r.reportId).eq('user_id', me!.userId);
  } else if (old == null) {
    await table.insert({
      'report_id': r.reportId,
      'user_id': me!.userId,
      'vote': value,
    });
  } else {
    await table
        .update({'vote': value})
        .eq('report_id', r.reportId)
        .eq('user_id', me!.userId);
  }
}

const _bucket = 'report-photos';

/// Posts a report (use case "Submit Flood Report"). Uploads the photo
/// first, then saves the row; if saving fails, the photo is removed again.
/// Throws on failure, so the form can say so and keep what was typed.
Future<void> submitReport({
  required String incidentType,
  required String severity,
  required int? depthCm,
  required String barangay,
  required LatLng point,
  required String note,
  required Uint8List? photo,
  required DateTime photoTakenAt,
}) async {
  String? path;
  String? url;
  if (photo != null) {
    path = '${me!.userId}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _db.storage
        .from(_bucket)
        .uploadBinary(
          path,
          photo,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    url = _db.storage.from(_bucket).getPublicUrl(path);
  }
  try {
    await _db.from('flood_reports').insert({
      'incident_type': incidentType,
      'severity': severity,
      'depth_cm': depthCm,
      'barangay': barangay,
      'latitude': double.parse(point.latitude.toStringAsFixed(6)),
      'longitude': double.parse(point.longitude.toStringAsFixed(6)),
      'note': note.trim().isEmpty ? null : note.trim(),
      'photo_url': url,
      'photo_taken_at': photoTakenAt.toUtc().toIso8601String(),
    });
  } catch (_) {
    if (path != null) {
      await _db.storage
          .from(_bucket)
          .remove([path])
          .catchError((_) => <FileObject>[]);
    }
    rethrow;
  }
  await loadReports();
}

/// Deletes one of the user's own reports and its photo.
Future<void> deleteReport(FloodReport r) async {
  await _db.from('flood_reports').delete().eq('report_id', r.reportId);
  final url = r.photoUrl;
  if (url != null && url.contains('/$_bucket/')) {
    await _db.storage
        .from(_bucket)
        .remove([url.split('/$_bucket/').last])
        .catchError((_) => <FileObject>[]);
  }
  await loadReports();
}

/// What to show when posting fails.
String reportErrorMessage(Object e) {
  if ('$e'.contains('more than 14 days old')) {
    return 'This photo is more than 14 days old. Take a new one.';
  }
  if (e is StorageException) {
    return 'The photo didn\'t upload (${e.message}). Try again.';
  }
  if (e is PostgrestException) {
    return 'The report wasn\'t saved (${e.message}). Try again.';
  }
  return 'Couldn\'t reach the server. Check your connection and try again.';
}

/// Set by "View on map" (Reports, Weather): the Map tab opens this
/// report, then sets it back to null.
final ValueNotifier<FloodReport?> focusedReport = ValueNotifier(null);
