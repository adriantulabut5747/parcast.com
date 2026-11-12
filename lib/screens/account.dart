import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../services/session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'home_shell.dart';

/// ============================================================
/// ACCOUNT — logging in and out
/// ============================================================
///
/// The app has no login screen of its own: logging in happens on the
/// landing page (`landing/index.html`), which opens the app as a user or
/// a guest (see services/session.dart). So on the website, "Log in" and
/// "Log out" both go back to the landing page.
///
/// An installed phone app has no landing page to go to, so there they
/// just restart the app as a user or a guest. Fine for a demo; a real
/// app would get its own login screen once there's a backend.

/// Goes to the landing page with its login popup open.
void logIn(BuildContext context) {
  if (kIsWeb) {
    goToLanding(openLogin: true);
    return;
  }
  _restartAs(context, guest: false);
}

void _restartAs(BuildContext context, {required bool guest}) {
  isGuest = guest;
  // A different person may be using the app now: forget the votes.
  myVotes.value = {};
  // pushAndRemoveUntil(..., (_) => false) removes every screen behind the
  // new one, so the back button can't return to the old session.
  Navigator.of(context)
      .pushAndRemoveUntil(slideRoute(const HomeShell()), (_) => false);
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
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Guests can only view. Log in or sign up to join in '
                      'and help your community.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 20),
                    PrimaryButton(
                      label: 'Log in',
                      icon: CupertinoIcons.arrow_right,
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        logIn(context);
                      },
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text(
                        'Not now',
                        style: TextStyle(color: c.textSecondary),
                      ),
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

/// Asks "Log out?" and, if confirmed, goes back to the landing page.
/// Used by the More tab and by the profile menu in the desktop top bar.
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
            'You\'ll stop getting alerts on this device.',
            style: TextStyle(color: c.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Log out',
            color: kDanger,
            onPressed: () {
              if (kIsWeb) {
                goToLanding();
              } else {
                _restartAs(context, guest: true);
              }
            },
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => Navigator.of(sheet).pop(),
            child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
          ),
        ],
      );
    },
  );
}
