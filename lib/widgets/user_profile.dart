import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;

import '../services/reports.dart';
import '../theme.dart';
import 'common.dart';

/// "Posted by Rafael Dizon · Brgy. Dau": who made a flood report. Tapping
/// the name opens their small profile card ([showUserProfile]).
class PostedBy extends StatelessWidget {
  final Uploader user;
  final String? trailing; // e.g. "5h ago"
  const PostedBy(this.user, {this.trailing, super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    return Semantics(
      button: true,
      label: 'Posted by ${user.name}. Open profile',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => showUserProfile(context, user),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              UserAvatar(user, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      [
                        'Brgy. ${user.barangay} resident',
                        ?trailing,
                      ].join(' · '),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A round avatar with the person's initials, on a color picked from their
/// user id (same person = same color everywhere, like iOS Contacts).
/// Never green / orange / red: those mean flood risk here.
class UserAvatar extends StatelessWidget {
  final Uploader user;
  final double size;
  const UserAvatar(this.user, {this.size = 40, super.key});

  static const _colors = [
    kBlue,
    kTileIndigo,
    kTileTeal,
    kTilePurple,
    Color(0xFFA2845E), // iOS brown
    Color(0xFF64D2FF), // iOS cyan
  ];

  @override
  Widget build(BuildContext context) {
    final color = _colors[user.userId.hashCode.abs() % _colors.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(color, Colors.white, 0.22)!, color],
        ),
      ),
      child: Text(
        user.initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// A small popup with someone's profile card: name, barangay, how many
/// reports they've posted, and the thumbs up/down on them. Same look as
/// the user's own card on the More tab.
Future<void> showUserProfile(BuildContext context, Uploader user) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (dialogContext, _, _) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Material(
            color: Colors.transparent,
            child: _ProfileCard(
              user: user,
              onClose: () => Navigator.of(dialogContext).pop(),
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (_, anim, _, child) => FadeTransition(
      opacity: anim,
      child: ScaleTransition(
        scale: Tween(begin: 0.95, end: 1.0).animate(anim),
        child: child,
      ),
    ),
  );
}

class _ProfileCard extends StatelessWidget {
  final Uploader user;
  final VoidCallback onClose;
  const _ProfileCard({required this.user, required this.onClose});

  @override
  Widget build(BuildContext context) {
    const white80 = Color(0xCCFFFFFF);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [kGraphite, kBgDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedWaves(
                height: 56,
                colors: [Color(0x14FFFFFF), Color(0x1FFFFFFF)],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.2),
                          border: Border.all(color: Colors.white, width: 2.5),
                        ),
                        child: Text(
                          user.initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              user.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              // Paper: reports and votes received.
                              '${user.reports} active ${user.reports == 1 ? 'report' : 'reports'}'
                              '  ·  ${user.upVotes} helpful  ·  ${user.downVotes} not helpful',
                              style: const TextStyle(
                                color: white80,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    CupertinoIcons.placemark_fill,
                                    color: Colors.white,
                                    size: 13,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'Brgy. ${user.barangay} resident',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: onClose,
                        icon: const Icon(
                          CupertinoIcons.xmark,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
