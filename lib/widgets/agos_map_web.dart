import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:web/web.dart' as web;

import '../data/demo_data.dart';
import '../theme.dart';
import 'agos_map.dart';

/// ============================================================
/// AGOS MAP (web) — MapLibre in a <div>, driven from Dart
/// ============================================================
///
/// Flutter puts an empty <div> on the page (HtmlElementView) where this
/// widget sits; web/agos_map.js draws the map into it. Dart only sends
/// small commands ("show these pins", "tilt to 3D") as plain values or
/// JSON text, and gets back taps and camera changes through callbacks.
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

  /// Room taken by things floating over the map (header, panels), so
  /// "fly to this pin" centers it in the part you can actually see.
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

class _AgosMapState extends State<AgosMap> implements MapBackend {
  web.HTMLElement? _div;
  _MapHandle? _map;
  String? _error;
  bool _dark = true;
  // Commands that arrive before the map exists: the last camera move.
  LatLng? _pendingCenter;
  double? _pendingZoom;
  // What was last sent, so unchanged values aren't sent again.
  String? _sentPins, _sentZones, _sentPadding, _sentHidden;
  String? _sentSelected;
  bool? _sentActive, _sentVisible;

  @override
  void initState() {
    super.initState();
    widget.controller?.attach(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dark = AppColors(context).isDark;
    if (dark != _dark) {
      _dark = dark;
      _map?.setTheme(_theme);
    }
    _sync();
  }

  @override
  void didUpdateWidget(AgosMap old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller?.detach(this);
      widget.controller?.attach(this);
    }
    _sync();
  }

  @override
  void dispose() {
    widget.controller?.detach(this);
    _map?.destroy();
    super.dispose();
  }

  String get _theme => _dark ? 'dark' : 'light';

  // The <div> exists; once it's on the page, load MapLibre and start.
  Future<void> _start(web.HTMLElement div) async {
    _div = div;
    _dark = AppColors(context).isDark;
    try {
      await _loadScripts();
      // Wait until Flutter has put the <div> on the page, so the map
      // knows its size from the start.
      for (var i = 0; i < 120 && !div.isConnected; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
      if (!mounted) return;
      final w = widget;
      final c = _pendingCenter ?? w.center;
      final opts = jsonEncode({
        'theme': _theme,
        'center': [c.longitude, c.latitude],
        'zoom': _pendingZoom ?? w.zoom,
        'minZoom': w.interactive ? 13 : 10,
        'interactive': w.interactive,
        // Open framing every pin, unless a pin was asked for already.
        'fit': w.interactive && _pendingCenter == null,
        'bounds': [
          [kCityBounds.west, kCityBounds.south],
          [kCityBounds.east, kCityBounds.north],
        ],
      });
      _map = _agosMap!.create(
        div,
        opts,
        _Callbacks(
          onPinTap: ((JSString id) => widget.onPinTap?.call(id.toDart)).toJS,
          onCamera: ((JSNumber bearing, JSNumber pitch) {
            widget.controller?.bearing.value = bearing.toDartDouble;
            widget.controller?.pitch.value = pitch.toDartDouble;
          }).toJS,
          onMoveEnd: ((JSNumber lat, JSNumber lng) {
            widget.controller?.center.value = LatLng(
              lat.toDartDouble,
              lng.toDartDouble,
            );
          }).toJS,
          onReady: (() {}).toJS,
        ),
      );
      _sync();
    } catch (e) {
      // No WebGL, or the map files didn't download: say so, don't fake it.
      if (mounted) setState(() => _error = '$e');
    }
  }

  // Sends whatever changed since last time.
  void _sync() {
    final m = _map;
    if (m == null || !mounted) return;
    final pins = jsonEncode([
      for (final p in widget.pins)
        {
          'id': p.id,
          'kind': p.kind.name,
          'lng': p.point.longitude,
          'lat': p.point.latitude,
          'color': _hex(p.color),
          'glyph': p.icon.codePoint,
          'font': p.icon.fontFamily,
          'title': p.title,
          'chip': p.chip,
          'pulse': p.pulse,
          'a11y': p.a11y,
        },
    ]);
    if (pins != _sentPins) m.setPins(_sentPins = pins);
    final zones = jsonEncode([
      for (final z in widget.zones)
        {
          'lng': z.center.longitude,
          'lat': z.center.latitude,
          'radius': z.radiusM,
          'color': _hex(z.color),
        },
    ]);
    if (zones != _sentZones) m.setZones(_sentZones = zones);
    final hidden = widget.hidden.map((k) => k.name).join(',');
    if (hidden != _sentHidden) {
      _sentHidden = hidden;
      for (final k in PinKind.values) {
        m.setHidden(k.name, widget.hidden.contains(k));
      }
    }
    if (widget.selectedId != _sentSelected) {
      m.select((_sentSelected = widget.selectedId)?.toJS);
    }
    final p = widget.padding;
    final pad = '${p.top},${p.right},${p.bottom},${p.left}';
    if (pad != _sentPadding) {
      _sentPadding = pad;
      m.setPadding(p.top, p.right, p.bottom, p.left);
    }
    // Hidden tab: the <div> must not catch taps meant for the tab on top.
    // Behind a sheet or popup: blurred and still.
    final visible = TickerMode.valuesOf(context).enabled;
    final active = ModalRoute.of(context)?.isCurrent ?? true;
    if (visible != _sentVisible || active != _sentActive) {
      _sentVisible = visible;
      _sentActive = active;
      m.setActive(active, visible);
    }
  }

  static String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  // ---- MapBackend (called through AgosMapController)
  @override
  void flyTo(LatLng p, double zoom, {String? place}) {
    final m = _map;
    if (m == null) {
      _pendingCenter = p;
      _pendingZoom = zoom;
      return;
    }
    m.flyTo(p.longitude, p.latitude, zoom, place?.toJS);
  }

  @override
  void zoomBy(double by) => _map?.zoomBy(by);

  @override
  void reset(LatLng p, double zoom) =>
      _map?.reset(p.longitude, p.latitude, zoom);

  @override
  void set3d(bool on) => _map?.set3d(on);

  @override
  void resetNorth() => _map?.resetNorth();

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: c.isDark ? Colors.black : const Color(0xFFF2F2F4)),
        HtmlElementView.fromTagName(
          tagName: 'div',
          onElementCreated: (el) {
            final div = el as web.HTMLElement;
            div.style
              ..width = '100%'
              ..height = '100%'
              ..position = 'relative'
              ..overflow = 'hidden';
            if (_div == null) _start(div);
          },
        ),
        if (_error != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.map, color: c.textSecondary, size: 32),
                  const SizedBox(height: 10),
                  Text(
                    'The map couldn\'t load on this browser.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'It needs WebGL. Try updating the browser, or open the '
                    'app in Chrome or Safari.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: c.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Loads web/agos_map.js (once), which then loads MapLibre itself.
Future<void>? _scripts;
Future<void> _loadScripts() => _scripts ??= () async {
  if (_agosMap == null) {
    final done = Completer<void>();
    final s = web.HTMLScriptElement()..src = 'agos_map.js';
    s.onload = ((web.Event _) => done.complete()).toJS;
    s.onerror = ((web.Event _) {
      _scripts = null;
      done.completeError('agos_map.js failed to load');
    }).toJS;
    web.document.head!.appendChild(s);
    await done.future;
  }
  await _agosMap!.load().toDart;
}();

// ---- The JavaScript side, as Dart types (web/agos_map.js)

@JS('agosMap')
external _AgosMapJs? get _agosMap;

extension type _AgosMapJs(JSObject _) implements JSObject {
  external JSPromise<JSAny?> load();
  external _MapHandle create(
    web.HTMLElement container,
    String opts,
    _Callbacks callbacks,
  );
}

extension type _Callbacks._(JSObject _) implements JSObject {
  external factory _Callbacks({
    JSFunction onPinTap,
    JSFunction onCamera,
    JSFunction onMoveEnd,
    JSFunction onReady,
  });
}

extension type _MapHandle(JSObject _) implements JSObject {
  external void setTheme(String theme);
  external void setPins(String json);
  external void setZones(String json);
  external void setHidden(String kind, bool off);
  external void select(JSString? id);
  external void flyTo(double lng, double lat, double zoom, JSString? place);
  external void zoomBy(double by);
  external void reset(double lng, double lat, double zoom);
  external void set3d(bool on);
  external void resetNorth();
  external void setPadding(
    double top,
    double right,
    double bottom,
    double left,
  );
  external void setActive(bool active, bool visible);
  external void destroy();
}
