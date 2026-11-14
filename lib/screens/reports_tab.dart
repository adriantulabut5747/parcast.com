import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'
    show CupertinoIcons, CupertinoActivityIndicator;

import '../data/demo_data.dart';
import '../services/auth.dart';
import '../services/reports.dart';
import '../theme.dart';
import '../widgets/agos_icons.dart';
import '../widgets/common.dart';
import '../widgets/flood_depth.dart';
import '../widgets/my_barangay.dart';
import '../widgets/responsive.dart';
import '../widgets/tugak.dart';
import '../widgets/user_profile.dart';
import '../widgets/vote_bar.dart';
import 'account.dart';
import 'deferred_screens.dart';
import 'home_shell.dart';

/// ============================================================
/// REPORTS TAB — a feed of what people saw, like Facebook posts
/// ============================================================
/// Top to bottom: Tugak's chat bubbles (Nov 14 2026, replaced the
/// "See flooding? Report it" composer: Adrian disliked it; on tablets and
/// desktops a "Report flooding" button sits under them, phones get the
/// round + above the bottom nav, see ReportFab), a search field with a
/// Filter button (the filters stay hidden until it's tapped), then the
/// posts. Pins disappear 14 days
/// after their photo was taken (kPinLifetime).
class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key});

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

/// Search: the poster's name, the note, the barangay and the type.
bool reportMatches(FloodReport z, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return [
    z.posterName,
    z.note,
    z.barangay,
    z.typeLabel,
  ].any((t) => t.toLowerCase().contains(q));
}

enum _Sort { newest, helpful, deepest }

class _ReportsTabState extends State<ReportsTab> {
  final _search = TextEditingController();
  String _query = '';
  bool _showFilters = false;
  RiskLevel? _risk; // null = any
  String? _type; // a kIncidentTypes label; null = any
  bool _mineOnly = false; // only the user's barangay
  bool _verifiedOnly = false;
  _Sort _sort = _Sort.newest;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  int get _activeFilters =>
      (_risk != null ? 1 : 0) +
      (_type != null ? 1 : 0) +
      (_mineOnly ? 1 : 0) +
      (_verifiedOnly ? 1 : 0) +
      (_sort != _Sort.newest ? 1 : 0);

  void _clear() => setState(() {
    _risk = null;
    _type = null;
    _mineOnly = false;
    _verifiedOnly = false;
    _sort = _Sort.newest;
    _search.clear();
    _query = '';
  });

  List<FloodReport> _posts(String? barangay) {
    final list = activeFloodReports.where((z) {
      return reportMatches(z, _query) &&
          (_risk == null || z.risk == _risk) &&
          (_type == null || z.incidentType == _type!.toLowerCase()) &&
          (!_mineOnly || z.barangay == barangay) &&
          (!_verifiedOnly || z.status == 'verified');
    }).toList();
    switch (_sort) {
      case _Sort.newest:
        list.sort((a, b) => a.photoAge.compareTo(b.photoAge));
      case _Sort.helpful:
        list.sort(
          (a, b) =>
              (b.upVotes - b.downVotes).compareTo(a.upVotes - a.downVotes),
        );
      case _Sort.deepest:
        list.sort((a, b) => b.depth.compareTo(a.depth));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    return ListenableBuilder(
      listenable: Listenable.merge([myBarangay, floodReports, reportsState]),
      builder: (context, _) {
        final barangay = myBarangay.value;
        final state = reportsState.value;
        if (barangay == null) _mineOnly = false;
        final posts = _posts(barangay);
        final phone = screenSizeOf(context) == ScreenSize.phone;
        final pad = pagePadding(context);
        // One feed column, like Facebook, centered on wide screens. Phones:
        // extra room at the end so the + button never covers the last post.
        return ListView(
          padding: phone ? pad.copyWith(bottom: pad.bottom + 64) : pad,
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const PageHeader(
                      'Reports',
                      subtitle: 'What people in Mabalacat are seeing',
                    ),
                    const SizedBox(height: 16),
                    TugakBeside(
                      pose: 'phone',
                      size: phone ? 96 : 128,
                      line: "See water on a street? Post one photo and pin the spot. That's all I need.",
                      footer: phone
                          ? null
                          : SizedBox(
                              width: 210,
                              child: PrimaryButton(
                                label: 'Report flooding',
                                icon: CupertinoIcons.plus,
                                onPressed: () => openReportIncident(context),
                              ),
                            ),
                    ),
                    const SizedBox(height: 20),
                    _searchRow(c),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 280),
                      curve: kSnappyCurve,
                      alignment: Alignment.topCenter,
                      child: _showFilters
                          ? _filters(c, barangay)
                          : const SizedBox(width: double.infinity),
                    ),
                    const SizedBox(height: 12),
                    _countRow(c, posts.length),
                    const SizedBox(height: 10),
                    if (state == LoadState.loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: Center(child: CupertinoActivityIndicator()),
                      )
                    else if (state == LoadState.failed)
                      _failed(c)
                    else if (posts.isEmpty)
                      _empty(c)
                    else
                      for (var i = 0; i < posts.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: FadeSlideIn(
                            key: ValueKey(posts[i].reportId),
                            delay: Duration(milliseconds: 40 * math.min(i, 6)),
                            child: ReportPost(zone: posts[i]),
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _searchRow(AppColors c) {
    final n = _activeFilters;
    return Row(
      children: [
        Expanded(
          child: AppTextField(
            controller: _search,
            hint: 'Search names, notes, barangays',
            icon: CupertinoIcons.search,
            textInputAction: TextInputAction.search,
            onChanged: (v) => setState(() => _query = v),
            suffix: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: Icon(
                      CupertinoIcons.xmark_circle_fill,
                      color: c.textSecondary,
                      size: 18,
                    ),
                    onPressed: () => setState(() {
                      _search.clear();
                      _query = '';
                    }),
                  ),
          ),
        ),
        const SizedBox(width: 8),
        Semantics(
          button: true,
          toggled: _showFilters,
          label: 'Filters${n > 0 ? ', $n on' : ''}',
          excludeSemantics: true,
          child: PressableScale(
            onTap: () => setState(() => _showFilters = !_showFilters),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: _showFilters || n > 0
                    ? c.accent.withValues(alpha: 0.16)
                    : c.surfaceAlt,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.slider_horizontal_3,
                    size: 18,
                    color: _showFilters || n > 0 ? c.accent : c.textPrimary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    n > 0 ? 'Filter · $n' : 'Filter',
                    style: TextStyle(
                      color: _showFilters || n > 0 ? c.accent : c.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _filters(AppColors c, String? barangay) {
    Widget group(String label, List<Widget> chips) => Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel(label),
          Wrap(spacing: 8, runSpacing: 8, children: chips),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        group('Sort by', [
          for (final (s, label) in [
            (_Sort.newest, 'Newest'),
            (_Sort.helpful, 'Most helpful'),
            (_Sort.deepest, 'Deepest'),
          ])
            SelectChip(
              label: label,
              selected: _sort == s,
              onTap: () => setState(() => _sort = s),
            ),
        ]),
        group('Risk', [
          SelectChip(
            label: 'Any',
            selected: _risk == null,
            onTap: () => setState(() => _risk = null),
          ),
          for (final (r, label) in [
            (RiskLevel.high, 'High'),
            (RiskLevel.moderate, 'Moderate'),
            (RiskLevel.normal, 'Low'),
          ])
            SelectChip(
              label: label,
              color: r.color,
              selected: _risk == r,
              onTap: () => setState(() => _risk = _risk == r ? null : r),
            ),
        ]),
        group('What happened', [
          SelectChip(
            label: 'Anything',
            selected: _type == null,
            onTap: () => setState(() => _type = null),
          ),
          for (final (icon, label) in kIncidentTypes)
            SelectChip(
              label: label,
              icon: icon,
              selected: _type == label,
              onTap: () =>
                  setState(() => _type = _type == label ? null : label),
            ),
        ]),
        group('Show only', [
          if (barangay != null)
            SelectChip(
              label: 'Brgy. $barangay',
              icon: CupertinoIcons.placemark_fill,
              selected: _mineOnly,
              onTap: () => setState(() => _mineOnly = !_mineOnly),
            )
          else
            const MyBarangayChip(),
          SelectChip(
            label: 'Verified by Admin',
            icon: CupertinoIcons.checkmark_seal_fill,
            selected: _verifiedOnly,
            onTap: () => setState(() => _verifiedOnly = !_verifiedOnly),
          ),
        ]),
      ],
    );
  }

  Widget _countRow(AppColors c, int count) {
    final filtered = _activeFilters > 0 || _query.trim().isNotEmpty;
    return Row(
      children: [
        Expanded(
          child: Text(
            '$count ${count == 1 ? 'report' : 'reports'}'
            '${filtered ? ' found' : ' · newest first'}',
            style: TextStyle(color: c.textSecondary, fontSize: 13),
          ),
        ),
        if (filtered)
          PressableScale(
            onTap: _clear,
            child: Text(
              'Clear all',
              style: TextStyle(
                color: c.accent,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _failed(AppColors c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Column(
      children: [
        Text(
          "Couldn't load the reports",
          style: TextStyle(
            fontFamily: kDisplayFont,
            color: c.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 17,
            letterSpacing: displayTracking(17),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Check your connection.',
          style: TextStyle(color: c.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 12),
        TintedButton(label: 'Retry', onPressed: loadReports),
      ],
    ),
  );

  Widget _empty(AppColors c) {
    final filtered = _activeFilters > 0 || _query.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Text(
            filtered ? 'Nothing matches' : 'No reports yet',
            style: TextStyle(
              fontFamily: kDisplayFont,
              color: c.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 17,
              letterSpacing: displayTracking(17),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            filtered
                ? 'Try other words, or clear the filters.'
                : 'Dry streets, or nobody has posted yet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textSecondary, fontSize: 13),
          ),
          if (filtered) ...[
            const SizedBox(height: 12),
            TintedButton(label: 'Clear all', onPressed: _clear),
          ],
        ],
      ),
    );
  }
}

/// One report as a Facebook-style post (Nov 13 2026): who posted it, when
/// and where at the top; their note; what happened + the risk; the photo
/// (edge to edge) with the depth on it; the depth bar and whether
/// vehicles can pass; "Still flooded?"; then the thumbs and "Map" at the
/// very bottom.
class ReportPost extends StatelessWidget {
  final FloodReport zone;
  const ReportPost({required this.zone, super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    final z = zone;
    final level = FloodLevel.of(z.depth);
    final risk = z.risk == RiskLevel.normal ? 'Low' : z.risk.label;
    final riskInk = c.readable(z.risk.color);
    final depthText = level == FloodLevel.dry ? 'Dry' : formatCm(z.depth);
    final hasPhoto = z.photoUrl != null;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- who, when, where
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 0),
            child: Row(
              children: [
                Semantics(
                  button: true,
                  label: 'Posted by ${z.posterName}. Open profile',
                  excludeSemantics: true,
                  child: PressableScale(
                    onTap: () => showUserProfile(context, z.uploader),
                    child: UserAvatar(z.uploader, size: 40),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => showUserProfile(context, z.uploader),
                        child: Text(
                          z.posterName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '${z.updated} · Brgy. ${z.barangay}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: c.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // New reports wait for an admin (status).
                          Tooltip(
                            message: z.status == 'verified'
                                ? 'Verified by Admin'
                                : 'Not verified yet',
                            child: Icon(
                              z.status == 'verified'
                                  ? CupertinoIcons.checkmark_seal_fill
                                  : CupertinoIcons.clock,
                              size: 13,
                              color: z.status == 'verified'
                                  ? c.accent
                                  : c.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Your own report: delete it (no voting on your own).
                if (z.mine) DeleteReportButton(report: z),
              ],
            ),
          ),
          // ---- the note
          if (z.note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Text(
                z.note,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),
          // ---- what happened + risk
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _Tag(
                  icon: z.typeIcon,
                  label: z.typeLabel,
                  color: c.textPrimary,
                  fill: c.surfaceAlt,
                ),
                _Tag(
                  dot: z.risk.color,
                  label: '$risk risk',
                  color: riskInk,
                  fill: z.risk.color.withValues(alpha: c.isDark ? 0.18 : 0.12),
                ),
              ],
            ),
          ),
          // ---- the photo, edge to edge, with the depth on it
          if (hasPhoto)
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: kGraphite),
                  Image.network(
                    z.photoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Center(
                      child: Icon(
                        CupertinoIcons.photo,
                        size: 28,
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                  if (z.hasDepth)
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.center,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x00000000), Color(0xA6000000)],
                        ),
                      ),
                    ),
                  // How old the photo is: what matters for a flood.
                  Positioned(
                    right: 10,
                    top: 10,
                    child: _PhotoPill('Photo ${timeAgo(z.photoAge)}'),
                  ),
                  if (z.hasDepth)
                    Positioned(
                      left: 14,
                      bottom: 10,
                      right: 14,
                      child: _DepthHeadline(
                        depth: depthText,
                        level: level == FloodLevel.dry ? '' : level.label,
                        ink: Colors.white,
                        muted: const Color(0xCCFFFFFF),
                      ),
                    ),
                ],
              ),
            ),
          // ---- depth details
          if (z.hasDepth)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!hasPhoto) ...[
                    _DepthHeadline(
                      depth: depthText,
                      level: level == FloodLevel.dry ? '' : level.label,
                      ink: c.textPrimary,
                      muted: c.textSecondary,
                    ),
                    const SizedBox(height: 10),
                  ],
                  _DepthBar(cm: z.depth, color: z.risk.color),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.car_detailed,
                        size: 15,
                        color: c.textPrimary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          vehicleAdvice(z.depth),
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 0),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
              ),
              child: StillFloodedRow(zone: z),
            ),
          ),
          // ---- the bottom bar: thumbs + map
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Row(
              children: [
                if (!z.mine) VoteBar(zone: z, showQuestion: false),
                const Spacer(),
                Semantics(
                  button: true,
                  label: 'View Brgy. ${z.barangay} on the map',
                  excludeSemantics: true,
                  child: PressableScale(
                    onTap: () {
                      HomeShell.of(context)?.switchTab(1);
                      focusedReport.value = z;
                    },
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
                      decoration: BoxDecoration(
                        color: c.accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Same icon as the Map tab in the nav.
                          Icon(AgosIcons.mapPinFill, size: 16, color: c.accent),
                          const SizedBox(width: 5),
                          Text(
                            'Map',
                            style: TextStyle(
                              color: c.accent,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
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

/// "110 cm  Chest-deep": the depth, big, with its body level.
class _DepthHeadline extends StatelessWidget {
  final String depth, level;
  final Color ink, muted;
  const _DepthHeadline({
    required this.depth,
    required this.level,
    required this.ink,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          depth,
          style: TextStyle(
            fontFamily: kDisplayFont,
            color: ink,
            fontSize: 28,
            height: 1,
            fontWeight: FontWeight.w700,
            letterSpacing: displayTracking(28),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            level,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: muted,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// A small rounded label: the type (with its icon) or the risk (with a dot).
class _Tag extends StatelessWidget {
  final IconData? icon;
  final Color? dot;
  final String label;
  final Color color, fill;
  const _Tag({
    this.icon,
    this.dot,
    required this.label,
    required this.color,
    required this.fill,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 5, 11, 5),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) Icon(icon, size: 14, color: color),
          if (dot != null)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoPill extends StatelessWidget {
  final String text;
  const _PhotoPill(this.text);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// Depth on a 0-150 cm bar in the risk color, with the body marks of the
/// gauge (ankle 12, knee 48, waist 92, chest 122 cm) as ticks.
class _DepthBar extends StatelessWidget {
  final double cm;
  final Color color;
  const _DepthBar({required this.cm, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    // A painter, not a LayoutBuilder: the desktop grid measures each
    // card's height first (IntrinsicHeight), which LayoutBuilder can't do.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: cm),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => SizedBox(
        height: 26,
        width: double.infinity,
        child: CustomPaint(
          painter: _DepthBarPainter(
            v,
            cm,
            color,
            c.surfaceAlt,
            c.textPrimary,
            c.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _DepthBarPainter extends CustomPainter {
  final double shown, cm;
  final Color color, track, ink, muted;
  _DepthBarPainter(
    this.shown,
    this.cm,
    this.color,
    this.track,
    this.ink,
    this.muted,
  );

  static const _max = 150.0;
  static const _marks = [
    (12.0, 'Ankle'),
    (48.0, 'Knee'),
    (92.0, 'Waist'),
    (122.0, 'Chest'),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    RRect bar(double width) => RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 2, width, 6),
      const Radius.circular(3),
    );
    canvas.drawRRect(bar(w), Paint()..color = track);
    canvas.drawRRect(
      bar(math.max(6, (shown / _max).clamp(0.0, 1.0) * w)),
      Paint()..color = color,
    );
    for (final (at, name) in _marks) {
      final x = at / _max * w;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, 10),
        Paint()
          ..color = muted.withValues(alpha: 0.6)
          ..strokeWidth = 1,
      );
      final reached = cm >= at;
      final label = TextPainter(
        text: TextSpan(
          text: name,
          style: TextStyle(
            color: reached ? ink : muted,
            fontSize: 11,
            fontWeight: reached ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(
        canvas,
        Offset((x - label.width / 2).clamp(0, w - label.width), 13),
      );
    }
  }

  @override
  bool shouldRepaint(_DepthBarPainter old) =>
      old.shown != shown ||
      old.color != color ||
      old.ink != ink ||
      old.track != track;
}

/// "Still flooded?" Yes / No, like Waze's "Still there?". Keeps old
/// photos honest. Saves only the user's own answer ([stillFlooded]).
class StillFloodedRow extends StatelessWidget {
  final FloodReport zone;
  const StillFloodedRow({required this.zone, super.key});

  void _answer(BuildContext context, bool? value) {
    if (isGuest) {
      showLoginRequired(context, action: 'answer');
      return;
    }
    final answers = {...stillFlooded.value};
    if (value == null) {
      answers.remove(zone.key);
    } else {
      answers[zone.key] = value;
    }
    stillFlooded.value = answers;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    return ValueListenableBuilder<Map<String, bool>>(
      valueListenable: stillFlooded,
      builder: (context, answers, _) {
        final mine = answers[zone.key];
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
                    fontSize: 13,
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
                    fontSize: 13,
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
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
        return Row(
          children: [
            Expanded(
              child: Text(
                // A landslide or power line isn't "flooded".
                zone.hasDepth ? 'Still flooded?' : 'Still there?',
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 13,
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
