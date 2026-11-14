import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/demo_data.dart';
import 'supabase_config.dart';

/// ============================================================
/// AUTH — accounts, through Supabase
/// ============================================================
///
/// Supabase Auth checks the email + password (we never see a stored
/// password). Our own data about the person (name, barangay, role) is one
/// row of the `users` table, made by a trigger when they sign up: see
/// supabase/01_users.sql. [me] is that row once someone is logged in.
///
/// Supabase remembers the login in the browser, so a reload stays logged
/// in: [initAuth] picks it up before the app starts.

/// One row of the `users` table (paper, Table 14). Field names match
/// the columns, so the Laravel build can mirror them.
class AppUser {
  final String userId;
  final String fullName;
  final String email;
  final String? phoneNumber;
  final String barangay;
  final String role; // 'registered' or 'admin'
  final String accountStatus; // 'active' or 'suspended'

  const AppUser({
    required this.userId,
    required this.fullName,
    required this.email,
    this.phoneNumber,
    required this.barangay,
    this.role = 'registered',
    this.accountStatus = 'active',
  });

  AppUser.fromRow(Map<String, dynamic> row)
    : userId = row['user_id'] as String,
      fullName = row['full_name'] as String,
      email = row['email'] as String,
      phoneNumber = row['phone_number'] as String?,
      barangay = row['barangay'] as String,
      role = row['role'] as String,
      accountStatus = row['account_status'] as String;

  bool get isAdmin => role == 'admin';

  /// "Juan Dela Cruz" -> "JC", "Tugak" -> "T". For the avatar.
  String get initials {
    final words = fullName.trim().split(RegExp(r'\s+'));
    final first = words.first[0];
    return (words.length == 1 ? first : first + words.last[0]).toUpperCase();
  }
}

/// The logged-in user, or null for a guest.
AppUser? me;

/// Guests can look around but can't vote or report (FR-G10).
bool get isGuest => me == null;

SupabaseClient get _db => Supabase.instance.client;

/// Connects to Supabase and, if this browser is still logged in, loads
/// the user's row. Called once in main(), before the app starts.
Future<void> initAuth() async {
  assert(kSupabaseUrl != '', 'Paste your project into supabase_config.dart');
  await Supabase.initialize(url: kSupabaseUrl, publishableKey: kSupabaseKey);
  if (_db.auth.currentSession == null) return;
  try {
    await _loadMe();
  } catch (_) {
    // Offline, or the account was suspended: start on the login screen.
  }
}

Future<void> logInWithEmail({
  required String email,
  required String password,
}) async {
  await _db.auth.signInWithPassword(email: email, password: password);
  await _loadMe();
}

/// Makes the account. The name and barangay ride along as "metadata",
/// which the database trigger copies into the new `users` row.
Future<void> signUp({
  required String fullName,
  required String email,
  required String password,
  required String barangay,
}) async {
  final res = await _db.auth.signUp(
    email: email,
    password: password,
    data: {'full_name': fullName, 'barangay': barangay},
  );
  // No session = Supabase wants the email confirmed first (the
  // "Confirm email" switch is on in the dashboard).
  if (res.session == null) {
    throw const AuthException(
      'Check your email to confirm your account, then log in.',
      code: 'confirm_email',
    );
  }
  await _loadMe();
}

Future<void> logOut() async {
  await _db.auth.signOut();
  me = null;
  // A different person may use the app next: forget this one's answers.
  myVotes.value = {};
  stillFlooded.value = {};
  myBarangay.value = null;
}

/// Saves "My barangay" to the user's row.
Future<void> saveMyBarangay(String barangay) async {
  await _db
      .from('users')
      .update({'barangay': barangay})
      .eq('user_id', me!.userId);
}

Future<void> _loadMe() async {
  final row = await _db
      .from('users')
      .select()
      .eq('user_id', _db.auth.currentUser!.id)
      .single();
  final user = AppUser.fromRow(row);
  if (user.accountStatus != 'active') {
    await _db.auth.signOut();
    throw const AuthException(
      'This account is suspended. Contact the AgosAlert admin.',
      code: 'account_suspended',
    );
  }
  me = user;
  myBarangay.value = user.barangay;
}
