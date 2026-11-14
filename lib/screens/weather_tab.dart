import 'dart:math' as math;

import 'package:flutter/cupertino.dart'
    show CupertinoIcons, CupertinoSliverRefreshControl;
import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../services/alerts.dart';
import '../services/weather.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/my_barangay.dart';
import '../widgets/responsive.dart';
import '../widgets/skeleton.dart';
import '../widgets/tugak.dart';
import '../widgets/tugak_stage.dart';
import '../widgets/weather_glyph.dart';
import 'weather_dashboard.dart';

/// ============================================================
/// WEATHER TAB (the first tab) — "am I safe right now?"
/// ============================================================
/// A dashboard (Nov 13 2026 redesign). Top to bottom: Tugak's 3D stage,
/// which is also the "now" card (the live readings drawn on it, Nov 14
/// 2026), the greeting + your barangay, the 5-day forecast, the
/// conditions tiles, rain over 48 hours, flood reports. (No flood watch
/// card since Nov 14 2026.) The panels below live in weather_dashboard.dart.
class WeatherTab extends StatefulWidget {
  const WeatherTab({super.key});

  @override
  State<WeatherTab> createState() => _WeatherTabState();
}

class _WeatherTabState extends State<WeatherTab> {
  // Usually already downloaded (prefetch.dart starts it at launch).
  late Future<MabalacatWeather> _weather = MabalacatWeather.load();
  late Future<AirQuality> _air = AirQuality.load();

  // The hour picked on the sky card's scrubber (0 = now); the conditions
  // tiles follow it.
  final _hour = ValueNotifier<int>(0);

  @override
  void dispose() {
    _hour.dispose();
    super.dispose();
  }

  // Pull-to-refresh: RefreshIndicator shows its spinner until the Future
  // returned here finishes, so we `await` the new download. setState swaps
  // in the new request, which makes the FutureBuilder below show the
  // skeleton and then the fresh weather.
  Future<void> _refresh() async {
    final next = MabalacatWeather.load(refresh: true);
    setState(() {
      _weather = next;
      _air = AirQuality.load(refresh: true);
      _hour.value = 0;
    });
    try {
      await next;
    } catch (_) {
      // The weather card shows the error and a Retry button.
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    final size = screenSizeOf(context);
    final wide = size == ScreenSize.desktop;
    final phone = size == ScreenSize.phone;
    final screen = MediaQuery.sizeOf(context);
    const gap = 16.0;
    // Pull down past the top: Apple's spinner appears above the content
    // (needs the iOS bounce, see main.dart).
    return CustomScrollView(
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: _refresh),
        SliverPadding(
          padding: pagePadding(context),
          sliver: SliverList.list(
            children: [
              // `snap` says how the download is going: not done yet ->
              // skeleton, failed -> error card, done -> the weather.
              FutureBuilder<MabalacatWeather>(
                future: _weather,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const _WeatherSkeleton();
                  }
                  if (snap.hasError) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: gap,
                      children: [const _Greeting(), _weatherError(c)],
                    );
                  }
                  final w = snap.data!;
                  Widget part(Widget child, int delayMs) => FadeSlideIn(
                    delay: Duration(milliseconds: delayMs),
                    child: child,
                  );
                  // Tugak's stage = the "now" card. Phones: the readings
                  // on top, Tugak, his bubble at the bottom (taller than
                  // wide). Desktop: as tall as the column beside it.
                  final terrace = _Terrace(weather: w, hour: _hour);
                  final stage = part(
                    wide
                        ? terrace
                        : SizedBox(
                            height: phone
                                ? (screen.width * 1.4).clamp(500.0, 580.0)
                                : 460.0,
                            child: terrace,
                          ),
                    0,
                  );
                  final conditions = part(
                    ConditionsGrid(
                      weather: w,
                      air: _air,
                      hour: _hour,
                      columns: size == ScreenSize.phone ? 2 : 4,
                    ),
                    120,
                  );
                  final rain = part(RainTotalsCard(weather: w), 160);
                  final ops = part(const FloodOpsCard(), 200);
                  final days = part(_DaysCard(weather: w), 120);
                  const greeting = FadeSlideIn(child: _Greeting());
                  if (!wide) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: gap,
                      children: [
                        stage,
                        greeting,
                        days, // right under the live readings, like desktop (Adrian, Nov 14 2026)
                        conditions,
                        rain,
                        ops,
                      ],
                    );
                  }
                  // Desktop: the stage (live readings + Tugak) with the
                  // greeting and 5 days beside it; below, the flood
                  // reports, the conditions tiles, then the 48-hour rain.
                  // (The flood watch card was dropped Nov 14 2026, Adrian.)
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 20,
                    children: [
                      _BesideStage(stage: stage, side: [greeting, days]),
                      ops,
                      conditions,
                      rain,
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
        ),
      ],
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
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Check your internet connection.',
                  style: TextStyle(color: c.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          TintedButton(label: 'Retry', onPressed: _refresh),
        ],
      ),
    );
  }
}

/// The newest unread High alert, or null. Makes Tugak serious (his line
/// names it; there's no red strip any more, Adrian removed it).
AppAlert? get newestHighAlert => alerts.value
    .where(
      (a) =>
          a.severity == RiskLevel.high && !readAlerts.value.contains(a.alertId),
    )
    .firstOrNull;

/// ------------------------------------------------------------
/// Tugak's terrace (the 3D scene, tugak_stage.dart): the sky and his mood
/// follow the hour picked on the sky card's scrubber, and so does his line.
/// Tap him for a tip (not on a high alert: the instruction stays up), tap
/// the clock for the time.
/// ------------------------------------------------------------
class _Terrace extends StatefulWidget {
  final MabalacatWeather weather;
  final ValueNotifier<int> hour;
  const _Terrace({required this.weather, required this.hour});

  @override
  State<_Terrace> createState() => _TerraceState();
}

class _TerraceState extends State<_Terrace> {
  int _tip = -1; // -1 = the weather line, 0.. = which tip
  int _shownHour = 0;

  void _tapped(StageTap hit, bool serious) => setState(() {
    if (!serious) _tip = (_tip + 1) % kTugakTips.length;
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.hour, alerts, readAlerts]),
      builder: (context, _) {
        final w = widget.weather;
        final i = math.min(widget.hour.value, w.hourly.length - 1);
        if (i != _shownHour) {
          // A new hour on the scrubber: back to the weather line.
          _shownHour = i;
          _tip = -1;
        }
        final alert = newestHighAlert;
        final weather = TugakWeather.at(w, i, alert: alert);
        final serious = alert != null || weather.mood == TugakMood.storm;
        final line = _tip >= 0
            ? kTugakTips[_tip]
            : i == 0
            ? tugakLine(w, alert: alert)
            : tugakLineAt(w.hourly[i], serious: alert != null);
        // The stage is the "now" card (Nov 14 2026, Adrian: the big box
        // was only a frog and a sentence): the live readings on the left
        // (phones: across the top), Tugak framed in the rest, his bubble
        // in the free corner (StageReserve).
        return LayoutBuilder(
          builder: (context, box) {
            final below = box.maxWidth < 560;
            final reserve = below
                ? const StageReserve(top: 196, bottom: 104, below: true)
                : StageReserve(left: (box.maxWidth * 0.5).clamp(300.0, 420.0));
            return CustomPaint(
              foregroundPainter: const GlassEdgePainter(radius: 30, dark: true),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Semantics(
                      label: 'Tugak says: $line',
                      hint: serious ? null : 'Tap Tugak for a tip',
                      excludeSemantics: true,
                      child: TugakStage(
                        weather: weather,
                        line: line,
                        reserve: reserve,
                        onTap: (hit) => _tapped(hit, serious),
                      ),
                    ),
                    Positioned(
                      left: below ? 16 : 20,
                      top: below ? 14 : 18,
                      width: below ? box.maxWidth - 32 : reserve.left - 36,
                      child: _NowReadout(weather: widget.weather),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Desktop: the scene on the left, as tall as the column on the right (no
/// dead space under either). The column is measured after each layout
/// and the scene follows (IntrinsicHeight can't: the 5-day card uses a
/// LayoutBuilder, which can't be measured ahead of time).
class _BesideStage extends StatefulWidget {
  final Widget stage;
  final List<Widget> side;
  const _BesideStage({required this.stage, required this.side});

  @override
  State<_BesideStage> createState() => _BesideStageState();
}

class _BesideStageState extends State<_BesideStage> {
  final _column = GlobalKey();
  double _height = 560;

  void _measure(Duration _) {
    final h = _column.currentContext?.size?.height;
    if (!mounted || h == null) return;
    final next = math.max(440.0, h);
    if ((next - _height).abs() > 1) setState(() => _height = next);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback(_measure);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SizedBox(height: _height, child: widget.stage),
        ),
        const SizedBox(width: 20),
        SizedBox(
          width: 400,
          child: Column(
            key: _column,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: widget.side,
          ),
        ),
      ],
    );
  }
}

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
    // right, centered on the greeting. (Not picked yet: the avatar menu's
    // "My barangay" sets it.) The greeting shrinks a little
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
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  greeting,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: kDisplayFont,
                    color: c.textPrimary,
                    // Apple's Large Title.
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    letterSpacing: displayTracking(34),
                    height: 1.15,
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

/// ------------------------------------------------------------
/// The weather right now, drawn on Tugak's stage (Nov 14 2026: was its own
/// card beside him). Live dot + time, the big temperature, what the sky is
/// doing, today's range, the next two hours, three stats. The stage is
/// navy in both themes, so the colors are the dark theme's.
/// ------------------------------------------------------------
class _NowReadout extends StatelessWidget {
  final MabalacatWeather weather;
  const _NowReadout({required this.weather});

  @override
  Widget build(BuildContext context) {
    final w = weather;
    final (label, _) = weatherInfo(w.weatherCode, isDay: w.isDay);
    final h = w.hourly.first;
    final temp = w.temperature.roundToDouble();
    const small = TextStyle(color: kTextSecondaryDark, fontSize: 12);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const LiveDot(color: kSafe),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'MABALACAT CITY · LIVE',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: kTextSecondaryDark,
                  fontSize: 11,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(formatTime(w.time), style: small),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            // Apple Weather's big thin numeral.
            RollingText(
              '${temp.round()}°',
              value: temp,
              style: TextStyle(
                fontFamily: kDisplayFont,
                color: kTextPrimaryDark,
                fontSize: 64,
                height: 1,
                fontWeight: FontWeight.w300,
                letterSpacing: -2,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: kDisplayFont,
                      color: kTextPrimaryDark,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'H ${w.today.max.round()}°  ·  L ${w.today.min.round()}°  ·  Feels ${w.feelsLike.round()}°',
                    style: small,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(
                        w.rainStartsAt != null
                            ? CupertinoIcons.cloud_rain_fill
                            : CupertinoIcons.checkmark_alt,
                        color: kTextPrimaryDark,
                        size: 13,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          w.nextTwoHoursText,
                          style: TextStyle(
                            color: kTextPrimaryDark,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // The three stats in a sunken well.
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: kTextPrimaryDark.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x1FFFFFFF)),
          ),
          child: Row(
            children: [
              _stat(
                CupertinoIcons.umbrella_fill,
                '${h.rainChance}%',
                'Rain chance',
              ),
              _stat(
                CupertinoIcons.drop_fill,
                '${h.rain.toStringAsFixed(1)} mm',
                'Rain this hour',
              ),
              _stat(CupertinoIcons.cloud, '${w.cloud}%', 'Cloud cover'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stat(IconData icon, String value, String label) => Expanded(
    child: Column(
      children: [
        Icon(icon, color: kTextSecondaryDark, size: 14),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: kTextPrimaryDark,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: kTextSecondaryDark, fontSize: 11),
        ),
      ],
    ),
  );
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
      fontSize: 15,
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
                    child: WeatherGlyph(code: days[i].weatherCode, size: 36),
                  ),
                  // Rain chance in Apple Weather's cyan, only when it's
                  // worth mentioning.
                  SizedBox(
                    width: 46,
                    child: Text(
                      days[i].rainChance >= 20 ? '${days[i].rainChance}%' : '',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: c.readable(const Color(0xFF40C8FF)),
                        fontSize: 13,
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
                      colors: [tempColor(days[i].min), tempColor(days[i].max)],
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

/// A temperature as a color, like Apple Weather's range bars: cool teal,
/// warm yellow, hot orange, very hot pink. (Not the app's risk red.)
Color tempColor(double c) {
  const stops = [
    (22.0, Color(0xFF40C8FF)),
    (27.0, Color(0xFFFFD60A)),
    (31.0, Color(0xFFFF9F0A)),
    (35.0, Color(0xFFFF6482)),
  ];
  if (c <= stops.first.$1) return stops.first.$2;
  for (var i = 1; i < stops.length; i++) {
    if (c <= stops[i].$1) {
      final (a, ca) = stops[i - 1];
      final (b, cb) = stops[i];
      return Color.lerp(ca, cb, (c - a) / (b - a))!;
    }
  }
  return stops.last.$2;
}

/// A low-high bar on a shared 0..1 scale, grown in from its middle. [now]
/// marks the current temperature (today only).
class _RangeBar extends StatelessWidget {
  final double from, to;
  final double? now;
  final int delayMs;
  final List<Color> colors; // the day's low and high, as temperature colors
  const _RangeBar({
    required this.from,
    required this.to,
    required this.colors,
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
                      gradient: LinearGradient(colors: colors),
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

/// Shimmering placeholder shaped like the sky card, outlook, and the
/// first conditions tiles, shown while the weather loads.
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
          SkeletonBox(height: 136, radius: 20), // conditions tiles
        ],
      ),
    );
  }
}
