import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../services/auth.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'login_screen.dart';

/// ============================================================
/// ACCOUNT — logging in and out
/// ============================================================
///
/// The login screen itself is screens/login_screen.dart; the Supabase
/// calls are in services/auth.dart.

/// Opens the login screen on top of the guest's app ("Continue as
/// guest" there comes back here).
void logIn(BuildContext context) {
  Navigator.of(context).push(slideRoute(const LoginScreen()));
}

/// Popup for guests who tap something only logged-in users can do, like
/// voting. [action] finishes the title, e.g. 'vote' -> "Log in to vote".
Future<void> showLoginRequired(BuildContext context, {required String action}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (dialogContext, _, _) {
      final c = AppColors(dialogContext);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          // At most 420 wide, so it stays a small card on desktops.
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Material(
              color: c.surface,
              borderRadius: BorderRadius.circular(28),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const IconBadge(CupertinoIcons.lock_fill, kBlue, size: 60),
                    const SizedBox(height: 14),
                    Text(
                      'Log in to $action',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Guests can only look around. A free account lets '
                      'you report floods and vote on reports.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 20),
                    PrimaryButton(
                      label: 'Log in or sign up',
                      icon: CupertinoIcons.arrow_right,
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        logIn(context);
                      },
                    ),
                    const SizedBox(height: 4),
                    SecondaryButton(
                      label: 'Not now',
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (_, anim, _, child) => FadeTransition(
      opacity: anim,
      child: ScaleTransition(
        scale: Tween(begin: 0.95, end: 1.0).animate(anim),
        child: child,
      ),
    ),
  );
}

/// Asks "Log out?" and, if confirmed, signs out and shows the login
/// screen. Used by the profile menu.
void confirmLogout(BuildContext context) {
  showAppSheet(
    context,
    builder: (sheet) {
      final c = AppColors(sheet);
      return Column(
        children: [
          const IconBadge(CupertinoIcons.square_arrow_right, kDanger, size: 60),
          const SizedBox(height: 14),
          Text(
            'Log out?',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'You\'ll go back to the login screen.',
            style: TextStyle(color: c.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Log out',
            color: kDanger,
            onPressed: () async {
              final nav = Navigator.of(context);
              await logOut();
              // Removes every screen behind it, so Back can't return to
              // the logged-in app.
              nav.pushAndRemoveUntil(
                slideRoute(const LoginScreen()),
                (_) => false,
              );
            },
          ),
          const SizedBox(height: 6),
          SecondaryButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(sheet).pop(),
          ),
        ],
      );
    },
  );
}
