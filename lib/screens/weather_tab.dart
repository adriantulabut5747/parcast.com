import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/demo_data.dart';
import '../services/weather.dart';
import '../theme.dart';
import '../widgets/city_map.dart';
import '../widgets/common.dart';
import '../widgets/flood_depth.dart';
import '../widgets/my_barangay.dart';
import '../widgets/responsive.dart';
import '../widgets/skeleton.dart';
import '../widgets/tugak.dart';
import 'deferred_screens.dart';
import 'home_shell.dart';

/// ============================================================
/// WEATHER TAB (the first tab) — "am I safe right now?"
/// ============================================================
/// Top to bottom: greeting + your barangay, the newest high alert (if
/// any), the sky card (live weather + Tugak, scrubbable through the next
/// 24 hours), the flood outlook (rain forecast AND reports, side by side),
/// the city map of all 27 barangays, and the 5-day forecast.
class WeatherTab extends StatefulWidget {
  const WeatherTab({super.key});

  @override
  State<WeatherTab> createState() => _WeatherTabState();
}

class _WeatherTabState extends State<WeatherTab> {
  // Usually already downloaded (prefetch.dart starts it at launch).
  late Future<MabalacatWeather> _weather = MabalacatWeather.load();

  // Pull-to-refresh: RefreshIndicator shows its spinner until the Future
  // returned here finishes, so we `await` the new download. setState swaps
  // in the new request, which makes the FutureBuilder below show the
  // skeleton and then the fresh weather.
  Future<void> _refresh() async {
    final next = MabalacatWeather.load(refresh: true);
    setState(() => _weather = next);
    try {
      await next;
    } catch (_) {
      // The weather card shows the error and a Retry button.
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    final wide = screenSizeOf(context) == ScreenSize.desktop;
    const gap = 16.0;
    return RefreshIndicator(
      onRefresh: _refresh,
      color: c.accent,
      child: ListView(
        padding: pagePadding(context),
        children: [
          const FadeSlideIn(child: _Greeting()),
          const SizedBox(height: 16),
          // The newest unread high alert, as a slim red strip. Rebuilds
          // when an alert is read (readAlerts).
          ValueListenableBuilder<Set<String>>(
            valueListenable: readAlerts,
            builder: (context, _, _) {
              final a = newestHighAlert;
              if (a == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: gap),
                child: FadeSlideIn(child: _AlertStrip(alert: a)),
              );
            },
          ),
          // `snap` says how the download is going: not done yet ->
          // skeleton, failed -> error card, done -> the weather.
          FutureBuilder<MabalacatWeather>(
            future: _weather,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const _WeatherSkeleton();
              }
              if (snap.hasError) return _weatherError(c);
              final w = snap.data!;
              Widget part(Widget child, int delayMs) => FadeSlideIn(
                delay: Duration(milliseconds: delayMs),
                child: child,
              );
              final sky = part(
                ValueListenableBuilder<Set<String>>(
                  valueListenable: readAlerts,
                  builder: (context, _, _) =>
                      _SkyCard(weather: w, alert: newestHighAlert),
                ),
                0,
              );
              final outlook = part(_OutlookCard(weather: w), 80);
              final city = part(const _CityCard(), 140);
              final days = part(_DaysCard(weather: w), 200);
              if (!wide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: gap,
                  children: [sky, outlook, city, days],
                );
              }
              // Desktop: sky on the left, outlook + days on the right,
              // then the city map across the full width.
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 20,
                children: [
                  TwoColumns(
                    leftFlex: 7,
                    rightFlex: 5,
                    spacing: 20,
                    left: [sky],
                    right: [outlook, days],
                  ),
                  city,
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Weather by Open-Meteo · Sections marked SAMPLE use demo data · Unofficial demo',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.textSecondary.withValues(alpha: 0.8),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _weatherError(AppColors c) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconBadge(CupertinoIcons.wifi_slash, c.textSecondary, size: 46),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Weather unavailable',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Check your internet connection.',
                  style: TextStyle(color: c.textSecondary, fontSize: 12.5),
                ),
              ],
            ),
          ),
          FilledButton.tonal(onPressed: _refresh, child: const Text('Retry')),
        ],
      ),
    );
  }
}

/// The newest unread High alert, or null. Shown as the red strip and
/// makes Tugak serious.
AppAlert? get newestHighAlert => kAlerts
    .where(
      (a) => a.severity == RiskLevel.high && !readAlerts.value.contains(a.id),
    )
    .firstOrNull;

/// Date, greeting in English and Kapampangan (by Manila time, same hours as
/// the landing page), and the user's barangay.
class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    final now = DateTime.now();
    final h = now.hour;
    final (greeting, kapampangan) = h >= 5 && h < 11
        ? ('Good morning', 'Mayap a abak')
        : h >= 11 && h < 13
        ? ('Good noon', 'Mayap a ugtu')
        : h >= 13 && h < 18
        ? ('Good afternoon', 'Mayap a gatpanapun')
        : ('Good evening', 'Mayap a bengi');
    // Greeting on the left; once a barangay is picked, its chip on the
    // right, centered on the greeting. (Not picked yet: the city map's
    // "Which one is yours?" asks instead.) The greeting shrinks a little
    // rather than wrap when a long barangay name needs the room.
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatDate(now).toUpperCase(),
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  greeting,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: kDisplayFont,
                    color: c.textPrimary,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Tooltip(
                message: 'Kapampangan for "$greeting"',
                child: Text(
                  kapampangan,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        ValueListenableBuilder<String?>(
          valueListenable: myBarangay,
          builder: (context, b, _) => b == null
              ? const SizedBox.shrink()
              : const Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: MyBarangayChip(),
                ),
        ),
      ],
    );
  }
}

/// Slim red strip for a high alert. Tap: the notifications sheet.
class _AlertStrip extends StatelessWidget {
  final AppAlert alert;
  const _AlertStrip({required this.alert});

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    return Semantics(
      button: true,
      label: 'High alert: ${alert.title}. Open notifications',
      child: PressableScale(
        onTap: () => openNotifications(context),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 11, 10, 11),
          decoration: BoxDecoration(
            color: kDanger.withValues(alpha: c.isDark ? 0.16 : 0.1),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: kDanger.withValues(alpha: 0.45)),
          ),
          child: Row(
            children: [
              const Icon(
                CupertinoIcons.exclamationmark_triangle_fill,
                color: kDanger,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: alert.title,
                        style: TextStyle(
                          color: c.isDark
                              ? const Color(0xFFFFB4AE)
                              : const Color(0xFFB91C1C),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextSpan(
                        text: '  ·  ${timeAgo(alert.ago)}',
                        style: TextStyle(color: c.textSecondary),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              Icon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: c.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ------------------------------------------------------------
/// The sky card, scrubbable through the next 24 hours: drag along the
/// strip at the bottom and the sky color, rain, stars, numbers and Tugak
/// all switch to that hour's forecast. The water at the bottom rises with
/// the rain forecast to add up by then.
/// ------------------------------------------------------------
class _SkyCard extends StatefulWidget {
  final MabalacatWeather weather;
  final AppAlert? alert;
  const _SkyCard({required this.weather, this.alert});

  @override
  State<_SkyCard> createState() => _SkyCardState();
}

class _SkyCardState extends State<_SkyCard> {
  int _i = 0; // the hour shown: 0 = now, 1 = next hour, ...
  bool _scrubbed = false; // hides the "drag" hint once used

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load all of Tugak's moods now, so dragging never shows a gap.
    for (final m in TugakMood.values) {
      precacheImage(
        AssetImage('assets/images/tugak_${m.name}.png'),
        context,
        onError: (_, _) {}, // missing picture: TugakImage leaves a gap
      );
    }
  }

  void _select(int i) {
    if (i == _i) return;
    HapticFeedback.selectionClick();
    setState(() {
      _i = i;
      _scrubbed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.weather;
    final hours = w.hourly;
    final i = math.min(_i, hours.length - 1);
    final h = hours[i];
    final now = i == 0;
    // "Now" uses the live readings; other hours use the forecast.
    final code = now ? w.weatherCode : h.weatherCode;
    final isDay = now ? w.isDay : h.isDay;
    final (label, _) = weatherInfo(code, isDay: isDay);
    final raining = code >= 51 || (!now && h.rain >= 0.1);
    final stormy = code >= 95 || h.rain >= kHeavyRainMm;
    final clearNight = !isDay && !raining && code <= 2;
    final alert = widget.alert;
    final rainBy = hours.take(i + 1).fold<double>(0, (s, h) => s + h.rain);
    final rainTotal = hours.fold<double>(0, (s, h) => s + h.rain);
    final day =
        w.daily.where((d) => _sameDay(d.date, h.time)).firstOrNull ?? w.today;
    final dayWord = _sameDay(h.time, w.time) ? 'Today' : formatWeekday(h.time);
    const white70 = Color(0xB3FFFFFF);

    return CustomPaint(
      foregroundPainter: const GlassEdgePainter(radius: 30, dark: true),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        // AnimatedContainer blends the old sky into the new one.
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: weatherGradient(code, isDay),
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedOpacity(
                  opacity: clearNight ? 1 : 0,
                  duration: const Duration(milliseconds: 500),
                  child: const CustomPaint(painter: _Stars()),
                ),
              ),
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  child: raining
                      ? _RainStreaks(key: ValueKey(stormy), heavy: stormy)
                      : const SizedBox.expand(),
                ),
              ),
              // Rain adding up: full height (half the card) at 30 mm, the
              // amount the flood outlook calls a high-risk day.
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: (rainBy / 30).clamp(0.0, 1.0)),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, level, _) => _RisingWater(level: level),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _topRow(now, h, dayWord, white70),
                    const SizedBox(height: 8),
                    // Temperature block on the left, Tugak on the right,
                    // his bubble under both at full width.
                    TugakSays(
                      mood: now
                          ? tugakMoodFor(w, alert: alert)
                          : tugakMoodAt(h),
                      line: now
                          ? tugakLine(w, alert: alert)
                          : tugakLineAt(h, serious: alert != null),
                      size: 136,
                      beside: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Counts up from 0 at first, then glides
                          // between hours.
                          TweenAnimationBuilder<double>(
                            tween: Tween(
                              begin: 0,
                              end: now ? w.temperature : h.temperature,
                            ),
                            duration: const Duration(milliseconds: 700),
                            curve: Curves.easeOutCubic,
                            builder: (context, v, _) => Text(
                              '${v.round()}°',
                              style: const TextStyle(
                                fontFamily: kDisplayFont,
                                color: Colors.white,
                                fontSize: 80,
                                height: 1,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            label,
                            style: const TextStyle(
                              fontFamily: kDisplayFont,
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            now
                                ? 'H ${w.today.max.round()}°  ·  L ${w.today.min.round()}°  ·  Feels ${w.feelsLike.round()}°'
                                : '$dayWord  ·  H ${day.max.round()}°  ·  L ${day.min.round()}°',
                            style: const TextStyle(
                              color: white70,
                              fontSize: 12.5,
                            ),
                          ),
                          if (now) ...[
                            const SizedBox(height: 8),
                            _nextTwoHours(w),
                          ],
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _stats(
                      chance: h.rainChance,
                      rain: h.rain,
                      humidity: now ? w.humidity : h.humidity,
                      wind: now ? w.windSpeed : h.windSpeed,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'NEXT 24 HOURS',
                            style: TextStyle(
                              color: white70,
                              fontSize: 10.5,
                              letterSpacing: 1,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          now
                              ? (rainTotal < 0.1
                                    ? 'Dry for 24 hours'
                                    : '${rainTotal.toStringAsFixed(1)} mm of rain')
                              : '${rainBy.toStringAsFixed(1)} mm of rain by ${formatHour(h.time)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _Scrubber(hours: hours, selected: i, onChanged: _select),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (final k in [0, 6, 12, 18])
                          if (k < hours.length)
                            Text(
                              k == 0 ? 'Now' : formatHour(hours[k].time),
                              style: const TextStyle(
                                color: white70,
                                fontSize: 10.5,
                              ),
                            ),
                      ],
                    ),
                    // A one-time nudge: the strip is draggable.
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      child: _scrubbed
                          ? const SizedBox(width: double.infinity)
                          : const Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    CupertinoIcons.hand_draw,
                                    color: white70,
                                    size: 14,
                                  ),
                                  SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Drag along the strip to see any hour',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: white70,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topRow(bool now, HourlyForecast h, String dayWord, Color white70) {
    return Row(
      children: [
        if (now)
          const LiveDot(color: Color(0xFF7CFFB2))
        else
          Icon(CupertinoIcons.clock, color: white70, size: 13),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            now
                ? 'MABALACAT CITY · LIVE'
                : 'FORECAST · ${dayWord.toUpperCase()} ${formatHour(h.time)}',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              letterSpacing: 1,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (now)
          Text(
            formatTime(widget.weather.time),
            style: TextStyle(color: white70, fontSize: 11.5),
          )
        else
          // Back to the live weather.
          Semantics(
            button: true,
            label: 'Back to now',
            child: PressableScale(
              onTap: () => _select(0),
              child: Container(
                padding: const EdgeInsets.fromLTRB(9, 4, 10, 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.arrow_counterclockwise,
                      color: Colors.white,
                      size: 12,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Now',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// "No rain in the next 2 hours" / "Rain likely from 3:15 PM".
  Widget _nextTwoHours(MabalacatWeather w) {
    final wet = w.rainStartsAt != null;
    return Row(
      children: [
        Icon(
          wet ? CupertinoIcons.cloud_rain_fill : CupertinoIcons.checkmark_alt,
          color: Colors.white,
          size: 14,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            w.nextTwoHoursText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _stats({
    required int chance,
    required double rain,
    required int humidity,
    required double wind,
  }) {
    Widget stat(IconData icon, String value, String label) => Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 10),
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          stat(CupertinoIcons.umbrella_fill, '$chance%', 'Rain chance'),
          stat(
            CupertinoIcons.drop_fill,
            '${rain.toStringAsFixed(1)} mm',
            'Rain this hour',
          ),
          stat(CupertinoIcons.drop, '$humidity%', 'Humidity'),
          stat(CupertinoIcons.wind, '${wind.round()} km/h', 'Wind'),
        ],
      ),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// The draggable strip: one rain bar per hour (blue when rain is
/// expected), the temperature as a line above, and a thumb on the hour
/// shown. Tap or drag anywhere on it; arrow keys work when it's focused.
class _Scrubber extends StatefulWidget {
  final List<HourlyForecast> hours;
  final int selected;
  final ValueChanged<int> onChanged;
  const _Scrubber({
    required this.hours,
    required this.selected,
    required this.onChanged,
  });

  @override
  State<_Scrubber> createState() => _ScrubberState();
}

class _ScrubberState extends State<_Scrubber> {
  bool _focused = false;

  String _name(int i) => i == 0 ? 'Now' : formatHour(widget.hours[i].time);

  void _step(int by) => widget.onChanged(
    (widget.selected + by).clamp(0, widget.hours.length - 1),
  );

  @override
  Widget build(BuildContext context) {
    final n = widget.hours.length;
    final sel = widget.selected;
    final h = widget.hours[sel];
    return Semantics(
      slider: true,
      label: 'Forecast hour',
      value:
          '${_name(sel)}, ${h.temperature.round()} degrees, ${h.rainChance}% chance of rain',
      increasedValue: sel < n - 1 ? _name(sel + 1) : null,
      decreasedValue: sel > 0 ? _name(sel - 1) : null,
      onIncrease: sel < n - 1 ? () => _step(1) : null,
      onDecrease: sel > 0 ? () => _step(-1) : null,
      child: Focus(
        onFocusChange: (f) => setState(() => _focused = f),
        onKeyEvent: (_, e) {
          if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
            return KeyEventResult.ignored;
          }
          if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
            _step(1);
            return KeyEventResult.handled;
          }
          if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _step(-1);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: LayoutBuilder(
          builder: (context, box) {
            void at(Offset p) => widget.onChanged(
              (p.dx / box.maxWidth * n).floor().clamp(0, n - 1),
            );
            return MouseRegion(
              cursor: SystemMouseCursors.resizeLeftRight,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => at(d.localPosition),
                onHorizontalDragStart: (d) => at(d.localPosition),
                onHorizontalDragUpdate: (d) => at(d.localPosition),
                // Bars grow in once; the thumb glides between hours.
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, grow, _) => TweenAnimationBuilder<double>(
                    tween: Tween(end: sel.toDouble()),
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOut,
                    builder: (context, thumb, _) => CustomPaint(
                      size: Size(box.maxWidth, 64),
                      painter: _ScrubPainter(
                        widget.hours,
                        thumb: thumb,
                        grow: grow,
                        focused: _focused,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ScrubPainter extends CustomPainter {
  final List<HourlyForecast> hours;
  final double thumb; // the hour shown (fractional while gliding)
  final double grow; // 0 -> 1 intro
  final bool focused;
  _ScrubPainter(
    this.hours, {
    required this.thumb,
    required this.grow,
    required this.focused,
  });

  static const _rainBlue = Color(0xFF9FD0FF);

  @override
  void paint(Canvas canvas, Size size) {
    final n = hours.length;
    final col = size.width / n;
    const curveTop = 6.0, curveBottom = 24.0, barsTop = 32.0;
    final barsMax = size.height - barsTop - 2;
    final sel = thumb.round();

    // Rain bars. At least 2 mm tall scale, so a drizzle stays small.
    final top = math.max(2.0, hours.map((h) => h.rain).reduce(math.max));
    for (var i = 0; i < n; i++) {
      final r = hours[i].rain;
      final bh = math.max(2.5, barsMax * math.min(1, r / top) * grow);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          col * i + col * 0.18,
          size.height - 2 - bh,
          col * 0.64,
          bh,
        ),
        const Radius.circular(2),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..color = i == sel
              ? Colors.white
              : r >= 0.1
              ? _rainBlue.withValues(alpha: 0.85)
              : Colors.white.withValues(alpha: 0.2),
      );
    }

    // Temperature line, drawn in from the left.
    final temps = hours.map((h) => h.temperature).toList();
    final lo = temps.reduce(math.min), hi = temps.reduce(math.max);
    double y(double t) => hi - lo < 0.5
        ? (curveTop + curveBottom) / 2
        : curveBottom - (t - lo) / (hi - lo) * (curveBottom - curveTop);
    final path = Path();
    for (var i = 0; i < n; i++) {
      final p = Offset(col * (i + 0.5), y(temps[i]));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        // Smooth: curve through the midpoint between hours.
        final prev = Offset(col * (i - 0.5), y(temps[i - 1]));
        final mid = (prev + p) / 2;
        path.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
        if (i == n - 1) path.lineTo(p.dx, p.dy);
      }
    }
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * grow, size.height));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.75),
    );
    canvas.restore();

    // The thumb: a thin line through the hour and a dot on the line.
    final i0 = thumb.floor().clamp(0, n - 1);
    final i1 = math.min(i0 + 1, n - 1);
    final f = thumb - i0;
    final tx = col * (thumb + 0.5);
    final ty = y(temps[i0] + (temps[i1] - temps[i0]) * f);
    canvas.drawLine(
      Offset(tx, 0),
      Offset(tx, size.height),
      Paint()
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.4),
    );
    canvas.drawCircle(
      Offset(tx, ty),
      7,
      Paint()..color = Colors.white.withValues(alpha: 0.25),
    );
    canvas.drawCircle(Offset(tx, ty), 4.5, Paint()..color = Colors.white);

    if (focused) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(8),
        ).inflate(3),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Colors.white.withValues(alpha: 0.7),
      );
    }
  }

  @override
  bool shouldRepaint(_ScrubPainter old) =>
      old.hours != hours ||
      old.thumb != thumb ||
      old.grow != grow ||
      old.focused != focused;
}

/// Slow water across the bottom of the sky card. [level] 0..1 lifts it
/// from a calm strip to half the card.
class _RisingWater extends StatefulWidget {
  final double level;
  const _RisingWater({required this.level});

  @override
  State<_RisingWater> createState() => _RisingWaterState();
}

class _RisingWaterState extends State<_RisingWater>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _ctrl.stop();
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(painter: _WaterPainter(_ctrl, widget.level)),
      ),
    );
  }
}

class _WaterPainter extends CustomPainter {
  final Animation<double> anim;
  final double level;
  _WaterPainter(this.anim, this.level) : super(repaint: anim);

  @override
  void paint(Canvas canvas, Size size) {
    final surface = size.height - 22 - level * size.height * 0.5;
    // The water's top edge as an open line, and that line closed down to
    // the bottom corners for the fill.
    Path line(double amp, double len, double phase) {
      final p = Path()..moveTo(0, surface + amp * math.sin(phase));
      for (double x = 6; x <= size.width + 6; x += 6) {
        p.lineTo(x, surface + amp * math.sin(x / len * 2 * math.pi + phase));
      }
      return p;
    }

    Path filled(Path top) => Path.from(top)
      ..lineTo(size.width + 6, size.height)
      ..lineTo(0, size.height)
      ..close();

    final t = anim.value * 2 * math.pi;
    canvas.drawPath(
      filled(line(5, 260, t + 1.3)),
      Paint()..color = Colors.white.withValues(alpha: 0.06),
    );
    final front = line(3.5, 190, -t);
    canvas.drawPath(
      filled(front),
      Paint()..color = Colors.white.withValues(alpha: 0.08),
    );
    canvas.drawPath(
      front,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.22),
    );
  }

  @override
  bool shouldRepaint(_WaterPainter old) => old.level != level;
}

/// Faint stars on a clear night. Fixed positions (a seeded random), so
/// they don't jump around when the card rebuilds.
class _Stars extends CustomPainter {
  const _Stars();

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    final paint = Paint()..color = Colors.white;
    for (var i = 0; i < 40; i++) {
      final p = Offset(
        rnd.nextDouble() * size.width,
        rnd.nextDouble() * size.height * 0.6,
      );
      paint.color = Colors.white.withValues(
        alpha: 0.25 + rnd.nextDouble() * 0.5,
      );
      canvas.drawCircle(p, 0.6 + rnd.nextDouble() * 0.9, paint);
    }
  }

  @override
  bool shouldRepaint(_Stars old) => false;
}

/// Thin slanted rain streaks falling across the card, looping forever.
class _RainStreaks extends StatefulWidget {
  final bool heavy;
  const _RainStreaks({required this.heavy, super.key});

  @override
  State<_RainStreaks> createState() => _RainStreaksState();
}

class _RainStreaksState extends State<_RainStreaks>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Respect "reduce motion" (accessibility setting): still streaks.
    if (MediaQuery.disableAnimationsOf(context)) _ctrl.stop();
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _StreakPainter(_ctrl, count: widget.heavy ? 70 : 40),
        ),
      ),
    );
  }
}

class _StreakPainter extends CustomPainter {
  final Animation<double> anim;
  final int count;
  _StreakPainter(this.anim, {required this.count}) : super(repaint: anim);

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(3);
    final paint = Paint()
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < count; i++) {
      final x0 = rnd.nextDouble() * (size.width + 60);
      final speed = 0.8 + rnd.nextDouble() * 0.6;
      final len = 10 + rnd.nextDouble() * 14;
      // Each streak falls the card's height once per loop, starting at its
      // own offset so they don't move in lockstep.
      final t = (anim.value * speed + rnd.nextDouble()) % 1;
      final y = t * (size.height + len) - len;
      final x = x0 - t * 40; // slanted: drifts left as it falls
      paint.color = Colors.white.withValues(
        alpha: 0.12 + rnd.nextDouble() * 0.16,
      );
      canvas.drawLine(Offset(x, y), Offset(x - len * 0.3, y + len), paint);
    }
  }

  @override
  bool shouldRepaint(_StreakPainter old) => old.count != count;
}

/// ------------------------------------------------------------
/// Flood outlook: what the rain forecast says AND what people report
/// right now, side by side, so the two never contradict each other.
/// ------------------------------------------------------------

/// Active reports with water on the street (moderate or high), deepest
/// first.
List<FloodZone> get _floodedNow =>
    activeFloodZones.where((z) => z.risk != RiskLevel.normal).toList()
      ..sort((a, b) => b.depthCm.compareTo(a.depthCm));

class _OutlookCard extends StatelessWidget {
  final MabalacatWeather weather;
  const _OutlookCard({required this.weather});

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    final o = weather.floodOutlook;
    final flooded = _floodedNow;
    final worst = flooded.firstOrNull;
    // "Dau, Tabun, Mabiga and 1 more"
    final names = flooded.map((z) => z.barangay).toList();
    final list = names.length <= 3
        ? names.join(', ')
        : '${names.take(3).join(', ')} and ${names.length - 3} more';
    final calm = o.level == RiskLevel.normal;
    final title = flooded.isEmpty
        ? (calm ? 'No flooding expected' : o.title)
        : calm
        ? 'Little rain, but ${_count(flooded.length)} flooded'
        : o.title;
    final message = flooded.isEmpty
        ? o.message
        : calm
        ? 'Little rain is expected, but water is still up in $list. Check the map before you go.'
        : '${o.message} Already flooded: $list.';
    // The card's edge takes the worse of the two.
    final edge =
        RiskLevel.values[math.max(o.level.index, worst?.risk.index ?? 0)].color;

    return AppCard(
      borderColor: edge.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FLOOD OUTLOOK TODAY',
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 10,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontFamily: kDisplayFont,
              color: c.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _rainTile(c, o)),
                const SizedBox(width: 10),
                Expanded(child: _reportsTile(context, c, flooded, worst)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  CupertinoIcons.info_circle,
                  size: 13,
                  color: c.textSecondary,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Rain level is our estimate from the forecast, not an official warning. Follow PAGASA & local authorities.',
                  style: TextStyle(color: c.textSecondary, fontSize: 10.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _count(int n) => n == 1 ? '1 barangay' : '$n barangays';

  Widget _tile(AppColors c, {required List<Widget> children}) => Container(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
    decoration: BoxDecoration(
      color: c.surfaceAlt,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );

  Widget _eyebrow(AppColors c, String text) => Text(
    text,
    style: TextStyle(
      color: c.textSecondary,
      fontSize: 9.5,
      letterSpacing: 0.8,
      fontWeight: FontWeight.w800,
    ),
  );

  Widget _big(String text, Color color) => Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      fontFamily: kDisplayFont,
      color: color,
      fontSize: 22,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.4,
    ),
  );

  Widget _small(AppColors c, String text) =>
      Text(text, style: TextStyle(color: c.textSecondary, fontSize: 11.5));

  Widget _rainTile(AppColors c, FloodOutlook o) {
    final today = weather.today;
    final step = o.level.index; // low 0, moderate 1, high 2
    return _tile(
      c,
      children: [
        _eyebrow(c, 'RAIN FORECAST'),
        const SizedBox(height: 4),
        _big(
          o.level == RiskLevel.normal ? 'Low' : o.level.label,
          o.level.color,
        ),
        _small(
          c,
          '${today.rainSum.toStringAsFixed(1)} mm · ${today.rainChance}% chance',
        ),
        const Spacer(),
        const SizedBox(height: 10),
        // Three-step meter: Low · Moderate · High, filling one by one.
        Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              Expanded(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: i <= step ? 1 : 0),
                  duration: Duration(milliseconds: 500 + i * 250),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => Container(
                    height: 5,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      color: c.surfaceAlt,
                    ),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: v,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          color: RiskLevel.values[i].color,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (i < 2) const SizedBox(width: 4),
            ],
          ],
        ),
      ],
    );
  }

  Widget _reportsTile(
    BuildContext context,
    AppColors c,
    List<FloodZone> flooded,
    FloodZone? worst,
  ) {
    return Semantics(
      button: true,
      label: 'Open flood reports',
      child: PressableScale(
        onTap: () => HomeShell.of(context)?.switchTab(2),
        child: _tile(
          c,
          children: [
            Row(
              children: [
                Expanded(child: _eyebrow(c, 'REPORTED NOW')),
                const SampleBadge(),
              ],
            ),
            const SizedBox(height: 4),
            _big(
              flooded.isEmpty ? 'None' : _count(flooded.length),
              worst?.risk.color ?? kSafe,
            ),
            _small(
              c,
              worst == null
                  ? 'No flooded streets reported'
                  : 'Deepest: ${worst.barangay}, ${formatCm(worst.depthCm)}',
            ),
            const Spacer(),
            const SizedBox(height: 8),
            Row(
              children: [
                Flexible(
                  child: Text(
                    'See reports',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(CupertinoIcons.chevron_right, size: 13, color: c.accent),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ------------------------------------------------------------
/// Your city right now: the 27 barangays on Mabalacat's outline, flooded
/// ones pulsing. Tap one to see its latest report and make it yours.
/// ------------------------------------------------------------
class _CityCard extends StatefulWidget {
  const _CityCard();

  @override
  State<_CityCard> createState() => _CityCardState();
}

class _CityCardState extends State<_CityCard> {
  String? _picked; // tapped on the map; null = follow "my barangay"

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    return ValueListenableBuilder<String?>(
      valueListenable: myBarangay,
      builder: (context, mine, _) {
        // Each barangay's worst active report.
        final reports = <String, RiskLevel>{};
        for (final z in activeFloodZones) {
          final had = reports[z.barangay];
          if (had == null || z.risk.index > had.index) {
            reports[z.barangay] = z.risk;
          }
        }
        final selected = _picked ?? mine ?? _floodedNow.firstOrNull?.barangay;
        final map = CityMap(
          reports: reports,
          mine: mine,
          selected: selected,
          onSelect: (b) => setState(() => _picked = b),
        );
        final panel = AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topLeft,
            children: [...previous, ?current],
          ),
          child: _BarangayPanel(
            key: ValueKey('$selected|$mine'),
            name: selected,
            mine: mine,
            onSetMine: () {
              myBarangay.value = selected;
              setState(() => _picked = null);
            },
          ),
        );
        return AppCard(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                'Your city right now',
                badge: const SampleBadge(),
                actionLabel: 'Open map',
                onAction: () => HomeShell.of(context)?.switchTab(1),
              ),
              LayoutBuilder(
                builder: (context, box) {
                  if (box.maxWidth >= 720) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            children: [
                              map,
                              const SizedBox(height: 10),
                              _legend(c),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(flex: 2, child: panel),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      map,
                      const SizedBox(height: 10),
                      _legend(c),
                      const SizedBox(height: 16),
                      panel,
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _legend(AppColors c) {
    Widget item(Color color, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: c.textSecondary, fontSize: 11)),
      ],
    );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 6,
      children: [
        item(kDanger, 'High'),
        item(kCaution, 'Moderate'),
        item(kSafe, 'Clear'),
        item(kBlue, 'Yours'),
      ],
    );
  }
}

/// The side panel of [_CityCard]: a nudge to pick a barangay (until one
/// is picked), then the selected barangay's latest report.
class _BarangayPanel extends StatelessWidget {
  final String? name;
  final String? mine;
  final VoidCallback onSetMine;
  const _BarangayPanel({
    required this.name,
    required this.mine,
    required this.onSetMine,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    final name = this.name;
    final zone = name == null
        ? null
        : (activeFloodZones.where((z) => z.barangay == name).toList()
                ..sort((a, b) => b.depthCm.compareTo(a.depthCm)))
              .firstOrNull;
    final isMine = name != null && name == mine;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (mine == null) ...[
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(CupertinoIcons.placemark_fill, color: c.accent, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Which one is yours?',
                        style: TextStyle(
                          color: c.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tap it on the map. Its reports and alerts come first everywhere in the app.',
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 4),
                      PressableScale(
                        onTap: () => pickMyBarangay(context),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            'Or pick from the list',
                            style: TextStyle(
                              color: c.accent,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (name != null) ...[
          Row(
            children: [
              Text(
                'BARANGAY',
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 10,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (isMine) ...[
                const SizedBox(width: 8),
                const StatusPill('Yours', kBlue, solid: true),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            name,
            style: TextStyle(
              fontFamily: kDisplayFont,
              color: c.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 8),
          if (zone == null)
            Row(
              children: [
                Icon(
                  CupertinoIcons.checkmark_circle,
                  size: 16,
                  color: c.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'No flood reports in the last 14 days.',
                    style: TextStyle(color: c.textSecondary, fontSize: 13),
                  ),
                ),
              ],
            )
          else ...[
            Row(
              children: [
                StatusPill(
                  zone.risk == RiskLevel.normal ? 'Clear' : zone.risk.label,
                  zone.risk.color,
                  solid: true,
                ),
                const SizedBox(width: 8),
                if (zone.depthCm > 0)
                  Expanded(
                    child: Text(
                      '${formatCm(zone.depthCm)} · ${FloodLevel.of(zone.depthCm).label}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              zone.note,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Reported ${zone.updated} by ${zone.uploader.name}',
              style: TextStyle(color: c.textSecondary, fontSize: 11.5),
            ),
          ],
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, box) {
              final buttons = [
                if (!isMine)
                  PrimaryButton(
                    label: 'Make it mine',
                    icon: CupertinoIcons.placemark_fill,
                    onPressed: onSetMine,
                  ),
                if (zone != null)
                  _GhostButton(
                    label: 'View on map',
                    icon: CupertinoIcons.map,
                    onTap: () {
                      HomeShell.of(context)?.switchTab(1);
                      focusedZone.value = zone;
                    },
                  ),
              ];
              if (box.maxWidth < 380) {
                return Column(spacing: 10, children: buttons);
              }
              return Row(
                spacing: 10,
                children: [for (final b in buttons) Expanded(child: b)],
              );
            },
          ),
        ],
      ],
    );
  }
}

/// Quiet pill button next to a [PrimaryButton].
class _GhostButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _GhostButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    return PressableScale(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: c.border),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: c.textPrimary),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ------------------------------------------------------------
/// The next 5 days. Each day's low-high range is a bar on the same scale
/// as the others, so a hot or cool day stands out at a glance.
/// ------------------------------------------------------------
class _DaysCard extends StatelessWidget {
  final MabalacatWeather weather;
  const _DaysCard({required this.weather});

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    final days = weather.daily;
    final lo = days.map((d) => d.min).reduce(math.min);
    final hi = days.map((d) => d.max).reduce(math.max);
    double at(double t) => hi - lo < 0.5 ? 0.5 : (t - lo) / (hi - lo);
    final degrees = TextStyle(
      color: c.textPrimary,
      fontWeight: FontWeight.w700,
      fontSize: 13.5,
    );
    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader('Next ${days.length} days'),
          for (var i = 0; i < days.length; i++) ...[
            if (i > 0) Divider(height: 1, color: c.border),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 52,
                    child: Text(
                      i == 0 ? 'Today' : formatWeekday(days[i].date),
                      style: degrees,
                    ),
                  ),
                  Tooltip(
                    message: weatherInfo(days[i].weatherCode).$1,
                    child: Icon(
                      weatherInfo(days[i].weatherCode).$2,
                      size: 20,
                      color: c.textSecondary,
                    ),
                  ),
                  SizedBox(
                    width: 46,
                    child: Text(
                      '${days[i].rainChance}%',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: days[i].rainChance >= 50
                            ? c.accent
                            : c.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 42,
                    child: Text(
                      '${days[i].min.round()}°',
                      textAlign: TextAlign.right,
                      style: degrees.copyWith(color: c.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _RangeBar(
                      from: at(days[i].min),
                      to: at(days[i].max),
                      now: i == 0 ? at(weather.temperature) : null,
                      delayMs: i * 60,
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 30,
                    child: Text(
                      '${days[i].max.round()}°',
                      textAlign: TextAlign.right,
                      style: degrees,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A low-high bar on a shared 0..1 scale, grown in from its middle. [now]
/// marks the current temperature (today only).
class _RangeBar extends StatelessWidget {
  final double from, to;
  final double? now;
  final int delayMs;
  const _RangeBar({
    required this.from,
    required this.to,
    this.now,
    this.delayMs = 0,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 700 + delayMs),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final mid = (from + to) / 2;
          final a = mid + (from - mid) * v, b = mid + (to - mid) * v;
          return SizedBox(
            height: 10,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                Positioned(
                  left: a * w,
                  width: math.max(5, (b - a) * w),
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [kTileTeal, kBlue],
                      ),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
                if (now != null)
                  Positioned(
                    left: (now!.clamp(0.0, 1.0) * w - 5).clamp(0.0, w - 10),
                    child: Opacity(
                      opacity: v,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: c.inverse,
                          shape: BoxShape.circle,
                          border: Border.all(color: c.background, width: 2),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Shimmering placeholder shaped like the sky card, outlook, and city
/// map, shown while the weather loads.
class _WeatherSkeleton extends StatelessWidget {
  const _WeatherSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(height: 520, radius: 30), // sky card
          SizedBox(height: 16),
          SkeletonBox(height: 220, radius: 20), // flood outlook
          SizedBox(height: 16),
          SkeletonBox(height: 320, radius: 20), // city map
        ],
      ),
    );
  }
}
