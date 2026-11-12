import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;

import '../theme.dart';
import 'responsive.dart';
import 'common.dart';

/// ============================================================
/// SKELETONS — gray placeholder shapes with a light sweeping
/// across them, shown while something loads. They make waiting
/// feel shorter because the page's layout appears right away.
/// ============================================================

/// Sweeps a soft highlight across [child] (the "shimmer" effect).
class Shimmer extends StatefulWidget {
  final Widget child;
  const Shimmer({required this.child, super.key});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    final base = c.surfaceAlt;
    final shine = c.isDark
        ? Color.lerp(c.surfaceAlt, Colors.white, 0.08)!
        : Colors.white;
    // ShaderMask repaints the child's pixels with a gradient.
    // BlendMode.srcATop = only where the child already has something drawn
    // (the gray boxes), so the gaps between boxes stay see-through.
    //
    // The gradient is gray -> light -> gray: a light band. Alignment -1 is
    // the left edge and +1 the right edge. x goes from -1.5 to +1.5 as the
    // animation runs 0 -> 1, so the band starts just off the left side and
    // ends just off the right side. The ±0.6 is the band's width, and the
    // -0.3 / +0.3 on the y-axis tilts it diagonally.
    return AnimatedBuilder(
      animation: _ctrl,
      child: widget.child,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (rect) {
          final x = -1.5 + _ctrl.value * 3; // sweeps left → right
          return LinearGradient(
            begin: Alignment(x - 0.6, -0.3),
            end: Alignment(x + 0.6, 0.3),
            colors: [base, shine, base],
          ).createShader(rect);
        },
        child: child,
      ),
    );
  }
}

/// A gray placeholder block. Put several inside one [Shimmer].
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  const SkeletonBox({
    this.width,
    required this.height,
    this.radius = 14,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors(context).surfaceAlt,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Downloads a split-off piece of the app (a Dart "deferred" library)
/// the first time it's shown, displaying [placeholder] meanwhile.
/// On a phone this keeps big parts like the map out of the first download.
class DeferredView extends StatefulWidget {
  final Future<void> Function() load;
  final Widget Function() builder;
  final Widget placeholder;
  const DeferredView({
    required this.load,
    required this.builder,
    required this.placeholder,
    super.key,
  });

  @override
  State<DeferredView> createState() => _DeferredViewState();
}

class _DeferredViewState extends State<DeferredView> {
  // Starts the download once and remembers it. (If we called widget.load()
  // inside build(), every rebuild would start it again.) Not `final`,
  // because the "Try again" button replaces it with a new attempt.
  late Future<void> _loading = widget.load();

  @override
  Widget build(BuildContext context) {
    // FutureBuilder rebuilds when the download finishes. Three cases:
    //   still downloading -> show the skeleton placeholder
    //   failed (offline)  -> show the error message with "Try again"
    //   done              -> build the real screen
    // AnimatedSwitcher cross-fades between them. The keys ('ready',
    // 'error') let it tell the three apart so it knows when to fade.
    return FutureBuilder<void>(
      future: _loading,
      builder: (context, snap) {
        final Widget child;
        if (snap.connectionState != ConnectionState.done) {
          child = widget.placeholder;
        } else if (snap.hasError) {
          child = _error(context);
        } else {
          child = KeyedSubtree(
            key: const ValueKey('ready'),
            child: widget.builder(),
          );
        }
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: child,
        );
      },
    );
  }

  Widget _error(BuildContext context) {
    final c = AppColors(context);
    return Center(
      key: const ValueKey('error'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconBadge(CupertinoIcons.wifi_slash, c.textSecondary, size: 60),
            const SizedBox(height: 14),
            Text(
              'Couldn\'t load this page',
              style: TextStyle(
                color: c.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Check your internet connection.',
              style: TextStyle(color: c.textSecondary, fontSize: 12.5),
            ),
            const SizedBox(height: 14),
            // Start a fresh download attempt. setState makes the
            // FutureBuilder watch the new one (and show the skeleton again).
            FilledButton.tonal(
              onPressed: () => setState(() => _loading = widget.load()),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder shaped like the Map tab.
class MapSkeleton extends StatelessWidget {
  const MapSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    // Same shapes as the Map tab: header and round controls at the top,
    // the glass panel (legend + report cards) at the bottom. Only the
    // shapes shimmer, not the background.
    // The Map tab runs under the top bar; its height comes as padding.
    return Container(
      color: AppColors(context).surfaceAlt,
      padding: EdgeInsets.fromLTRB(
        12,
        MediaQuery.paddingOf(context).top + 10,
        12,
        96,
      ),
      child: const Shimmer(
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: SkeletonBox(height: 112, radius: 22)),
                SizedBox(width: 10),
                SkeletonBox(width: 48, height: 97, radius: 24),
              ],
            ),
            Spacer(),
            SkeletonBox(height: 168, radius: 26), // legend + report cards
          ],
        ),
      ),
    );
  }
}

/// Placeholder shaped like a form page (used for Report incident).
class FormPageSkeleton extends StatelessWidget {
  final String title;
  const FormPageSkeleton({required this.title, super.key});

  @override
  Widget build(BuildContext context) {
    return SubpageScaffold(
      title: title,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Shimmer(
            child: ListView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: SkeletonBox(width: 240, height: 14, radius: 6),
                ),
                const SizedBox(height: 26),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: SkeletonBox(width: 110, height: 10, radius: 4),
                ),
                const SizedBox(height: 12),
                for (var row = 0; row < 2; row++) ...[
                  const Row(
                    children: [
                      Expanded(child: SkeletonBox(height: 96, radius: 18)),
                      SizedBox(width: 10),
                      Expanded(child: SkeletonBox(height: 96, radius: 18)),
                      SizedBox(width: 10),
                      Expanded(child: SkeletonBox(height: 96, radius: 18)),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: SkeletonBox(width: 130, height: 10, radius: 4),
                ),
                const SizedBox(height: 12),
                const SkeletonBox(height: 60),
                const SizedBox(height: 26),
                const SkeletonBox(height: 96, radius: 18),
                const SizedBox(height: 26),
                const SkeletonBox(height: 54),
                const SizedBox(height: 10),
                const SkeletonBox(height: 150, radius: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Placeholder for a tab while its code downloads (Alerts, Assistance,
/// More): a page title, a row of filters, and a few cards. On desktops the
/// cards sit in two columns, like the real pages.
class ListPageSkeleton extends StatelessWidget {
  const ListPageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final desktop = screenSizeOf(context) == ScreenSize.desktop;
    Widget cards(int n) => Column(
      spacing: 12,
      children: [
        for (var i = 0; i < n; i++) const SkeletonBox(height: 92, radius: 20),
      ],
    );
    return Shimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: pagePadding(context),
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: SkeletonBox(width: 180, height: 26, radius: 8),
          ),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: SkeletonBox(width: 140, height: 12, radius: 6),
          ),
          const SizedBox(height: 22),
          const Row(
            spacing: 8,
            children: [
              SkeletonBox(width: 70, height: 36, radius: 18),
              SkeletonBox(width: 90, height: 36, radius: 18),
              SkeletonBox(width: 90, height: 36, radius: 18),
            ],
          ),
          const SizedBox(height: 18),
          if (desktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 24,
              children: [
                SizedBox(width: 420, child: cards(5)),
                const Expanded(child: SkeletonBox(height: 480, radius: 20)),
              ],
            )
          else
            cards(5),
        ],
      ),
    );
  }
}
