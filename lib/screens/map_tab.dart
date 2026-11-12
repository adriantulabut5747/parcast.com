import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../data/demo_data.dart';
import '../services/weather.dart';
import '../theme.dart';
import '../widgets/agos_icons.dart';
import '../widgets/agos_map.dart';
import '../widgets/common.dart';
import '../widgets/flood_depth.dart';
import '../widgets/links.dart';
import '../widgets/map_glass.dart';
import '../widgets/responsive.dart';
import '../widgets/user_profile.dart';
import '../widgets/vote_bar.dart';
import 'deferred_screens.dart';

/// ============================================================
/// MAP TAB — Mabalacat City in 3D, with flood reports and shelters
/// ============================================================
///
/// The map itself is AgosMap (widgets/agos_map.dart): MapLibre in the
/// browser, drawn from map files that ship with the app (web/map/, made by
/// tools/make_map.py). It opens flat, like a paper map; the 3D button (or
/// tilting with two fingers) raises the buildings and the hills.
///
/// Everything else floats on top, iPhone Maps style:
///   phones/tablets  small layer chips top left (+ the depth legend on
///                   demand), round controls top right, and a sheet at
///                   the bottom: a thin bar until dragged up, then the
///                   reports and shelters. Reporting is the + in the nav.
///   desktop         a side panel with the lists, the map next to it.
/// Anything floating over the web map is wrapped in MapGlass, which gives
/// it real blur and stops its taps from reaching the map.
class MapTab extends StatefulWidget {
  const MapTab({super.key});

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  final _map = AgosMapController();
  bool _showZones = true;
  bool _showCenters = true;
  // The pin that's highlighted (bigger) on the map and in the lists.
  String? _selected;

  // The report cards in the bottom panel: deepest water first.
  late final List<FloodZone> _zones = activeFloodZones.toList()
    ..sort((a, b) => b.depthCm.compareTo(a.depthCm));

  // Zoom levels: each +1 doubles the detail. 13 shows the whole city,
  // 18 single streets and buildings.
  static const _startZoom = 13.3;
  static const _pinZoom = 15.5;

  static String _zoneId(FloodZone z) => 'zone-${z.barangay}';
  static String _centerId(EvacuationCenter e) => 'center-${e.name}';

  late final List<MapPin> _pins = [
    for (final z in _zones)
      MapPin(
        id: _zoneId(z),
        kind: PinKind.flood,
        point: z.point,
        color: z.risk.color,
        icon: AgosIcons.flood,
        title: z.barangay,
        chip: FloodLevel.of(z.depthCm) == FloodLevel.dry
            ? 'Dry'
            : formatCm(z.depthCm),
        pulse: z.risk == RiskLevel.high,
        a11y: 'Brgy. ${z.barangay}, ${formatCm(z.depthCm)}',
      ),
    for (final e in kEvacCenters)
      MapPin(
        id: _centerId(e),
        kind: PinKind.shelter,
        point: e.point,
        color: e.open ? kSafe : kGray,
        icon: e.icon,
        title: e.name,
        a11y: '${e.name}, evacuation center, ${e.open ? 'open' : 'standby'}',
      ),
  ];

  // A see-through circle around each report (bigger for high risk).
  late final List<MapZone> _rings = [
    for (final z in _zones)
      MapZone(z.point, z.risk == RiskLevel.high ? 650 : 480, z.risk.color),
  ];

  // "View on map" on the Home feed sets focusedZone and switches to this
  // tab; we then fly to that pin and open it. Checked once at start too,
  // in case this tab was only just opened (and downloaded) for it.
  @override
  void initState() {
    super.initState();
    focusedZone.addListener(_openFocused);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openFocused());
  }

  @override
  void dispose() {
    focusedZone.removeListener(_openFocused);
    _map.dispose();
    super.dispose();
  }

  void _openFocused() {
    final z = focusedZone.value;
    if (z == null || !mounted) return;
    focusedZone.value = null;
    _showZone(context, z);
  }

  void _onPinTap(String id) {
    for (final z in _zones) {
      if (_zoneId(z) == id) return _showZone(context, z);
    }
    for (final e in kEvacCenters) {
      if (_centerId(e) == id) return _showCenter(context, e);
    }
  }

  // Highlights a pin (and its row in the lists) and flies there.
  void _focus(String id, LatLng point) {
    setState(() => _selected = id);
    _map.flyTo(point, zoom: _pinZoom);
  }

  void _recenter() {
    setState(() => _selected = null);
    _map.reset(kMabalacatCenter, _startZoom);
  }

  Set<PinKind> get _hidden => {
    if (!_showZones) PinKind.flood,
    if (!_showCenters) PinKind.shelter,
  };

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    // Desktop: a side panel (lists, layers, report) next to the map.
    // Phones and tablets: everything floats on the map.
    if (screenSizeOf(context) == ScreenSize.desktop) return _desktop(c);
    return _floatingLayout(c, wide: isWideScreen(context));
  }

  Widget _mapView(EdgeInsets padding) => AgosMap(
    controller: _map,
    pins: _pins,
    zones: _rings,
    hidden: _hidden,
    selectedId: _selected,
    onPinTap: _onPinTap,
    zoom: _startZoom,
    padding: padding,
  );

  // ------------------------------------------------------------ phones
  // Nov 2026: the big header and bottom panel covered half the map, so
  // phones now get iPhone-Maps-style pieces: a row of small chips at the
  // top, the round controls on the right, and a sheet at the bottom that
  // is just a thin bar until you drag it up (or tap it).

  // The bottom sheet: [_peek] tall when closed. _dragHeight is its height
  // while a finger is dragging it (null otherwise).
  static const _peek = 64.0;
  bool _sheetOpen = false;
  double? _dragHeight;
  bool _legendOpen = false;

  double _sheetMax(BoxConstraints box) => math.min(box.maxHeight * 0.5, 440.0);

  Widget _floatingLayout(AppColors c, {required bool wide}) {
    // The map runs under the shell's glass top bar; `top` is that bar's
    // height (handed down as MediaQuery padding by HomeShell).
    final top = MediaQuery.paddingOf(context).top;
    // Phones: the sheet sits above the floating bottom nav. Tablets have
    // none, and their sheet doesn't stretch across the whole screen.
    final bottom = wide ? 16.0 : 96.0;
    return LayoutBuilder(
      builder: (context, box) {
        final max = _sheetMax(box);
        final height = _dragHeight ?? (_sheetOpen ? max : _peek);
        return Stack(
          children: [
            Positioned.fill(
              child: _mapView(
                EdgeInsets.fromLTRB(0, top + 60, 64, bottom + _peek + 8),
              ),
            ),
            Positioned(
              top: top + 10,
              left: 12,
              right: 12,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _chipsAndLegend(c)),
                  const SizedBox(width: 10),
                  _controls(c, zoomButtons: wide),
                ],
              ),
            ),
            // The sheet. While dragging it follows the finger instantly
            // (duration 0); let go and it springs open or closed.
            AnimatedPositioned(
              duration: _dragHeight == null
                  ? const Duration(milliseconds: 420)
                  : Duration.zero,
              curve: kSnappyCurve,
              left: 12,
              right: wide ? null : 12,
              width: wide ? 420 : null,
              bottom: bottom,
              height: height,
              child: _sheet(c, max: max, height: height),
            ),
          ],
        );
      },
    );
  }

  // Small glass chips: what's on the map, and the depth legend on demand.
  Widget _chipsAndLegend(AppColors c) {
    final open = kEvacCenters.where((e) => e.open).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _layerChip(
              c,
              icon: AgosIcons.flood,
              label: 'Reports ${_zones.length}',
              on: _showZones,
              onTap: () => setState(() => _showZones = !_showZones),
            ),
            _layerChip(
              c,
              icon: CupertinoIcons.house_alt_fill,
              label: 'Shelters $open/${kEvacCenters.length}',
              on: _showCenters,
              onTap: () => setState(() => _showCenters = !_showCenters),
            ),
            _layerChip(
              c,
              icon: CupertinoIcons.info_circle,
              label: 'Depth',
              on: _legendOpen,
              plain: true,
              onTap: () => setState(() => _legendOpen = !_legendOpen),
            ),
          ],
        ),
        // AnimatedSize grows / shrinks smoothly when the legend appears.
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topLeft,
          child: !_legendOpen
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SizedBox(
                    width: 240,
                    child: _glass(
                      c,
                      radius: 18,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                        child: _legend(c),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  // A layer chip. On = solid (white in dark mode); off = glass with the
  // label crossed out a little (faded). [plain] = a toggle that isn't a
  // layer (the legend), shown as glass either way.
  Widget _layerChip(
    AppColors c, {
    required IconData icon,
    required String label,
    required bool on,
    required VoidCallback onTap,
    bool plain = false,
  }) {
    final solid = on && !plain;
    final fg = solid ? c.onInverse : c.textPrimary;
    return Semantics(
      button: true,
      toggled: on,
      label: label,
      child: PressableScale(
        onTap: onTap,
        child: MapGlass(
          radius: 18,
          blur: !solid,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: solid
                  ? c.inverse
                  : c.surface.withValues(alpha: c.isDark ? 0.62 : 0.78),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: solid ? c.inverse : c.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: fg.withValues(alpha: on ? 1 : 0.5)),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: fg.withValues(alpha: on ? 1 : 0.55),
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

  // The bottom sheet: a handle and a one-line summary; dragged up, the
  // reports (deepest first) and the shelters.
  Widget _sheet(AppColors c, {required double max, required double height}) {
    final open = kEvacCenters.where((e) => e.open).length;
    void toggle() => setState(() => _sheetOpen = !_sheetOpen);
    final header = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: toggle,
      onVerticalDragUpdate: (d) =>
          setState(() => _dragHeight = (height - d.delta.dy).clamp(_peek, max)),
      onVerticalDragEnd: (d) => setState(() {
        final v = d.primaryVelocity ?? 0; // + = moving down
        final h = _dragHeight ?? height;
        // A flick decides; a slow drag snaps to whichever end is closer.
        _sheetOpen = v < -300 || (v <= 300 && h > (_peek + max) / 2);
        _dragHeight = null;
      }),
      child: SizedBox(
        height: _peek,
        child: Column(
          children: [
            const SizedBox(height: 7),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.textSecondary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const LiveDot(color: kDanger),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${_zones.length} reports · $open shelters open',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: kDisplayFont,
                          color: c.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SampleBadge(),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: _sheetOpen ? 0.5 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        CupertinoIcons.chevron_up,
                        size: 16,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return Semantics(
      label: _sheetOpen ? 'Reports list, open' : 'Reports list. Tap to open',
      child: _glass(
        c,
        radius: 24,
        child: Column(
          children: [
            header,
            // The list fades in as the sheet rises.
            Expanded(
              child: Opacity(
                opacity: ((height - _peek) / 120).clamp(0.0, 1.0),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: FieldLabel('Deepest first'),
                    ),
                    for (final z in _zones) _pinRow(c, z),
                    const SizedBox(height: 8),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: FieldLabel('Evacuation centers'),
                    ),
                    for (final e in kEvacCenters) _centerRow(c, e),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glass(AppColors c, {required Widget child, double radius = 22}) {
    return MapGlass(
      radius: radius,
      child: GlassCard(radius: radius, padding: EdgeInsets.zero, child: child),
    );
  }

  // The round controls, iPhone Maps style: one glass capsule (3D, back to
  // the city, and zoom on bigger screens), with a compass under it that
  // only appears while the map is turned.
  Widget _controls(AppColors c, {required bool zoomButtons}) {
    Widget divider() => Container(
      width: 26,
      height: 1,
      color: c.textPrimary.withValues(alpha: 0.12),
    );
    return Column(
      children: [
        _glass(
          c,
          radius: 24,
          child: SizedBox(
            width: 48,
            child: Column(
              children: [
                ValueListenableBuilder<double>(
                  valueListenable: _map.pitch,
                  builder: (context, pitch, _) {
                    final is3d = pitch > 12;
                    return _ctrlButton(
                      c,
                      tooltip: is3d ? 'Flat view' : '3D view',
                      onTap: () => _map.set3d(!is3d),
                      child: Text(
                        is3d ? '2D' : '3D',
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    );
                  },
                ),
                divider(),
                _ctrlButton(
                  c,
                  tooltip: 'Back to the city',
                  onTap: _recenter,
                  child: Icon(
                    CupertinoIcons.location_fill,
                    size: 19,
                    color: c.accent,
                  ),
                ),
                if (zoomButtons) ...[
                  divider(),
                  _ctrlButton(
                    c,
                    tooltip: 'Zoom in',
                    onTap: () => _map.zoomBy(1),
                    child: Icon(
                      CupertinoIcons.plus,
                      size: 20,
                      color: c.textPrimary,
                    ),
                  ),
                  divider(),
                  _ctrlButton(
                    c,
                    tooltip: 'Zoom out',
                    onTap: () => _map.zoomBy(-1),
                    child: Icon(
                      CupertinoIcons.minus,
                      size: 20,
                      color: c.textPrimary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        ValueListenableBuilder<double>(
          valueListenable: _map.bearing,
          builder: (context, bearing, _) {
            final turned = bearing.abs() > 1;
            return AnimatedScale(
              scale: turned ? 1 : 0,
              duration: const Duration(milliseconds: 450),
              curve: turned ? kBouncyCurve : Curves.easeIn,
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _glass(
                  c,
                  radius: 24,
                  child: _ctrlButton(
                    c,
                    tooltip: 'Turn north up',
                    onTap: _map.resetNorth,
                    child: Transform.rotate(
                      angle: -bearing * math.pi / 180,
                      child: CustomPaint(
                        size: const Size(26, 26),
                        painter: _CompassPainter(c.textPrimary),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _ctrlButton(
    AppColors c, {
    required String tooltip,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Tooltip(
      message: tooltip,
      child: PressableScale(
        onTap: onTap,
        child: SizedBox(width: 48, height: 48, child: Center(child: child)),
      ),
    );
  }

  // The depth scale, low to high (same cut-offs as flood_depth.dart).
  Widget _legend(AppColors c) {
    Widget step(Color color, String label) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 4,
            margin: const EdgeInsets.only(right: 3),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STREET FLOOD DEPTH',
          style: TextStyle(
            color: c.textSecondary,
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            step(kSafe, '≤ 20 cm'),
            step(kCaution, '21–50'),
            step(kDanger, '50+ cm'),
          ],
        ),
      ],
    );
  }

  // ----------------------------------------------------------- desktop
  // Desktop: the map fills the whole window (under the glass top bar),
  // and the side panel, controls and legend float on it as glass.
  Widget _desktop(AppColors c) {
    final top = MediaQuery.paddingOf(context).top;
    const gap = 16.0;
    const panel = 360.0;
    const mapLeft = panel + gap * 2;
    return Stack(
      children: [
        Positioned.fill(
          child: _mapView(
            const EdgeInsets.fromLTRB(
              mapLeft,
              gap,
              72,
              60,
            ).copyWith(top: top + gap),
          ),
        ),
        Positioned(
          top: top + gap,
          left: gap,
          bottom: gap,
          width: panel,
          child: _sidePanel(c),
        ),
        Positioned(
          top: top + gap,
          right: gap,
          child: _controls(c, zoomButtons: true),
        ),
        Positioned(
          left: mapLeft,
          bottom: gap,
          width: 280,
          child: _glass(
            c,
            radius: 18,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: _legend(c),
            ),
          ),
        ),
      ],
    );
  }

  // Desktop: everything that floats on the phone map, as a quiet column:
  // what to show, the reports (deepest water first), the shelters, and a
  // way to add a report.
  Widget _sidePanel(AppColors c) {
    return _glass(
      c,
      radius: 24,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Flood map',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(width: 10),
                const SampleBadge(),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Reports from residents · Mabalacat City',
              style: TextStyle(color: c.textSecondary, fontSize: 12.5),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SelectChip(
                  label: 'Flood zones · ${_zones.length}',
                  icon: AgosIcons.flood,
                  selected: _showZones,
                  onTap: () => setState(() => _showZones = !_showZones),
                ),
                SelectChip(
                  label: 'Evacuation · ${kEvacCenters.length}',
                  icon: CupertinoIcons.house_alt_fill,
                  color: kSafe,
                  selected: _showCenters,
                  onTap: () => setState(() => _showCenters = !_showCenters),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                // No automatic top padding (the tab passes the top bar's
                // height down as MediaQuery padding).
                padding: EdgeInsets.zero,
                children: [
                  const FieldLabel('Deepest first'),
                  for (final z in _zones) _pinRow(c, z),
                  const SizedBox(height: 10),
                  const FieldLabel('Evacuation centers'),
                  for (final e in kEvacCenters) _centerRow(c, e),
                ],
              ),
            ),
            const SizedBox(height: 14),
            PrimaryButton(
              label: 'Report flooding',
              icon: CupertinoIcons.plus,
              onPressed: () => openReportIncident(context),
            ),
          ],
        ),
      ),
    );
  }

  // A pressable row in the side panel, tinted while its pin is picked.
  Widget _row(
    AppColors c, {
    required String id,
    required VoidCallback onTap,
    required Widget leading,
    required String title,
    required String subtitle,
  }) {
    final selected = _selected == id;
    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? c.surfaceAlt : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            SizedBox(width: 58, child: leading),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: c.textSecondary.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pinRow(AppColors c, FloodZone z) => _row(
    c,
    id: _zoneId(z),
    onTap: () => _showZone(context, z),
    leading: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '${z.depthCm.round()}',
            style: TextStyle(
              color: z.risk.color,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          TextSpan(
            text: ' cm',
            style: TextStyle(color: c.textSecondary, fontSize: 11),
          ),
        ],
      ),
    ),
    title: 'Brgy. ${z.barangay}',
    subtitle: '${FloodLevel.of(z.depthCm).label} · ${z.updated}',
  );

  Widget _centerRow(AppColors c, EvacuationCenter e) => _row(
    c,
    id: _centerId(e),
    onTap: () => _showCenter(context, e),
    leading: Align(
      alignment: Alignment.centerLeft,
      child: IconBadge(
        e.icon,
        e.open ? kSafe : kGray,
        size: 34,
        squircle: true,
      ),
    ),
    title: e.name,
    subtitle: e.open
        ? 'Open · ${e.occupants} of ${e.capacity} people'
        : 'Standby · not open yet',
  );

  // ------------------------------------------------------------ sheets
  // Tapping a flood pin (or its card/row): fly the map to it, then slide
  // up a details sheet. `sheet` is the sheet's own context, used to close
  // it (Navigator.of(sheet).pop()) before opening Google Maps.
  void _showZone(BuildContext context, FloodZone z) {
    final color = z.risk.color;
    _focus(_zoneId(z), z.point);
    showAppSheet(
      context,
      maxWidth: 600,
      builder: (sheet) {
        final c = AppColors(sheet);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ZonePhoto(zone: z),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Brgy. ${z.barangay}',
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Mabalacat City · Updated ${z.updated}',
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: StatusPill('${z.risk.label} risk', color),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Who posted it. Tap the name for their profile card.
            PostedBy(z.uploader),
            const SizedBox(height: 12),
            _PinDates(zone: z),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1, color: c.border),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DepthGauge(depthCm: z.depthCm, color: color),
                const SizedBox(width: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: DepthReadout(depthCm: z.depthCm),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              z.note,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            // Guidance as a quote-style block: a thin colored bar on the
            // left instead of a filled box.
            Container(
              padding: const EdgeInsets.only(left: 12),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: color, width: 3)),
              ),
              child: Text(
                _guidance(z.risk),
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(height: 18),
            VoteBar(zone: z),
            const SizedBox(height: 22),
            PrimaryButton(
              label: 'Directions',
              icon: CupertinoIcons.arrow_up_right_diamond_fill,
              onPressed: () {
                Navigator.of(sheet).pop();
                openDirections(context, z.point);
              },
            ),
          ],
        );
      },
    );
  }

  void _showCenter(BuildContext context, EvacuationCenter e) {
    _focus(_centerId(e), e.point);
    showAppSheet(
      context,
      builder: (sheet) {
        final c = AppColors(sheet);
        final color = e.open ? kSafe : kGray;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconBadge(e.icon, color, size: 48, squircle: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.name,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Evacuation center · Brgy. ${e.barangay}',
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
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _statBox(
                    c,
                    'Status',
                    e.open ? 'Open' : 'Standby',
                    color,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statBox(
                    c,
                    'Occupancy',
                    '${e.occupants}/${e.capacity}',
                    c.accent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statBox(
                    c,
                    'Distance',
                    '${e.distanceKm} km',
                    c.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Directions',
              icon: CupertinoIcons.arrow_up_right_diamond_fill,
              onPressed: () {
                Navigator.of(sheet).pop();
                openDirections(context, e.point);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _statBox(AppColors c, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: c.textSecondary, fontSize: 11)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // A "switch expression": picks the text that matches the risk level.
  // Dart checks that every RiskLevel is covered, so adding a new level
  // later won't compile until it gets a message here too.
  String _guidance(RiskLevel risk) => switch (risk) {
    RiskLevel.high => 'Move to higher ground now and avoid this area until the water goes down.',
    RiskLevel.moderate => 'Stay alert and keep checking for updates. Avoid unnecessary travel here.',
    RiskLevel.normal => 'Conditions are normal. No action needed right now.',
  };
}

/// The compass needle: red half points north, gray half south.
class _CompassPainter extends CustomPainter {
  final Color color;
  _CompassPainter(this.color);

  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final r = s.width / 2;
    final north = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + r * 0.3, c.dy)
      ..lineTo(c.dx - r * 0.3, c.dy)
      ..close();
    final south = Path()
      ..moveTo(c.dx, c.dy + r)
      ..lineTo(c.dx + r * 0.3, c.dy)
      ..lineTo(c.dx - r * 0.3, c.dy)
      ..close();
    canvas.drawPath(north, Paint()..color = kDanger);
    canvas.drawPath(south, Paint()..color = color.withValues(alpha: 0.35));
  }

  @override
  bool shouldRepaint(_CompassPainter old) => old.color != color;
}

/// "Sample photo" label and photo credit, on a dark fade so it stays
/// readable on any photo.
class _PhotoCredit extends StatelessWidget {
  const _PhotoCredit();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 18, 12, 8),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x00000000), Color(0x99000000)],
          ),
        ),
        child: const Text(
          kFloodPhotoCredit,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// The photo at the top of a flood pin's sheet. Until a real photo
/// exists (see FloodZone.photo), shows a calm placeholder with water
/// drawn at the same depth as the gauge, so it still says something.
class _ZonePhoto extends StatelessWidget {
  final FloodZone zone;
  const _ZonePhoto({required this.zone});

  @override
  Widget build(BuildContext context) {
    final color = zone.risk.color;
    // 0 cm -> no water, 180 cm -> water fills 70% of the placeholder.
    final fill = (zone.depthCm / DepthGauge.maxCm).clamp(0.0, 1.0) * 0.7;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.asset(
          zone.photo,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          // Once the photo has loaded (frame != null), lay the credit
          // over its bottom edge. The license (CC BY-SA) requires it.
          frameBuilder: (context, child, frame, _) => frame == null
              ? child
              : Stack(
                  fit: StackFit.expand,
                  children: [child, const _PhotoCredit()],
                ),
          errorBuilder: (_, _, _) => LayoutBuilder(
            builder: (context, box) => Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [kGraphite, kInk],
                ),
              ),
              child: Stack(
                children: [
                  if (fill > 0)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: AnimatedWaves(
                        height: math.max(24, box.maxHeight * fill),
                        colors: [
                          color.withValues(alpha: 0.25),
                          color.withValues(alpha: 0.35),
                          color.withValues(alpha: 0.5),
                        ],
                      ),
                    ),
                  Positioned(
                    left: 14,
                    top: 12,
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.camera,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'No photo yet',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// When the pin's photo was taken, and when the pin will be removed
/// (pins only last [kPinLifetime]), so people can tell if it's still
/// happening or the photo is old.
class _PinDates extends StatelessWidget {
  final FloodZone zone;
  const _PinDates({required this.zone});

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    final taken = zone.photoTakenAt;
    final left = zone.timeLeft;
    final leftText = left.inDays >= 1
        ? '${left.inDays} ${left.inDays == 1 ? 'day' : 'days'}'
        : '${left.inHours} ${left.inHours == 1 ? 'hour' : 'hours'}';
    // Last 2 days: show it in orange, the photo is getting old.
    final ending = left.inDays < 2;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _line(
            c,
            CupertinoIcons.camera,
            'Photo taken ${formatDate(taken)}, ${formatTime(taken)} '
            '(${timeAgo(zone.photoAge)})',
            c.textPrimary,
          ),
          const SizedBox(height: 6),
          _line(
            c,
            CupertinoIcons.hourglass,
            'Pin will be removed in $leftText',
            ending ? kCaution : c.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _line(AppColors c, IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(color: color, fontSize: 12.5)),
        ),
      ],
    );
  }
}
