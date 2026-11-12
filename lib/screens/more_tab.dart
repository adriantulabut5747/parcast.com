import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;

import '../data/demo_data.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'evacuation_centers_screen.dart';
import 'home_shell.dart';
import 'info_screens.dart';
import 'account.dart';
import 'settings_screen.dart';

/// ============================================================
/// MORE TAB — profile, shortcuts, settings, help, log out
/// ============================================================
class MoreTab extends StatelessWidget {
  const MoreTab({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    void push(Widget page) => Navigator.of(context).push(slideRoute(page));
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        const PageHeader('More'),
        const SizedBox(height: 16),
        FadeSlideIn(child: _profileCard(c)),
        const SizedBox(height: 24),
        FadeSlideIn(
          delay: const Duration(milliseconds: 80),
          child: _group(c, 'Safety', [
            _Item(
              CupertinoIcons.map_fill,
              'Flood map',
              kGray,
              () => HomeShell.of(context)?.switchTab(1),
            ),
            _Item(
              CupertinoIcons.house_alt_fill,
              'Evacuation centers',
              kGray,
              () => push(const EvacuationCentersScreen()),
            ),
            _Item(
              CupertinoIcons.phone_fill,
              'Emergency hotlines',
              kDanger,
              () => HomeShell.of(context)?.switchTab(3),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        FadeSlideIn(
          delay: const Duration(milliseconds: 140),
          child: _group(c, 'App', [
            _Item(
              CupertinoIcons.slider_horizontal_3,
              'Settings',
              kGray,
              () => push(const SettingsScreen()),
            ),
            _Item(
              CupertinoIcons.question_circle_fill,
              'Help & FAQ',
              kGray,
              () => push(const HelpScreen()),
            ),
            _Item(
              CupertinoIcons.info_circle_fill,
              'About AgosAlert',
              kGray,
              () => push(const AboutScreen()),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        FadeSlideIn(
          delay: const Duration(milliseconds: 200),
          child: _group(c, null, [
            _Item(
              CupertinoIcons.square_arrow_right,
              'Log out',
              kDanger,
              () => confirmLogout(context),
              destructive: true,
            ),
          ]),
        ),
        const SizedBox(height: 28),
        Center(
          child: Column(
            children: [
              Opacity(
                opacity: 0.8,
                child: const BrandLogo.wordmark(height: 26),
              ),
              const SizedBox(height: 6),
              Text(
                'Version 1.0.0 · Made in Mabalacat City',
                style: TextStyle(color: c.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _profileCard(AppColors c) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [kGraphite, Color(0xFF111113)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedWaves(
                height: 60,
                colors: [Color(0x14FFFFFF), Color(0x1FFFFFFF)],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.2),
                          border: Border.all(color: Colors.white, width: 2.5),
                        ),
                        alignment: Alignment.center,
                        child: isGuest
                            ? const Icon(
                                CupertinoIcons.person_fill,
                                color: Colors.white,
                                size: 32,
                              )
                            : const Text(
                                kDemoUserInitials,
                                style: TextStyle(
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
                            Text(
                              isGuest ? 'Guest' : kDemoUserName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              isGuest
                                  ? 'Log in to vote and upload'
                                  : kDemoUserEmail,
                              style: const TextStyle(
                                color: Color(0xD9FFFFFF),
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(height: 10),
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
                                  Icon(
                                    isGuest
                                        ? CupertinoIcons.eye_fill
                                        : CupertinoIcons.placemark_fill,
                                    color: Colors.white,
                                    size: 13,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      isGuest
                                          ? 'Guest mode · view only'
                                          : 'Mabalacat City resident',
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
                    ],
                  ),
                  if (!isGuest) ...[const SizedBox(height: 18), _voteStats()],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Thumbs up/down other people gave on this user's uploads.
  Widget _voteStats() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Votes on your uploads',
                  style: TextStyle(
                    color: Color(0xD9FFFFFF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                'SAMPLE',
                style: TextStyle(
                  color: Color(0xB3FFFFFF),
                  fontSize: 8.5,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _voteStat(
                CupertinoIcons.hand_thumbsup_fill,
                kMyUpVotesReceived,
                'Thumbs up',
              ),
              _voteStat(
                CupertinoIcons.hand_thumbsdown_fill,
                kMyDownVotesReceived,
                'Thumbs down',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _voteStat(IconData icon, int count, String label) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xD9FFFFFF),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _group(AppColors c, String? title, List<_Item> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) FieldLabel(title),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) Divider(height: 1, indent: 64, color: c.border),
                _row(c, items[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(AppColors c, _Item item) {
    return InkWell(
      onTap: item.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            IconBadge(item.icon, item.color, size: 36, squircle: true),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(
                  color: item.destructive ? kDanger : c.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (!item.destructive)
              Icon(CupertinoIcons.chevron_right, color: c.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _Item {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool destructive;
  const _Item(
    this.icon,
    this.label,
    this.color,
    this.onTap, {
    this.destructive = false,
  });
}
