import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;

import '../data/demo_data.dart';
import '../services/weather.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/flood_depth.dart';
import '../widgets/responsive.dart';
import '../widgets/user_profile.dart';
import '../widgets/vote_bar.dart';
import '../widgets/skeleton.dart';
import 'evacuation_centers_screen.dart';
import 'home_shell.dart';
import 'deferred_screens.dart';
import '../widgets/agos_icons.dart';

/// ============================================================
/// HOME TAB — live Mabalacat weather, flood outlook, forecast,
/// quick actions, flood report feed, evacuation centers, safety tips
/// ============================================================
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  // Usually already downloaded while the user was on the login screen.
  late Future<MabalacatWeather> _weather = MabalacatWeather.load();

  // Pull-to-refresh (drag the list down). RefreshIndicator shows its
  // spinner until the Future returned here finishes, so we `await` the new
  // download. setState swaps in the new request, which makes the
  // FutureBuilder below show the skeleton and then the fresh weather.
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
    // Two columns only on desktops; tablets keep the phone order (the
    // flood outlook right under the weather).
    final wide = screenSizeOf(context) == ScreenSize.desktop;
    final gap = wide ? 24.0 : 26.0;
    return RefreshIndicator(
      onRefresh: _refresh,
      color: c.accent,
      child: ListView(
        padding: pagePadding(context),
        children: [
          FadeSlideIn(child: _banner(c, wide)),
          SizedBox(height: wide ? 24 : 18),
          // Shows the weather once the download finishes. `snap` (the
          // "snapshot") says how the download is going:
          //   not done yet -> gray placeholder (_WeatherSkeleton)
          //   failed       -> error card with a Retry button
          //   done         -> snap.data! is the weather (the `!` means
          //                   "I know this isn't null here")
          FutureBuilder<MabalacatWeather>(
            future: _weather,
            builder: (context, snap) {
              final w =
                  snap.connectionState == ConnectionState.done && !snap.hasError
                  ? snap.data!
                  : null;
              final Widget weatherTop = w != null
                  ? FadeSlideIn(child: _WeatherSection(w, _WeatherPart.hero))
                  : snap.connectionState != ConnectionState.done
                  ? const _WeatherSkeleton()
                  : _weatherError(c);
              Widget part(_WeatherPart p, int delayMs) => FadeSlideIn(
                delay: Duration(milliseconds: delayMs),
                child: _WeatherSection(w!, p),
              );
              final actions = FadeSlideIn(
                delay: const Duration(milliseconds: 250),
                child: _quickActions(context, c, wide),
              );
              if (!wide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: gap,
                  children: [
                    weatherTop,
                    if (w != null) ...[
                      part(_WeatherPart.outlook, 90),
                      part(_WeatherPart.forecast, 160),
                    ],
                    actions,
                  ],
                );
              }
              // Desktop: weather and the forecast on the left; the flood
              // outlook and shortcuts on the right.
              return TwoColumns(
                leftFlex: 8,
                rightFlex: 4,
                spacing: gap,
                left: [
                  weatherTop,
                  if (w != null) part(_WeatherPart.forecast, 160),
                ],
                right: [if (w != null) part(_WeatherPart.outlook, 90), actions],
              );
            },
          ),
          SizedBox(height: gap + 2),
          const FadeSlideIn(
            delay: Duration(milliseconds: 360),
            child: _ReportFeed(),
          ),
          SizedBox(height: gap + 2),
          FadeSlideIn(
            delay: const Duration(milliseconds: 400),
            child: _evacuationCenters(context, c, wide),
          ),
          SizedBox(height: gap + 2),
          FadeSlideIn(
            delay: const Duration(milliseconds: 460),
            child: const _SafetyTips(),
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

  // The photo banner at the top: a real local river, the greeting in
  // English and in Kapampangan (the local language), and the city.
  Widget _banner(AppColors c, bool wide) {
    final now = DateTime.now();
    final (greeting, kapampangan) = now.hour < 12
        ? ('Good morning', 'Mayap a abak')
        : now.hour < 18
        ? ('Good afternoon', 'Mayap a gatpanapun')
        : ('Good evening', 'Mayap a bengi');
    return LocalPhotoView(
      kPhotoSacobia,
      height: wide ? 250 : 196,
      radius: wide ? 24 : 22,
      showPlace: wide,
      overlay: Stack(
        children: [
          // Darkens the bottom-left corner so the white text is readable
          // on any part of the photo.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color(0x10060911), Color(0xCC060911)],
              ),
            ),
            child: SizedBox.expand(),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: WaterLines(
              color: Colors.white.withValues(alpha: 0.22),
              height: 70,
              count: 4,
            ),
          ),
          Positioned(
            left: wide ? 28 : 18,
            right: wide ? 28 : 18,
            bottom: wide ? 26 : 30,
            top: wide ? 22 : 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(8, 5, 12, 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.placemark_fill,
                        size: 15,
                        color: Colors.white,
                      ),
                      SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Mabalacat City, Pampanga',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  formatDate(now).toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$greeting!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: wide ? 36 : 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Tooltip(
                  message: 'Kapampangan for "$greeting"',
                  child: Text(
                    kapampangan,
                    style: TextStyle(
                      color: const Color(0xE6FFFFFF),
                      fontSize: wide ? 17 : 15,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
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

  Widget _quickActions(BuildContext context, AppColors c, bool wide) {
    final actions = [
      (
        CupertinoIcons.map_fill,
        'Flood\nMap',
        c.textPrimary,
        () => HomeShell.of(context)?.switchTab(1),
      ),
      (
        CupertinoIcons.exclamationmark_bubble_fill,
        'Report\nIncident',
        c.textPrimary,
        () => openReportIncident(context),
      ),
      (
        CupertinoIcons.house_alt_fill,
        'Evacuation\nCenters',
        c.textPrimary,
        () =>
            Navigator.of(context)
                .push(slideRoute(const EvacuationCentersScreen())),
      ),
      (
        CupertinoIcons.phone_fill,
        'Emergency\nHotlines',
        kDanger,
        () => HomeShell.of(context)?.switchTab(3),
      ),
    ];
    // Phones: four small tiles in a row. Desktop (the right column): a
    // 2 x 2 grid of wider tiles, with the label beside the icon.
    // Tinted, not gradient-filled, to keep the page calm; color only
    // marks what each action is about.
    Widget tile((IconData, String, Color, VoidCallback) a) {
      final (icon, label, color, onTap) = a;
      final badge = Container(
        width: wide ? 40 : 56,
        height: wide ? 40 : 56,
        decoration: BoxDecoration(
          color: color.withValues(alpha: c.isDark ? 0.10 : 0.06),
          borderRadius: BorderRadius.circular(wide ? 12 : 18),
        ),
        child: Icon(icon, color: color, size: wide ? 21 : 26),
      );
      if (!wide) {
        return PressableScale(
          onTap: onTap,
          child: Column(
            children: [
              badge,
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 11.5,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }
      return AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            badge,
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label.replaceAll('\n', ' '),
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 13,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Quick actions'),
        if (wide)
          Column(
            spacing: 10,
            children: [
              for (var row = 0; row < 2; row++)
                Row(
                  spacing: 10,
                  children: [
                    Expanded(child: tile(actions[row * 2])),
                    Expanded(child: tile(actions[row * 2 + 1])),
                  ],
                ),
            ],
          )
        else
          Row(children: [for (final a in actions) Expanded(child: tile(a))]),
      ],
    );
  }

  Widget _evacuationCenters(BuildContext context, AppColors c, bool wide) {
    final centers = [...kEvacCenters]
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          'Evacuation centers',
          badge: const SampleBadge(),
          actionLabel: 'See all',
          onAction: () =>
              Navigator.of(context)
                  .push(slideRoute(const EvacuationCentersScreen())),
        ),
        // Desktop: all four side by side, equally tall (IntrinsicHeight +
        // stretch). Phones: a row you swipe sideways.
        if (wide)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [
                for (final e in centers)
                  Expanded(child: EvacCenterCard(center: e, compact: true)),
              ],
            ),
          )
        else
          SizedBox(
            height: 206,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: centers.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) => SizedBox(
                width: 220,
                child: EvacCenterCard(center: centers[i], compact: true),
              ),
            ),
          ),
      ],
    );
  }
}

/// ------------------------------------------------------------
/// Weather: hero card, flood outlook, hourly strip, next days
/// ------------------------------------------------------------
/// The four weather pieces. They're separate so the desktop layout can put
/// them in different columns.
enum _WeatherPart { hero, outlook, forecast }

class _WeatherSection extends StatelessWidget {
  final MabalacatWeather weather;
  final _WeatherPart part;
  const _WeatherSection(this.weather, this.part);

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    final w = weather;
    return switch (part) {
      _WeatherPart.hero => _hero(w),
      _WeatherPart.outlook => _outlook(c, w.floodOutlook),
      _WeatherPart.forecast => _ForecastCard(weather: w),
    };
  }

  Widget _hero(MabalacatWeather w) {
    final (label, icon) = weatherInfo(w.weatherCode, isDay: w.isDay);
    final colors = weatherGradient(w.weatherCode, w.isDay);
    const white70 = Color(0xB3FFFFFF);
    return CustomPaint(
      foregroundPainter: const GlassEdgePainter(radius: 28, dark: true),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedWaves(
                  height: 70,
                  colors: [
                    Color(0x14FFFFFF),
                    Color(0x1AFFFFFF),
                    Color(0x22FFFFFF),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const LiveDot(color: Color(0xFF7CFFB2)),
                        const SizedBox(width: 6),
                        const Text(
                          'LIVE WEATHER · MABALACAT CITY',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          formatTime(w.time),
                          style: const TextStyle(
                            color: white70,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // The big temperature counts up from 0 to the
                              // real value over 1.1 s. v is the in-between
                              // number on each frame, rounded for display.
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: w.temperature),
                                duration: const Duration(milliseconds: 1100),
                                curve: Curves.easeOutCubic,
                                builder: (context, v, _) => Text(
                                  '${v.round()}°',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 72,
                                    height: 1,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -3,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'H ${w.today.max.round()}°  ·  L ${w.today.min.round()}°  ·  Feels ${w.feelsLike.round()}°',
                                style: const TextStyle(
                                  color: white70,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(icon, color: Colors.white, size: 64),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        children: [
                          _heroStat(
                            CupertinoIcons.umbrella_fill,
                            '${w.today.rainChance}%',
                            'Rain chance',
                          ),
                          _heroStat(
                            CupertinoIcons.drop_fill,
                            '${w.today.rainSum.toStringAsFixed(1)} mm',
                            'Rain today',
                          ),
                          _heroStat(
                            CupertinoIcons.drop,
                            '${w.humidity}%',
                            'Humidity',
                          ),
                          _heroStat(
                            CupertinoIcons.wind,
                            '${w.windSpeed.round()} km/h',
                            'Wind',
                          ),
                        ],
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

  Widget _heroStat(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 18),
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
            style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _outlook(AppColors c, FloodOutlook o) {
    final color = o.level.color;
    // Position of the risk level in the enum: normal 0, moderate 1, high 2.
    // Used by the 3-bar meter below.
    final step = RiskLevel.values.indexOf(o.level);
    return AppCard(
      borderColor: color.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(AgosIcons.flood, color, size: 44, squircle: true),
              const SizedBox(width: 12),
              Expanded(
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
                      o.title,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              StatusPill(
                o.level == RiskLevel.normal ? 'Low' : o.level.label,
                color,
                solid: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            o.message,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          // Three-step meter: Low · Moderate · High
          // Bar i fills up (0 -> 1) if i <= step, else stays empty.
          // E.g. moderate (step 1): bars 0 and 1 fill, bar 2 stays gray.
          // Each bar's animation is 250 ms longer than the one before, so
          // they fill one after another from left to right.
          // FractionallySizedBox(widthFactor: v) = colored part is v * 100%
          // of the bar's width.
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                Expanded(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: i <= step ? 1 : 0),
                    duration: Duration(milliseconds: 500 + i * 250),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => Container(
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: c.surfaceAlt,
                      ),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: v,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: RiskLevel.values[i].color,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (i < 2) const SizedBox(width: 6),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                CupertinoIcons.info_circle,
                size: 13,
                color: c.textSecondary,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Estimated from the rain forecast. Not an official warning. Follow PAGASA & local authorities.',
                  style: TextStyle(color: c.textSecondary, fontSize: 10.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The forecast: the next 12 hours OR the next days, switched with a
/// small toggle. Showing one at a time keeps Home calm; no boxes around
/// each hour, no colored bars, just the numbers that matter.
class _ForecastCard extends StatefulWidget {
  final MabalacatWeather weather;
  const _ForecastCard({required this.weather});

  @override
  State<_ForecastCard> createState() => _ForecastCardState();
}

class _ForecastCardState extends State<_ForecastCard> {
  bool _days = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Forecast',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16.5,
                  ),
                ),
              ),
              _toggle(c),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _days ? _daily(c) : _hourly(c),
          ),
        ],
      ),
    );
  }

  // Two-option switch: "12 hours" | "5 days".
  Widget _toggle(AppColors c) {
    Widget option(String label, bool days) {
      final on = _days == days;
      return Semantics(
        button: true,
        selected: on,
        child: GestureDetector(
          onTap: () => setState(() => _days = days),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: on ? c.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: on && !c.isDark
                    ? [BoxShadow(color: c.shadow, blurRadius: 4)]
                    : null,
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: on ? c.textPrimary : c.textSecondary,
                  fontSize: 12.5,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [option('12 hours', false), option('5 days', true)],
      ),
    );
  }

  Widget _hourly(AppColors c) {
    final hours = widget.weather.hourly;
    final rainy = c.accent;
    Widget hour(int i) {
      final h = hours[i];
      final now = i == 0;
      final (_, icon) = weatherInfo(h.weatherCode, isDay: h.isDay);
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: now ? c.surfaceAlt : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              now ? 'Now' : formatHour(h.time),
              style: TextStyle(
                color: now ? c.textPrimary : c.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Icon(icon, size: 22, color: c.textSecondary),
            const SizedBox(height: 8),
            Text(
              '${h.temperature.round()}°',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            // Rain chance: only stands out (blue) when it's likely.
            Text(
              '${h.rainChance}%',
              style: TextStyle(
                color: h.rainChance >= 50 ? rainy : c.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      key: const ValueKey('hours'),
      builder: (context, box) {
        // Wide enough for all hours side by side: no scrolling needed.
        if (box.maxWidth / hours.length >= 50) {
          return Row(
            children: [
              for (var i = 0; i < hours.length; i++) Expanded(child: hour(i)),
            ],
          );
        }
        return SizedBox(
          height: 118,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: hours.length,
            itemExtent: 56,
            itemBuilder: (context, i) => hour(i),
          ),
        );
      },
    );
  }

  Widget _daily(AppColors c) {
    final days = widget.weather.daily;
    final rainy = c.accent;
    return Column(
      key: const ValueKey('days'),
      children: [
        for (var i = 0; i < days.length; i++) ...[
          if (i > 0) Divider(height: 1, color: c.border),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  child: Text(
                    i == 0 ? 'Today' : formatWeekday(days[i].date),
                    style: TextStyle(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                ),
                Icon(
                  weatherInfo(days[i].weatherCode).$2,
                  size: 20,
                  color: c.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    weatherInfo(days[i].weatherCode).$1,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.textSecondary, fontSize: 13),
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: Text(
                    '${days[i].rainChance}%',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: days[i].rainChance >= 50 ? rainy : c.textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(
                  width: 84,
                  child: Text(
                    '${days[i].min.round()}° / ${days[i].max.round()}°',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Shimmering placeholder shaped like the weather card, flood outlook,
/// and hourly strip, shown while the weather loads.
class _WeatherSkeleton extends StatelessWidget {
  const _WeatherSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(height: 262, radius: 28), // weather card
          SizedBox(height: 14),
          SkeletonBox(height: 150, radius: 20), // flood outlook
          SizedBox(height: 26),
          SkeletonBox(width: 120, height: 14, radius: 6), // "Next 12 hours"
          SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: SkeletonBox(height: 128, radius: 22)),
              SizedBox(width: 10),
              Expanded(child: SkeletonBox(height: 128, radius: 22)),
              SizedBox(width: 10),
              Expanded(child: SkeletonBox(height: 128, radius: 22)),
              SizedBox(width: 10),
              Expanded(child: SkeletonBox(height: 128, radius: 22)),
            ],
          ),
        ],
      ),
    );
  }
}

/// ------------------------------------------------------------
/// Safety tips: numbered steps in one card
/// ------------------------------------------------------------
class _SafetyTips extends StatelessWidget {
  const _SafetyTips();

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    final desktop = screenSizeOf(context) == ScreenSize.desktop;
    // Desktop: four steps side by side, split by thin lines.
    // Phones and tablets: the same steps, one under the other.
    final steps = [
      for (var i = 0; i < kSafetyTips.length; i++)
        _step(c, i + 1, kSafetyTips[i], desktop),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('When the water rises'),
        AppCard(
          padding: EdgeInsets.symmetric(
            horizontal: desktop ? 8 : 18,
            vertical: desktop ? 22 : 6,
          ),
          child: desktop
              ? IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < steps.length; i++) ...[
                        if (i > 0) VerticalDivider(width: 1, color: c.border),
                        Expanded(child: steps[i]),
                      ],
                    ],
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < steps.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: c.border),
                      steps[i],
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _step(AppColors c, int n, SafetyTip t, bool desktop) {
    final number = Text(
      '$n',
      style: TextStyle(
        color: c.accent.withValues(alpha: 0.85),
        fontSize: desktop ? 26 : 20,
        fontWeight: FontWeight.w800,
        height: 1,
      ),
    );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.title,
          style: TextStyle(
            color: c.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 14.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          t.body,
          style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.45),
        ),
      ],
    );
    if (desktop) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [number, const SizedBox(height: 12), text],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 30, child: number),
          Expanded(child: text),
        ],
      ),
    );
  }
}

/// ------------------------------------------------------------
/// Latest flood reports: the map's pins as a feed, newest first
/// ------------------------------------------------------------
/// Keeps Home alive: each post shows who reported it, the photo, the
/// depth, the same thumbs up/down as the pin, and "View on map".
class _ReportFeed extends StatefulWidget {
  const _ReportFeed();

  @override
  State<_ReportFeed> createState() => _ReportFeedState();
}

class _ReportFeedState extends State<_ReportFeed> {
  // Phones start with a few posts; "Show all" reveals the rest.
  bool _all = false;
  static const _phoneCount = 3;

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    final desktop = screenSizeOf(context) == ScreenSize.desktop;
    final posts = activeFloodZones.toList()
      ..sort((a, b) => a.photoAge.compareTo(b.photoAge));
    final shown = desktop || _all ? posts : posts.take(_phoneCount).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Latest flood reports',
          badge: const SampleBadge(),
          actionLabel: 'Open map',
          onAction: () => HomeShell.of(context)?.switchTab(1),
        ),
        if (desktop)
          // Three posts per row, each row as tall as its tallest post.
          Column(
            spacing: 16,
            children: [
              for (var i = 0; i < shown.length; i += 3)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 16,
                    children: [
                      for (var j = i; j < i + 3; j++)
                        Expanded(
                          child: j < shown.length
                              ? _post(context, c, shown[j], true)
                              : const SizedBox.shrink(),
                        ),
                    ],
                  ),
                ),
            ],
          )
        else ...[
          for (final z in shown) ...[
            _post(context, c, z, false),
            const SizedBox(height: 14),
          ],
          if (posts.length > _phoneCount)
            TextButton(
              onPressed: () => setState(() => _all = !_all),
              child: Text(
                _all ? 'Show fewer' : 'Show all ${posts.length} reports',
                style: TextStyle(color: c.accent, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ],
    );
  }

  Widget _post(BuildContext context, AppColors c, FloodZone z, bool desktop) {
    final level = FloodLevel.of(z.depthCm);
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: PostedBy(z.uploader, trailing: timeAgo(z.photoAge)),
          ),
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: kGraphite),
                Image.asset(
                  z.photo,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
                Positioned(
                  left: 8,
                  bottom: 8,
                  right: 8,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Text(
                        kFloodPhotoCredit,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: z.risk.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Brgy. ${z.barangay} · ${formatCm(z.depthCm)}, ${level.label.toLowerCase()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  z.note,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 13.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          // On desktop the rows are equally tall: this pushes the buttons
          // to the bottom of every post.
          if (desktop) const Spacer(),
          Divider(height: 1, color: c.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
            child: Row(
              children: [
                VoteBar(zone: z, showQuestion: false),
                const SizedBox(width: 8),
                // Takes the rest of the row; on narrow posts the label
                // shortens with "…" instead of overflowing.
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        HomeShell.of(context)?.switchTab(1);
                        focusedZone.value = z;
                      },
                      icon: const Icon(CupertinoIcons.map, size: 18),
                      label: const Text(
                        'View on map',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: c.accent,
                        textStyle: const TextStyle(
                          fontFamily: kFontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
