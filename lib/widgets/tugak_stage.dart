import '../services/alerts.dart';
import '../services/weather.dart';
import 'tugak.dart';

// Tugak's terrace, the 3D scene at the top of the Weather tab. Two versions
// of the same TugakStage class, picked when compiling (like AgosMap):
// - in the browser: three.js in a <div> (web/tugak/scene.js, the model is
//   web/tugak/tugak.glb from tools/tugak3d.py);
// - everywhere else (tests, a phone build): his still picture on the sky.
export 'tugak_stage_io.dart'
    if (dart.library.js_interop) 'tugak_stage_web.dart';

/// What the scene shows for one hour: the sky, the rain, and Tugak's mood.
/// Sent to the scene as JSON (see skyFor() in web/tugak/scene.js).
class TugakWeather {
  final int code; // WMO weather code
  final bool isDay;
  final double hour; // local hour of day, 0-24 (sun / moon position)
  final int cloud; // % of the sky covered
  final double rain; // mm in that hour
  final double wind; // km/h (slants the rain)
  final TugakMood mood;

  const TugakWeather({
    required this.code,
    required this.isDay,
    required this.hour,
    required this.cloud,
    required this.rain,
    required this.wind,
    required this.mood,
  });

  /// Hour [i] of the forecast (0 = now, using the live readings).
  factory TugakWeather.at(MabalacatWeather w, int i, {AppAlert? alert}) {
    final h = w.hourly[i.clamp(0, w.hourly.length - 1)];
    final now = i == 0;
    final t = now ? w.time : h.time;
    return TugakWeather(
      code: now ? w.weatherCode : h.weatherCode,
      isDay: now ? w.isDay : h.isDay,
      hour: t.hour + t.minute / 60,
      cloud: now ? w.cloud : h.cloud,
      rain: h.rain,
      wind: now ? w.windSpeed : h.windSpeed,
      mood: now ? tugakMoodFor(w, alert: alert) : tugakMoodAt(h),
    );
  }

  /// His face for the mood: lids wide open on a storm, heavy at night.
  String get face => switch (mood) {
    TugakMood.storm => 'alert',
    TugakMood.rain => 'wet',
    TugakMood.night => 'sleepy',
    TugakMood.fine => 'stern',
  };

  Map<String, Object> toJson() => {
    'code': code,
    'isDay': isDay,
    'hour': hour,
    'cloud': cloud,
    'rain': rain,
    'wind': wind,
    'mood': face,
  };
}

/// What a tap on the scene hit.
enum StageTap { tugak }

/// The part of the stage Flutter covers with the live readings (Nov 14
/// 2026: the stage is the "now" card). Tugak is framed in what's left, and
/// his bubble goes to the free corner: [below] = across the bottom (phones),
/// else bottom left beside him. In CSS px.
/// [zoom] > 1 brings the camera closer (phones: a shorter card, a bigger
/// Tugak; Nov 14 2026, Adrian).
class StageReserve {
  final double left, top, bottom, zoom;
  final bool below;
  const StageReserve({
    this.left = 0,
    this.top = 0,
    this.bottom = 0,
    this.below = false,
    this.zoom = 1,
  });

  Map<String, Object> toJson() => {
    'left': left,
    'top': top,
    'bottom': bottom,
    'bubble': below ? 'below' : 'side',
    'zoom': zoom,
  };

  @override
  bool operator ==(Object other) =>
      other is StageReserve &&
      other.left == left &&
      other.top == top &&
      other.bottom == bottom &&
      other.below == below &&
      other.zoom == zoom;

  @override
  int get hashCode => Object.hash(left, top, bottom, below, zoom);
}
