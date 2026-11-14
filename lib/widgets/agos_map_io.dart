import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../data/demo_data.dart';
import '../theme.dart';
import 'agos_map.dart';
import 'map_tiles.dart';

/// ============================================================
/// AGOS MAP (not web) — flutter_map fallback
/// ============================================================
///
/// Used by tests and phone builds, where MapLibre's web version can't run.
/// Flat only (no 3D, no turning); pins are Flutter widgets drawn like the
/// web ones (web/agos_map.js).
class AgosMap extends StatefulWidget {
  final AgosMapController? controller;
  final List<MapPin> pins;
  final List<MapZone> zones;
  final Set<PinKind> hidden;
  final String? selectedId;
  final ValueChanged<String>? onPinTap;
  final LatLng center;
  final double zoom;
  final bool interactive;
  final EdgeInsets padding;

  const AgosMap({
    this.controller,
    this.pins = const [],
    this.zones = const [],
    this.hidden = const {},
    this.selectedId,
    this.onPinTap,
    this.center = kMabalacatCenter,
    this.zoom = 13.3,
    this.interactive = true,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  @override
  State<AgosMap> createState() => _AgosMapState();
}

/// The city box as flutter_map bounds (tests check the map stays inside).
final LatLngBounds kCityLatLngBounds = LatLngBounds(
  LatLng(kCityBounds.south, kCityBounds.west),
  LatLng(kCityBounds.north, kCityBounds.east),
);

class _AgosMapState extends State<AgosMap> implements MapBackend {
  final _map = MapController();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    widget.controller?.attach(this);
  }

  @override
  void didUpdateWidget(AgosMap old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller?.detach(this);
      widget.controller?.attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?.detach(this);
    super.dispose();
  }

  void _move(LatLng p, double zoom) {
    if (_ready) _map.move(p, zoom.clamp(13, 18));
  }

  @override
  void flyTo(LatLng p, double zoom) => _move(p, zoom);
  @override
  void zoomBy(double by) => _move(_map.camera.center, _map.camera.zoom + by);
  @override
  void reset(LatLng p, double zoom) => _move(p, zoom);
  @override
  void set3d(bool on) {} // flat only
  @override
  void resetNorth() {}

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    final pins = widget.pins.where((p) => !widget.hidden.contains(p.kind));
    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: widget.center,
        initialZoom: widget.zoom,
        minZoom: widget.interactive ? 13 : 10,
        maxZoom: 18,
        cameraConstraint: widget.interactive
            ? CameraConstraint.contain(bounds: kCityLatLngBounds)
            : const CameraConstraint.unconstrained(),
        backgroundColor: c.surfaceAlt,
        onMapReady: () => _ready = true,
        onPositionChanged: (camera, _) =>
            widget.controller?.center.value = camera.center,
        interactionOptions: InteractionOptions(
          flags: widget.interactive
              ? InteractiveFlag.all & ~InteractiveFlag.rotate
              : InteractiveFlag.none,
        ),
      ),
      children: [
        const AppTileLayer(),
        if (!widget.hidden.contains(PinKind.flood))
          CircleLayer(
            circles: [
              for (final z in widget.zones)
                CircleMarker(
                  point: z.center,
                  radius: z.radiusM,
                  useRadiusInMeter: true,
                  color: z.color.withValues(alpha: 0.18),
                  borderColor: z.color.withValues(alpha: 0.6),
                  borderStrokeWidth: 1.5,
                ),
            ],
          ),
        MarkerLayer(
          markers: [
            for (final p in pins)
              Marker(
                point: p.point,
                width: _Pin.size,
                height: _Pin.size,
                child: _Pin(
                  key: ValueKey('pin-${p.id}'),
                  pin: p,
                  selected: p.id == widget.selectedId,
                  onTap: () => widget.onPinTap?.call(p.id),
                ),
              ),
          ],
        ),
        if (widget.interactive)
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: EdgeInsets.only(
                right: 8 + widget.padding.right,
                bottom: 6 + widget.padding.bottom,
              ),
              child: Text(
                AppTileLayer.credits,
                style: TextStyle(color: c.textSecondary, fontSize: 11),
              ),
            ),
          ),
      ],
    );
  }
}

/// A pin like the web one: balloon with a white icon, tip on the spot,
/// depth chip and name under it. flutter_map centers a marker on its
/// point, so the marker is a square with the tip at its center.
class _Pin extends StatelessWidget {
  static const double size = 120;
  final MapPin pin;
  final bool selected;
  final VoidCallback onTap;
  const _Pin({
    required this.pin,
    required this.selected,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    final shelter = pin.kind == PinKind.shelter;
    return Semantics(
      button: true,
      label: pin.a11y,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Positioned(
              bottom: shelter ? size / 2 - 16 : size / 2,
              child: AnimatedScale(
                scale: selected ? 1.3 : 1,
                duration: const Duration(milliseconds: 300),
                alignment: shelter ? Alignment.center : Alignment.bottomCenter,
                child: SizedBox(
                  width: shelter ? 32 : 34,
                  height: shelter ? 32 : 43,
                  child: CustomPaint(
                    painter: _Balloon(pin.color, square: shelter),
                    child: Padding(
                      padding: EdgeInsets.only(top: shelter ? 0 : 6),
                      child: Align(
                        alignment: shelter
                            ? Alignment.center
                            : Alignment.topCenter,
                        child: Icon(pin.icon, color: Colors.white, size: 17),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: size / 2 + (shelter ? 20 : 7),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (pin.chip != null)
                    Container(
                      padding: const EdgeInsets.fromLTRB(6, 2, 8, 2),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(color: Color(0x40000000), blurRadius: 6),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(radius: 3.5, backgroundColor: pin.color),
                          const SizedBox(width: 5),
                          Text(
                            pin.chip!,
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
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
      ),
    );
  }
}

class _Balloon extends CustomPainter {
  final Color color;
  final bool square;
  _Balloon(this.color, {required this.square});

  @override
  void paint(Canvas canvas, Size s) {
    final Path path;
    if (square) {
      path = Path()
        ..addRRect(
          RRect.fromRectAndRadius(Offset.zero & s, const Radius.circular(10)),
        );
    } else {
      // Same outline as BALLOON in web/agos_map.js (34 x 43).
      path = Path()
        ..moveTo(17, 42)
        ..cubicTo(14, 34, 1, 29, 1, 17)
        ..arcTo(
          Rect.fromCircle(center: const Offset(17, 17), radius: 16),
          math.pi,
          math.pi,
          false,
        )
        ..cubicTo(33, 29, 20, 34, 17, 42)
        ..close();
    }
    canvas.drawShadow(path, Colors.black, 3, false);
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
  }

  @override
  bool shouldRepaint(_Balloon old) =>
      old.color != color || old.square != square;
}
