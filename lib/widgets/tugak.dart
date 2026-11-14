import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/alerts.dart';
import '../services/weather.dart';
import '../theme.dart';
import 'tugak_stage.dart';

/// ============================================================
/// TUGAK — the AgosAlert mascot ("tugak" = frog in Kapampangan)
/// ============================================================
///
/// A dark green toad in a black mafia fedora (Nov 13 2026 redesign:
/// personality and a stare, so the app never reads as a kids' app). He's a
/// 3D model built by tools/tugak3d.py in Blender: web/tugak/tugak.glb for
/// the terrace scene on the Weather tab (tugak_stage.dart), and the still
/// assets/images/tugak.png everywhere else. Edit the script, never those.
///
/// His mood follows the real weather, and what he says is built from real
/// numbers (the rain forecast, the latest alert). On a high alert he drops
/// the jokes and only says what to do.
enum TugakMood { fine, rain, storm, night }

/// Picks his mood: storm on a high flood outlook or an unread high alert,
/// rain when it's raining or about to, night after dark, otherwise fine.
TugakMood tugakMoodFor(MabalacatWeather w, {AppAlert? alert}) {
  if (alert != null || w.floodOutlook.level == RiskLevel.high) {
    return TugakMood.storm;
  }
  if (w.weatherCode >= 51 || w.rainStartsAt != null) return TugakMood.rain;
  if (!w.isDay) return TugakMood.night;
  return TugakMood.fine;
}

/// What he says for the current weather. Deadpan: what to do first, then
/// (only when nothing is wrong) a short dry line.
String tugakLine(MabalacatWeather w, {AppAlert? alert}) {
  if (alert != null) {
    // Name the alert (the Weather tab has no red strip any more), then
    // what to do.
    if (alert.actions.isEmpty) return '${alert.title}. Stay tuned here.';
    return '${alert.title}. ${alert.actions.first}.';
  }
  final outlook = w.floodOutlook;
  if (outlook.level == RiskLevel.high) {
    return 'Heavy rain today. Keep your go-bag by the door and stay off low streets.';
  }
  if (w.weatherCode >= 51) {
    return 'It\'s raining now. Skip the shortcuts by the creek.';
  }
  final start = w.rainStartsAt;
  if (start != null) {
    return 'Rain from ${formatTime(start)}. Cross low streets before then, not after.';
  }
  // First hour later today that's more likely wet than dry.
  final wetHour = w.hourly.skip(1).where((h) => h.rainChance >= 50).firstOrNull;
  if (wetHour != null) {
    return 'Rain likely around ${formatHour(wetHour.time)}. Bring the umbrella, not the excuses.';
  }
  if (!w.isDay) {
    return 'No rain tonight. Charge your phone and sleep. I\'ve got the watch.';
  }
  return 'Dry roads for now. Go run your errands, I\'ll hold the fort.';
}

/// Rain in one hour, by PAGASA's rainfall-intensity bands (mm per hour):
/// light under 2.5, moderate 2.5-7.5, heavy over 7.5.
const double kModerateRainMm = 2.5;
const double kHeavyRainMm = 7.5;

/// His mood for a forecast hour (the Weather tab's time scrubber).
TugakMood tugakMoodAt(HourlyForecast h) {
  if (h.weatherCode >= 95 || h.rain >= kHeavyRainMm) return TugakMood.storm;
  if (h.rain >= 0.1 || h.rainChance >= 50 || h.weatherCode >= 51) {
    return TugakMood.rain;
  }
  return h.isDay ? TugakMood.fine : TugakMood.night;
}

/// What he says about a forecast hour. [serious] (an unread high alert)
/// drops the jokes, like [tugakLine] does.
String tugakLineAt(HourlyForecast h, {required bool serious}) {
  final t = formatHour(h.time);
  final mm = h.rain.toStringAsFixed(1);
  if (h.weatherCode >= 95) {
    return '$t: thunderstorm. Be indoors before it starts and keep off the open roads.';
  }
  if (h.rain >= kHeavyRainMm) {
    return '$t: heavy rain, $mm mm in one hour. Low streets flood fast in that.';
  }
  if (h.rain >= kModerateRainMm) {
    return '$t: steady rain, $mm mm. Leave before it or wait it out.';
  }
  if (h.rain >= 0.1 || h.rainChance >= 50) {
    return '$t: ${h.rainChance}% chance of rain. Take the umbrella${serious ? '.' : '. The big one.'}';
  }
  if (serious) return '$t looks dry. Use it to move things to higher ground.';
  if (!h.isDay) return "$t looks dry. Sleep. I've got the watch.";
  if (h.temperature >= 33) {
    return '$t: dry and ${h.temperature.round()}°. Drink water. Frogs know.';
  }
  return '$t looks dry. Good window for errands.';
}

/// Tips he cycles through when tapped (general advice, not data).
const List<String> kTugakTips = [
  'Save the CDRRMO number now. During a flood is too late.',
  'See a flooded street? Post one photo in Reports. That\'s all I need.',
  'Pack the go-bag before the rain does. The checklist is in Help.',
  'Safe after a storm? Send "I\'m safe" from Help so nobody has to guess.',
];

/// Tugak's still picture (a render of the 3D model). [pose]: one of the
/// landing page's poses that tugak3d.py --poses copies into
/// assets/images/tugak/ (phone, think, handset, tip); null = him sitting.
class TugakImage extends StatelessWidget {
  final double size;
  final String? pose;
  const TugakImage({this.size = 120, this.pose, super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      pose == null
          ? 'assets/images/tugak.png'
          : 'assets/images/tugak/$pose.webp',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      // Missing file (tugak3d.py not run yet): leave the space empty.
      errorBuilder: (_, _, _) => SizedBox(width: size, height: size),
      semanticLabel: 'Tugak, the AgosAlert toad',
    );
  }
}

/// Tugak's speech bubble, the landing page's `.say`: a blue TUGAK label
/// ([name]: only the first bubble of a run has it), an optional bold
/// [title], and a tail pointing at him: down (he's under it) by default,
/// [tail] another way, or null for none (an earlier bubble in a chat run,
/// like iMessage: only the last one gets the tail). Navy on the dark
/// theme, white on the light one (Nov 14 2026, Adrian).
class TugakSay extends StatelessWidget {
  final String text;
  final String? title;
  final AxisDirection? tail;
  final bool name;
  const TugakSay(
    this.text, {
    this.title,
    this.tail = AxisDirection.down,
    this.name = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    final title = this.title;
    final t = _SayPainter.tail;
    return CustomPaint(
      painter: _SayPainter(tail, dark: c.isDark),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16 + (tail == AxisDirection.left ? t : 0),
          11 + (tail == AxisDirection.up ? t : 0),
          16 + (tail == AxisDirection.right ? t : 0),
          13 + (tail == AxisDirection.down ? t : 0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (name) ...[
              Text(
                'TUGAK',
                style: TextStyle(
                  color: c.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 3),
            ],
            if (title != null)
              Text(
                title,
                style: TextStyle(
                  fontFamily: kDisplayFont,
                  color: c.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: displayTracking(17),
                ),
              ),
            Text(
              text,
              style: TextStyle(
                color: title == null ? c.textPrimary : c.textSecondary,
                fontSize: 15,
                height: 1.4,
                fontWeight: title == null ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tugak in a [pose] with his bubbles to the right, like a chat: [line],
/// then [more] lines as their own bubbles, the last one with the tail
/// pointing at him. [footer] (e.g. a button) sits under the bubbles.
/// Used atop quiet sections (Reports, Help & FAQ, Be ready).
class TugakBeside extends StatelessWidget {
  final String pose;
  final String line;
  final List<String> more;
  final Widget? footer;
  final double size;
  const TugakBeside({
    required this.pose,
    required this.line,
    this.more = const [],
    this.footer,
    this.size = 96,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final lines = [line, ...more];
    final footer = this.footer;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        TugakImage(size: size, pose: pose),
        const SizedBox(width: 6),
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < lines.length; i++) ...[
                  if (i > 0) const SizedBox(height: 6),
                  TugakSay(
                    lines[i],
                    name: i == 0,
                    tail: i == lines.length - 1 ? AxisDirection.left : null,
                  ),
                ],
                if (footer != null) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(left: _SayPainter.tail),
                    child: footer,
                  ),
                ],
                // keeps his feet level with the last bubble's tail
                if (footer == null) SizedBox(height: size * 0.12),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SayPainter extends CustomPainter {
  static const double tail = 7;
  final AxisDirection? to; // which way the tail points (at him); null = none
  final bool dark;
  const _SayPainter(this.to, {required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    const t = tail;
    final w = size.width, h = size.height;
    final body = switch (to) {
      AxisDirection.left => Rect.fromLTRB(t, 0, w, h),
      AxisDirection.right => Rect.fromLTRB(0, 0, w - t, h),
      AxisDirection.up => Rect.fromLTRB(0, t, w, h),
      AxisDirection.down => Rect.fromLTRB(0, 0, w, h - t),
      null => Offset.zero & size,
    };
    // a triangle from just inside the body's edge out to the tip
    final (a, tipAt, b) = switch (to) {
      AxisDirection.left => (
        Offset(t + 1, h / 2 - t),
        Offset(0, h / 2),
        Offset(t + 1, h / 2 + t),
      ),
      AxisDirection.right => (
        Offset(w - t - 1, h / 2 - t),
        Offset(w, h / 2),
        Offset(w - t - 1, h / 2 + t),
      ),
      AxisDirection.up => (
        Offset(w / 2 - t, t + 1),
        Offset(w / 2, 0),
        Offset(w / 2 + t, t + 1),
      ),
      AxisDirection.down => (
        Offset(w / 2 - t, h - t - 1),
        Offset(w / 2, h),
        Offset(w / 2 + t, h - t - 1),
      ),
      // no tail: a zero-size triangle inside the body
      null => (
        Offset(w / 2, h / 2),
        Offset(w / 2, h / 2),
        Offset(w / 2, h / 2),
      ),
    };
    final tip = Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(tipAt.dx, tipAt.dy)
      ..lineTo(b.dx, b.dy)
      ..close();
    // one outline round bubble + tail, so the edge line runs along the tail too
    final shape = Path.combine(
      PathOperation.union,
      Path()
        ..addRRect(RRect.fromRectAndRadius(body, const Radius.circular(20))),
      tip,
    );
    if (dark) {
      canvas.drawShadow(shape, Colors.black, 8, false);
    } else {
      // a soft, low drop, like AppCard's on the light theme
      canvas.drawPath(
        shape.shift(const Offset(0, 4)),
        Paint()
          ..color = const Color(0x14000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
    // dark: the landing's .say (rgba(18,20,32,.78) over its night), opaque
    // here; light: white with a hairline, like the app's cards
    canvas.drawPath(
      shape,
      Paint()..color = dark ? const Color(0xFF12141F) : Colors.white,
    );
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = dark ? const Color(0x1FFFFFFF) : const Color(0x14000000),
    );
  }

  @override
  bool shouldRepaint(_SayPainter old) => old.to != to || old.dark != dark;
}

/// Tugak on the sky without 3D: what the terrace shows before its 3D
/// frame is ready, where WebGL is missing, and outside the browser.
/// [line] (if given) sits in a glass bubble at the top, or where
/// [reserve] says (the same spots as the 3D scene).
class TugakStill extends StatelessWidget {
  final TugakWeather weather;
  final String? line;
  final bool showTugak;
  final StageReserve? reserve;
  const TugakStill({
    required this.weather,
    this.line,
    this.showTugak = true,
    this.reserve,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final line = this.line;
    // The 3D scene's dark stage (STAGE in web/tugak/scene.js) with a soft
    // pool of the sky behind him, so the switch to 3D doesn't jump.
    const stage = Color(0xFF070A1C);
    final sky = weatherGradient(weather.code, weather.isDay).first;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.3),
          radius: 0.8,
          colors: [Color.alphaBlend(sky.withValues(alpha: 0.5), stage), stage],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, box) => Stack(
          children: [
            if (reserve case final r?) ...[
              if (showTugak)
                Positioned(
                  left: r.left,
                  top: r.top,
                  right: 0,
                  bottom: r.bottom,
                  child: LayoutBuilder(
                    builder: (context, area) => Align(
                      alignment: Alignment.bottomCenter,
                      child: TugakImage(
                        size: math.min(area.maxWidth, area.maxHeight) * 0.9,
                      ),
                    ),
                  ),
                ),
              if (line != null)
                r.below
                    ? Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: TugakSay(line, tail: AxisDirection.up),
                      )
                    : Positioned(
                        left: 16,
                        bottom: math.max(16, r.bottom),
                        width: math.max(160, r.left - 30),
                        child: TugakSay(line, tail: AxisDirection.right),
                      ),
            ] else ...[
              if (showTugak)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: TugakImage(size: box.maxHeight * 0.72),
                ),
              if (line != null)
                Positioned(
                  left: 12,
                  right: 12,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                    decoration: BoxDecoration(
                      color: const Color(0xC7121420),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0x1AFFFFFF)),
                    ),
                    child: Text(
                      line,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
