import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;

import '../data/demo_data.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/responsive.dart';
import '../widgets/links.dart';
import 'evacuation_centers_screen.dart';
import 'deferred_screens.dart';
import '../widgets/agos_icons.dart';

/// ============================================================
/// ASSISTANCE TAB — SOS, quick help, hotlines, go-bag checklist
/// ============================================================
class AssistanceTab extends StatefulWidget {
  const AssistanceTab({super.key});

  @override
  State<AssistanceTab> createState() => _AssistanceTabState();
}

class _AssistanceTabState extends State<AssistanceTab> {
  // Go-bag checklist: the positions (0, 1, 2...) in kGoBagItems of the
  // items the user has ticked. A Set can't hold the same number twice.
  final Set<int> _packed = {};

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    final sos = FadeSlideIn(
      child: _SosCard(onActivated: () => _sosSheet(context)),
    );
    final quickHelp = FadeSlideIn(
      delay: const Duration(milliseconds: 100),
      child: _quickHelp(context, c),
    );
    final hotlines = FadeSlideIn(
      delay: const Duration(milliseconds: 180),
      child: _hotlines(context, c),
    );
    final goBag = FadeSlideIn(
      delay: const Duration(milliseconds: 240),
      child: _goBag(c),
    );
    final note = Text(
      'Numbers sourced from Mabalacat City government channels. Verify locally before relying on them in an actual emergency.',
      style: TextStyle(color: c.textSecondary, fontSize: 11, height: 1.45),
    );
    // Desktop: SOS next to the quick-help tiles, then hotlines next to
    // the go-bag checklist. Phones and tablets: one column, as before.
    if (screenSizeOf(context) == ScreenSize.desktop) {
      return ListView(
        padding: pagePadding(context),
        children: [
          const PageHeader('Emergency help', subtitle: 'Help is one tap away'),
          const SizedBox(height: 24),
          TwoColumns(
            leftFlex: 5,
            rightFlex: 7,
            // A heading on both sides, so the two titles line up.
            left: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [const SectionHeader('In an emergency'), sos],
              ),
            ],
            right: [quickHelp],
          ),
          const SizedBox(height: 28),
          TwoColumns(
            leftFlex: 7,
            rightFlex: 5,
            left: [hotlines, note],
            right: [goBag],
          ),
        ],
      );
    }
    return ListView(
      padding: pagePadding(context),
      children: [
        const PageHeader('Emergency help', subtitle: 'Help is one tap away'),
        const SizedBox(height: 18),
        sos,
        const SizedBox(height: 26),
        quickHelp,
        const SizedBox(height: 26),
        hotlines,
        const SizedBox(height: 26),
        goBag,
        const SizedBox(height: 18),
        note,
      ],
    );
  }

  Widget _quickHelp(BuildContext context, AppColors c) {
    final items = [
      (
        AgosIcons.boat,
        'Request rescue',
        'Send your location',
        kDanger,
        () => _rescueSheet(context),
      ),
      (
        CupertinoIcons.house_alt_fill,
        'Evacuation',
        'Find open centers',
        kGray,
        () =>
            Navigator.of(context)
                .push(slideRoute(const EvacuationCentersScreen())),
      ),
      (
        CupertinoIcons.exclamationmark_bubble_fill,
        'Report incident',
        'Flooding, blocked roads',
        kGray,
        () => openReportIncident(context),
      ),
      (
        CupertinoIcons.person_crop_circle_badge_exclam,
        'Missing person',
        'Report someone missing',
        kGray,
        () => _missingSheet(context),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Get help'),
        // A plain list, like a phone's settings: easy to scan, and the
        // colored icons are enough to tell the options apart.
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) Divider(height: 1, indent: 56, color: c.border),
                _helpRow(c, items[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _helpRow(
    AppColors c,
    (IconData, String, String, Color, VoidCallback) item,
  ) {
    final (icon, title, sub, color, onTap) = item;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: TextStyle(color: c.textSecondary, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_right, color: c.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _hotlines(BuildContext context, AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Hotline directory'),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              for (var i = 0; i < kHotlines.length; i++) ...[
                if (i > 0) Divider(height: 1, indent: 68, color: c.border),
                _hotlineRow(context, c, kHotlines[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _hotlineRow(BuildContext context, AppColors c, Hotline h) {
    return InkWell(
      onTap: () =>
          confirmCall(context, name: h.name, number: h.number, color: h.color),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            IconBadge(h.icon, h.color, size: 40),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    h.name,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    h.number,
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: kSafe.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.phone_fill,
                color: kSafe,
                size: 19,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _goBag(AppColors c) {
    final done = _packed.length;
    final total = kGoBagItems.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Go-bag checklist'),
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 56,
                    height: 56,
                    // Go-bag progress circle. With no `begin`, the tween
                    // starts from wherever it currently is, so ticking an
                    // item slides the circle smoothly from the old
                    // percentage to the new one (done / total).
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: done / total),
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) => Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: v,
                            strokeWidth: 6,
                            strokeCap: StrokeCap.round,
                            backgroundColor: c.surfaceAlt,
                            color: done == total ? kSafe : c.accent,
                          ),
                          Center(
                            child: Text(
                              '${(v * 100).round()}%',
                              style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          done == total ? 'You\'re ready!' : 'Pack your go-bag',
                          style: TextStyle(
                            color: c.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          '$done of $total items packed',
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < total; i++)
                CheckboxListTile(
                  value: _packed.contains(i),
                  onChanged: (v) =>
                      setState(() => v! ? _packed.add(i) : _packed.remove(i)),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: kSafe,
                  checkboxShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  side: BorderSide(color: c.textSecondary, width: 1.5),
                  title: Text(
                    kGoBagItems[i].$1,
                    style: TextStyle(
                      color: _packed.contains(i)
                          ? c.textSecondary
                          : c.textPrimary,
                      decoration: _packed.contains(i)
                          ? TextDecoration.lineThrough
                          : null,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: kGoBagItems[i].$2.isEmpty
                      ? null
                      : Text(
                          kGoBagItems[i].$2,
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 11.5,
                          ),
                        ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ----- Sheets -----

  void _sosSheet(BuildContext context) {
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
                _rescueSheet(context);
              },
            ),
          ],
        );
      },
    );
  }

  void _rescueSheet(BuildContext context) {
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
                          () => needs.contains(n)
                              ? needs.remove(n)
                              : needs.add(n),
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

  void _missingSheet(BuildContext context) {
    String barangay = 'Poblacion';
    showAppSheet(
      context,
      builder: (sheet) {
        return StatefulBuilder(
          builder: (sheet, setSheet) {
            final c = AppColors(sheet);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Report a missing person',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Share details to help responders find them',
                  style: TextStyle(color: c.textSecondary, fontSize: 12.5),
                ),
                const SizedBox(height: 20),
                const FieldLabel('Full name'),
                const AppTextField(
                  hint: 'Juan Dela Cruz',
                  icon: CupertinoIcons.person,
                ),
                const SizedBox(height: 14),
                const FieldLabel('Age'),
                const AppTextField(
                  hint: 'e.g. 12',
                  icon: CupertinoIcons.calendar,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 14),
                const FieldLabel('Last seen in'),
                BarangayDropdown(
                  value: barangay,
                  onChanged: (v) => setSheet(() => barangay = v),
                ),
                const SizedBox(height: 14),
                const FieldLabel('Description'),
                const AppTextField(
                  hint: 'Clothes, height, where they were going…',
                  maxLines: 3,
                ),
                const SizedBox(height: 22),
                PrimaryButton(
                  label: 'Submit report',
                  icon: CupertinoIcons.paperplane_fill,
                  onPressed: () {
                    Navigator.of(sheet).pop();
                    showSuccessDialog(
                      context,
                      title: 'Report submitted (demo)',
                      message: 'In the full app, this would go to the Admins. Nothing was actually sent — contact the police (PNP) directly.',
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
          color: onTap == null
              ? c.surfaceAlt
              : c.accent.withValues(alpha: 0.15),
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
}

/// Big red press-and-hold SOS button (holding avoids accidental taps).
class _SosCard extends StatefulWidget {
  final VoidCallback onActivated;
  const _SosCard({required this.onActivated});

  @override
  State<_SosCard> createState() => _SosCardState();
}

// TickerProviderStateMixin (not "Single..."): this widget has TWO
// animation controllers, and the Single version only allows one.
class _SosCardState extends State<_SosCard> with TickerProviderStateMixin {
  // How far the hold has got: 0.0 = not pressed, 1.0 = held for the full
  // 1.4 seconds. The status listener fires when it reaches the end
  // ("completed"): it resets the ring to empty and opens the SOS sheet.
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
  // The ripple rings around the button, looping every 2 seconds.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
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
    // A plain card with a thin red edge: the red button is the only loud
    // thing on it, so the eye goes straight there.
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 16, 20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kDanger.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'In danger?',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Press and hold SOS until the ring fills to call for help or request a rescue.',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Press = start filling the ring (forward). Let go early, or
          // slide the finger off = the ring drains back to empty (reverse),
          // so nothing happens. Only a full 1.4 s hold triggers SOS.
          GestureDetector(
            onTapDown: (_) => _hold.forward(),
            onTapUp: (_) => _hold.reverse(),
            onTapCancel: () => _hold.reverse(),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: SizedBox(
                width: 116,
                height: 116,
                // Listenable.merge: rebuild when EITHER animation ticks.
                // The Stack draws three things on top of each other:
                // ripple rings, the white progress ring, the SOS button.
                child: AnimatedBuilder(
                  animation: Listenable.merge([_hold, _pulse]),
                  builder: (context, _) => Stack(
                    alignment: Alignment.center,
                    children: [
                      // Two ripple rings, half a loop apart, so there's
                      // always one growing. `% 1` keeps t between 0 and 1
                      // (e.g. 0.7 + 0.5 = 1.2 -> 0.2). Each ring grows from
                      // 76 px to 116 px while fading from 0.18 to 0.
                      for (final offset in [0.0, 0.5])
                        Builder(
                          builder: (context) {
                            final t = (_pulse.value + offset) % 1;
                            return Container(
                              width: 76 + 40 * t,
                              height: 76 + 40 * t,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: kDanger.withValues(
                                  alpha: 0.16 * (1 - t),
                                ),
                              ),
                            );
                          },
                        ),
                      // The white ring that fills up while holding.
                      SizedBox(
                        width: 92,
                        height: 92,
                        child: CircularProgressIndicator(
                          value: _hold.value,
                          strokeWidth: 5,
                          strokeCap: StrokeCap.round,
                          color: kDanger,
                          backgroundColor: Colors.transparent,
                        ),
                      ),
                      // The button sinks in (shrinks up to 8%) the longer
                      // it's held, like pressing a real button.
                      Transform.scale(
                        scale: 1 - _hold.value * 0.08,
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFDC2626),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'SOS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
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
        ],
      ),
    );
  }
}
