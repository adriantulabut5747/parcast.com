import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../services/weather.dart';
import '../theme.dart';
import 'common.dart';

/// ============================================================
/// TUGAK — the AgosAlert mascot ("tugak" = frog in Kapampangan)
/// ============================================================
///
/// A field toad in a rescue jacket. The pictures are made by
/// `python tools/tugak.py` from tools/tugak.js (assets/images/tugak_*.png):
/// edit the script, never the PNGs.
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
    // The red strip above already names the alert: say what to do.
    if (alert.actions.isEmpty) return '${alert.title}. Stay tuned here.';
    return '${alert.actions.take(2).join('. ')}.';
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
  'See a flooded street? One photo from the + button. That\'s all I need.',
  'Pack the go-bag before the rain does. The checklist is in Help.',
  'Safe after a storm? Tap + and send "I\'m safe" so nobody has to guess.',
];

/// Tugak's picture. [hop] > 0 lifts him (the tap jump).
class TugakImage extends StatelessWidget {
  final TugakMood mood;
  final double size;
  const TugakImage({this.mood = TugakMood.fine, this.size = 120, super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/tugak_${mood.name}.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      // Missing file (e.g. tugak.py not run yet): leave the space empty.
      errorBuilder: (_, _, _) => SizedBox(width: size, height: size),
      semanticLabel: 'Tugak, the AgosAlert toad',
    );
  }
}

/// Tugak with his speech bubble. Tap him: he hops and tells a tip (except
/// on a high alert, when the instruction stays up).
class TugakSays extends StatefulWidget {
  final TugakMood mood;
  final String line;
  final double size;

  /// Bubble to the left of Tugak (default) or above him.
  final bool bubbleAbove;

  /// If set: [beside] on the left, Tugak on the right, and the bubble
  /// below both at full width, pointing up at him (the sky card).
  final Widget? beside;
  const TugakSays({
    required this.mood,
    required this.line,
    this.size = 112,
    this.bubbleAbove = false,
    this.beside,
    super.key,
  });

  @override
  State<TugakSays> createState() => _TugakSaysState();
}

class _TugakSaysState extends State<TugakSays>
    with SingleTickerProviderStateMixin {
  // -1 = say the weather line; 0, 1, 2... = which tip.
  int _tip = -1;

  // The hop: 0 -> 1 -> 0 over 450 ms (see _lift).
  late final AnimationController _hop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  @override
  void didUpdateWidget(TugakSays old) {
    super.didUpdateWidget(old);
    // New weather line (e.g. the time scrubber moved): drop the tip and
    // say it. A new mood gets a hop, so the change is noticed.
    if (old.line != widget.line) _tip = -1;
    if (old.mood != widget.mood && !MediaQuery.disableAnimationsOf(context)) {
      _hop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _hop.dispose();
    super.dispose();
  }

  void _tap() {
    _hop.forward(from: 0);
    if (widget.mood == TugakMood.storm) return; // serious: keep the order up
    setState(() => _tip = (_tip + 1) % kTugakTips.length);
  }

  // A hop is a quick rise and fall: up 14 px at the middle (t = 0.5), back
  // down at the end, a straight line each way.
  double _lift(double t) => -14 * (t < 0.5 ? t * 2 : (1 - t) * 2);

  @override
  Widget build(BuildContext context) {
    final text = _tip < 0 ? widget.line : kTugakTips[_tip];
    final beside = widget.beside;
    final bubble = _Bubble(
      text: text,
      serious: widget.mood == TugakMood.storm,
      tailRight: !widget.bubbleAbove && beside == null,
      tailTopRight: beside != null,
      fullWidth: beside != null,
    );
    final frog = Semantics(
      button: true,
      label: 'Tugak. Tap for a tip.',
      child: PressableScale(
        onTap: _tap,
        child: AnimatedBuilder(
          animation: _hop,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, _lift(Curves.easeOut.transform(_hop.value))),
            child: child,
          ),
          // Cross-fades between moods instead of blinking.
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: TugakImage(
              key: ValueKey(widget.mood),
              mood: widget.mood,
              size: widget.size,
            ),
          ),
        ),
      ),
    );
    if (beside != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: beside),
              frog,
            ],
          ),
          bubble,
        ],
      );
    }
    if (widget.bubbleAbove) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [bubble, frog],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: widget.size * 0.35),
            child: Align(alignment: Alignment.bottomRight, child: bubble),
          ),
        ),
        frog,
      ],
    );
  }
}

/// White speech bubble with a small "TUGAK" label. The text fades when it
/// changes. [serious] (high alert) gets a red label instead of the brown.
class _Bubble extends StatelessWidget {
  final String text;
  final bool serious;
  final bool tailRight;
  final bool tailTopRight;
  final bool fullWidth;
  const _Bubble({
    required this.text,
    required this.serious,
    required this.tailRight,
    this.tailTopRight = false,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: fullWidth ? double.infinity : 260),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        // The squared corner points at Tugak, like a speech-bubble tail.
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: Radius.circular(tailTopRight ? 4 : 16),
          bottomLeft: const Radius.circular(16),
          bottomRight: Radius.circular(tailRight ? 4 : 16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            serious ? 'TUGAK · ALERT' : 'TUGAK',
            style: TextStyle(
              color: serious ? kDanger : const Color(0xFF8C6C43),
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(
              text,
              key: ValueKey(text),
              style: const TextStyle(
                color: kInk,
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
