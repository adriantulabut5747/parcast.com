import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../data/demo_data.dart';
import '../theme.dart';
import 'common.dart';

/// ============================================================
/// CITY MAP: Mabalacat's outline with a dot for each of its 27 barangays
/// ============================================================
/// Drawn by hand (no tiles), so it costs nothing to load. The Weather tab
/// uses it to show where flooding is reported and to pick "my barangay".
///
/// The outline is the city boundary from OpenStreetMap, in the landing
/// page's map coordinates (its `<svg class="map-svg" viewBox="-10 -10 820
/// 550">`), copied from landing/index.html. Pairs of x, y.
const List<double> _kOutline = [
  0.0, 218.0, 75.5, 530.3, 117.8, 477.8, 127.8, 479.2, 132.2, 462.7, //
  152.4, 457.7, 152.1, 453.0, 174.7, 461.6, 174.3, 452.4, 184.7, 453.1,
  195.7, 471.6, 242.5, 452.7, 279.8, 453.6, 305.8, 466.2, 347.5, 457.5,
  381.5, 482.7, 387.1, 503.8, 415.8, 502.6, 477.7, 473.4, 498.8, 426.6,
  525.4, 437.3, 517.8, 457.8, 560.3, 466.3, 587.9, 460.4, 585.0, 448.3,
  602.1, 456.0, 640.7, 440.9, 667.3, 449.5, 693.7, 443.9, 719.5, 449.4,
  779.3, 433.5, 800.0, 422.5, 669.9, 0.0, 648.5, 9.7, 604.0, 2.4, //
  559.6, 17.6, 496.9, 13.0, 445.4, 36.1, 419.9, 56.8, 393.0, 53.9,
  374.9, 72.2, 234.5, 92.8, 181.3, 137.7, 58.7, 180.6,
];
const double _kViewW = 820, _kViewH = 550, _kViewPad = 10;

/// Latitude/longitude -> the outline's coordinates. Fitted to the
/// landing map's 27 barangay dots (off by under half a unit).
Offset _project(LatLng p) => Offset(
  (p.longitude - 120.461753) * 4630.71,
  (15.267467 - p.latitude) * 4798.61,
);

/// The map's width / height, for an AspectRatio around it.
const double kCityMapAspect = _kViewW / _kViewH;

/// Each barangay's dot in a box of [size] (same order as [kBarangays]).
List<Offset> _dots(Size size) {
  final s = size.width / _kViewW;
  return [
    for (final b in kBarangays)
      (_project(kBarangayPoints[b]!) + const Offset(_kViewPad, _kViewPad)) * s,
  ];
}

Path _outline(Size size) {
  final s = size.width / _kViewW;
  Offset at(int i) =>
      Offset(_kOutline[i] + _kViewPad, _kOutline[i + 1] + _kViewPad) * s;
  final path = Path()..moveTo(at(0).dx, at(0).dy);
  for (var i = 2; i < _kOutline.length; i += 2) {
    path.lineTo(at(i).dx, at(i).dy);
  }
  return path..close();
}

/// The map. [reports] = each reported barangay's worst current risk;
/// [mine] = the user's barangay; [selected] = the one shown in the panel
/// next to it. Tapping (or clicking) near a dot calls [onSelect].
class CityMap extends StatefulWidget {
  final Map<String, RiskLevel> reports;
  final String? mine;
  final String? selected;
  final ValueChanged<String> onSelect;
  const CityMap({
    required this.reports,
    required this.onSelect,
    this.mine,
    this.selected,
    super.key,
  });

  @override
  State<CityMap> createState() => _CityMapState();
}

class _CityMapState extends State<CityMap> with TickerProviderStateMixin {
  // The dots appear once, spreading out from Poblacion like a signal.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();

  // High-risk dots send out a ring every 2 seconds.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );

  String? _hovered;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduce motion: no intro, no pulsing.
    if (MediaQuery.disableAnimationsOf(context)) {
      _intro.value = 1;
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _pulse.dispose();
    super.dispose();
  }

  /// The barangay nearest to [p], if it's within reach of a finger.
  String? _nearest(Offset p, Size size) {
    final dots = _dots(size);
    String? best;
    var bestD = 26.0;
    for (var i = 0; i < dots.length; i++) {
      final d = (dots[i] - p).distance;
      if (d < bestD) {
        bestD = d;
        best = kBarangays[i];
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    return AspectRatio(
      aspectRatio: kCityMapAspect,
      child: LayoutBuilder(
        builder: (context, box) {
          final size = box.biggest;
          return MouseRegion(
            cursor: _hovered == null
                ? MouseCursor.defer
                : SystemMouseCursors.click,
            onHover: (e) {
              final h = _nearest(e.localPosition, size);
              if (h != _hovered) setState(() => _hovered = h);
            },
            onExit: (_) => setState(() => _hovered = null),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (e) {
                final b = _nearest(e.localPosition, size);
                if (b != null) widget.onSelect(b);
              },
              child: Stack(
                children: [
                  // The river-ripple pattern, only inside the city.
                  Positioned.fill(
                    child: ClipPath(
                      clipper: _OutlineClipper(),
                      child: ColoredBox(
                        color: c.surfaceAlt,
                        child: WaterLines(
                          color: c.textPrimary.withValues(alpha: 0.07),
                          height: size.height,
                          count: 9,
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _CityPainter(
                          intro: _intro,
                          pulse: _pulse,
                          reports: widget.reports,
                          mine: widget.mine,
                          selected: widget.selected,
                          hovered: _hovered,
                          edge: c.textPrimary.withValues(alpha: 0.22),
                          dot: c.textSecondary.withValues(alpha: 0.55),
                          text: c.textPrimary,
                          halo: c.background,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OutlineClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => _outline(size);

  @override
  bool shouldReclip(_OutlineClipper old) => false;
}

class _CityPainter extends CustomPainter {
  final Animation<double> intro;
  final Animation<double> pulse;
  final Map<String, RiskLevel> reports;
  final String? mine;
  final String? selected;
  final String? hovered;
  final Color edge, dot, text, halo;
  _CityPainter({
    required this.intro,
    required this.pulse,
    required this.reports,
    required this.mine,
    required this.selected,
    required this.hovered,
    required this.edge,
    required this.dot,
    required this.text,
    required this.halo,
  }) : super(repaint: Listenable.merge([intro, pulse]));

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      _outline(size),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeJoin = StrokeJoin.round
        ..color = edge,
    );

    final dots = _dots(size);
    final center = dots[kBarangays.indexOf('Poblacion')];
    final far = dots.map((d) => (d - center).distance).reduce(math.max);
    final labels = <(Offset, String, bool)>[];

    for (var i = 0; i < dots.length; i++) {
      final name = kBarangays[i];
      final p = dots[i];
      // This dot's own slice of the intro: nearer Poblacion = sooner.
      final start = (p - center).distance / far * 0.6;
      final t = ((intro.value - start) / 0.4).clamp(0.0, 1.0);
      if (t == 0) continue;
      final grow = Curves.easeOutBack.transform(t);
      final risk = reports[name];
      final isMine = name == mine;

      if (risk == RiskLevel.high) {
        // Two rings half a beat apart, growing and fading.
        for (final shift in [0.0, 0.5]) {
          final v = (pulse.value + shift) % 1;
          canvas.drawCircle(
            p,
            6 + 22 * v,
            Paint()..color = risk!.color.withValues(alpha: 0.35 * (1 - v) * t),
          );
        }
      } else if (risk == RiskLevel.moderate) {
        canvas.drawCircle(
          p,
          11 * grow,
          Paint()..color = risk!.color.withValues(alpha: 0.18 * t),
        );
      }

      if (name == selected) {
        canvas.drawCircle(
          p,
          12 * grow,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = text,
        );
      }

      final r = isMine ? 6.0 : (risk != null ? 5.0 : 3.2);
      final fill = isMine ? kBlue : (risk?.color ?? dot);
      if (isMine || risk != null) {
        // A halo in the page color, so the dot stands off the ripples.
        canvas.drawCircle(p, (r + 2) * grow, Paint()..color = halo);
      }
      canvas.drawCircle(p, r * grow, Paint()..color = fill);
      if (isMine) {
        canvas.drawCircle(p, 2.2 * grow, Paint()..color = Colors.white);
      }

      // Names only where they matter, so the map stays readable.
      final strong = name == selected || isMine;
      if (strong ||
          name == hovered ||
          (risk != null && risk != RiskLevel.normal)) {
        labels.add((p, name, strong));
      }
    }

    // Labels last, on top of every dot.
    for (final (p, name, strong) in labels) {
      final tp = TextPainter(
        text: TextSpan(
          text: name,
          style: TextStyle(
            fontFamily: kFontFamily,
            fontSize: strong ? 12 : 11,
            fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
            color: strong ? text : text.withValues(alpha: 0.8),
            shadows: [Shadow(color: halo, blurRadius: 4)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      // Right of the dot, or left of it near the east edge.
      final right = p.dx + 12 + tp.width < size.width;
      final at = Offset(
        right ? p.dx + 12 : p.dx - 12 - tp.width,
        p.dy - tp.height / 2,
      );
      tp.paint(canvas, at);
    }
  }

  @override
  bool shouldRepaint(_CityPainter old) =>
      old.reports != reports ||
      old.mine != mine ||
      old.selected != selected ||
      old.hovered != hovered ||
      old.text != text ||
      old.halo != halo;
}
