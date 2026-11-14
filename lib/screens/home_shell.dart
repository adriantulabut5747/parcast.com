import 'dart:ui';

import 'package:flutter/cupertino.dart' show CupertinoIcons;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../data/demo_data.dart';
import '../services/alerts.dart';
import '../services/auth.dart';
import '../services/reports.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/map_glass.dart';
import '../widgets/responsive.dart';
import '../services/prefetch.dart';
import 'account.dart';
import 'weather_tab.dart';
import 'deferred_screens.dart';
import '../widgets/agos_icons.dart';
import '../widgets/my_barangay.dart';

/// Phones only: keeps the phone layout from stretching (wider screens get
/// the website layout, see _wideLayout).
const double kMaxContentWidth = 560;

/// ============================================================
/// HOME SHELL — top bar + the four tabs + bottom nav
/// (Weather, Map, Reports, Help; reporting = the round + on phones,
/// ReportFab, and a button under Tugak on wider Reports pages)
/// ============================================================
class HomeShell extends StatefulWidget {
  /// Which tab opens first (same numbers as HomeShellState._index).
  final int initialTab;
  const HomeShell({this.initialTab = 0, super.key});

  /// Lets any tab switch tabs: `HomeShell.of(context)?.switchTab(1)`.
  /// It walks UP the widget tree from [context] until it finds the
  /// HomeShell's state. Returns null if there's no HomeShell above (the
  /// `?.` then just skips the call instead of crashing).
  static HomeShellState? of(BuildContext context) =>
      context.findAncestorStateOfType<HomeShellState>();

  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell>
    with SingleTickerProviderStateMixin {
  // Which tab is showing right now: 0 Weather, 1 Map, 2 Reports, 3 Help
  // (same order as _tabs and _items below).
  late int _index = widget.initialTab;

  // Tabs are only built the first time they're opened (so, e.g., the map
  // doesn't download tiles until someone opens the Map tab). After that
  // they stay alive, so scroll position and filters are kept.
  late final Set<int> _opened = {_index};

  // ---- Moving between tabs (Apple's "fluid interfaces" rules) ----
  // _slide = how far the current tab has moved, in page widths: 0 = still,
  // -1 = all the way out to the left (the next tab is in), +1 = out to the
  // right. A swipe drives it 1:1 with the finger; a tap or a released
  // swipe springs it to -1 / 0 / +1. Everything that moves (the pages, the
  // phone pill, the desktop segmented control) reads this one number, so
  // they always agree, and any of it can be grabbed again mid-motion.
  late final AnimationController _slide = AnimationController.unbounded(
    vsync: this,
  );
  int? _to; // the tab coming in (null = no move under way)
  double _dragRaw = 0; // finger travel in widths, before rubber-banding
  double _pageWidth = 400;

  // Critically damped (no bounce), response 0.42 s: Apple's page settle.
  // stiffness = (2π / response)², damping = 4π / response.
  static const _pageSpring = SpringDescription(
    mass: 1,
    stiffness: 224,
    damping: 29.9,
  );

  /// Which way [_to] lies: +1 = to the right of the current tab.
  int get _dir => _to == null ? 0 : (_to! > _index ? 1 : -1);

  /// The live tab position, as a fraction: 1.4 = 40% of the way from Map
  /// to Reports. Drives both navs.
  double get _livePage => _to == null
      ? _index.toDouble()
      : _index + (_to! - _index) * _slide.value.abs();

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Right after the first frame, quietly start downloading the other
    // tabs' code, the first map tiles, and the weather (web only), so
    // switching tabs is instant. addPostFrameCallback = "after the first
    // frame is drawn", so this never delays Home appearing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) prefetchAppContent(dark: AppColors(context).isDark);
    });
  }

  // Runs after initState, and again when the theme changes: loads the
  // matching logo images early so the top bar never shows an empty logo.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    BrandLogo.precache(context);
    for (final n in _navArt) {
      precacheImage(AssetImage('assets/images/nav_$n.png'), context);
    }
  }

  /// Moves to [index] with a slide in its direction (taps, links, ?tab=).
  /// Interruptible: a tap mid-move keeps going from where things are.
  void switchTab(int index) {
    if (_to == index) return; // already on its way
    if (_to == null && index == _index) return;
    // Mid-move toward somewhere else: settle on whichever tab shows more,
    // then head for the new one.
    if (_to != null) {
      if (_slide.value.abs() >= 0.5) _index = _to!;
      _slide.value = 0;
      _to = null;
      if (index == _index) return setState(() {});
    }
    setState(() {
      _opened.add(index);
      _to = index;
    });
    if (MediaQuery.disableAnimationsOf(context)) return _settle();
    _springTo(-_dir.toDouble(), 0);
  }

  void _springTo(double target, double velocity) {
    _slide
        .animateWith(
          SpringSimulation(_pageSpring, _slide.value, target, velocity),
        )
        .whenCompleteOrCancel(() {
          // A spring ends within a hair of its target, never exactly on it.
          if (mounted &&
              !_slide.isAnimating &&
              (_slide.value - target).abs() < 0.01) {
            _settle();
          }
        });
  }

  // The move is over: the incoming tab becomes the current one (or, if the
  // swipe was let go early, everything is back where it was).
  void _settle() => setState(() {
    if (_to != null && _slide.value.abs() >= 0.5) _index = _to!;
    _to = null;
    _slide.value = 0;
  });

  // ---- Swiping (phones). Not on the Map: there a drag pans the map. ----
  // The scrubber, rain bars and chip rows inside a tab are horizontal drags
  // too; Flutter gives the touch to the innermost one, so they still win.

  void _dragStart(DragStartDetails _) {
    _slide.stop(); // grabbed mid-flight: carry on from where it is
    if (_to != null && _slide.value.abs() >= 0.5) {
      // The incoming tab is mostly in: it's the current one now.
      final d = _dir;
      _index = _to!;
      _slide.value += d;
    }
    _to = null;
    _dragRaw = _slide.value;
  }

  void _dragUpdate(DragUpdateDetails d) {
    _dragRaw += d.primaryDelta! / _pageWidth;
    final next = _index + (_dragRaw < 0 ? 1 : -1);
    if (_dragRaw != 0 && next >= 0 && next < _tabs.length) {
      if (_to != next) setState(() => _opened.add(_to = next));
      _slide.value = _dragRaw;
    } else {
      // Nothing that way: resist more the further it's pulled.
      if (_to != null) setState(() => _to = null);
      _slide.value = _rubberBand(_dragRaw);
    }
  }

  void _dragEnd(DragEndDetails d) {
    final v = (d.primaryVelocity ?? 0) / _pageWidth; // widths per second
    // Where the flick is going, not where the finger let go (Apple's
    // projection with decelerationRate 0.99: v/1000 · 0.99 / 0.01).
    final projected = _slide.value + v * 0.099;
    final target =
        _to != null &&
            projected.abs() > 0.5 &&
            projected.sign == _slide.value.sign
        ? _slide.value.sign
        : 0.0;
    _springTo(target, v); // hand the finger's speed to the spring
  }

  static double _rubberBand(double x) {
    const c = 0.55, dim = 1.0; // Apple's constant; dimension = one page
    return (x * dim * c) / (dim + c * x.abs());
  }

  // Every tab but Weather is downloaded the first time it's opened.
  static final _tabs = [
    const WeatherTab(),
    deferredMapTab(),
    deferredReportsTab(),
    deferredHelpTab(),
  ];

  // One entry per tab: (icon when not selected, icon when selected,
  // label). These are Dart "records", unpacked in _navItem with
  // `final (outline, filled, label) = _items[i];`.
  static const _items = [
    (CupertinoIcons.cloud_sun, CupertinoIcons.cloud_sun_fill, 'Weather'),
    (AgosIcons.mapPin, AgosIcons.mapPinFill, 'Map'),
    (CupertinoIcons.news, CupertinoIcons.news_solid, 'Reports'),
    (AgosIcons.lifebuoy, AgosIcons.lifebuoyFill, 'Help'),
  ];

  // All opened tabs are stacked on top of each other; only the current one
  // (and, mid-move, the incoming one) is shown (see _TabLayer). This is
  // what keeps each tab's scroll position when you switch away and come
  // back. ValueKey(i) tells Flutter which layer is which tab, so it doesn't
  // mix them up when a newly opened tab gets added to the Stack.
  //
  // [bar] is the top bar's height. Tabs start below it, except the Map:
  // the map runs under the (glass) bar, edge to edge, and gets the bar's
  // height as MediaQuery top padding, so its own buttons start below it.
  //
  // [pager] (phones): pages sit side by side and slide a full width, and
  // a swipe moves them. Wider screens: a short directional cross-fade
  // (a full-width slide is too much travel on a desktop).
  Widget _tabStack(double bar, {required bool pager}) {
    final mq = MediaQuery.of(context);
    final stack = LayoutBuilder(
      builder: (context, box) {
        _pageWidth = box.maxWidth;
        return AnimatedBuilder(
          animation: _slide,
          builder: (context, _) {
            final o = _slide.value;
            return Stack(
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  if (_opened.contains(i))
                    _TabLayer(
                      key: ValueKey(i),
                      // Where this tab sits, in page widths (null = hidden).
                      offset: i == _index
                          ? o
                          : i == _to
                          ? o + _dir
                          : null,
                      current: i == _index,
                      pager: pager,
                      width: box.maxWidth,
                      child: i == 1
                          ? MediaQuery(
                              data: mq.copyWith(
                                padding: mq.padding.copyWith(
                                  top: mq.padding.top + bar,
                                ),
                              ),
                              child: _tabs[i],
                            )
                          : Padding(
                              padding: EdgeInsets.only(top: bar),
                              child: _tabs[i],
                            ),
                    ),
              ],
            );
          },
        );
      },
    );
    if (!pager) return stack;
    final canSwipe = _index != 1 || _to != null;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: canSwipe ? _dragStart : null,
      onHorizontalDragUpdate: canSwipe ? _dragUpdate : null,
      onHorizontalDragEnd: canSwipe ? _dragEnd : null,
      onHorizontalDragCancel: canSwipe ? () => _springTo(0, 0) : null,
      child: stack,
    );
  }

  static const _phoneBarHeight = 62.0;
  static const _webBarHeight = 64.0;

  // The top bar's background. Over the map it's frosted glass (MapGlass
  // gives it the browser's real blur there, see map_glass.dart).
  Widget _barGlass(AppColors c, {required bool filled, required Widget child}) {
    return MapGlass(
      enabled: _index == 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: filled
              ? c.surface.withValues(alpha: c.isDark ? 0.55 : 0.72)
              : c.surface.withValues(alpha: 0),
          border: Border(
            bottom: BorderSide(
              color: filled ? c.border : c.border.withValues(alpha: 0),
            ),
          ),
        ),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    // Tablets and desktops get the website layout: nav at the top, no
    // bottom bar. Resizing the browser window switches between the two
    // on the fly (build runs again when the size changes).
    final size = screenSizeOf(context);
    if (size != ScreenSize.phone) return _wideLayout(c, size);
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: PageBackground(
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _tabStack(_phoneBarHeight, pager: true),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    // Phones: only the Map needs a bar background (other
                    // tabs scroll below it on the plain page).
                    child: _barGlass(c, filled: _index == 1, child: _topBar(c)),
                  ),
                  // Reports' + (the Map draws its own, next to its sheet).
                  // It fades and shrinks with the swipe, like the nav.
                  Positioned(
                    right: 16,
                    bottom: 96 + MediaQuery.paddingOf(context).bottom,
                    child: AnimatedBuilder(
                      animation: _slide,
                      builder: (context, child) {
                        final v = (1 - (_livePage - 2).abs()).clamp(0.0, 1.0);
                        return IgnorePointer(
                          ignoring: v < 0.5,
                          child: Opacity(
                            opacity: v,
                            child: Transform.scale(
                              scale: 0.6 + 0.4 * v,
                              child: child,
                            ),
                          ),
                        );
                      },
                      child: const ReportFab(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              // Over the web map, the nav needs the browser's blur (and
              // must keep its taps away from the map). See MapGlass.
              child: MapGlass(
                radius: 28,
                enabled: _index == 1,
                child: _bottomNav(c),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // Tablet / desktop layout
  // ------------------------------------------------------------

  Widget _wideLayout(AppColors c, ScreenSize size) {
    final active = _index;
    final compact = size == ScreenSize.tablet;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PageBackground(
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Positioned.fill(child: _tabStack(_webBarHeight, pager: false)),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _barGlass(
                  c,
                  filled: true,
                  child: _webTopBar(c, active, compact),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Logo on the left, the four tabs in the middle, bell / theme / profile
  // on the right. On tablets ([compact]) the tabs show icons only.
  Widget _webTopBar(AppColors c, int active, bool compact) {
    return Container(
      height: _webBarHeight,
      padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 28),
      child: Row(
        children: [
          // The two Expanded sides are equally wide, which keeps the nav
          // exactly in the middle of the window.
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Semantics(
                button: true,
                label: 'AgosAlert home',
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => switchTab(0),
                    child: BrandLogo.wordmark(height: compact ? 30 : 34),
                  ),
                ),
              ),
            ),
          ),
          _segmentedNav(c, compact),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _bell(c),
                Container(
                  width: 1,
                  height: 24,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: c.border,
                ),
                _ProfileMenu(
                  // The name next to the avatar only fits on wider windows.
                  compact: MediaQuery.sizeOf(context).width < 1280,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // The tabs as an Apple segmented control: one glass track, and a raised
  // glass thumb that slides to the open tab. It follows the same live
  // position as the pages (_livePage), so it moves with the transition;
  // while travelling it stretches a little toward where it's going and
  // settles back to its size when it lands (iOS 26's liquid thumb).
  // Tablets ([compact]) show icons only.
  Widget _segmentedNav(AppColors c, bool compact) {
    final seg = compact ? 54.0 : 118.0;
    const h = 40.0, pad = 3.0, inner = h - 2 * pad;
    return Container(
      height: h,
      padding: const EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: c.isDark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.black.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(h / 2),
      ),
      child: AnimatedBuilder(
        animation: _slide,
        builder: (context, _) {
          final p = _livePage;
          // 0 when resting on a tab, 0.5 halfway between two.
          final between = (p - p.round()).abs();
          final w = seg * (1 + 0.22 * between);
          return SizedBox(
            width: seg * _tabs.length,
            height: inner,
            child: Stack(
              children: [
                Positioned(
                  left: p * seg - (w - seg) / 2,
                  width: w,
                  top: 0,
                  bottom: 0,
                  child: _segmentThumb(c, inner),
                ),
                Positioned.fill(
                  // Stretch: each segment fills the control's full height,
                  // so its hover capsule is the thumb's size and shape.
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < _tabs.length; i++)
                        _segment(
                          c,
                          i,
                          (1 - (i - p).abs()).clamp(0.0, 1.0),
                          seg,
                          compact,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _segmentThumb(AppColors c, double height) => CustomPaint(
    foregroundPainter: GlassEdgePainter(radius: height / 2, dark: c.isDark),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: c.isDark
            ? Colors.white.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(height / 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: c.isDark ? 0.35 : 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    ),
  );

  /// One segment. [s] = how selected it is (0..1), from the live position,
  /// so the label brightens as the thumb arrives instead of snapping.
  Widget _segment(AppColors c, int i, double s, double width, bool compact) {
    final (outline, filled, label) = _items[i];
    final fg = Color.lerp(c.textSecondary, c.textPrimary, s)!;
    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(s > 0.5 ? filled : outline, color: fg, size: 18),
        if (!compact) ...[
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.08,
            ),
          ),
        ],
      ],
    );
    return Semantics(
      button: true,
      selected: i == _index,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: compact ? label : '',
        child: _HoverTint(
          radius: 999, // a capsule, same as the thumb
          enabled: s < 0.5,
          child: PressableScale(
            onTap: () => switchTab(i),
            child: SizedBox(width: width, child: content),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // Phone layout
  // ------------------------------------------------------------

  // The bell, with the number of unread alerts (services/alerts.dart).
  // ListenableBuilder rebuilds just this button when the alerts or the
  // read-marks change, so the badge updates without rebuilding the shell.
  Widget _bell(AppColors c) => ListenableBuilder(
    listenable: Listenable.merge([alerts, readAlerts]),
    builder: (context, _) => _roundButton(
      c,
      icon: CupertinoIcons.bell,
      tooltip: 'Notifications',
      badge: unreadAlertCount,
      onTap: () => openNotifications(context),
    ),
  );

  Widget _topBar(AppColors c) {
    return Container(
      height: _phoneBarHeight,
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
      child: Row(
        children: [
          // Wordmark logo; falls back to the old icon + text if it fails.
          BrandLogo.wordmark(
            height: 36,
            fallback: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: const BoxDecoration(
                    color: kGraphite,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    AgosIcons.waves,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'AGOSALERT',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          _bell(c),
          const SizedBox(width: 8),
          // The avatar menu (replaces the old More tab and theme button).
          const _ProfileMenu(compact: true, avatarOnly: true),
        ],
      ),
    );
  }

  Widget _roundButton(
    AppColors c, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color? color,
    int badge = 0,
  }) {
    return Tooltip(
      message: tooltip,
      child: PressableScale(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: c.surface.withValues(alpha: 0.7),
                shape: BoxShape.circle,
                border: Border.all(color: c.border),
              ),
              // AnimatedSwitcher animates whenever its child changes, and
              // the child counts as "changed" when its key changes. That's
              // why the Icon has key: ValueKey(icon): switching sun <-> moon
              // spins/fades the old icon out and the new one in.
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, anim) => RotationTransition(
                  turns: Tween(begin: 0.6, end: 1.0).animate(anim),
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Icon(
                  icon,
                  key: ValueKey(icon),
                  color: color ?? c.textPrimary,
                  size: 21,
                ),
              ),
            ),
            if (badge > 0)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  decoration: BoxDecoration(
                    color: kDanger,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.background, width: 2),
                  ),
                  child: Text(
                    '$badge',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Phone nav: a floating glass pill with the four tabs. The open tab grows
  // wider and gets a highlight; its icon gets bigger and pops up out of the
  // pill, with its name below and ‹ › at the sides (decoration only).
  // Closed tabs show just their icon, a bit faded (long-press = its name).
  // Icons: tools/nav_icons.js -> assets/images/nav_<name>.png.
  static const _navHeight = 68.0;
  static const _navArt = ['weather', 'map', 'reports', 'help'];
  static const _navGrow = 0.8; // the open tab is this much wider than 1 tab
  static const _navInset = 6.0; // gap between the pill's edge and the tabs

  Widget _bottomNav(AppColors c) {
    // p = the live tab position (see _livePage): it follows a swipe 1:1 and
    // springs with a tap, and every tab's "how open am I" (0..1) comes
    // from it, so width, highlight, icon size and label all move together,
    // and the tab widths always add up to the pill's width.
    return AnimatedBuilder(
      animation: _slide,
      builder: (context, _) {
        final p = _livePage;
        return LayoutBuilder(
          builder: (context, box) {
            final n = _tabs.length;
            final unit = (box.maxWidth - _navInset * 2) / (n + _navGrow);
            double open(int i) => (1 - (i - p).abs()).clamp(0.0, 1.0);
            return SizedBox(
              height: _navHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(child: _navGlass(c)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: _navInset),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < n; i++)
                          // The last tab takes what's left, so rounding never
                          // makes the row a hair too wide.
                          i == n - 1
                              ? Expanded(child: _navTab(c, i, open(i)))
                              : SizedBox(
                                  width: unit * (1 + _navGrow * open(i)),
                                  child: _navTab(c, i, open(i)),
                                ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // The pill: frosted glass with the lit edge. It's clipped (the blur
  // needs that), so it sits UNDER the tabs, whose icons may stick out.
  // Nearly solid (Nov 14 2026, Adrian: at 62% the page's text read
  // through it and mixed with the tabs; the blur alone can't be trusted
  // on the web, e.g. next to Tugak's 3D stage, a separate HTML layer).
  Widget _navGlass(AppColors c) => ClipRRect(
    borderRadius: BorderRadius.circular(28),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
      child: CustomPaint(
        foregroundPainter: GlassEdgePainter(radius: 28, dark: c.isDark),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: c.surface.withValues(alpha: c.isDark ? 0.92 : 0.94),
            borderRadius: BorderRadius.circular(28),
          ),
        ),
      ),
    ),
  );

  /// One tab. [s] = how open it is: 0 = closed, 1 = the open tab.
  Widget _navTab(AppColors c, int i, double s) {
    final label = _items[i].$3;
    final icon = lerpDouble(33, 46, s)!;
    const inner = _navHeight - 16; // the highlight's height
    return Semantics(
      button: true,
      selected: i == _index,
      label: label,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: PressableScale(
          onTap: () => switchTab(i),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: c.textPrimary.withValues(
                  alpha: (c.isDark ? 0.12 : 0.07) * s,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  Positioned(
                    // Closed: centered. Open: lifted out of the pill.
                    top: lerpDouble((inner - icon) / 2, -22, s),
                    child: Image.asset(
                      'assets/images/nav_${_navArt[i]}.png',
                      width: icon,
                      height: icon,
                      opacity: AlwaysStoppedAnimation(lerpDouble(0.7, 1, s)!),
                      filterQuality: FilterQuality.medium,
                      excludeFromSemantics: true,
                    ),
                  ),
                  if (s > 0.01) ...[
                    Positioned(
                      bottom: 6,
                      child: Opacity(
                        opacity: s,
                        child: Text(
                          label,
                          style: TextStyle(
                            fontFamily: kFontFamily,
                            color: c.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                    for (final left in [true, false])
                      Positioned(
                        left: left ? 8 : null,
                        right: left ? null : 8,
                        top: 0,
                        bottom: 0,
                        child: Opacity(
                          opacity: s,
                          child: Icon(
                            left
                                ? CupertinoIcons.chevron_left
                                : CupertinoIcons.chevron_right,
                            size: 13,
                            color: c.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The avatar button at the top right (every screen size). It opens a
/// dropdown: profile and votes, your barangay, dark mode, Settings, Help,
/// About, and Log out (or Log in, for guests).
class _ProfileMenu extends StatelessWidget {
  /// Hide the name next to the avatar (narrow windows).
  final bool compact;

  /// Phones: just the avatar, no name or arrow.
  final bool avatarOnly;
  const _ProfileMenu({required this.compact, this.avatarOnly = false});

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    final itemStyle = MenuItemButton.styleFrom(
      foregroundColor: c.textPrimary,
      iconColor: c.textSecondary,
      minimumSize: const Size(280, 46),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: const TextStyle(
        fontFamily: kFontFamily,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    );
    return MenuAnchor(
      alignmentOffset: const Offset(0, 10),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(c.surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(10),
        shadowColor: WidgetStatePropertyAll(
          Colors.black.withValues(alpha: 0.5),
        ),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(8)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: c.border),
          ),
        ),
      ),
      builder: (context, menu, _) => Tooltip(
        message: 'Account',
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => menu.isOpen ? menu.close() : menu.open(),
            child: Padding(
              padding: avatarOnly
                  ? const EdgeInsets.all(2)
                  : const EdgeInsets.fromLTRB(4, 4, 8, 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Avatar(size: avatarOnly ? 40 : 34),
                  if (!compact) ...[
                    const SizedBox(width: 10),
                    Text(
                      isGuest ? 'Guest' : me!.fullName,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (!avatarOnly) ...[
                    const SizedBox(width: 2),
                    Icon(CupertinoIcons.chevron_down, color: c.textSecondary),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      menuChildren: [
        _header(c),
        Divider(height: 17, color: c.border),
        MenuItemButton(
          style: itemStyle,
          leadingIcon: const Icon(CupertinoIcons.placemark, size: 20),
          trailingIcon: Text(
            myBarangay.value ?? 'Not set',
            style: TextStyle(color: c.textSecondary, fontSize: 13),
          ),
          onPressed: () => pickMyBarangay(context),
          child: const Text('My barangay'),
        ),
        MenuItemButton(
          style: itemStyle,
          leadingIcon: Icon(
            c.isDark ? CupertinoIcons.moon_fill : CupertinoIcons.sun_max,
            size: 20,
          ),
          trailingIcon: Text(
            c.isDark ? 'On' : 'Off',
            style: TextStyle(color: c.textSecondary, fontSize: 13),
          ),
          // Changing themeNotifier.value makes the ValueListenableBuilder
          // in main.dart rebuild MaterialApp with the other theme.
          onPressed: () =>
              themeNotifier.value = c.isDark ? ThemeMode.light : ThemeMode.dark,
          child: const Text('Dark mode'),
        ),
        Divider(height: 17, color: c.border),
        MenuItemButton(
          style: itemStyle,
          leadingIcon: const Icon(CupertinoIcons.slider_horizontal_3, size: 20),
          onPressed: () => openSettings(context),
          child: const Text('Settings'),
        ),
        MenuItemButton(
          style: itemStyle,
          leadingIcon: const Icon(CupertinoIcons.question_circle, size: 20),
          onPressed: () => openHelp(context),
          child: const Text('Help & FAQ'),
        ),
        MenuItemButton(
          style: itemStyle,
          leadingIcon: const Icon(CupertinoIcons.info_circle, size: 20),
          onPressed: () => openAbout(context),
          child: const Text('About AgosAlert'),
        ),
        Divider(height: 17, color: c.border),
        if (isGuest)
          MenuItemButton(
            style: itemStyle,
            leadingIcon: const Icon(
              CupertinoIcons.person_crop_circle,
              size: 20,
            ),
            onPressed: () => logIn(context),
            child: const Text('Log in'),
          )
        else
          MenuItemButton(
            style: itemStyle.copyWith(
              foregroundColor: const WidgetStatePropertyAll(kDanger),
              iconColor: const WidgetStatePropertyAll(kDanger),
            ),
            leadingIcon: const Icon(
              CupertinoIcons.square_arrow_right,
              size: 20,
            ),
            onPressed: () => confirmLogout(context),
            child: const Text('Log out'),
          ),
      ],
    );
  }

  // Name, email, and (for logged-in users) the votes on their uploads.
  Widget _header(AppColors c) {
    return SizedBox(
      width: 280,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _Avatar(size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isGuest ? 'Guest' : me!.fullName,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        isGuest ? 'Browsing as a guest' : me!.email,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: isGuest
                  ? Text(
                      'Guests can only view. Log in to vote and upload.',
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    )
                  // Real counts from report_votes, on the user's active
                  // reports (reports and their votes go after 14 days).
                  : ValueListenableBuilder(
                      valueListenable: floodReports,
                      builder: (context, reports, _) {
                        final mine = reports.where((r) => r.mine);
                        Widget count(IconData icon, int n) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 16, color: c.textSecondary),
                            const SizedBox(width: 6),
                            Text(
                              '$n',
                              style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        );
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Votes on your uploads',
                              style: TextStyle(
                                color: c.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                count(
                                  CupertinoIcons.hand_thumbsup_fill,
                                  mine.fold(0, (n, r) => n + r.upVotes),
                                ),
                                const SizedBox(width: 18),
                                count(
                                  CupertinoIcons.hand_thumbsdown_fill,
                                  mine.fold(0, (n, r) => n + r.downVotes),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Round avatar with the user's initials (a person icon for guests).
class _Avatar extends StatelessWidget {
  final double size;
  const _Avatar({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Indigo-to-blue, like an iOS contact photo without a picture.
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kTileIndigo, kTileBlue],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: isGuest
          ? Icon(
              CupertinoIcons.person_fill,
              color: Colors.white,
              size: size * 0.6,
            )
          : Text(
              me!.initials,
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.36,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }
}

/// One tab in the shell. [offset] = where it sits, in page widths (0 = in
/// place, -1 = one page to the left); null = hidden. Hidden tabs stay in
/// the tree (so they keep their state) but are invisible, can't be tapped,
/// and pause their animations.
class _TabLayer extends StatelessWidget {
  final double? offset;
  final bool current;
  final bool pager;
  final double width;
  final Widget child;
  const _TabLayer({
    required this.offset,
    required this.current,
    required this.pager,
    required this.width,
    required this.child,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final o = offset;
    final shown = o != null && o.abs() < 1;
    // Phones: a real pager, pages side by side, full width. Wider screens:
    // the page drifts 64 px in its direction while cross-fading.
    final dx = o == null ? 0.0 : (pager ? o * width : o * 64);
    final opacity = !shown
        ? 0.0
        : (pager ? 1.0 : (1 - o.abs()).clamp(0.0, 1.0));
    return IgnorePointer(
      // Only the current tab takes taps, even mid-move (so it can be
      // grabbed again); the incoming one waits until it's settled.
      ignoring: !current,
      child: ExcludeSemantics(
        excluding: !current,
        child: Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(dx, 0),
            // Pause hidden tabs' animations (and tell the web map it's
            // hidden, see agos_map_web.dart).
            child: TickerMode(enabled: shown, child: child),
          ),
        ),
      ),
    );
  }
}

/// A soft highlight while the mouse is over [child] (desktop hover, like
/// macOS toolbar buttons). [enabled] false = no highlight (e.g. the
/// selected segment, which already has the thumb).
class _HoverTint extends StatefulWidget {
  final Widget child;
  final double radius;
  final bool enabled;
  const _HoverTint({
    required this.child,
    required this.radius,
    this.enabled = true,
  });

  @override
  State<_HoverTint> createState() => _HoverTintState();
}

class _HoverTintState extends State<_HoverTint> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: c.textPrimary.withValues(
            alpha: _hover && widget.enabled ? 0.06 : 0,
          ),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
        child: widget.child,
      ),
    );
  }
}
