import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/demo_data.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/responsive.dart';
import '../widgets/check_in.dart';
import '../widgets/links.dart';
import 'evacuation_centers_screen.dart';
import '../widgets/agos_icons.dart';

/// ============================================================
/// HELP TAB (file name kept from when it was "Assistance")
/// ============================================================
/// Two parts only:
/// 1. Need help now: one card with the SOS button (hold = call 911), one-tap
///    CDRRMO / Police, all hotlines, I'm safe, Request rescue; then the
///    nearest open shelter.
/// 2. Be ready: tips Before / During / After, with the go-bag checklist
///    inside Before (that's when you pack it).
class AssistanceTab extends StatefulWidget {
  const AssistanceTab({super.key});

  @override
  State<AssistanceTab> createState() => _AssistanceTabState();
}

class _AssistanceTabState extends State<AssistanceTab> {
  // Go-bag items the user has ticked, saved by NAME (not position), so
  // reordering kGoBagItems later doesn't tick the wrong ones.
  Set<String> _packed = {};
  static const _packedKey = 'go_bag_packed';

  // Which part of the flood timeline is open: 0 Before, 1 During, 2 After.
  int _phase = 0;

  @override
  void initState() {
    super.initState();
    _loadPacked();
  }

  // The browser keeps the ticks (shared_preferences = localStorage on web),
  // so they survive a reload. Until Supabase, they stay on this device.
  Future<void> _loadPacked() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_packedKey);
      if (saved != null && mounted) setState(() => _packed = saved.toSet());
    } catch (_) {
      // Storage blocked (e.g. some private windows): ticks just aren't saved.
    }
  }

  Future<void> _togglePacked(String item) async {
    setState(
      () => _packed.contains(item) ? _packed.remove(item) : _packed.add(item),
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_packedKey, _packed.toList());
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    final emergency = _emergency(context, c);
    final hotlines = _hotlines(context, c);
    final shelter = _nearestShelter(context, c);
    final note = Text(
      'Hotline numbers are from Mabalacat City government channels. Check them locally before you rely on them.',
      style: TextStyle(color: c.textSecondary, fontSize: 11.5, height: 1.45),
    );
    const header = PageHeader(
      'Help',
      subtitle: 'Get help fast, and be ready before the rain',
    );
    // Desktop: two full-width bands, so nothing ends up lopsided.
    // Band 1: SOS (left) and hotlines + shelter (right), stretched to the
    // same height. Band 2: Be ready across the whole width.
    if (screenSizeOf(context) == ScreenSize.desktop) {
      return ListView(
        padding: pagePadding(context),
        children: [
          header,
          const SizedBox(height: 28),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 28,
              children: [
                Expanded(child: emergency),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      hotlines,
                      const SizedBox(height: 24),
                      shelter,
                      const Spacer(),
                      const SizedBox(height: 16),
                      note,
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          _beReady(c, wide: true),
        ],
      );
    }
    return ListView(
      padding: pagePadding(context),
      children: [
        header,
        const SizedBox(height: 18),
        emergency,
        const SizedBox(height: 30),
        hotlines,
        const SizedBox(height: 30),
        shelter,
        const SizedBox(height: 34),
        _beReady(c),
        const SizedBox(height: 20),
        note,
      ],
    );
  }

  // The focal point of the page: the SOS button, alone and centered. It is
  // the only strong color here, so the eye lands on it first.
  Widget _emergency(BuildContext context, AppColors c) {
    final sos = kHotlines.first; // 911
    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _SosButton(
            number: sos.number,
            onActivated: () => confirmCall(
              context,
              name: sos.name,
              number: sos.number,
              color: sos.color,
            ),
          ),
          const SizedBox(height: 22),
          Divider(height: 1, color: c.border),
          const SizedBox(height: 16),
          Row(
            spacing: 10,
            children: [
              Expanded(
                child: _pill(
                  c,
                  CupertinoIcons.checkmark_shield_fill,
                  'I\'m safe',
                  kSafe,
                  () => showImSafe(context),
                ),
              ),
              Expanded(
                child: _pill(
                  c,
                  AgosIcons.boat,
                  'Request rescue',
                  c.textPrimary,
                  () => rescueSheet(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(
    AppColors c,
    IconData icon,
    String label,
    Color iconColor,
    VoidCallback onTap,
  ) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // CDRRMO and Police one tap away; the rest behind "All".
  Widget _hotlines(BuildContext context, AppColors c) {
    final quick = kHotlines
        .where((h) => h.short == 'CDRRMO' || h.short == 'Police')
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Hotlines',
          actionLabel: 'All ${kHotlines.length}',
          onAction: () => _allHotlines(context),
        ),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              for (var i = 0; i < quick.length; i++) ...[
                if (i > 0) Divider(height: 1, indent: 52, color: c.border),
                _hotlineRow(
                  c,
                  quick[i],
                  () => confirmCall(
                    context,
                    name: quick[i].name,
                    number: quick[i].number,
                    color: quick[i].color,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // Every hotline, in a sheet. Tapping one closes the sheet, then asks
  // before calling (so the two popups don't stack).
  void _allHotlines(BuildContext context) {
    showAppSheet(
      context,
      builder: (sheet) {
        final c = AppColors(sheet);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Hotlines',
              style: TextStyle(
                fontFamily: kDisplayFont,
                color: c.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap a number to call. We ask first.',
              style: TextStyle(color: c.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < kHotlines.length; i++) ...[
              if (i > 0) Divider(height: 1, indent: 52, color: c.border),
              _hotlineRow(c, kHotlines[i], () {
                Navigator.of(sheet).pop();
                confirmCall(
                  context,
                  name: kHotlines[i].name,
                  number: kHotlines[i].number,
                  color: kHotlines[i].color,
                );
              }),
            ],
          ],
        );
      },
    );
  }

  Widget _hotlineRow(AppColors c, Hotline h, VoidCallback onTap) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        color: Colors.transparent, // makes the whole row tappable
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            _Glyph(h.icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    h.name,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    h.number,
                    style: TextStyle(color: c.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(CupertinoIcons.phone_fill, color: c.accent, size: 19),
          ],
        ),
      ),
    );
  }

  // The closest OPEN evacuation center, as one compact row.
  Widget _nearestShelter(BuildContext context, AppColors c) {
    final open = kEvacCenters.where((e) => e.open).toList()
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    final e = open.firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Nearest open shelter',
          badge: const SampleBadge(),
          actionLabel: 'All centers',
          onAction: () =>
              Navigator.of(context)
                  .push(slideRoute(const EvacuationCentersScreen())),
        ),
        if (e == null)
          Text(
            'No evacuation center is open right now.',
            style: TextStyle(color: c.textSecondary, fontSize: 13),
          )
        else
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _Glyph(e.icon),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.name,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Brgy. ${e.barangay} · Open',
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                PressableScale(
                  onTap: () => openDirections(context, e.point),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: c.surfaceAlt,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.arrow_up_right_diamond_fill,
                          color: c.accent,
                          size: 15,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Directions',
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
              ],
            ),
          ),
      ],
    );
  }

  // Be ready: a Before → During → After timeline. Each step shows its tips,
  // plus one extra: the go-bag (Before) and the water-depth diagram (During).
  // [wide] (desktop): tips side by side, go-bag items in 3 columns.
  Widget _beReady(AppColors c, {bool wide = false}) {
    final (_, tips) = kSafetyPhases[_phase];
    Widget tip(SafetyTip t) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Glyph(t.icon),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.title,
                style: TextStyle(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                t.body,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    final tipsCard = wide
        ? AppCard(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < tips.length; i++) ...[
                    if (i > 0) VerticalDivider(width: 1, color: c.border),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: tip(tips[i]),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          )
        : AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < tips.length; i++) ...[
                  if (i > 0) Divider(height: 1, indent: 52, color: c.border),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: tip(tips[i]),
                  ),
                ],
              ],
            ),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Be ready'),
        _PhaseTimeline(
          selected: _phase,
          onSelect: (i) => setState(() => _phase = i),
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [...previous, ?current],
          ),
          child: Column(
            key: ValueKey(_phase),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              tipsCard,
              if (_phase == 0) ...[
                const SizedBox(height: 14),
                _goBag(c, wide: wide),
              ],
              if (_phase == 1) ...[
                const SizedBox(height: 14),
                const _DepthDiagram(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _goBag(AppColors c, {bool wide = false}) {
    final done = kGoBagItems.where((i) => _packed.contains(i.$1)).length;
    final total = kGoBagItems.length;
    final ready = done == total;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ready ? 'Your go-bag is ready' : 'Pack a go-bag',
                  style: TextStyle(
                    fontFamily: kDisplayFont,
                    color: c.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                '$done/$total',
                style: TextStyle(
                  color: ready ? kSafe : c.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Keep it by the door. Ticks are saved on this device.',
            style: TextStyle(color: c.textSecondary, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          // One segment per item: you see what's left at a glance.
          Row(
            spacing: 4,
            children: [
              for (var i = 0; i < total; i++)
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    height: 5,
                    decoration: BoxDecoration(
                      color: i < done
                          ? (ready ? kSafe : c.accent)
                          : c.surfaceAlt,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (wide)
            // 3 columns, filled row by row.
            for (var r = 0; r < total; r += 3)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 16,
                children: [
                  for (var i = r; i < r + 3; i++)
                    Expanded(
                      child: i < total
                          ? _checkRow(
                              c,
                              kGoBagItems[i].$1,
                              kGoBagItems[i].$2,
                              _packed.contains(kGoBagItems[i].$1),
                            )
                          : const SizedBox(),
                    ),
                ],
              )
          else
            for (final (item, note) in kGoBagItems)
              _checkRow(c, item, note, _packed.contains(item)),
        ],
      ),
    );
  }

  Widget _checkRow(AppColors c, String item, String note, bool packed) {
    return Semantics(
      checked: packed,
      child: PressableScale(
        onTap: () => _togglePacked(item),
        child: Container(
          color: Colors.transparent, // whole row is tappable
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: packed ? c.accent : Colors.transparent,
                  border: packed
                      ? null
                      : Border.all(color: c.textSecondary, width: 1.5),
                ),
                child: packed
                    ? const Icon(
                        CupertinoIcons.checkmark,
                        color: Colors.white,
                        size: 13,
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item,
                      style: TextStyle(
                        color: packed ? c.textSecondary : c.textPrimary,
                        decoration: packed ? TextDecoration.lineThrough : null,
                        decorationColor: c.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (note.isNotEmpty)
                      Text(
                        note,
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

/// One neutral icon tile, used for every list icon on this page. Same color
/// everywhere on purpose: color is kept for SOS (red) and "I'm safe" (green).
class _Glyph extends StatelessWidget {
  final IconData icon;
  const _Glyph(this.icon);

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: c.textPrimary.withValues(alpha: 0.8), size: 18),
    );
  }
}

/// Before → During → After as a timeline: three dots on a line, the line
/// filled up to the open step. Tap a step to open it.
class _PhaseTimeline extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;
  const _PhaseTimeline({required this.selected, required this.onSelect});

  // What each step means, in one line.
  static const _hints = [
    'Rain is on the way',
    'Water is rising',
    'Water is going down',
  ];

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    final n = kSafetyPhases.length;
    return LayoutBuilder(
      builder: (context, box) {
        // Dot centers sit in the middle of each third of the width.
        final step = box.maxWidth / n;
        return Stack(
          children: [
            // The track, then the filled part up to the open step.
            Positioned(
              left: step / 2,
              right: step / 2,
              top: 10,
              child: Container(height: 2, color: c.border),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              left: step / 2,
              width: step * selected,
              top: 10,
              child: Container(height: 2, color: c.accent),
            ),
            Row(
              children: [
                for (var i = 0; i < n; i++)
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: i == selected,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onSelect(i),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Column(
                            children: [
                              _dot(c, i),
                              const SizedBox(height: 10),
                              Text(
                                kSafetyPhases[i].$1,
                                style: TextStyle(
                                  color: i == selected
                                      ? c.textPrimary
                                      : c.textSecondary,
                                  fontSize: 14,
                                  fontWeight: i == selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _hints[i],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: c.textSecondary,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _dot(AppColors c, int i) {
    final open = i == selected;
    final passed = i < selected;
    return SizedBox(
      width: 22,
      height: 22,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: open ? 22 : 12,
          height: open ? 22 : 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: open || passed ? c.accent : c.background,
            border: open || passed
                ? null
                : Border.all(color: c.textSecondary, width: 1.5),
            boxShadow: open
                ? [
                    BoxShadow(
                      color: c.accent.withValues(alpha: 0.25),
                      blurRadius: 0,
                      spreadRadius: 5,
                    ),
                  ]
                : null,
          ),
          child: open
              ? Center(
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

/// How little MOVING water it takes: three tanks filled to 15, 30 and
/// 60 cm, on the same scale. Figures from the US National Weather
/// Service's "Turn Around, Don't Drown" safety campaign.
class _DepthDiagram extends StatelessWidget {
  const _DepthDiagram();

  static const _scaleCm = 75.0; // a full tank
  static const _levels = [
    (15, '6 in', 'Can knock an adult off their feet'),
    (30, '1 ft', 'Can carry away most cars'),
    (60, '2 ft', 'Can carry away SUVs and trucks'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Moving water is stronger than it looks',
            style: TextStyle(
              fontFamily: kDisplayFont,
              color: c.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'If it is flowing, don\'t walk or drive through it.',
            style: TextStyle(color: c.textSecondary, fontSize: 12.5),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              for (final (cm, imperial, what) in _levels)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _tank(c, cm),
                      const SizedBox(height: 10),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '$cm cm',
                              style: TextStyle(
                                color: c.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            TextSpan(
                              text: '  $imperial',
                              style: TextStyle(color: c.textSecondary),
                            ),
                          ],
                        ),
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        what,
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Source: US National Weather Service, "Turn Around, Don\'t Drown"',
            style: TextStyle(color: c.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // A tank on a shared scale, the water rising to [cm] when it first shows.
  Widget _tank(AppColors c, int cm) {
    const height = 96.0;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.bottomCenter,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: cm / _scaleCm),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => Container(
          height: height * v,
          decoration: BoxDecoration(
            color: c.accent.withValues(alpha: 0.28),
            border: Border(top: BorderSide(color: c.accent, width: 2)),
          ),
        ),
      ),
    );
  }
}

// ----- Sheets (top-level, so the + button can open SOS too) -----

/// Emergency SOS: the main hotlines, or request a rescue.
void showSosSheet(BuildContext context) {
  showAppSheet(
    context,
    builder: (sheet) {
      final c = AppColors(sheet);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Emergency SOS',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Who do you need to reach?',
            style: TextStyle(color: c.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 18),
          for (final h in kHotlines.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                padding: const EdgeInsets.all(14),
                onTap: () {
                  Navigator.of(sheet).pop();
                  confirmCall(
                    context,
                    name: h.name,
                    number: h.number,
                    color: h.color,
                  );
                },
                child: Row(
                  children: [
                    IconBadge(h.icon, h.color, size: 44),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        h.name,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      h.number,
                      style: TextStyle(
                        color: h.color,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 6),
          PrimaryButton(
            label: 'Request rescue instead',
            icon: AgosIcons.boat,
            onPressed: () {
              Navigator.of(sheet).pop();
              rescueSheet(context);
            },
          ),
        ],
      );
    },
  );
}

void rescueSheet(BuildContext context) {
  String barangay = 'Dau';
  int people = 1;
  final needs = <String>{};
  showAppSheet(
    context,
    builder: (sheet) {
      return StatefulBuilder(
        builder: (sheet, setSheet) {
          final c = AppColors(sheet);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const IconBadge(
                    AgosIcons.boat,
                    kDanger,
                    size: 48,
                    squircle: true,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Request rescue',
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Rescuers will come to your barangay',
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const FieldLabel('Your barangay'),
              BarangayDropdown(
                value: barangay,
                onChanged: (v) => setSheet(() => barangay = v),
              ),
              const SizedBox(height: 16),
              const FieldLabel('How many people?'),
              Row(
                children: [
                  _stepButton(
                    c,
                    CupertinoIcons.minus,
                    people > 1 ? () => setSheet(() => people--) : null,
                  ),
                  SizedBox(
                    width: 64,
                    child: Text(
                      '$people',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _stepButton(
                    c,
                    CupertinoIcons.plus,
                    people < 50 ? () => setSheet(() => people++) : null,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const FieldLabel('Anyone who needs extra help?'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final n in [
                    'Elderly',
                    'PWD',
                    'Infant / child',
                    'Pregnant',
                    'Needs medical care',
                  ])
                    SelectChip(
                      label: n,
                      selected: needs.contains(n),
                      color: kDanger,
                      onTap: () => setSheet(
                        () =>
                            needs.contains(n) ? needs.remove(n) : needs.add(n),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const FieldLabel('Notes (optional)'),
              const AppTextField(
                hint: 'e.g. We are on the 2nd floor, water is rising',
                maxLines: 2,
              ),
              const SizedBox(height: 22),
              PrimaryButton(
                label: 'Send rescue request',
                icon: CupertinoIcons.paperplane_fill,
                color: kDanger,
                onPressed: () {
                  Navigator.of(sheet).pop();
                  showSuccessDialog(
                    context,
                    title: 'Request sent (demo)',
                    message:
                        'In the full app, the Admins would receive your request for $people ${people == 1 ? 'person' : 'people'} in Brgy. $barangay.\n\nNothing was actually sent. In a real emergency, call 911.',
                  );
                },
              ),
            ],
          );
        },
      );
    },
  );
}

Widget _stepButton(AppColors c, IconData icon, VoidCallback? onTap) {
  return PressableScale(
    onTap: onTap,
    child: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: onTap == null ? c.surfaceAlt : c.accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        icon,
        color: onTap == null ? c.textSecondary : c.accent,
        size: 22,
      ),
    ),
  );
}

/// The big red press-and-hold SOS button (holding avoids accidental taps),
/// with its caption. Screen readers get a plain button instead: tapping
/// it still asks before calling.
class _SosButton extends StatefulWidget {
  final String number;
  final VoidCallback onActivated;
  const _SosButton({required this.number, required this.onActivated});

  @override
  State<_SosButton> createState() => _SosButtonState();
}

// TickerProviderStateMixin (not "Single..."): this widget has TWO
// animation controllers, and the Single version only allows one.
class _SosButtonState extends State<_SosButton> with TickerProviderStateMixin {
  // How far the hold has got: 0.0 = not pressed, 1.0 = held for the full
  // 1.4 seconds. Reaching the end resets the ring and fires onActivated.
  late final AnimationController _hold =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1400),
      )..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          _hold.reset();
          widget.onActivated();
        }
      });
  // The soft ripples around the button, looping.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  @override
  void dispose() {
    _hold.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    // "Reduce motion" turned on: no ripples.
    final still = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: Listenable.merge([_hold, _pulse]),
      builder: (context, _) {
        final holding = _hold.value > 0;
        return Column(
          children: [
            Semantics(
              button: true,
              label: 'SOS, call ${widget.number}',
              onTap: widget.onActivated,
              excludeSemantics: true,
              // Press = the ring fills (forward). Let go early, or slide
              // off = it drains back (reverse) and nothing happens.
              child: GestureDetector(
                onTapDown: (_) => _hold.forward(),
                onTapUp: (_) => _hold.reverse(),
                onTapCancel: () => _hold.reverse(),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: SizedBox(
                    width: 176,
                    height: 176,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Two ripples half a loop apart, growing from the
                        // button's edge outwards while fading.
                        if (!still && !holding)
                          for (final offset in [0.0, 0.5])
                            Builder(
                              builder: (context) {
                                final t = (_pulse.value + offset) % 1;
                                return Container(
                                  width: 116 + 60 * t,
                                  height: 116 + 60 * t,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: kDanger.withValues(
                                      alpha: 0.12 * (1 - t),
                                    ),
                                  ),
                                );
                              },
                            ),
                        // The ring that fills while holding.
                        SizedBox(
                          width: 140,
                          height: 140,
                          child: CircularProgressIndicator(
                            value: _hold.value,
                            strokeWidth: 5,
                            strokeCap: StrokeCap.round,
                            color: kDanger,
                            backgroundColor: holding
                                ? kDanger.withValues(alpha: 0.15)
                                : Colors.transparent,
                          ),
                        ),
                        // The button sinks in (up to 6%) the longer it's
                        // held, like pressing a real button.
                        Transform.scale(
                          scale: 1 - _hold.value * 0.06,
                          child: Container(
                            width: 116,
                            height: 116,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              // Lit from the top, like the rest of the app.
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFFEE5A5A), Color(0xFFD23C3C)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFD23C3C)
                                      .withValues(alpha: c.isDark ? 0.35 : 0.3),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              'SOS',
                              style: TextStyle(
                                fontFamily: kDisplayFont,
                                color: Colors.white,
                                fontSize: 30,
                                letterSpacing: 1,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              holding ? 'Keep holding…' : 'Hold to call ${widget.number}',
              style: TextStyle(
                fontFamily: kDisplayFont,
                color: c.textPrimary,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'For danger to life. We ask before calling.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, fontSize: 13),
            ),
          ],
        );
      },
    );
  }
}
