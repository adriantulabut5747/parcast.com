import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../theme.dart';
import 'tugak.dart';
import 'tugak_stage.dart';

/// ============================================================
/// TUGAK STAGE (web) — three.js in a <div>, driven from Dart
/// ============================================================
///
/// Same idea as AgosMap: Flutter puts an empty <div> where this widget
/// sits and web/tugak/scene.js draws the terrace into it. Dart sends the
/// weather for the hour shown, Tugak's line, and the pointer; the scene
/// says what a tap hit.
///
/// The <div> never takes touches itself (pointer-events: none): a swipe
/// over the scene must still scroll the page on a phone. A transparent
/// Flutter layer on top catches hovers and taps and passes them in.
///
/// Until the first 3D frame is drawn (three.js + the model download after
/// the page appears), and if WebGL is missing, [TugakStill] shows instead.
class TugakStage extends StatefulWidget {
  final TugakWeather weather;
  final String line;
  final ValueChanged<StageTap>? onTap;
  final StageReserve? reserve; // the part the live readings cover
  const TugakStage({
    required this.weather,
    required this.line,
    this.onTap,
    this.reserve,
    super.key,
  });

  @override
  State<TugakStage> createState() => _TugakStageState();
}

class _TugakStageState extends State<TugakStage> {
  web.HTMLElement? _div;
  _Stage? _stage;
  bool _ready = false;
  bool _failed = false;
  String? _sentWeather, _sentLine;
  StageReserve? _sentReserve;
  bool? _sentActive, _sentVisible, _sentDark;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(TugakStage old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _stage?.destroy();
    super.dispose();
  }

  Future<void> _start(web.HTMLElement div) async {
    _div = div;
    try {
      await _loadScene();
      for (var i = 0; i < 120 && !div.isConnected; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
      if (!mounted) return;
      _stage = _agosTugak!.create(
        div,
        jsonEncode({
          'dark': AppColors(context).isDark,
          'weather': widget.weather.toJson(),
          'reserve': ?widget.reserve?.toJson(),
        }),
        _Callbacks(
          onReady: (() {
            if (mounted) setState(() => _ready = true);
          }).toJS,
          onError: ((JSString _) {
            if (mounted) setState(() => _failed = true);
          }).toJS,
        ),
      );
      _sync();
    } catch (_) {
      // No WebGL or the files didn't download: the still picture stays.
      if (mounted) setState(() => _failed = true);
    }
  }

  // Sends whatever changed since last time.
  void _sync() {
    final s = _stage;
    if (s == null || !mounted) return;
    final weather = jsonEncode(widget.weather.toJson());
    if (weather != _sentWeather) s.setWeather(_sentWeather = weather);
    if (widget.line != _sentLine) s.say(_sentLine = widget.line);
    final reserve = widget.reserve;
    if (reserve != null && reserve != _sentReserve) {
      s.setReserve(jsonEncode((_sentReserve = reserve).toJson()));
    }
    final dark = AppColors(context).isDark;
    if (dark != _sentDark) s.setTheme(_sentDark = dark);
    // Hidden tab or behind a popup: stop drawing (saves the battery).
    final visible = TickerMode.valuesOf(context).enabled;
    final active = ModalRoute.of(context)?.isCurrent ?? true;
    if (visible != _sentVisible || active != _sentActive) {
      _sentVisible = visible;
      _sentActive = active;
      s.setActive(active, visible);
    }
  }

  // Pointer position as -1..1 across the stage, y up (three.js's way).
  (double, double) _norm(Offset p, Size size) =>
      (p.dx / size.width * 2 - 1, -(p.dy / size.height * 2 - 1));

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        return Stack(
          fit: StackFit.expand,
          children: [
            AnimatedOpacity(
              opacity: _ready ? 0 : 1,
              duration: const Duration(milliseconds: 600),
              child: TugakStill(
                weather: widget.weather,
                line: _failed ? widget.line : null,
                showTugak: _failed,
                reserve: widget.reserve,
              ),
            ),
            if (!_failed)
              HtmlElementView.fromTagName(
                tagName: 'div',
                onElementCreated: (el) {
                  final div = el as web.HTMLElement;
                  div.style
                    ..width = '100%'
                    ..height = '100%'
                    ..position = 'relative'
                    ..pointerEvents = 'none';
                  if (_div == null) _start(div);
                },
              ),
            // Hovers and taps, passed into the scene. Vertical drags are left
            // alone, so the page still scrolls.
            if (_ready)
              MouseRegion(
                onHover: (e) {
                  final (x, y) = _norm(e.localPosition, size);
                  _stage?.pointer(x, y);
                },
                onExit: (_) => _stage?.pointer(0, 0),
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapUp: (d) {
                    final (x, y) = _norm(d.localPosition, size);
                    final hit = _stage?.tap(x, y).toDart ?? '';
                    if (hit == 'tugak') widget.onTap?.call(StageTap.tugak);
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Loads web/tugak/scene.js (once). It's a JS module: it pulls in its
/// three.js files itself.
Future<void>? _scene;
Future<void> _loadScene() => _scene ??= () async {
  if (_agosTugak != null) return;
  final done = Completer<void>();
  final s = web.HTMLScriptElement()
    ..type = 'module'
    ..src = 'tugak/scene.js';
  s.onload = ((web.Event _) => done.complete()).toJS;
  s.onerror = ((web.Event _) {
    _scene = null;
    done.completeError('tugak/scene.js failed to load');
  }).toJS;
  web.document.head!.appendChild(s);
  await done.future;
}();

// ---- The JavaScript side, as Dart types (web/tugak/scene.js)

@JS('agosTugak')
external _AgosTugakJs? get _agosTugak;

extension type _AgosTugakJs(JSObject _) implements JSObject {
  external _Stage create(web.HTMLElement container, String opts, _Callbacks cb);
}

extension type _Callbacks._(JSObject _) implements JSObject {
  external factory _Callbacks({JSFunction onReady, JSFunction onError});
}

extension type _Stage(JSObject _) implements JSObject {
  external void setWeather(String json);
  external void say(String text);
  external void pointer(double x, double y);
  external JSString tap(double x, double y);
  external void setActive(bool active, bool visible);
  external void setTheme(bool dark);
  external void setReserve(String json);
  external void destroy();
}
