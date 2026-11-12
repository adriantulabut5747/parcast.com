import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/services.dart';

import 'dart:math' as math;

import '../theme.dart';

/// ============================================================
/// FLOOD DEPTH — how deep the water is, in body terms, cm and ft,
/// plus the gauge drawing (ruler + person + water line) used on the
/// map's pin sheet and the report form.
/// ============================================================

/// Depth described the way people in the Philippines usually say it
/// ("tuhod" / knee-deep, "baywang" / waist-deep...), for an adult of
/// about 160 cm. Each depth gets the closest body mark in the gauge
/// (ankle 12, knee 48, waist 92, chest 122 cm), so the word always
/// matches the drawing. The limits are the halfway points between marks.
enum FloodLevel {
  dry('Dry'),
  ankle('Ankle-deep'),
  knee('Knee-deep'),
  waist('Waist-deep'),
  chest('Chest-deep'),
  overHead('Over head');

  final String label;
  const FloodLevel(this.label);

  static FloodLevel of(double cm) {
    if (cm < 5) return dry;
    if (cm < 30) return ankle;
    if (cm < 70) return knee;
    if (cm < 107) return waist;
    if (cm < 140) return chest;
    return overHead;
  }
}

/// Same cut-offs as the map legend: up to ankle-deep is normal, up to the
/// knee is moderate, anything deeper is high.
RiskLevel riskForDepth(double cm) {
  if (cm <= 20) return RiskLevel.normal;
  if (cm <= 50) return RiskLevel.moderate;
  return RiskLevel.high;
}

/// Loosely based on MMDA's flood gauge: above ~20 cm water reaches a
/// car's engine air intake, above ~45 cm even trucks struggle.
String vehicleAdvice(double cm) {
  if (cm <= 20) return 'All vehicles can pass';
  if (cm <= 45) return 'Too deep for cars';
  return 'No vehicles should pass';
}

String formatCm(double cm) => '${cm.round()} cm';
String formatFt(double cm) => '${(cm / 30.48).toStringAsFixed(1)} ft';

/// A flood gauge drawing: a cm ruler on the left, a person standing next
/// to it, and water filled up to [depthCm].
///
/// With [onChanged] set, the user can drag (or tap) anywhere on it to
/// move the water line. The value snaps to the body marks (ankle, knee...)
/// when close, otherwise to the nearest 5 cm.
class DepthGauge extends StatelessWidget {
  final double depthCm;
  final Color color;
  final double width;
  final double height;
  final ValueChanged<double>? onChanged;

  const DepthGauge({
    required this.depthCm,
    required this.color,
    this.width = 150,
    this.height = 210,
    this.onChanged,
    super.key,
  });

  static const double maxCm = 180;

  void _setFromY(double y) {
    final geo = _Geometry(Size(width, height));
    var cm = geo.cmAt(y);
    final mark = _marks
        .map((m) => m.cm)
        .followedBy(const [0.0])
        .firstWhere((m) => (m - cm).abs() <= 5, orElse: () => -1);
    cm = mark >= 0 ? mark : (cm / 5).round() * 5.0;
    if (cm == depthCm) return;
    // A small "tick" on phones each time the level word changes.
    if (FloodLevel.of(cm) != FloodLevel.of(depthCm)) {
      HapticFeedback.selectionClick();
    }
    onChanged!(cm);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    final gauge = CustomPaint(
      size: Size(width, height),
      painter: _GaugePainter(
        depthCm: depthCm,
        color: color,
        figure: Color.lerp(c.surfaceAlt, c.textSecondary, 0.45)!,
        ink: c.textSecondary,
        interactive: onChanged != null,
      ),
    );
    if (onChanged == null) {
      return Semantics(label: 'Water depth ${formatCm(depthCm)}', child: gauge);
    }
    // Semantics(slider: true) lets screen readers treat it like a slider
    // (swipe up/down to change the value by 5 cm).
    String describe(double cm) => '${formatCm(cm)}, ${FloodLevel.of(cm).label}';
    final up = math.min(maxCm, depthCm + 5);
    final down = math.max(0.0, depthCm - 5);
    return Semantics(
      slider: true,
      label: 'Water depth',
      value: describe(depthCm),
      increasedValue: describe(up),
      decreasedValue: describe(down),
      onIncrease: () => onChanged!(up),
      onDecrease: () => onChanged!(down),
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeUpDown,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _setFromY(d.localPosition.dy),
          onVerticalDragStart: (d) => _setFromY(d.localPosition.dy),
          onVerticalDragUpdate: (d) => _setFromY(d.localPosition.dy),
          child: gauge,
        ),
      ),
    );
  }
}

/// Body marks drawn beside the person, and the level each one stands for.
const _marks = [
  (label: 'Head', cm: 158.0, level: FloodLevel.overHead),
  (label: 'Chest', cm: 122.0, level: FloodLevel.chest),
  (label: 'Waist', cm: 92.0, level: FloodLevel.waist),
  (label: 'Knee', cm: 48.0, level: FloodLevel.knee),
  (label: 'Ankle', cm: 12.0, level: FloodLevel.ankle),
];

/// Where everything sits on the canvas. Shared by the painter and the
/// drag handler so a finger at a given height maps to the same cm the
/// painter draws there.
class _Geometry {
  final Size size;
  _Geometry(this.size);

  static const _top = 10.0;
  double get ground => size.height - 14;
  double get pxPerCm => (ground - _top) / DepthGauge.maxCm;
  double y(double cm) => ground - cm * pxPerCm;
  double cmAt(double y) =>
      ((ground - y) / pxPerCm).clamp(0, DepthGauge.maxCm).toDouble();

  double get rulerX => 26;
  double get figureX => rulerX + 12 + 25 * pxPerCm;
  double get labelX => figureX + 25 * pxPerCm + 8;
}

class _GaugePainter extends CustomPainter {
  final double depthCm;
  final Color color;
  final Color figure;
  final Color ink;
  final bool interactive;

  _GaugePainter({
    required this.depthCm,
    required this.color,
    required this.figure,
    required this.ink,
    required this.interactive,
  });

  void _text(
    Canvas canvas,
    String s,
    Offset at, {
    required Color color,
    double size = 9.5,
    FontWeight weight = FontWeight.w600,
    bool alignRight = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontFamily: kFontFamily,
          fontSize: size,
          fontWeight: weight,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = alignRight ? at.dx - tp.width : at.dx;
    tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final g = _Geometry(size);
    final s = g.pxPerCm;
    final hair = Paint()
      ..color = ink.withValues(alpha: 0.35)
      ..strokeWidth = 1;

    // Ruler: a tick every 10 cm, a longer one with a number every 50 cm.
    canvas.drawLine(
      Offset(g.rulerX, g.ground),
      Offset(g.rulerX, g.y(DepthGauge.maxCm)),
      hair,
    );
    for (var cm = 0; cm <= DepthGauge.maxCm; cm += 10) {
      final major = cm % 50 == 0;
      final y = g.y(cm.toDouble());
      canvas.drawLine(
        Offset(g.rulerX, y),
        Offset(g.rulerX + (major ? 7 : 4), y),
        hair,
      );
      if (major && cm > 0) {
        _text(
          canvas,
          '$cm',
          Offset(g.rulerX - 5, y),
          color: ink,
          alignRight: true,
        );
      }
    }
    _text(
      canvas,
      'cm',
      Offset(g.rulerX - 5, g.y(DepthGauge.maxCm)),
      color: ink,
      size: 8.5,
      alignRight: true,
    );

    // The person, built from rounded boxes in cm (x from the body's
    // middle, heights from the ground). One Path so overlaps don't
    // darken.
    final fx = g.figureX;
    Rect box(double x1, double x2, double h1, double h2) =>
        Rect.fromLTRB(fx + x1 * s, g.y(h2), fx + x2 * s, g.y(h1));
    final r = Radius.circular(3.5 * s);
    final body = Path()
      ..addOval(Rect.fromCircle(center: Offset(fx, g.y(149)), radius: 10.5 * s))
      ..addRect(box(-3.5, 3.5, 133, 141))
      ..addRRect(
        RRect.fromRectAndCorners(
          box(-18.5, 18.5, 88, 137),
          topLeft: Radius.circular(8 * s),
          topRight: Radius.circular(8 * s),
          bottomLeft: r,
          bottomRight: r,
        ),
      )
      ..addRRect(RRect.fromRectAndRadius(box(-24.5, -19.5, 80, 134), r))
      ..addRRect(RRect.fromRectAndRadius(box(19.5, 24.5, 80, 134), r))
      ..addRRect(RRect.fromRectAndRadius(box(-15, -1.5, 0, 92), r))
      ..addRRect(RRect.fromRectAndRadius(box(1.5, 15, 0, 92), r));
    canvas.drawPath(body, Paint()..color = figure);

    // Body marks with a dotted leader line from the figure.
    final current = FloodLevel.of(depthCm);
    for (final m in _marks) {
      final y = g.y(m.cm);
      final on = m.level == current;
      for (var x = fx + 26 * s; x < g.labelX - 3; x += 4) {
        canvas.drawLine(Offset(x, y), Offset(x + 1.5, y), hair);
      }
      _text(
        canvas,
        m.label,
        Offset(g.labelX, y),
        color: on ? color : ink,
        weight: on ? FontWeight.w800 : FontWeight.w600,
      );
    }

    // Ground line.
    canvas.drawLine(
      Offset(g.rulerX, g.ground),
      Offset(size.width, g.ground),
      Paint()
        ..color = ink.withValues(alpha: 0.5)
        ..strokeWidth = 1.5,
    );

    // Water, drawn over the person so the body under it looks submerged.
    if (depthCm > 0) {
      final top = g.y(depthCm);
      final surface = Path()..moveTo(g.rulerX, top);
      for (var x = g.rulerX; x <= size.width; x += 2) {
        surface.lineTo(
          x,
          top + math.sin((x - g.rulerX) / 22 * 2 * math.pi) * 1.6,
        );
      }
      final water = Path.from(surface)
        ..lineTo(size.width, g.ground)
        ..lineTo(g.rulerX, g.ground)
        ..close();
      canvas.drawPath(water, Paint()..color = color.withValues(alpha: 0.24));
      canvas.drawPath(
        surface,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // Pointer on the ruler at the current depth.
    final py = g.y(depthCm);
    canvas.drawPath(
      Path()
        ..moveTo(g.rulerX + 1, py)
        ..lineTo(g.rulerX - 6, py - 4.5)
        ..lineTo(g.rulerX - 6, py + 4.5)
        ..close(),
      Paint()..color = depthCm > 0 ? color : ink,
    );

    // Drag handle at the right end of the water line.
    if (interactive) {
      final knob = Offset(size.width - 11, py);
      canvas.drawCircle(knob, 10, Paint()..color = color);
      canvas.drawCircle(
        knob,
        10,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      final grip = Paint()
        ..color = Colors.white
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      for (final dy in const [-3.0, 0.0, 3.0]) {
        canvas.drawLine(knob + Offset(-4, dy), knob + Offset(4, dy), grip);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.depthCm != depthCm ||
      old.color != color ||
      old.figure != figure ||
      old.ink != ink ||
      old.interactive != interactive;
}

/// The numbers next to the gauge: depth in cm and ft, the body-level
/// word, and whether vehicles can get through. [depthCm] null = the user
/// hasn't set it yet.
class DepthReadout extends StatelessWidget {
  final double? depthCm;
  final String caption;
  const DepthReadout({
    required this.depthCm,
    this.caption = 'Estimated depth',
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    final cm = depthCm;
    final color = cm == null ? c.textSecondary : riskForDepth(cm).color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          caption.toUpperCase(),
          style: TextStyle(
            color: c.textSecondary,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: cm == null ? '—' : '${cm.round()}',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  letterSpacing: -0.5,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const TextSpan(
                text: ' cm',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          style: TextStyle(color: c.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          cm == null ? 'Drag the water line' : '≈ ${formatFt(cm)}',
          style: TextStyle(color: c.textSecondary, fontSize: 12.5),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                cm == null ? 'Not set' : FloodLevel.of(cm).label,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Divider(height: 1, color: c.border),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(CupertinoIcons.car_fill, size: 16, color: c.textSecondary),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                cm == null ? '—' : vehicleAdvice(cm),
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 12.5,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
