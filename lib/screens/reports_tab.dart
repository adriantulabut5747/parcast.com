import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;

import '../data/demo_data.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/flood_depth.dart';
import '../widgets/my_barangay.dart';
import '../widgets/responsive.dart';
import '../widgets/tugak.dart';
import '../widgets/user_profile.dart';
import '../widgets/vote_bar.dart';
import 'account.dart';
import 'home_shell.dart';

/// ============================================================
/// REPORTS TAB — flood photos people post, newest first
/// ============================================================
/// Each post is one flood pin on the map: who posted it, the photo, the
/// depth, "Still flooded?", the thumbs, and "View on map". Pins disappear
/// 14 days after their photo was taken (kPinLifetime).
class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key});

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

/// Which posts to show. `mine` = only the user's barangay.
enum _Filter { all, mine, high, moderate, low }

class _ReportsTabState extends State<ReportsTab> {
  _Filter _filter = _Filter.all;
  bool _byHelpful = false; // false = newest first

  List<FloodZone> _posts(String? barangay) {
    final list = activeFloodZones.where((z) {
      return switch (_filter) {
        _Filter.all => true,
        _Filter.mine => z.barangay == barangay,
        _Filter.high => z.risk == RiskLevel.high,
        _Filter.moderate => z.risk == RiskLevel.moderate,
        _Filter.low => z.risk == RiskLevel.normal,
      };
    }).toList();
    list.sort(
      (a, b) => _byHelpful
          ? (b.upVotes - b.downVotes).compareTo(a.upVotes - a.downVotes)
          : a.photoAge.compareTo(b.photoAge),
    );
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    final desktop = screenSizeOf(context) == ScreenSize.desktop;
    return ValueListenableBuilder<String?>(
      valueListenable: myBarangay,
      builder: (context, barangay, _) {
        // "My barangay" was picked, then cleared: fall back to All.
        if (_filter == _Filter.mine && barangay == null) _filter = _Filter.all;
        final posts = _posts(barangay);
        return ListView(
          padding: pagePadding(context),
          children: [
            PageHeader(
              'Reports',
              subtitle: 'Flood photos from people in Mabalacat',
              // The + (report, I'm safe, SOS) moved here from the nav.
              trailing: const Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                spacing: 12,
                children: [
                  Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: SampleBadge(),
                  ),
                  NewActionsButton(),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _chips(barangay),
            const SizedBox(height: 10),
            _sortRow(c, posts.length),
            const SizedBox(height: 12),
            if (posts.isEmpty)
              _empty(c, barangay)
            else if (desktop)
              // Three posts per row, each row as tall as its tallest post.
              Column(
                spacing: 16,
                children: [
                  for (var i = 0; i < posts.length; i += 3)
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 16,
                        children: [
                          for (var j = i; j < i + 3; j++)
                            Expanded(
                              child: j < posts.length
                                  ? ReportPost(zone: posts[j], fill: true)
                                  : const SizedBox.shrink(),
                            ),
                        ],
                      ),
                    ),
                ],
              )
            else
              for (var i = 0; i < posts.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: FadeSlideIn(
                    delay: Duration(milliseconds: 40 * i),
                    child: ReportPost(zone: posts[i]),
                  ),
                ),
          ],
        );
      },
    );
  }

  Widget _chips(String? barangay) {
    Widget chip(_Filter f, String label, {IconData? icon, Color? color}) =>
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: SelectChip(
            label: label,
            icon: icon,
            color: color,
            selected: _filter == f,
            onTap: () => setState(() => _filter = f),
          ),
        );
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        children: [
          chip(_Filter.all, 'All'),
          if (barangay != null)
            chip(
              _Filter.mine,
              'Brgy. $barangay',
              icon: CupertinoIcons.placemark_fill,
            )
          else
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Center(child: MyBarangayChip()),
            ),
          chip(_Filter.high, 'High', color: kDanger),
          chip(_Filter.moderate, 'Moderate', color: kCaution),
          chip(_Filter.low, 'Low', color: kSafe),
        ],
      ),
    );
  }

  Widget _sortRow(AppColors c, int count) {
    Widget option(String label, bool helpful) {
      final on = _byHelpful == helpful;
      return Semantics(
        button: true,
        selected: on,
        child: PressableScale(
          onTap: () => setState(() => _byHelpful = helpful),
          child: Text(
            label,
            style: TextStyle(
              color: on ? c.textPrimary : c.textSecondary,
              fontSize: 12.5,
              fontWeight: on ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: Text(
            '$count ${count == 1 ? 'report' : 'reports'}',
            style: TextStyle(color: c.textSecondary, fontSize: 12.5),
          ),
        ),
        option('Newest', false),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('·', style: TextStyle(color: c.textSecondary)),
        ),
        option('Most helpful', true),
      ],
    );
  }

  Widget _empty(AppColors c, String? barangay) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const TugakImage(size: 120),
          const SizedBox(height: 12),
          Text(
            _filter == _Filter.mine
                ? 'Nothing reported in Brgy. $barangay'
                : 'No reports here',
            style: TextStyle(
              fontFamily: kDisplayFont,
              color: c.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Dry streets, or nobody has posted yet. See water? Tap + to report it.',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// One report as a post. [fill] (desktop grid): pushes the buttons to the
/// bottom so posts in a row line up.
class ReportPost extends StatelessWidget {
  final FloodZone zone;
  final bool fill;
  const ReportPost({required this.zone, this.fill = false, super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    final z = zone;
    final level = FloodLevel.of(z.depthCm);
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: PostedBy(z.uploader, trailing: timeAgo(z.photoAge)),
          ),
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: kGraphite),
                Image.asset(
                  z.photo,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
                // Depth badge, top left: the first thing people need.
                Positioned(
                  left: 10,
                  top: 10,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: z.risk.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          level == FloodLevel.dry ? 'Dry' : formatCm(z.depthCm),
                          style: const TextStyle(
                            fontFamily: kDisplayFont,
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  bottom: 8,
                  right: 8,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Text(
                        kFloodPhotoCredit,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Brgy. ${z.barangay} · ${level.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: kDisplayFont,
                    color: c.textPrimary,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  z.note,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 13.5,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 10),
                StillFloodedRow(zone: z),
              ],
            ),
          ),
          if (fill) const Spacer(),
          const SizedBox(height: 6),
          Divider(height: 1, color: c.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
            child: Row(
              children: [
                VoteBar(zone: z, showQuestion: false),
                const SizedBox(width: 8),
                // Takes the rest of the row; on narrow posts the label
                // shortens with "…" instead of overflowing.
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        HomeShell.of(context)?.switchTab(1);
                        focusedZone.value = z;
                      },
                      icon: const Icon(CupertinoIcons.map, size: 18),
                      label: const Text(
                        'View on map',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: c.accent,
                        textStyle: const TextStyle(
                          fontFamily: kFontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Still flooded?" Yes / No, like Waze's "Still there?". Keeps old
/// photos honest. Saves only the user's own answer ([stillFlooded]).
class StillFloodedRow extends StatelessWidget {
  final FloodZone zone;
  const StillFloodedRow({required this.zone, super.key});

  void _answer(BuildContext context, bool? value) {
    if (isGuest) {
      showLoginRequired(context, action: 'answer');
      return;
    }
    final answers = {...stillFlooded.value};
    if (value == null) {
      answers.remove(zone.barangay);
    } else {
      answers[zone.barangay] = value;
    }
    stillFlooded.value = answers;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    return ValueListenableBuilder<Map<String, bool>>(
      valueListenable: stillFlooded,
      builder: (context, answers, _) {
        final mine = answers[zone.barangay];
        if (mine != null) {
          return Row(
            children: [
              Icon(
                CupertinoIcons.checkmark_circle_fill,
                size: 15,
                color: c.accent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  mine
                      ? 'You said it\'s still flooded. Thanks.'
                      : 'You said the water\'s gone. Thanks.',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              PressableScale(
                onTap: () => _answer(context, null),
                child: Text(
                  'Undo',
                  style: TextStyle(
                    color: c.accent,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          );
        }
        Widget pill(String label, bool value) => PressableScale(
          onTap: () => _answer(context, value),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: c.border),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
        return Row(
          children: [
            Expanded(
              child: Text(
                'Still flooded?',
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            pill('Yes', true),
            const SizedBox(width: 6),
            pill('No', false),
          ],
        );
      },
    );
  }
}
