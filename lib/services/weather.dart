import 'dart:convert';

import 'package:flutter/cupertino.dart' show CupertinoIcons;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../theme.dart';

/// ============================================================
/// LIVE WEATHER for Mabalacat City from Open-Meteo
/// (https://open-meteo.com). Free, no API key, and it allows
/// browser requests, so it works on Flutter web.
/// ============================================================

class HourlyForecast {
  final DateTime time;
  final double temperature;
  final int rainChance; // %
  final double rain; // mm expected in this hour
  final int weatherCode;
  final bool isDay;
  final int humidity; // %
  final double windSpeed; // km/h
  const HourlyForecast(
    this.time,
    this.temperature,
    this.rainChance,
    this.rain,
    this.weatherCode,
    this.isDay,
    this.humidity,
    this.windSpeed,
  );
}

class DailyForecast {
  final DateTime date;
  final double max;
  final double min;
  final int rainChance; // %
  final double rainSum; // mm
  final int weatherCode;
  const DailyForecast(
    this.date,
    this.max,
    this.min,
    this.rainChance,
    this.rainSum,
    this.weatherCode,
  );
}

class MabalacatWeather {
  final double temperature;
  final double feelsLike;
  final int humidity;
  final double precipitation; // mm in the last 15 minutes
  final double windSpeed; // km/h
  final int weatherCode; // WMO code, see weatherInfo()
  final bool isDay;
  final DateTime time; // local Manila time
  final List<HourlyForecast> hourly; // next 24 hours
  final List<DailyForecast> daily; // today + next days
  // Rain in each 15 minutes of the next 2 hours: (start time, mm).
  // Open-Meteo makes these from its forecast models (outside Europe and
  // North America they're filled in from hourly data, not from radar).
  final List<(DateTime, double)> nextTwoHours;

  const MabalacatWeather({
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.precipitation,
    required this.windSpeed,
    required this.weatherCode,
    required this.isDay,
    required this.time,
    required this.hourly,
    required this.daily,
    required this.nextTwoHours,
  });

  DailyForecast get today => daily.first;

  /// When rain is expected to start in the next 2 hours, or null if it
  /// stays dry. 0.1 mm in 15 minutes is about the lightest rain you notice.
  DateTime? get rainStartsAt {
    for (final (t, mm) in nextTwoHours) {
      if (mm >= 0.1) return t;
    }
    return null;
  }

  /// One plain line for the rain chart: "Rain likely from 3:15 PM" or
  /// "No rain in the next 2 hours".
  String get nextTwoHoursText {
    final start = rainStartsAt;
    if (start == null) return 'No rain in the next 2 hours';
    if (!start.isAfter(time)) return 'Raining now';
    return 'Rain likely from ${formatTime(start)}';
  }

  // The web address we ask for the weather. Uri.https builds it safely:
  //   https://api.open-meteo.com/v1/forecast?latitude=15.2236&...
  // `current` / `hourly` / `daily` list which values we want back;
  // anything not listed isn't sent (smaller, faster download).
  static final _url = Uri.https('api.open-meteo.com', '/v1/forecast', {
    'latitude': '15.2236', // Mabalacat City
    'longitude': '120.5714',
    'current':
        'temperature_2m,relative_humidity_2m,apparent_temperature,'
        'precipitation,weather_code,wind_speed_10m,is_day',
    'hourly':
        'temperature_2m,precipitation_probability,precipitation,'
        'weather_code,is_day,relative_humidity_2m,wind_speed_10m',
    'minutely_15': 'precipitation',
    'forecast_minutely_15': '9', // the current quarter + the next 2 hours
    'daily':
        'weather_code,temperature_2m_max,temperature_2m_min,'
        'precipitation_probability_max,precipitation_sum',
    'forecast_days': '5',
    'timezone': 'Asia/Manila',
  });

  // The last request, shared by everyone who asks, so the weather can be
  // downloaded while the user is still on the login screen and Home shows
  // it instantly.
  //
  // It stores the Future (the request itself), not the finished result.
  // A Future is a "promise" of a value that arrives later. Storing it
  // means a second caller that asks while the download is still running
  // gets the SAME download instead of starting a second one.
  // `static` = one shared copy for the whole app, not one per object.
  static Future<MabalacatWeather>? _cached;
  static DateTime? _cachedAt;

  /// Returns the shared weather request, starting a new one if there is
  /// none yet, it's older than 10 minutes, it failed, or [refresh] is true.
  static Future<MabalacatWeather> load({bool refresh = false}) {
    final stale =
        _cachedAt == null ||
        DateTime.now().difference(_cachedAt!) > const Duration(minutes: 10);
    if (refresh || stale || _cached == null) {
      final request = fetch();
      _cached = request;
      _cachedAt = DateTime.now();
      // If it fails, forget it so the next load() tries again. (Listening
      // here also stops a failed background download from being reported
      // as an uncaught error.)
      // identical(...) check: only clear the cache if it still holds THIS
      // request. If a newer request replaced it meanwhile (e.g. the user
      // pulled to refresh), an old failure mustn't wipe the new one.
      request.then(
        (_) {},
        onError: (Object _) {
          if (identical(_cached, request)) {
            _cached = null;
            _cachedAt = null;
          }
        },
      );
    }
    return _cached!;
  }

  /// Downloads the weather once and turns it into a [MabalacatWeather].
  /// Use [load] instead in the app; it reuses a recent download.
  static Future<MabalacatWeather> fetch() async {
    // `await` pauses here until the server answers (without freezing the
    // app). If it takes over 10 seconds, give up with an error instead of
    // spinning forever on a bad connection.
    final res = await http.get(_url).timeout(const Duration(seconds: 10));
    // 200 = "OK". Anything else (e.g. 500 = server problem) is an error.
    if (res.statusCode != 200) {
      throw Exception('Weather API returned ${res.statusCode}');
    }
    // The answer is JSON text. jsonDecode turns it into Dart Maps and
    // Lists. The shape is roughly:
    //   { "current": { "temperature_2m": 31.2, ... },
    //     "hourly":  { "time": ["2026-09-25T00:00", ...],
    //                  "temperature_2m": [27.1, 26.8, ...], ... },
    //     "daily":   { same idea, one entry per day } }
    // So hourly/daily are "columns": item i of every list belongs to the
    // same hour/day as time[i].
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final cur = json['current'] as Map<String, dynamic>;
    final h = json['hourly'] as Map<String, dynamic>;
    final d = json['daily'] as Map<String, dynamic>;
    final now = DateTime.parse(cur['time'] as String);

    // Small helper: item i of a list as a number, or 0 if the API sent
    // null there (it sometimes has gaps).
    num n(List list, int i) => (list[i] as num?) ?? 0;

    // Hourly data starts at midnight today; keep the next 24 hours.
    // Hours before the current hour are skipped with `continue`, and the
    // loop stops once 24 hours are collected.
    final hTimes = (h['time'] as List).cast<String>();
    final hourly = <HourlyForecast>[];
    for (var i = 0; i < hTimes.length && hourly.length < 24; i++) {
      final t = DateTime.parse(hTimes[i]);
      if (t.isBefore(DateTime(now.year, now.month, now.day, now.hour))) {
        continue;
      }
      hourly.add(
        HourlyForecast(
          t,
          n(h['temperature_2m'], i).toDouble(),
          n(h['precipitation_probability'], i).toInt(),
          n(h['precipitation'], i).toDouble(),
          n(h['weather_code'], i).toInt(),
          n(h['is_day'], i) == 1,
          n(h['relative_humidity_2m'], i).toInt(),
          n(h['wind_speed_10m'], i).toDouble(),
        ),
      );
    }

    final dTimes = (d['time'] as List).cast<String>();
    final daily = [
      for (var i = 0; i < dTimes.length; i++)
        DailyForecast(
          DateTime.parse(dTimes[i]),
          n(d['temperature_2m_max'], i).toDouble(),
          n(d['temperature_2m_min'], i).toDouble(),
          n(d['precipitation_probability_max'], i).toInt(),
          n(d['precipitation_sum'], i).toDouble(),
          n(d['weather_code'], i).toInt(),
        ),
    ];

    // 15-minute rain: keep the quarters that haven't ended yet.
    final m = json['minutely_15'] as Map<String, dynamic>?;
    final nextTwoHours = <(DateTime, double)>[];
    if (m != null) {
      final mTimes = (m['time'] as List).cast<String>();
      for (var i = 0; i < mTimes.length; i++) {
        final t = DateTime.parse(mTimes[i]);
        if (t.add(const Duration(minutes: 15)).isAfter(now)) {
          nextTwoHours.add((t, n(m['precipitation'], i).toDouble()));
        }
      }
    }

    return MabalacatWeather(
      temperature: (cur['temperature_2m'] as num).toDouble(),
      feelsLike: (cur['apparent_temperature'] as num).toDouble(),
      humidity: (cur['relative_humidity_2m'] as num).toInt(),
      precipitation: (cur['precipitation'] as num).toDouble(),
      windSpeed: (cur['wind_speed_10m'] as num).toDouble(),
      weatherCode: (cur['weather_code'] as num).toInt(),
      isDay: cur['is_day'] == 1,
      time: now,
      hourly: hourly,
      daily: daily,
      nextTwoHours: nextTwoHours,
    );
  }

  /// A rough flood outlook from today's rain forecast.
  /// Not an official warning — PAGASA and local authorities are.
  ///
  /// The rules, checked from worst to best:
  ///   HIGH     - 30 mm or more of rain today, or a storm (see below) with
  ///              a 60%+ chance of rain.
  ///   MODERATE - 10 mm or more, or a 70%+ chance of rain.
  ///   LOW      - everything else.
  /// "Stormy" weather codes: 95+ = thunderstorm, 65 = heavy rain,
  /// 82 = violent rain showers (WMO codes, same as in weatherInfo()).
  /// The mm limits are our own simple choice, not an official standard.
  FloodOutlook get floodOutlook {
    final sum = today.rainSum;
    final chance = today.rainChance;
    final stormy = weatherCode >= 95 || weatherCode == 65 || weatherCode == 82;
    if (sum >= 30 || (stormy && chance >= 60)) {
      return const FloodOutlook(
        RiskLevel.high,
        'High flood risk',
        'Heavy rain expected. Flooding is likely in low-lying areas. Prepare to evacuate if told to.',
      );
    }
    if (sum >= 10 || chance >= 70) {
      return const FloodOutlook(
        RiskLevel.moderate,
        'Moderate flood risk',
        'Significant rain expected. Stay alert near rivers and low-lying streets.',
      );
    }
    return const FloodOutlook(
      RiskLevel.normal,
      'Low flood risk',
      'Little rain expected today. No flooding expected.',
    );
  }
}

class FloodOutlook {
  final RiskLevel level;
  final String title;
  final String message;
  const FloodOutlook(this.level, this.title, this.message);
}

/// Turns a WMO weather code into a label and icon.
///
/// WMO codes are a world standard numbering for weather: 0 clear,
/// 1-3 clouds, 45-48 fog, 51-57 drizzle, 61-67 rain, 71-77 snow,
/// 80-82 rain showers, 95-99 thunderstorm. The checks go from low to
/// high, so each `code <= X` only catches codes the earlier lines didn't.
/// Returns a record: two values at once, used like
/// `final (label, icon) = weatherInfo(code);`.
(String, IconData) weatherInfo(int code, {bool isDay = true}) {
  if (code == 0) {
    return isDay
        ? ('Clear sky', CupertinoIcons.sun_max_fill)
        : ('Clear night', CupertinoIcons.moon_fill);
  }
  if (code <= 2) {
    return isDay
        ? ('Partly cloudy', CupertinoIcons.cloud_fill)
        : ('Partly cloudy', CupertinoIcons.cloud_moon_fill);
  }
  if (code == 3) return ('Overcast', CupertinoIcons.cloud_fill);
  if (code <= 48) return ('Foggy', CupertinoIcons.cloud_fog_fill);
  if (code <= 57) return ('Drizzle', CupertinoIcons.cloud_drizzle_fill);
  if (code <= 67) return ('Rain', CupertinoIcons.drop_fill);
  if (code <= 77) return ('Snow', CupertinoIcons.snow);
  if (code <= 82) return ('Rain showers', CupertinoIcons.umbrella_fill);
  return ('Thunderstorm', CupertinoIcons.cloud_bolt_rain_fill);
}

/// The sky card's colors, like looking up: blue on a clear day, slate when
/// it rains, dark storm gray, deep indigo at night. White text reads on
/// all of them.
List<Color> weatherGradient(int code, bool isDay) {
  if (code >= 95) return const [Color(0xFF3B404F), Color(0xFF16181F)];
  if (code >= 51) return const [Color(0xFF4A6375), Color(0xFF1E2A33)];
  if (!isDay) return const [Color(0xFF262C66), Color(0xFF0C0F2B)];
  if (code >= 3) return const [Color(0xFF5B6675), Color(0xFF2B323C)];
  return const [Color(0xFF3F8AE6), Color(0xFF173F80)];
}

// 24-hour to 12-hour clock: `% 12` is the remainder after dividing by 12
// (13 -> 1, 23 -> 11). 0 (midnight) and 12 (noon) both give 0, which
// must show as 12, hence the `== 0 ? 12` part.
String formatHour(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h ${t.hour < 12 ? 'AM' : 'PM'}';
}

String formatTime(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}';
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String formatWeekday(DateTime d) => _weekdays[d.weekday - 1];
String formatDate(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day}';
