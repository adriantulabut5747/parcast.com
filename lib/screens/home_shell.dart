import 'dart:ui';

import 'package:flutter/cupertino.dart' show CupertinoIcons;

import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/map_glass.dart';
import '../widgets/responsive.dart';
import '../services/prefetch.dart';
import 'account.dart';
import 'weather_tab.dart';
import 'deferred_screens.dart';
import '../widgets/agos_icons.dart';
import '../widgets/check_in.dart';
import '../widgets/my_barangay.dart';

/// Phones only: keeps the phone layout from stretching (wider screens get
/// the website layout, see _wideLayout).
const double kMaxContentWidth = 560;

/// ============================================================
/// HOME SHELL — top bar + the four tabs + bottom nav
/// (Weather, Map, Reports, Help; the + lives in the Reports tab)
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

class HomeShellState extends State<HomeShell> {
  // Which tab is showing right now: 0 Weather, 1 Map, 2 Reports, 3 Help
  // (same order as _tabs and _items below).
  late int _index = widget.initialTab;

  // Tabs are only built the first time they're opened (so, e.g., the map
  // doesn't download tiles until someone opens the Map tab). After that
  // they stay alive, so scroll position and filters are kept.
  late final Set<int> _opened = {_index};

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

  void switchTab(int index) => setState(() {
    _index = index;
    _opened.add(index);
  });

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
    (CupertinoIcons.map, CupertinoIcons.map_fill, 'Map'),
    (CupertinoIcons.news, CupertinoIcons.news_solid, 'Reports'),
    (AgosIcons.lifebuoy, AgosIcons.lifebuoyFill, 'Help'),
  ];

  // All opened tabs are stacked on top of each other, and only the active
  // one is visible (see _TabLayer). This is what keeps each tab's scroll
  // position when you switch away and come back. ValueKey(i) tells Flutter
  // which layer is which tab, so it doesn't mix them up when a newly
  // opened tab gets added to the Stack.
  //
  // [bar] is the top bar's height. Tabs start below it, except the Map:
  // the map runs under the (glass) bar, edge to edge, and gets the bar's
  // height as MediaQuery top padding, so its own buttons start below it.
  Widget _tabStack(int active, double bar) {
    final mq = MediaQuery.of(context);
    return Stack(
      children: [
        for (var i = 0; i < _tabs.length; i++)
          if (_opened.contains(i))
            _TabLayer(
              key: ValueKey(i),
              active: i == active,
              child: i == 1
                  ? MediaQuery(
                      data: mq.copyWith(
                        padding: mq.padding.copyWith(top: mq.padding.top + bar),
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
                  Positioned.fill(child: _tabStack(_index, _phoneBarHeight)),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    // Phones: only the Map needs a bar background (other
                    // tabs scroll below it on the plain page).
                    child: _barGlass(c, filled: _index == 1, child: _topBar(c)),
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
              Positioned.fill(child: _tabStack(active, _webBarHeight)),
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
          for (var i = 0; i < 4; i++) _webNavItem(c, i, i == active, compact),
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

  Widget _webNavItem(AppColors c, int i, bool selected, bool compact) {
    final (outline, filled, label) = _items[i];
    final fg = selected ? c.accent : c.textSecondary;
    final Widget icon = Icon(selected ? filled : outline, color: fg, size: 20);
    final item = Material(
      color: selected
          ? c.textPrimary.withValues(alpha: c.isDark ? 0.1 : 0.06)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        hoverColor: c.textPrimary.withValues(alpha: 0.05),
        onTap: () => switchTab(i),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 14 : 16,
            vertical: 10,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              if (!compact) ...[
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Semantics(
        button: true,
        selected: selected,
        label: compact ? label : null,
        child: compact ? Tooltip(message: label, child: item) : item,
      ),
    );
  }

  // ------------------------------------------------------------
  // Phone layout
  // ------------------------------------------------------------

  // The bell, with the number of unread alerts. readAlerts (demo_data.dart)
  // is a ValueNotifier: ValueListenableBuilder rebuilds just this button
  // when it changes, so the badge updates without rebuilding the shell.
  Widget _bell(AppColors c) => ValueListenableBuilder<Set<String>>(
    valueListenable: readAlerts,
    builder: (context, _, _) => _roundButton(
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
                    fontSize: 18,
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
                      fontSize: 9,
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
    // p slides from the old tab number to the new one (on a spring), and
    // every tab's "how open am I" (0..1) comes from it, so width, highlight,
    // icon size and label all move together, and the tab widths always add
    // up to the pill's width.
    return TweenAnimationBuilder<double>(
      tween: Tween(end: _index.toDouble()),
      duration: const Duration(milliseconds: 450),
      curve: kSnappyCurve,
      builder: (context, p, _) => LayoutBuilder(
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
      ),
    );
  }

  // The pill: frosted glass with the lit edge. It's clipped (the blur
  // needs that), so it sits UNDER the tabs, whose icons may stick out.
  Widget _navGlass(AppColors c) => ClipRRect(
    borderRadius: BorderRadius.circular(28),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
      child: CustomPaint(
        foregroundPainter: GlassEdgePainter(radius: 28, dark: c.isDark),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: c.surface.withValues(alpha: c.isDark ? 0.62 : 0.78),
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
                            fontSize: 11.5,
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

/// The + (report a flood, "I'm safe", SOS). Lives in the Reports tab's
/// header since the nav became four tabs.
class NewActionsButton extends StatelessWidget {
  final double size;
  const NewActionsButton({this.size = 44, super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    return Tooltip(
      message: 'Report, I\'m safe, SOS',
      child: Semantics(
        button: true,
        label: 'New: report a flood, I\'m safe, or SOS',
        child: PressableScale(
          onTap: () => showNewActions(context),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF3D9BFF), kBlue],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
              boxShadow: [
                BoxShadow(
                  color: kBlue.withValues(alpha: c.isDark ? 0.35 : 0.3),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              CupertinoIcons.plus,
              color: Colors.white,
              size: size * 0.46,
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
        fontSize: 14,
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
                      isGuest ? 'Guest' : kDemoUserName,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 14,
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
                        isGuest ? 'Guest' : kDemoUserName,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        isGuest ? 'Browsing as a guest' : kDemoUserEmail,
                        overflow: TextOverflow.ellipsis,
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
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Votes on your uploads',
                                style: TextStyle(
                                  color: c.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SampleBadge(),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              CupertinoIcons.hand_thumbsup_fill,
                              size: 16,
                              color: kSafe,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$kMyUpVotesReceived',
                              style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 18),
                            const Icon(
                              CupertinoIcons.hand_thumbsdown_fill,
                              size: 16,
                              color: kDanger,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$kMyDownVotesReceived',
                              style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
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
              kDemoUserInitials,
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.36,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }
}

/// One tab in the shell. The active tab fades and slides in; hidden tabs
/// are invisible, can't be tapped, and pause their animations.
class _TabLayer extends StatelessWidget {
  final bool active;
  final Widget child;
  const _TabLayer({required this.active, required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    const duration = Duration(milliseconds: 280);
    // For a hidden tab (active == false):
    //   IgnorePointer    -> taps pass through it (it's invisible but still
    //                       in the Stack, so otherwise it would block taps).
    //   ExcludeSemantics -> screen readers skip it.
    //   opacity 0        -> invisible.
    //   Offset(0, 0.02)  -> sits 2% lower, so when it becomes active it
    //                       slides up into place while fading in.
    return IgnorePointer(
      ignoring: !active,
      child: ExcludeSemantics(
        excluding: !active,
        child: AnimatedOpacity(
          opacity: active ? 1 : 0,
          duration: duration,
          curve: Curves.easeOut,
          child: AnimatedSlide(
            offset: active ? Offset.zero : const Offset(0, 0.02),
            duration: duration,
            curve: Curves.easeOutCubic,
            // Pause only the tab's own animations. TickerMode must stay
            // INSIDE the fade: wrapped around it, it also froze the
            // fade-out, so old tabs stayed visible on top of each other.
            child: TickerMode(enabled: active, child: child),
          ),
        ),
      ),
    );
  }
}

/// The + button's actions: Report flood, I'm safe, SOS. They pop up from
/// the button in a fan (phones) or under it (wider screens), over a dark
/// backdrop; tap outside or the x to close. [context] must be inside
/// HomeShell, so the actions can open their screens.
void showNewActions(BuildContext context) {
  final wide = isWideScreen(context);
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withValues(alpha: 0.65),
    transitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (dialog, _, _) {
      void run(void Function(BuildContext) action) {
        Navigator.of(dialog).pop();
        action(context);
      }

      final actions = [
        (AgosIcons.flood, 'Report flood', kBlue, () => run(openReportIncident)),
        (
          CupertinoIcons.checkmark_shield_fill,
          'I\'m safe',
          kSafe,
          () => run(showImSafe),
        ),
        (
          CupertinoIcons.exclamationmark_triangle_fill,
          'SOS',
          kDanger,
          () => run(openSos),
        ),
      ];
      // Each button rises and fades in a little after the one before.
      Widget button(int i) {
        final (icon, label, color, onTap) = actions[i];
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 420 + i * 90),
          curve: kBouncyCurve,
          builder: (context, v, child) => Opacity(
            opacity: v.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, 30 * (1 - v)),
              child: child,
            ),
          ),
          child: Semantics(
            button: true,
            label: label,
            child: PressableScale(
              onTap: onTap,
              child: SizedBox(
                width: 92,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == 2 ? kDanger : const Color(0xFF232326),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                      child: Icon(
                        icon,
                        color: i == 2 ? Colors.white : color,
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      final row = Row(
        mainAxisSize: MainAxisSize.min,
        children: [button(0), button(1), button(2)],
      );
      final close = Semantics(
        button: true,
        label: 'Close',
        child: PressableScale(
          onTap: () => Navigator.of(dialog).pop(),
          child: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF2C2C30),
            ),
            child: const Icon(
              CupertinoIcons.xmark,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      );
      // Material gives the labels the app's text style (without it,
      // Flutter marks bare text with a yellow underline).
      return Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: wide
              ? Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 76, 120, 0),
                    child: row,
                  ),
                )
              : Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    // The x lands where the + was (the nav's middle).
                    padding: const EdgeInsets.only(bottom: 12 + 68 - 42),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [row, const SizedBox(height: 22), close],
                    ),
                  ),
                ),
        ),
      );
    },
  );
}
