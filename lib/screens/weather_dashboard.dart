import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/weather.dart';
import '../services/reports.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/flood_depth.dart';
import 'home_shell.dart';

/// ============================================================
/// WEATHER DASHBOARD PANELS (Nov 13 2026 redesign: "make it feel like a
/// professional dashboard"). Every number is real: Open-Meteo weather and
/// air quality; the flood panel uses the sample pins (SAMPLE badge).
/// ============================================================

// ------------------------------------------------------------
// Conditions: 8 instrument tiles. They follow the hour picked on the sky
// card's scrubber (air quality is "now" only). Tap a tile: it flips to a
// plain explanation of what the number means.
// ------------------------------------------------------------
class ConditionsGrid extends StatelessWidget {
  final MabalacatWeather weather;
  final Future<AirQuality> air;
  final ValueListenable<int> hour;
  final int columns;
  const ConditionsGrid({
    required this.weather,
    required this.air,
    required this.hour,
    this.columns = 2,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    return ValueListenableBuilder<int>(
      valueListenable: hour,
      builder: (context, i, _) {
        final w = weather;
        final hrs = w.hourly;
        i = math.min(i, hrs.length - 1);
        final h = hrs[i];
        final now = i == 0;
        final t = now ? w.time : h.time;
        final tiles = [
          _windTile(now, h),
          _feelsTile(now, h),
          _humidityTile(now, h),
          _uvTile(now, h),
          _airTile(now),
          _visibilityTile(now, h),
          _pressureTile(i),
          _sunTile(t),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // One plain title (follows the scrubbed hour). Each tile shows
            // its own small (i): tapping explains it, so no hint line.
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                now ? 'Right now' : 'At ${formatHour(h.time)}',
                style: TextStyle(
                  fontFamily: kDisplayFont,
                  color: c.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: displayTracking(20),
                ),
              ),
            ),
            LayoutBuilder(
              builder: (context, box) {
                const gap = 12.0;
                final tileW = (box.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final t in tiles)
                      SizedBox(width: tileW, height: 150, child: t),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _windTile(bool now, HourlyForecast h) {
    final speed = now ? weather.windSpeed : h.windSpeed;
    final dir = now ? weather.windDir : h.windDir;
    return _Tile(
      icon: CupertinoIcons.wind,
      label: 'WIND',
      value: '${speed.round()}',
      unit: ' km/h',
      sub: now
          ? 'From ${_compass(dir)} · gusts ${weather.gusts.round()}'
          : 'From ${_compass(dir)}',
      corner: _Compass(degrees: dir.toDouble()),
      info:
          'Wind from the ${_compassName(dir)}. PAGASA raises Wind Signal No. 1 at 39-61 km/h: loose roofing and branches start to fly.',
    );
  }

  Widget _feelsTile(bool now, HourlyForecast h) {
    final feels = now ? weather.feelsLike : h.feelsLike;
    final temp = now ? weather.temperature : h.temperature;
    // PAGASA heat index bands.
    final band = feels >= 52
        ? 'Extreme danger'
        : feels >= 42
        ? 'Danger'
        : feels >= 33
        ? 'Extreme caution'
        : feels >= 27
        ? 'Caution'
        : 'No heat risk';
    return _Tile(
      icon: CupertinoIcons.thermometer,
      label: 'FEELS LIKE',
      value: '${feels.round()}°',
      sub: band,
      note: feels - temp >= 2
          ? 'Humidity makes it feel warmer than the actual ${temp.round()}°.'
          : 'Close to the actual ${temp.round()}°.',
      info: 'Heat index: how hot humid air feels. PAGASA: 33-41° extreme caution, 42° and up danger. Drink water, rest in shade.',
    );
  }

  Widget _humidityTile(bool now, HourlyForecast h) {
    final hum = now ? weather.humidity : h.humidity;
    return _Tile(
      icon: CupertinoIcons.drop,
      label: 'HUMIDITY',
      value: '$hum%',
      sub: hum >= 80
          ? 'Very humid'
          : hum >= 60
          ? 'Humid'
          : 'Comfortable',
      note: hum >= 60
          ? 'Wet floors and laundry dry slowly.'
          : 'Things dry normally today.',
      info: 'How much water the air holds. Humid air makes heat feel worse and slows wet clothes and floors from drying.',
    );
  }

  Widget _uvTile(bool now, HourlyForecast h) {
    final uv = now ? weather.uv : h.uv;
    final r = uv.round();
    // WHO UV index categories.
    final band = r >= 11
        ? 'Extreme'
        : r >= 8
        ? 'Very high'
        : r >= 6
        ? 'High'
        : r >= 3
        ? 'Moderate'
        : 'Low';
    return _Tile(
      icon: CupertinoIcons.sun_max,
      label: 'UV INDEX',
      value: '$r',
      sub: band,
      scale: (uv / 11).clamp(0.0, 1.0),
      scaleColors: const [
        Color(0xFF30D158),
        Color(0xFFFFD60A),
        Color(0xFFFF9F0A),
        Color(0xFFFF453A),
        Color(0xFFBF5AF2),
      ],
      info: 'Sunburn strength (WHO scale). 3 and up: sunscreen and a hat. 8 and up: stay in the shade around midday.',
    );
  }

  Widget _airTile(bool now) {
    return FutureBuilder<AirQuality>(
      future: air,
      builder: (context, snap) {
        final a = snap.data;
        return _Tile(
          icon: CupertinoIcons.smoke,
          label: 'AIR QUALITY',
          tag: now ? null : 'NOW',
          value: a == null ? (snap.hasError ? '–' : '…') : '${a.usAqi}',
          sub: a == null
              ? (snap.hasError ? 'Unavailable right now' : 'Loading')
              : '${a.label} · PM2.5 ${a.pm25.toStringAsFixed(1)}',
          // US EPA bands: good to hazardous, as a scale with a dot.
          scale: a == null ? null : (a.usAqi / 300).clamp(0.0, 1.0),
          scaleColors: const [
            Color(0xFF30D158),
            Color(0xFFFFD60A),
            Color(0xFFFF9F0A),
            Color(0xFFFF453A),
            Color(0xFFBF5AF2),
            Color(0xFF8E3A4E),
          ],
          info: 'US EPA index from Open-Meteo model data, not a local sensor. 0-50 good, 51-100 moderate, over 100 unhealthy for sensitive groups.',
        );
      },
    );
  }

  Widget _visibilityTile(bool now, HourlyForecast h) {
    final km = (now ? weather.visibility : h.visibility) / 1000;
    return _Tile(
      icon: CupertinoIcons.eye,
      label: 'VISIBILITY',
      value: km >= 10 ? '${km.round()}' : km.toStringAsFixed(1),
      unit: ' km',
      // WMO: fog under 1 km, mist 1-5 km.
      sub: km < 1
          ? 'Fog'
          : km < 5
          ? 'Mist or haze'
          : 'Clear view',
      note: km < 1
          ? 'Drive slowly with your lights on.'
          : km < 5
          ? 'Far roads look hazy.'
          : 'You can see far and clearly.',
      info: 'How far you can see clearly. Under 1 km counts as fog (WMO): drive slowly with your lights on.',
    );
  }

  Widget _pressureTile(int i) {
    final hrs = weather.hourly;
    final p = i == 0 ? weather.pressure : hrs[i].pressure;
    final later = i + 3 < hrs.length ? hrs[i + 3].pressure : null;
    final d = later == null ? 0 : later - p;
    return _Tile(
      icon: CupertinoIcons.gauge,
      label: 'PRESSURE',
      value: p.round().toString(),
      unit: ' hPa',
      sub: later == null
          ? 'Sea level'
          : d >= 1
          ? 'Rising next 3 h'
          : d <= -1
          ? 'Falling next 3 h'
          : 'Steady next 3 h',
      bottom: _Sparkline(
        values: [for (final h in hrs) h.pressure],
        selected: i,
      ),
      info: 'Air pressure at sea level. A steady fall over a few hours often comes before a storm or typhoon.',
    );
  }

  Widget _sunTile(DateTime t) {
    final days = weather.daily;
    final idx = days.indexWhere((d) => _sameDay(d.date, t));
    final day = idx < 0 ? weather.today : days[idx];
    final next = idx >= 0 && idx + 1 < days.length ? days[idx + 1] : null;
    final (label, at) = t.isBefore(day.sunrise)
        ? ('SUNRISE', day.sunrise)
        : t.isBefore(day.sunset) || next == null
        ? ('SUNSET', day.sunset)
        : ('SUNRISE', next.sunrise);
    final light = day.sunset.difference(day.sunrise);
    return _Tile(
      icon: label == 'SUNRISE' ? CupertinoIcons.sunrise : CupertinoIcons.sunset,
      label: label,
      value: formatTime(at),
      sub: 'Daylight ${light.inHours} h ${light.inMinutes % 60} m',
      bottom: _SunArc(
        progress:
            t.difference(day.sunrise).inMinutes / math.max(1, light.inMinutes),
      ),
      info: 'If heavy rain is coming, travel in daylight: flood water on roads is much harder to judge in the dark.',
    );
  }

  static const _points = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  static const _names = [
    'north',
    'northeast',
    'east',
    'southeast',
    'south',
    'southwest',
    'west',
    'northwest',
  ];
  static int _octant(int deg) => ((deg % 360) / 45).round() % 8;
  static String _compass(int deg) => _points[_octant(deg)];
  static String _compassName(int deg) => _names[_octant(deg)];
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// One instrument tile. [corner] sits top right (the compass), [meter]
/// (0..1) or [bottom] fills the foot. Tap flips it to [info].
class _Tile extends StatefulWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final String sub;
  final String info;
  final String? tag;
  final Widget? corner;
  final Widget? bottom;

  /// A plain sentence at the foot, for tiles with no picture to show.
  final String? note;

  /// Where the value sits on its index scale (0..1), drawn as Apple's
  /// gradient bar with a dot; [scaleColors] = the scale, low to high.
  final double? scale;
  final List<Color>? scaleColors;
  const _Tile({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.info,
    this.unit = '',
    this.tag,
    this.corner,
    this.bottom,
    this.note,
    this.scale,
    this.scaleColors,
  });

  @override
  State<_Tile> createState() => _TileState();
}

class _TileState extends State<_Tile> {
  bool _flipped = false;

  // Each tile's own color, like Apple Weather's tinted symbols: a soft
  // wash in the corner and the icon. Never the risk green / orange / red.
  static final _tints = <IconData, Color>{
    CupertinoIcons.wind: kTileTeal,
    CupertinoIcons.thermometer: const Color(0xFFFFB340),
    CupertinoIcons.drop: kBlue,
    CupertinoIcons.sun_max: const Color(0xFFFFD60A),
    CupertinoIcons.smoke: kTilePurple,
    CupertinoIcons.eye: kTileIndigo,
    CupertinoIcons.gauge: const Color(0xFF64D2FF),
    CupertinoIcons.sunrise: const Color(0xFFFFC94D),
    CupertinoIcons.sunset: const Color(0xFFFF9F6B),
  };
  // Which way the value rolls when the scrubbed hour changes it.
  bool _up = true;

  static double? _number(String v) =>
      double.tryParse(RegExp(r'-?\d+(\.\d+)?').firstMatch(v)?.group(0) ?? '');

  @override
  void didUpdateWidget(_Tile old) {
    super.didUpdateWidget(old);
    final a = _number(old.value), b = _number(widget.value);
    if (a != null && b != null && a != b) _up = b > a;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    final tint = _tints[widget.icon] ?? c.accent;
    final eyebrow = TextStyle(
      color: c.textSecondary,
      fontSize: 12,
      letterSpacing: 0.3,
      fontWeight: FontWeight.w600,
    );
    final front = Column(
      key: const ValueKey('front'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(widget.icon, size: 14, color: c.readable(tint)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: eyebrow,
              ),
            ),
            if (widget.tag != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(widget.tag!, style: eyebrow.copyWith(fontSize: 11)),
              )
            else
              Icon(
                CupertinoIcons.info_circle,
                size: 14,
                color: c.textSecondary.withValues(alpha: 0.55),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              // The value rolls up or down (iOS numeric transition).
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 380),
                switchInCurve: const Cubic(0.16, 1, 0.3, 1),
                switchOutCurve: const Cubic(0.16, 1, 0.3, 1),
                layoutBuilder: (cur, prev) => Stack(
                  alignment: Alignment.centerLeft,
                  children: [...prev, ?cur],
                ),
                transitionBuilder: (child, anim) {
                  final incoming = child.key == ValueKey(widget.value);
                  return FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween(
                        begin: Offset(0, incoming == _up ? 0.35 : -0.35),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  );
                },
                child: FittedBox(
                  key: ValueKey(widget.value),
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text.rich(
                    TextSpan(
                      text: widget.value,
                      children: [
                        TextSpan(
                          text: widget.unit,
                          style: TextStyle(
                            fontSize: 13,
                            color: c.textSecondary,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                    style: TextStyle(
                      fontFamily: kDisplayFont,
                      color: c.textPrimary,
                      fontSize: 28,
                      height: 1.05,
                      fontWeight: FontWeight.w600,
                      letterSpacing: displayTracking(28),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
            ?widget.corner,
          ],
        ),
        const SizedBox(height: 3),
        Text(
          widget.sub,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: c.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        if (widget.bottom != null)
          widget.bottom!
        else if (widget.scale != null)
          _IndexScale(value: widget.scale!, colors: widget.scaleColors!)
        else if (widget.note != null)
          Text(
            widget.note!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.3),
          ),
      ],
    );
    final back = Column(
      key: const ValueKey('back'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: eyebrow.copyWith(color: c.accent)),
        const SizedBox(height: 6),
        Expanded(
          child: Text(
            widget.info,
            overflow: TextOverflow.fade,
            style: TextStyle(color: c.textPrimary, fontSize: 13, height: 1.4),
          ),
        ),
      ],
    );
    return Semantics(
      button: true,
      label:
          '${widget.label}: ${widget.value}${widget.unit}, ${widget.sub}. ${_flipped ? widget.info : 'Tap for what it means.'}',
      excludeSemantics: true,
      child: AppCard(
        radius: 20,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: c.isDark
              ? [
                  tint.withValues(alpha: 0.2),
                  Colors.white.withValues(alpha: 0.045),
                ]
              : [
                  Color.alphaBlend(
                    tint.withValues(alpha: 0.12),
                    Colors.white.withValues(alpha: 0.92),
                  ),
                  Colors.white.withValues(alpha: 0.78),
                ],
          stops: const [0, 0.7],
        ),
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _flipped = !_flipped);
        },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: ScaleTransition(
              scale: Tween(begin: 0.96, end: 1.0).animate(a),
              child: child,
            ),
          ),
          child: _flipped ? back : front,
        ),
      ),
    );
  }
}

/// Apple Weather's index scale: a thin bar in the scale's own colors
/// (low to high) and a dot, ringed in the card color, at the reading. The
/// dot glides when the scrubbed hour changes it.
class _IndexScale extends StatelessWidget {
  final double value; // 0..1 along the scale
  final List<Color> colors;
  const _IndexScale({required this.value, required this.colors});

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    return SizedBox(
      height: 10,
      child: LayoutBuilder(
        builder: (context, box) => TweenAnimationBuilder<double>(
          tween: Tween(end: value),
          duration: const Duration(milliseconds: 450),
          curve: const Cubic(0.16, 1, 0.3, 1),
          builder: (context, v, _) => Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: LinearGradient(colors: colors),
                ),
              ),
              Positioned(
                left: (box.maxWidth - 10) * v,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: c.isDark ? const Color(0xFF26262A) : Colors.white,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small compass: ring, N mark, and an arrow showing where the wind
/// blows TO (the reading is where it comes FROM).
class _Compass extends StatelessWidget {
  final double degrees;
  const _Compass({required this.degrees});

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: degrees),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, d, _) => CustomPaint(
        size: const Size(40, 40),
        painter: _CompassPainter(d, c.textSecondary, c.accent),
      ),
    );
  }
}

class _CompassPainter extends CustomPainter {
  final double deg;
  final Color ink, accent;
  _CompassPainter(this.deg, this.ink, this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final o = size.center(Offset.zero);
    final r = size.width / 2 - 1;
    final tick = Paint()
      ..color = ink.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (var k = 0; k < 12; k++) {
      final a = k * math.pi / 6;
      final len = k % 3 == 0 ? 4.0 : 2.0;
      canvas.drawLine(
        o + Offset(math.sin(a), -math.cos(a)) * r,
        o + Offset(math.sin(a), -math.cos(a)) * (r - len),
        tick,
      );
    }
    final n = TextPainter(
      text: TextSpan(
        text: 'N',
        style: TextStyle(color: ink, fontSize: 11, fontWeight: FontWeight.w800),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    n.paint(canvas, o + Offset(-n.width / 2, -r + 4));
    // Arrow pointing downwind.
    canvas.save();
    canvas.translate(o.dx, o.dy);
    canvas.rotate((deg + 180) * math.pi / 180);
    final arrow = Path()
      ..moveTo(0, -r + 7)
      ..lineTo(4, -r + 13)
      ..lineTo(1.2, -r + 12)
      ..lineTo(1.2, r - 8)
      ..lineTo(-1.2, r - 8)
      ..lineTo(-1.2, -r + 12)
      ..lineTo(-4, -r + 13)
      ..close();
    canvas.drawPath(arrow, Paint()..color = accent);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CompassPainter old) => old.deg != deg || old.ink != ink;
}

/// 24-hour line with a dot on the selected hour.
class _Sparkline extends StatelessWidget {
  final List<double> values;
  final int selected;
  const _Sparkline({required this.values, required this.selected});

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    return SizedBox(
      height: 22,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparkPainter(values, selected, c.textSecondary, c.accent),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> v;
  final int sel;
  final Color ink, accent;
  _SparkPainter(this.v, this.sel, this.ink, this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    if (v.length < 2) return;
    final lo = v.reduce(math.min), hi = v.reduce(math.max);
    Offset at(int i) => Offset(
      i / (v.length - 1) * size.width,
      hi - lo < 0.5
          ? size.height / 2
          : size.height - 3 - (v[i] - lo) / (hi - lo) * (size.height - 6),
    );
    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < v.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round
        ..color = ink.withValues(alpha: 0.6),
    );
    final p = at(sel.clamp(0, v.length - 1));
    canvas.drawCircle(p, 4, Paint()..color = accent.withValues(alpha: 0.3));
    canvas.drawCircle(p, 2.5, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.sel != sel || old.v != v || old.ink != ink;
}

/// The sun's path from sunrise to sunset; [progress] 0..1 places it (out
/// of that range = night, the sun waits dimmed on the horizon).
class _SunArc extends StatelessWidget {
  final double progress;
  const _SunArc({required this.progress});

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: progress),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, p, _) => SizedBox(
        height: 28,
        width: double.infinity,
        child: CustomPaint(painter: _SunPainter(p, c.textSecondary)),
      ),
    );
  }
}

class _SunPainter extends CustomPainter {
  final double p;
  final Color ink;
  _SunPainter(this.p, this.ink);

  @override
  void paint(Canvas canvas, Size size) {
    final base = size.height - 2;
    final rect = Rect.fromLTWH(6, 4, size.width - 12, (base - 4) * 2);
    canvas.drawLine(
      Offset(0, base),
      Offset(size.width, base),
      Paint()
        ..color = ink.withValues(alpha: 0.35)
        ..strokeWidth = 1,
    );
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = ink.withValues(alpha: 0.45);
    canvas.drawArc(rect, math.pi, math.pi, false, arc);
    final up = p >= 0 && p <= 1;
    final q = p.clamp(0.0, 1.0);
    final a = math.pi + q * math.pi;
    final sun = up
        ? Offset(
            rect.center.dx + math.cos(a) * rect.width / 2,
            rect.center.dy + math.sin(a) * rect.height / 2,
          )
        : Offset(p < 0 ? rect.left : rect.right, base);
    if (up) {
      canvas.drawArc(
        rect,
        math.pi,
        q * math.pi,
        false,
        arc..color = const Color(0xFFFFC94D),
      );
      canvas.drawCircle(sun, 7, Paint()..color = const Color(0x55FFC94D));
    }
    canvas.drawCircle(
      sun,
      4,
      Paint()
        ..color = up ? const Color(0xFFFFC94D) : ink.withValues(alpha: 0.6),
    );
  }

  @override
  bool shouldRepaint(_SunPainter old) => old.p != p || old.ink != ink;
}

// ------------------------------------------------------------
// Rain over 48 hours: the last 24 (measured by the model) and the next 24
// (forecast), each against the 30 mm "high-risk day" line, and one bar
// per hour. Drag across the bars to read any hour.
// ------------------------------------------------------------
class RainTotalsCard extends StatefulWidget {
  final MabalacatWeather weather;
  const RainTotalsCard({required this.weather, super.key});

  @override
  State<RainTotalsCard> createState() => _RainTotalsCardState();
}

class _RainTotalsCardState extends State<RainTotalsCard> {
  int? _sel; // the hour being read; null = none

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    final w = widget.weather;
    final bars = [...w.pastRain, for (final h in w.hourly) (h.time, h.rain)];
    final nowAt = w.pastRain.length; // index of the current hour
    final past = w.pastRain.fold<double>(0, (s, e) => s + e.$2);
    final next = w.hourly.fold<double>(0, (s, h) => s + h.rain);
    final sel = _sel;
    String readout() {
      if (sel == null) return 'Drag across the bars to read any hour';
      final (t, mm) = bars[sel];
      final day = _sameDay(t, w.time)
          ? 'Today'
          : t.isBefore(w.time)
          ? 'Yesterday'
          : 'Tomorrow';
      return '$day ${formatHour(t)} · ${mm.toStringAsFixed(1)} mm${sel < nowAt ? '' : ' forecast'}';
    }

    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader('Rain, 48 hours'),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _Total(label: 'LAST 24 H', mm: past),
                ),
                VerticalDivider(width: 24, color: c.border),
                Expanded(
                  child: _Total(label: 'NEXT 24 H', mm: next),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: Text(
              readout(),
              key: ValueKey(sel),
              style: TextStyle(
                color: sel == null ? c.textSecondary : c.textPrimary,
                fontSize: 12,
                fontWeight: sel == null ? FontWeight.w500 : FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, box) {
              void at(Offset p) {
                final i = (p.dx / box.maxWidth * bars.length).floor().clamp(
                  0,
                  bars.length - 1,
                );
                if (i != _sel) {
                  HapticFeedback.selectionClick();
                  setState(() => _sel = i);
                }
              }

              return MouseRegion(
                cursor: SystemMouseCursors.resizeLeftRight,
                onHover: (e) => at(e.localPosition),
                onExit: (_) => setState(() => _sel = null),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) => at(d.localPosition),
                  onHorizontalDragStart: (d) => at(d.localPosition),
                  onHorizontalDragUpdate: (d) => at(d.localPosition),
                  onHorizontalDragEnd: (_) => setState(() => _sel = null),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, grow, _) => CustomPaint(
                      size: Size(box.maxWidth, 96),
                      painter: _RainBarsPainter(
                        bars.map((b) => b.$2).toList(),
                        nowAt: nowAt,
                        sel: sel,
                        grow: grow,
                        past: c.textSecondary.withValues(alpha: 0.45),
                        future: kBlue,
                        ink: c.textSecondary,
                        hi: c.textPrimary,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final (i, l) in const [
                '24 h ago',
                '12 h ago',
                'Now',
                '+12 h',
                '+24 h',
              ].indexed)
                Expanded(
                  child: Text(
                    l,
                    textAlign: i == 0
                        ? TextAlign.left
                        : i == 4
                        ? TextAlign.right
                        : TextAlign.center,
                    style: TextStyle(
                      color: i == 2 ? c.textPrimary : c.textSecondary,
                      fontSize: 11,
                      fontWeight: i == 2 ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Past hours are Open-Meteo model estimates, not a rain gauge. 30 mm in a day is the line our flood outlook calls high risk.',
            style: TextStyle(color: c.textSecondary, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }
}

/// A 24-hour total and its bar toward the 30 mm high-risk line.
class _Total extends StatelessWidget {
  final String label;
  final double mm;
  const _Total({required this.label, required this.mm});

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    // Same cut-offs as floodOutlook: 10 mm moderate, 30 mm high.
    final color = mm >= 30
        ? kDanger
        : mm >= 10
        ? kCaution
        : kBlue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: c.textSecondary,
            fontSize: 11,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text.rich(
          TextSpan(
            text: mm < 0.1 ? '0' : mm.toStringAsFixed(1),
            children: [
              TextSpan(
                text: ' mm',
                style: TextStyle(
                  fontSize: 13,
                  color: c.textSecondary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          style: TextStyle(
            fontFamily: kDisplayFont,
            color: c.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: displayTracking(28),
          ),
        ),
        const SizedBox(height: 8),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: (mm / 30).clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => Container(
            height: 5,
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(5),
            ),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: math.max(0.02, v),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Bar ends at 30 mm: high risk',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: c.textSecondary, fontSize: 11),
        ),
      ],
    );
  }
}

class _RainBarsPainter extends CustomPainter {
  final List<double> mm;
  final int nowAt;
  final int? sel;
  final double grow;
  final Color past, future, ink, hi;
  _RainBarsPainter(
    this.mm, {
    required this.nowAt,
    required this.sel,
    required this.grow,
    required this.past,
    required this.future,
    required this.ink,
    required this.hi,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final n = mm.length;
    if (n == 0) return;
    const top = 14.0; // room for the scale label
    final h = size.height - top;
    final col = size.width / n;
    // At least a 2 mm scale, so a drizzle stays small.
    final scale = math.max(2.0, mm.reduce(math.max));

    // One quiet grid line at the top of the scale, labeled.
    final grid = Paint()
      ..color = ink.withValues(alpha: 0.2)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, top), Offset(size.width, top), grid);
    final label = TextPainter(
      text: TextSpan(
        text: '${scale.toStringAsFixed(scale < 10 ? 1 : 0)} mm/h',
        style: TextStyle(color: ink, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset(0, 0));
    canvas.drawLine(
      Offset(0, size.height - 0.5),
      Offset(size.width, size.height - 0.5),
      grid,
    );

    for (var i = 0; i < n; i++) {
      final bh = math.max(2.0, h * math.min(1, mm[i] / scale) * grow);
      final color = i == sel
          ? hi
          : i < nowAt
          ? past
          : mm[i] >= 0.1
          ? future
          : future.withValues(alpha: 0.3);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(
            col * i + 1,
            size.height - bh,
            math.max(1, col - 2),
            bh,
          ),
          topLeft: const Radius.circular(2),
          topRight: const Radius.circular(2),
        ),
        Paint()..color = color,
      );
    }

    // "Now": a dashed line between the past and the forecast.
    final x = col * nowAt;
    final dash = Paint()
      ..color = hi.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    for (double y = top; y < size.height; y += 5) {
      canvas.drawLine(
        Offset(x, y),
        Offset(x, math.min(size.height, y + 2.5)),
        dash,
      );
    }
  }

  @override
  bool shouldRepaint(_RainBarsPainter old) =>
      old.sel != sel || old.grow != grow || old.mm != mm || old.hi != hi;
}

// ------------------------------------------------------------
// What's on the map right now (Nov 14 2026, Adrian: list the happenings,
// not the old depth bars, and no big red): the live reports newest first,
// each a quiet row (type icon in a kBlue tile, type + barangay, depth and
// how deep that is, verified, when). Risk is only a small dot. Two columns
// on wide screens. Tap a row: the map opens on that pin.
// ------------------------------------------------------------
class FloodOpsCard extends StatelessWidget {
  const FloodOpsCard({super.key});

  // Rebuilds when someone posts or deletes a report.
  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: floodReports,
    builder: (context, _, _) => _card(context),
  );

  Widget _card(BuildContext context) {
    final c = AppColors(context);
    final all = activeFloodReports.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final barangays = all.map((z) => z.barangay).toSet().length;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            'On the map now',
            actionLabel: 'Open map',
            onAction: () => HomeShell.of(context)?.switchTab(1),
          ),
          Text(
            all.isEmpty
                ? 'Nothing reported right now.'
                : '${all.length} active ${all.length == 1 ? 'report' : 'reports'} in $barangays ${barangays == 1 ? 'barangay' : 'barangays'}, from people nearby',
            style: TextStyle(color: c.textSecondary, fontSize: 13),
          ),
          if (all.isNotEmpty) ...[
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, box) {
                const gap = 10.0;
                final cols = box.maxWidth >= 720 ? 2 : 1;
                final shown = all.take(cols * 3).toList();
                final w = (box.maxWidth - gap * (cols - 1)) / cols;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (final z in shown)
                          SizedBox(width: w, child: _row(context, c, z)),
                      ],
                    ),
                    // only when some didn't fit
                    if (all.length > shown.length)
                      PressableScale(
                        onTap: () => HomeShell.of(context)?.switchTab(2),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'See all ${all.length} in Reports',
                            style: TextStyle(
                              color: c.accent,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(BuildContext context, AppColors c, FloodReport z) {
    final details = [
      if (z.hasDepth)
        '${formatCm(z.depth)}, ${FloodLevel.of(z.depth).label.toLowerCase()}',
      if (z.status == 'verified') 'Verified',
      z.updated,
    ].join(' · ');
    return Semantics(
      button: true,
      label:
          '${z.typeLabel} in ${z.barangay}, ${z.risk.label} risk. $details. View on map',
      excludeSemantics: true,
      child: PressableScale(
        onTap: () {
          HomeShell.of(context)?.switchTab(1);
          focusedReport.value = z;
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            color: c.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              IconBadge(z.typeIcon, kBlue, size: 36, squircle: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${z.typeLabel} · ${z.barangay}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        // the risk, kept small: a dot, not a colored bar
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: z.risk.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            details,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                CupertinoIcons.chevron_right,
                size: 13,
                color: c.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
