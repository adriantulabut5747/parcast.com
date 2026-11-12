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
import 'home_tab.dart';
import 'deferred_screens.dart';
import '../widgets/agos_icons.dart';

/// Phones only: keeps the phone layout from stretching (wider screens get
/// the website layout, see _wideLayout).
const double kMaxContentWidth = 560;

/// ============================================================
/// HOME SHELL — top bar + the five tabs + floating bottom nav
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
  // Which tab is showing right now: 0 Home, 1 Map, 2 Alerts,
  // 3 Assistance, 4 More (same order as _tabs and _items below).
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
  }

  void switchTab(int index) => setState(() {
    _index = index;
    _opened.add(index);
  });

  // The Map tab's code is downloaded the first time it's opened.
  static final _tabs = [
    const HomeTab(),
    deferredMapTab(),
    deferredAlertsTab(),
    deferredAssistanceTab(),
    deferredMoreTab(),
  ];

  // One entry per bottom-nav button: (icon when not selected, icon when
  // selected, label). These are Dart "records", unpacked in _navItem with
  // `final (outline, filled, label) = _items[i];`.
  static const _items = [
    (CupertinoIcons.house, CupertinoIcons.house_fill, 'Home'),
    (CupertinoIcons.map, CupertinoIcons.map_fill, 'Map'),
    (CupertinoIcons.bell, CupertinoIcons.bell_fill, 'Alerts'),
    (AgosIcons.lifebuoy, AgosIcons.lifebuoyFill, 'Assistance'),
    (
      CupertinoIcons.square_grid_2x2,
      CupertinoIcons.square_grid_2x2_fill,
      'More',
    ),
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
    // There's no More tab up top (its items live in the profile menu), so
    // if the window was widened while More was open, show Home instead.
    final active = _index == 4 ? 0 : _index;
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
                ValueListenableBuilder<Set<String>>(
                  valueListenable: readAlerts,
                  builder: (context, _, _) => _roundButton(
                    c,
                    icon: CupertinoIcons.bell,
                    tooltip: 'Notifications',
                    badge: unreadAlertCount,
                    onTap: () => switchTab(2),
                  ),
                ),
                const SizedBox(width: 8),
                _roundButton(
                  c,
                  icon: c.isDark
                      ? CupertinoIcons.sun_max_fill
                      : CupertinoIcons.moon_fill,
                  tooltip: c.isDark
                      ? 'Switch to light mode'
                      : 'Switch to dark mode',
                  onTap: () => themeNotifier.value = c.isDark
                      ? ThemeMode.light
                      : ThemeMode.dark,
                ),
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
    Widget icon = Icon(selected ? filled : outline, color: fg, size: 20);
    // Unread dot on Alerts, like the phone's bottom nav.
    if (i == 2) {
      icon = ValueListenableBuilder<Set<String>>(
        valueListenable: readAlerts,
        builder: (context, _, child) => Badge(
          isLabelVisible: unreadAlertCount > 0,
          smallSize: 8,
          backgroundColor: kDanger,
          child: child,
        ),
        child: icon,
      );
    }
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
          // readAlerts (demo_data.dart) is a ValueNotifier holding the ids
          // of the alerts the user has read. ValueListenableBuilder rebuilds
          // just this bell button whenever that set changes, so the red
          // unread-count badge updates without rebuilding the whole shell.
          ValueListenableBuilder<Set<String>>(
            valueListenable: readAlerts,
            builder: (context, _, _) => _roundButton(
              c,
              icon: CupertinoIcons.bell,
              tooltip: 'Alerts',
              badge: unreadAlertCount,
              onTap: () => switchTab(2),
            ),
          ),
          const SizedBox(width: 8),
          _roundButton(
            c,
            icon: c.isDark
                ? CupertinoIcons.sun_max_fill
                : CupertinoIcons.moon_fill,
            tooltip: c.isDark ? 'Switch to light mode' : 'Switch to dark mode',
            // Changing themeNotifier.value makes the ValueListenableBuilder
            // in main.dart rebuild MaterialApp with the other theme.
            onTap: () => themeNotifier.value = c.isDark
                ? ThemeMode.light
                : ThemeMode.dark,
          ),
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

  Widget _bottomNav(AppColors c) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: CustomPaint(
          foregroundPainter: GlassEdgePainter(radius: 28, dark: c.isDark),
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              color: c.surface.withValues(alpha: c.isDark ? 0.55 : 0.75),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: c.shadow,
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            // LayoutBuilder tells us how wide the bar actually is, so we can
            // work out where each button sits: 5 equal slots, each itemWidth
            // wide, and tab i starts at x = itemWidth * i.
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth / _items.length;
                return Stack(
                  children: [
                    // Sliding highlight behind the selected tab. When _index
                    // changes, AnimatedPositioned slides it from the old
                    // `left` to the new one. "+ 8" and "- 16" leave an 8 px
                    // gap on each side of the pill. A snappy spring: it
                    // overshoots slightly, then settles.
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 450),
                      curve: kSnappyCurve,
                      left: itemWidth * _index + 8,
                      top: 8,
                      bottom: 8,
                      width: itemWidth - 16,
                      child: Container(
                        decoration: BoxDecoration(
                          color: c.textPrimary.withValues(
                            alpha: c.isDark ? 0.12 : 0.07,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < _items.length; i++)
                          Expanded(child: _navItem(c, i)),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(AppColors c, int i) {
    final selected = i == _index;
    final (outline, filled, label) = _items[i];
    final color = selected ? c.accent : c.textSecondary;
    // Semantics describes the button for screen readers (used by blind
    // users): "Map, button, selected". The icon alone doesn't say that.
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: PressableScale(
        onTap: () => switchTab(i),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedScale(
                  scale: selected ? 1.12 : 1,
                  duration: const Duration(milliseconds: 650),
                  curve: kBouncyCurve,
                  child: Icon(
                    selected ? filled : outline,
                    color: color,
                    size: 23,
                  ),
                ),
                // Tab 2 (Alerts) gets a small red dot while there are
                // unread alerts.
                if (i == 2)
                  ValueListenableBuilder<Set<String>>(
                    valueListenable: readAlerts,
                    builder: (context, _, _) => unreadAlertCount == 0
                        ? const SizedBox.shrink()
                        : Positioned(
                            top: -1,
                            right: -2,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: kDanger,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontFamily: kFontFamily,
                color: color,
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w400,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

/// The avatar button at the top right on tablets and desktops. It opens a
/// dropdown with what the More tab has on phones: profile and votes,
/// Settings, Help, About, and Log out (or Log in, for guests).
class _ProfileMenu extends StatelessWidget {
  final bool compact;
  const _ProfileMenu({required this.compact});

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
              padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _Avatar(size: 34),
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
                  const SizedBox(width: 2),
                  Icon(CupertinoIcons.chevron_down, color: c.textSecondary),
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
      decoration: const BoxDecoration(color: kGraphite, shape: BoxShape.circle),
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
