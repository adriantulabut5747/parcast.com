import 'dart:math' as math;

import 'package:flutter/material.dart';

/// ============================================================
/// WEATHER GLYPH — full-color weather icons, drawn in code
/// ============================================================
/// Like Apple Weather's multicolor symbols: a yellow-orange sun, white
/// clouds, blue rain drops, a yellow bolt, a pale moon at night. Cupertino
/// icons are one flat color, which made the forecast look dead (Adrian,
/// Nov 13 2026). Gently alive: the sun's rays turn, rain falls, the cloud
/// bobs; all still when the system asks for reduced motion.
enum SkyKind { clear, partly, cloudy, fog, drizzle, rain, storm }

/// WMO weather code -> what to draw (same groups as weatherInfo()).
SkyKind skyKindOf(int code) {
  if (code == 0) return SkyKind.clear;
  if (code <= 2) return SkyKind.partly;
  if (code == 3) return SkyKind.cloudy;
  if (code <= 48) return SkyKind.fog;
  if (code <= 57) return SkyKind.drizzle;
  if (code <= 82) return SkyKind.rain;
  return SkyKind.storm;
}

class WeatherGlyph extends StatefulWidget {
  final int code;
  final bool isDay;
  final double size;
  const WeatherGlyph({
    required this.code,
    this.isDay = true,
    this.size = 28,
    super.key,
  });

  @override
  State<WeatherGlyph> createState() => _WeatherGlyphState();
}

class _WeatherGlyphState extends State<WeatherGlyph>
    with SingleTickerProviderStateMixin {
  // One slow 6 s cycle, played ONCE when the icon appears (a forever loop
  // redraws the whole screen 60x a second on the web); each part reads its
  // own phase from it, and the end pose equals the start pose.
  late final _loop = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      _loop.stop();
    } else if (!_loop.isAnimating && _loop.value == 0) {
      _loop.forward();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(
          painter: _GlyphPainter(skyKindOf(widget.code), widget.isDay, _loop),
        ),
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  final SkyKind kind;
  final bool day;
  final Animation<double> t;
  _GlyphPainter(this.kind, this.day, this.t) : super(repaint: t);

  static const _sunCore = [Color(0xFFFFE066), Color(0xFFFFA51F)];
  static const _ray = Color(0xFFFFB627);
  static const _drop = [Color(0xFF7FD4FF), Color(0xFF2E8BFF)];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24; // drawn on a 24-unit grid
    canvas.scale(s);
    final v = t.value;
    switch (kind) {
      case SkyKind.clear:
        day
            ? _sun(canvas, const Offset(12, 12), 5.2, v)
            : _moon(canvas, const Offset(12, 12), 7);
      case SkyKind.partly:
        day
            ? _sun(canvas, const Offset(15.5, 8.5), 4.2, v)
            : _moon(canvas, const Offset(16, 8), 5);
        _cloud(canvas, const Offset(10.5, 15.5), 0.92, v);
      case SkyKind.cloudy:
        _cloud(canvas, const Offset(15.5, 9.5), 0.62, v + 0.5, dim: true);
        _cloud(canvas, const Offset(11, 14.5), 1, v);
      case SkyKind.fog:
        _cloud(canvas, const Offset(12, 10.5), 0.9, v);
        final p = Paint()
          ..color = const Color(0xFFB8C2D1)
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round;
        for (final (y, x0, x1) in [(18.0, 4.5, 17.0), (21.0, 7.0, 19.5)]) {
          final dx = math.sin((v + y) * 2 * math.pi) * 0.8;
          canvas.drawLine(Offset(x0 + dx, y), Offset(x1 + dx, y), p);
        }
      case SkyKind.drizzle:
        _rain(canvas, v, drops: 2, long: false);
        _cloud(canvas, const Offset(12, 9.5), 1, v);
      case SkyKind.rain:
        _rain(canvas, v, drops: 3, long: true);
        _cloud(canvas, const Offset(12, 9.5), 1, v, dark: true);
      case SkyKind.storm:
        _rain(canvas, v, drops: 2, long: true);
        _cloud(canvas, const Offset(12, 9.5), 1, v, dark: true);
        _bolt(canvas, v);
    }
  }

  void _sun(Canvas canvas, Offset c, double r, double v) {
    // Rays turn slowly (one turn per loop / 8 rays = barely noticeable).
    final rays = Paint()
      ..color = _ray
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4 + v * math.pi / 4;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + d * (r + 1.6), c + d * (r + 3.4), rays);
    }
    canvas.drawCircle(c, r + 1.2, Paint()..color = const Color(0x33FFC233));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.4),
          colors: _sunCore,
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  void _moon(Canvas canvas, Offset c, double r) {
    final disc = Path()..addOval(Rect.fromCircle(center: c, radius: r));
    final bite = Path()
      ..addOval(
        Rect.fromCircle(
          center: c + Offset(r * 0.55, -r * 0.4),
          radius: r * 0.85,
        ),
      );
    canvas.drawPath(
      Path.combine(PathOperation.difference, disc, bite),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF4C2), Color(0xFFE3C96A)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  // A cloud as three puffs on a flat base; [scale] 1 = 18 units wide.
  void _cloud(
    Canvas canvas,
    Offset c,
    double scale,
    double v, {
    bool dark = false,
    bool dim = false,
  }) {
    final bob = math.sin(v * 2 * math.pi) * 0.45;
    canvas.save();
    canvas.translate(c.dx, c.dy + bob);
    canvas.scale(scale);
    final path = Path()
      ..addOval(Rect.fromCircle(center: const Offset(-4.2, 1.2), radius: 3.6))
      ..addOval(Rect.fromCircle(center: const Offset(0.6, -1.4), radius: 5.0))
      ..addOval(Rect.fromCircle(center: const Offset(5.0, 1.4), radius: 3.4))
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTRB(-7.8, 0.8, 8.4, 4.8),
          const Radius.circular(2),
        ),
      );
    final colors = dark
        ? const [Color(0xFFD6DCE6), Color(0xFF8C97A8)]
        : dim
        ? const [Color(0xFFC9D1DC), Color(0xFF9AA6B6)]
        : const [Color(0xFFFFFFFF), Color(0xFFD3DBE6)];
    canvas.drawPath(
      path.shift(const Offset(0, 0.7)),
      Paint()..color = const Color(0x33000000),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ).createShader(const Rect.fromLTRB(-8, -6.5, 8.5, 5)),
    );
    canvas.restore();
  }

  // Drops falling out of the cloud and fading near the bottom.
  void _rain(
    Canvas canvas,
    double v, {
    required int drops,
    required bool long,
  }) {
    final xs = drops == 2 ? [9.0, 14.5] : [7.5, 12.0, 16.5];
    for (var i = 0; i < xs.length; i++) {
      final phase = (v * 3 + i * 0.37) % 1.0;
      final y = 13.5 + phase * 8.5;
      final len = long ? 3.4 : 1.8;
      final a = (1 - phase).clamp(0.0, 1.0);
      final p = Paint()
        ..strokeWidth = 2.1
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _drop[0].withValues(alpha: a),
            _drop[1].withValues(alpha: a),
          ],
        ).createShader(Rect.fromLTWH(xs[i] - 1, y, 2, len));
      canvas.drawLine(Offset(xs[i] + 0.8, y), Offset(xs[i] - 0.2, y + len), p);
    }
  }

  void _bolt(Canvas canvas, double v) {
    // Flashes brighter for a moment once per loop.
    final flash = v > 0.82 && v < 0.9;
    final bolt = Path()
      ..moveTo(12.6, 12.2)
      ..lineTo(9.4, 17.6)
      ..lineTo(11.8, 17.6)
      ..lineTo(10.6, 22.4)
      ..lineTo(15.0, 16.0)
      ..lineTo(12.5, 16.0)
      ..lineTo(14.0, 12.2)
      ..close();
    canvas.drawPath(
      bolt,
      Paint()
        ..color = flash ? const Color(0xFFFFFBE0) : const Color(0xFFFFD60A),
    );
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.kind != kind || old.day != day || old.t != t;
}
