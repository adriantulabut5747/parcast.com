import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';

// The map widget itself. Two versions with the same AgosMap class:
// - in the browser (the real app): MapLibre, a 3D vector map drawn with
//   WebGL from the files in web/map/ (see web/agos_map.js);
// - everywhere else (tests, a phone build): flutter_map with Esri tiles.
// Dart picks one when compiling (`if (dart.library.js_interop)` = "when
// building for the web"), so the web app never contains flutter_map.
export 'agos_map_io.dart' if (dart.library.js_interop) 'agos_map_web.dart';

/// ============================================================
/// AGOS MAP — what the map shows, shared by both versions
/// ============================================================

enum PinKind { flood, shelter }

/// One tappable pin: a flood report or an evacuation center.
class MapPin {
  final String id;
  final PinKind kind;
  final LatLng point;
  final Color color;
  final IconData icon;
  final String title; // under the pin, e.g. the barangay
  final String? chip; // small tag above the title, e.g. "65 cm"
  final bool pulse; // a ring pinging out on the ground (high risk)
  final String a11y; // what a screen reader says
  const MapPin({
    required this.id,
    required this.kind,
    required this.point,
    required this.color,
    required this.icon,
    required this.title,
    required this.a11y,
    this.chip,
    this.pulse = false,
  });
}

/// A see-through colored circle on the ground, [radiusM] meters wide.
class MapZone {
  final LatLng center;
  final double radiusM;
  final Color color;
  const MapZone(this.center, this.radiusM, this.color);
}

/// What both map versions must be able to do when asked by the controller.
abstract class MapBackend {
  void flyTo(LatLng p, double zoom);
  void zoomBy(double by);
  void reset(LatLng p, double zoom);
  void set3d(bool on);
  void resetNorth();
}

/// Lets screens move the map (buttons, "show this pin") and follow its
/// tilt and turn (the 3D button and the compass).
class AgosMapController {
  MapBackend? _backend;

  /// Degrees the map is turned from north (0 = north up).
  final bearing = ValueNotifier<double>(0);

  /// Degrees the map is tilted (0 = looking straight down).
  final pitch = ValueNotifier<double>(0);

  void attach(MapBackend b) => _backend = b;
  void detach(MapBackend b) {
    if (_backend == b) _backend = null;
  }

  void flyTo(LatLng p, {double zoom = 15.5}) => _backend?.flyTo(p, zoom);
  void zoomBy(double by) => _backend?.zoomBy(by);
  void reset(LatLng p, double zoom) => _backend?.reset(p, zoom);
  void set3d(bool on) => _backend?.set3d(on);
  void resetNorth() => _backend?.resetNorth();

  void dispose() {
    bearing.dispose();
    pitch.dispose();
  }
}
