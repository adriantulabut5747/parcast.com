import 'dart:math' as math;

import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoIcons;

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../data/demo_data.dart';
import '../theme.dart';
import 'responsive.dart';

/// ============================================================
/// SHARED WIDGETS — the building blocks every screen uses
/// ============================================================

/// The page background. Dark (Nov 14 2026): the landing page's night sky
/// (landing.css .sky): two navy glows over a navy-to-black fade, and still
/// stars painted once (no twinkle: any loop redraws the whole web app every
/// frame). Light: warm off-white with two soft blue glows and faint water
/// lines across the top. (The film grain was removed Nov 13 2026: ~20k
/// dots redrawn every frame made each frame ~40% slower on desktop.)
class PageBackground extends StatelessWidget {
  final Widget child;
  const PageBackground({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    Widget glow(Alignment at, Color color, double alpha, [double r = 1.1]) =>
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: at,
                radius: r,
                colors: [
                  color.withValues(alpha: alpha),
                  color.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        );
    // Fill the whole screen, even when the child (e.g. a scroll view) is
    // shorter — otherwise the area below it shows as a blank strip.
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: c.background,
        gradient: c.isDark
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.6],
                colors: [Color(0xFF070A1C), kBgDark],
              )
            : null,
      ),
      child: Stack(
        children: [
          if (c.isDark) ...[
            glow(
              const Alignment(0.56, -1.1),
              const Color(0xFF1C3D72),
              0.55,
              0.8,
            ),
            glow(
              const Alignment(-1.1, 1.1),
              const Color(0xFF16194A),
              0.55,
              0.75,
            ),
            const Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(painter: _StarsPainter()),
              ),
            ),
          ] else ...[
            // one faint sky-blue light at the top; the water lines only
            // just there (stronger, they read as dirty stripes)
            glow(const Alignment(-0.9, -1.3), kBlue, 0.07, 0.9),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: WaterLines(
                color: kBlue.withValues(alpha: 0.05),
                height: 200,
              ),
            ),
          ],
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

/// Still stars, the landing page's recipe (landing.js starLayer): mostly
/// white, a few tinted kBlue / indigo. Same seed every time, so they don't
/// jump between rebuilds. Fewer and dimmer than the landing's (1 per
/// 6500 px²): the app's cards are see-through, so stars show inside them.
class _StarsPainter extends CustomPainter {
  const _StarsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(14);
    // Phones (Nov 14 2026, Adrian: they looked busy there): a third as
    // many, and dimmer, below.
    final phone = size.width < 600;
    final n = (size.width * size.height / (phone ? 20000 : 6500))
        .clamp(16, 400)
        .round();
    final paint = Paint();
    for (var i = 0; i < n; i++) {
      final at = Offset(
        rnd.nextDouble() * size.width,
        rnd.nextDouble() * size.height,
      );
      final t = rnd.nextDouble();
      final rgb = t < 0.12
          ? const Color(0xFF78B4FF)
          : t < 0.19
          ? const Color(0xFFA09EFF)
          : const Color(0xFFFFFFFF);
      final big = rnd.nextDouble(); // three sizes, like the landing's 3 layers
      final r = big < 0.1
          ? 1.0
          : big < 0.35
          ? 0.75
          : 0.5;
      paint.color = rgb.withValues(
        alpha:
            (0.15 + rnd.nextDouble() * 0.4) *
            (r == 0.5 ? 0.8 : 1) *
            (phone ? 0.55 : 1),
      );
      canvas.drawCircle(at, r, paint);
    }
  }

  @override
  bool shouldRepaint(_StarsPainter old) => false;
}

/// Thin, still wave lines, like the surface of a river: the app's
/// signature pattern (backgrounds, the Home banner, the login screen).
/// Drawn once, not animated, so it costs nothing while scrolling.
class WaterLines extends StatelessWidget {
  final Color color;
  final double height;
  final int count;
  const WaterLines({
    required this.color,
    this.height = 160,
    this.count = 6,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size(double.infinity, height),
        painter: _WaterLinesPainter(color, count),
      ),
    );
  }
}

class _WaterLinesPainter extends CustomPainter {
  final Color color;
  final int count;
  _WaterLinesPainter(this.color, this.count);

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < count; i++) {
      // Each line sits a bit lower, is a bit longer-waved, and fades a
      // little, so together they look like ripples, not a pattern.
      final y = size.height * (i + 1) / (count + 1);
      final amp = 5 + i * 1.6;
      final wave = 240 + i * 55;
      final phase = i * 1.7;
      final path = Path()..moveTo(0, y + amp * math.sin(phase));
      for (double x = 8; x <= size.width + 8; x += 8) {
        path.lineTo(x, y + amp * math.sin(x / wave * 2 * math.pi + phase));
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = color.withValues(alpha: color.a * (1 - i / (count * 1.6))),
      );
    }
  }

  @override
  bool shouldRepaint(_WaterLinesPainter old) =>
      old.color != color || old.count != count;
}

/// A local photo (see [LocalPhoto]) filling its box, fading in once loaded,
/// with its credit in a small label (the photo licenses require it).
/// [overlay] is drawn on top of the photo, under the credit.
class LocalPhotoView extends StatelessWidget {
  final LocalPhoto photo;
  final double? height;
  final double radius;
  final Widget? overlay;
  final bool showPlace;
  const LocalPhotoView(
    this.photo, {
    this.height,
    this.radius = 20,
    this.overlay,
    this.showPlace = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Navy underneath, so the box never flashes white while the
            // photo loads (or if it's missing).
            const ColoredBox(color: kGraphite),
            Image.asset(
              photo.asset,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              frameBuilder: (context, child, frame, loadedAtOnce) =>
                  loadedAtOnce
                  ? child
                  : AnimatedOpacity(
                      opacity: frame == null ? 0 : 1,
                      duration: const Duration(milliseconds: 400),
                      child: child,
                    ),
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
            ?overlay,
            Positioned(
              right: 8,
              bottom: 8,
              child: Tooltip(
                message: '${photo.place} · ${photo.credit}',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    showPlace
                        ? '${photo.place} · ${photo.credit}'
                        : photo.credit,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows an image from assets/images/, or [fallback] if it fails to load.
class AssetImageWithFallback extends StatelessWidget {
  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget fallback;
  const AssetImageWithFallback(
    this.path, {
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    required this.fallback,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      path,
      width: width,
      height: height,
      fit: fit,
      // Keep showing the old image while a new one loads (no flicker).
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

/// The AgosAlert logo, in the right colors for the current theme:
/// the white-text versions (`*_dark.png`) in dark mode, the navy-text
/// versions in light mode. If a file is missing it falls back to the other
/// version, then to [fallback].
class BrandLogo extends StatelessWidget {
  final bool wordmark; // true = wide "agosalert." text, false = round icon
  final double height;
  final Widget fallback;
  const BrandLogo.icon({
    required this.height,
    this.fallback = const SizedBox.shrink(),
    super.key,
  }) : wordmark = false;
  const BrandLogo.wordmark({
    required this.height,
    this.fallback = const SizedBox.shrink(),
    super.key,
  }) : wordmark = true;

  static const _light = [
    'assets/images/logo_icon.png',
    'assets/images/logo_wordmark.png',
  ];
  static const _dark = [
    'assets/images/logo_icon_dark.png',
    'assets/images/logo_wordmark_dark.png',
  ];

  /// Loads the current theme's two logos ahead of time. (Only the current
  /// theme's: loading all four cost phones ~150 KB extra at startup. The
  /// other pair loads when the theme is switched; gaplessPlayback in
  /// AssetImageWithFallback keeps the old logo visible meanwhile.)
  static void precache(BuildContext context) {
    final paths = AppColors(context).isDark ? _dark : _light;
    for (final path in paths) {
      precacheImage(AssetImage(path), context, onError: (_, _) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // Index into the _light/_dark lists: 0 = round icon, 1 = wordmark.
    final i = wordmark ? 1 : 0;
    final dark = AppColors(context).isDark;
    final first = dark ? _dark[i] : _light[i];
    final second = dark ? _light[i] : _dark[i];
    return AssetImageWithFallback(
      first,
      height: height,
      fallback: AssetImageWithFallback(
        second,
        height: height,
        fallback: fallback,
      ),
    );
  }
}

/// The see-through fill of a glass card: a faint white sheen that is a
/// little brighter at the top, like light falling on glass.
Gradient glassFill(AppColors c) => LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: c.isDark
      ? [
          Colors.white.withValues(alpha: 0.085),
          Colors.white.withValues(alpha: 0.045),
        ]
      // light: solid white (see-through cards went gray over the page)
      : [Colors.white, Colors.white],
);

/// Paints the glass edge the way light hits a real curved glass rim
/// (model from QuickLiquid's specular.ts): one light from the top left.
/// Each point of the edge gets brighter the more it faces that light
/// (strongest at the top-left corner), the opposite edge gets a faint
/// glint (light leaving the glass), and a soft glow sits just inside the
/// rim (the curved bezel catching light). Use as `foregroundPainter`.
class GlassEdgePainter extends CustomPainter {
  final double radius;
  final bool dark;
  const GlassEdgePainter({required this.radius, required this.dark});

  // Direction the light comes from (unit vector, screen y points down).
  static const _light = Offset(-0.5, -0.866);

  // How much an edge whose outward direction is [n] faces the light (lit)
  // or faces away from it (back). Power 4 keeps the highlight tight.
  static double _lit(Offset n) =>
      math.pow(math.max(0, n.dx * _light.dx + n.dy * _light.dy), 4).toDouble();
  static double _back(Offset n) => math
      .pow(math.max(0, -(n.dx * _light.dx + n.dy * _light.dy)), 4)
      .toDouble();

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.min(radius, size.shortestSide / 2);
    // 1. Soft glow just inside the rim, kept inside the card.
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(r)),
    );
    _rim(
      canvas,
      size,
      r,
      inset: 3,
      width: 6,
      blur: 3.5,
      color: (n) {
        return Colors.white.withValues(alpha: (dark ? 0.14 : 0.5) * _lit(n));
      },
    );
    canvas.restore();
    // 2. The sharp 1 px edge. Light theme first gets a faint dark line so
    // white cards still stand out from the gray page.
    if (!dark) {
      _rim(
        canvas,
        size,
        r,
        inset: 0.5,
        width: 1,
        color: (n) {
          return Colors.black.withValues(alpha: 0.05 + 0.05 * _back(n));
        },
      );
    }
    _rim(
      canvas,
      size,
      r,
      inset: 0.5,
      width: 1,
      color: (n) {
        return Colors.white.withValues(
          alpha: dark ? 0.07 + 0.38 * _lit(n) + 0.12 * _back(n) : _lit(n),
        );
      },
    );
  }

  /// Strokes a rounded rectangle, colouring each point by its outward
  /// direction. Straight sides face one way, so each is one flat colour;
  /// corners turn, so a sweep gradient around the corner's center gives
  /// every point of the arc its exact colour.
  static void _rim(
    Canvas canvas,
    Size size,
    double radius, {
    required double inset,
    required double width,
    required Color Function(Offset n) color,
    double blur = 0,
  }) {
    Paint paint() => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..maskFilter = blur > 0 ? MaskFilter.blur(BlurStyle.normal, blur) : null;
    final l = inset, t = inset;
    final rt = size.width - inset, b = size.height - inset;
    final rr = math.max(0.0, radius - inset);

    void side(Offset a, Offset z, Offset n) {
      if ((z - a).distance < 0.01) return;
      canvas.drawLine(a, z, paint()..color = color(n));
    }

    void corner(Offset center, double start) {
      if (rr < 0.01) return;
      final rect = Rect.fromCircle(center: center, radius: rr);
      const steps = 6;
      final colors = [
        for (var i = 0; i <= steps; i++)
          color(
            Offset(
              math.cos(start + i / steps * math.pi / 2),
              math.sin(start + i / steps * math.pi / 2),
            ),
          ),
      ];
      canvas.drawArc(
        rect,
        start,
        math.pi / 2,
        false,
        paint()
          ..shader = SweepGradient(
            startAngle: start,
            endAngle: start + math.pi / 2,
            colors: colors,
          ).createShader(rect),
      );
    }

    side(Offset(l + rr, t), Offset(rt - rr, t), const Offset(0, -1));
    side(Offset(rt, t + rr), Offset(rt, b - rr), const Offset(1, 0));
    side(Offset(rt - rr, b), Offset(l + rr, b), const Offset(0, 1));
    side(Offset(l, b - rr), Offset(l, t + rr), const Offset(-1, 0));
    corner(Offset(l + rr, t + rr), math.pi);
    corner(Offset(rt - rr, t + rr), 1.5 * math.pi);
    corner(Offset(rt - rr, b - rr), 0);
    corner(Offset(l + rr, b - rr), 0.5 * math.pi);
  }

  @override
  bool shouldRepaint(GlassEdgePainter old) =>
      old.radius != radius || old.dark != dark;
}

/// Frosted glass that really blurs what's behind it. Costly, so use it only
/// where something sharp moves underneath (over the map, a photo, or
/// scrolling content). Everywhere else use [AppCard]: on a plain background
/// a blur looks exactly the same as no blur.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final double? opacity; // fill opacity; null = the usual see-through glass
  const GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 24,
    this.opacity,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    // BackdropFilter blurs whatever is BEHIND the card (not the card
    // itself). ClipRRect limits that blur to the card's rounded shape;
    // without it the blur would spread over the whole screen.
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: kGlassBlur,
        child: CustomPaint(
          foregroundPainter: GlassEdgePainter(radius: radius, dark: c.isDark),
          child: Container(
            padding: padding,
            color: c.surface.withValues(
              alpha: opacity ?? (c.isDark ? 0.62 : 0.72),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// The iPhone's frosted-glass recipe: a strong blur, plus more color
/// saturation so things behind the glass stay vivid instead of going gray.
final ImageFilter kGlassBlur = ImageFilter.compose(
  outer: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
  inner: const ColorFilter.matrix(_saturate18),
);

// A standard saturation matrix for 1.8x (deckai.app uses saturate(178%)).
const List<double> _saturate18 = [
  1.6299, -0.5722, -0.0578, 0, 0, //
  -0.1701, 1.2278, -0.0578, 0, 0, //
  -0.1701, -0.5722, 1.7422, 0, 0, //
  0, 0, 0, 1, 0,
];

/// Light theme cards: a tight contact shadow plus a wide soft one (one
/// wide shadow alone made the cards look like they float in fog).
const List<BoxShadow> kLightCardShadow = [
  BoxShadow(color: Color(0x0A000000), blurRadius: 2, offset: Offset(0, 1)),
  BoxShadow(color: Color(0x0F000000), blurRadius: 24, offset: Offset(0, 8)),
];

/// The standard card: see-through glass with a lit edge.
/// Pass [onTap] to make it pressable (it shrinks slightly when pressed).
/// [borderColor] swaps the glass edge for a plain colored one (e.g. a
/// risk color); [color] or [gradient] replace the glass fill.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? color; // fill color; defaults to the surface color
  final Gradient? gradient;
  final double radius;
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.borderColor,
    this.color,
    this.gradient,
    this.radius = 20,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    Widget card = Container(
      decoration: BoxDecoration(
        color: color,
        gradient: color == null ? (gradient ?? glassFill(c)) : null,
        borderRadius: BorderRadius.circular(radius),
        border: borderColor == null ? null : Border.all(color: borderColor!),
        // Dark theme: the lit edge alone separates cards (shadows don't
        // show on black). Light theme: a soft, wide shadow.
        boxShadow: c.isDark ? null : kLightCardShadow,
      ),
      // A see-through Material so tap ripples (InkWell, ListTile) show on
      // top of the card color instead of hiding behind it.
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      ),
    );
    if (borderColor == null) {
      card = CustomPaint(
        foregroundPainter: GlassEdgePainter(radius: radius, dark: c.isDark),
        child: card,
      );
    }
    if (onTap == null) return card;
    return PressableScale(onTap: onTap, child: card);
  }
}

/// Apple-style springs (stiffness/damping from QuickLiquid's spring.ts;
/// Flutter's SpringDescription uses the same units). Snappy = tab
/// switches, bouncy = release after a press, stiff = the press itself.
const kSpringSnappy = SpringDescription(mass: 1, stiffness: 400, damping: 30);
const kSpringBouncy = SpringDescription(mass: 1, stiffness: 250, damping: 15);
const kSpringStiff = SpringDescription(mass: 1, stiffness: 600, damping: 35);

/// A spring as a [Curve], for widgets that take a curve + duration
/// (AnimatedPositioned, TweenAnimationBuilder...). [seconds] must be long
/// enough for the spring to settle, or it jumps to the end.
class SpringCurve extends Curve {
  final double seconds;
  final SpringSimulation _sim;
  SpringCurve(SpringDescription spring, this.seconds)
    : _sim = SpringSimulation(spring, 0, 1, 0);

  @override
  double transformInternal(double t) => _sim.x(t * seconds);
}

/// Spring curves for 450 ms (snappy) and 650 ms (bouncy) animations.
final kSnappyCurve = SpringCurve(kSpringSnappy, 0.45);
final kBouncyCurve = SpringCurve(kSpringBouncy, 0.65);

/// The liquid press: while held, the child sinks in and squishes a little
/// wider and shorter (like pressing a water drop); on release it springs
/// back with a small bounce. Small buttons sink to 95%, wide cards only
/// ~98%, so every size moves about the same few pixels.
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  const PressableScale({
    required this.child,
    this.onTap,
    this.onLongPress,
    super.key,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale>
    with TickerProviderStateMixin {
  // Width and height scale, each driven by a spring. `unbounded` because a
  // spring overshoots past 1.0 for a moment on release.
  late final _sx = AnimationController.unbounded(vsync: this, value: 1);
  late final _sy = AnimationController.unbounded(vsync: this, value: 1);

  @override
  void dispose() {
    _sx.dispose();
    _sy.dispose();
    super.dispose();
  }

  void _springTo(double x, double y, SpringDescription spring) {
    // Reduced motion (phone setting): no squish, no bounce.
    if (MediaQuery.disableAnimationsOf(context)) return;
    // Starting from the current speed keeps it smooth if a press
    // interrupts a bounce that's still going.
    _sx.animateWith(SpringSimulation(spring, _sx.value, x, _sx.velocity));
    _sy.animateWith(SpringSimulation(spring, _sy.value, y, _sy.velocity));
  }

  void _press() {
    if (widget.onTap == null && widget.onLongPress == null) return;
    // Sink ~10 px total, clamped to QuickLiquid's 0.95 for small buttons.
    final w = context.size?.width ?? 100;
    final s = (1 - 10 / w).clamp(0.95, 0.985);
    final squish = (1 - s) * 0.4;
    _springTo(s + squish, s - squish, kSpringStiff);
  }

  void _release() => _springTo(1, 1, kSpringBouncy);

  @override
  Widget build(BuildContext context) {
    // MouseRegion: hand cursor on desktop, only when there's something to
    // tap. HitTestBehavior.opaque: taps on transparent spots still count.
    // onTapCancel = the finger slid away, so it springs back too.
    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press(),
        onTapUp: (_) => _release(),
        onTapCancel: _release,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedBuilder(
          animation: Listenable.merge([_sx, _sy]),
          child: widget.child,
          builder: (context, child) => Transform(
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(_sx.value, _sy.value, 1),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Fades and slides its child up when it first appears.
/// Give each item a bigger [delay] for a staggered entrance.
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const FadeSlideIn({
    required this.child,
    this.delay = Duration.zero,
    super.key,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  static const _run = Duration(milliseconds: 600);
  // The delay is built into the animation (it waits during the first part)
  // instead of using a timer, so nothing is left pending in tests.
  //
  // AnimationController = a number that goes from 0.0 to 1.0 over
  // `duration`. `vsync: this` (from SingleTickerProviderStateMixin) ties
  // it to the screen's refresh so it pauses when the widget is off-screen.
  // `late` = created the first time it's used. `..forward()` (the ".."
  // cascade) starts it right away and still returns the controller.
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: widget.delay + _run,
  )..forward();
  // Interval(start, 1) = stay at 0 until `start`, then go 0 -> 1.
  // Example: delay 200 ms, run 520 ms, total 720 ms.
  // start = 200 / 720 = 0.28, so for the first 28% of the time nothing
  // moves (that's the delay), then it fades/slides in over the rest.
  late final Animation<double> _curve = CurvedAnimation(
    parent: _ctrl,
    curve: Interval(
      widget.delay.inMilliseconds / (widget.delay + _run).inMilliseconds,
      1,
      // Apple's ease-out: fast start, long gentle landing.
      curve: const Cubic(0.16, 1, 0.3, 1),
    ),
  );

  // Stop the controller when the widget is removed from the screen,
  // otherwise it keeps running in the background (a memory leak).
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // AnimatedBuilder re-runs `builder` on every animation frame.
    // `child` is passed through separately so the (possibly big) child
    // widget is built once, and only the Opacity/Transform wrapper changes.
    // v = _curve.value (0 -> 1): it fades in, rises 14 px and grows from
    // 98.5% to full size, so the card arrives instead of just sliding.
    // Reduced motion (phone setting): it's simply there.
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return AnimatedBuilder(
      animation: _curve,
      child: widget.child,
      builder: (context, child) {
        final v = _curve.value;
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - v)),
            child: Transform.scale(scale: 0.985 + 0.015 * v, child: child),
          ),
        );
      },
    );
  }
}

/// A number that rolls when it changes, like iOS's numeric text
/// transition: going up, the new value rises in from below while the old
/// one leaves through the top (going down, the other way), each fading.
/// [value] decides the direction; [text] is what's shown.
class RollingText extends StatefulWidget {
  final String text;
  final double value;
  final TextStyle style;
  const RollingText(
    this.text, {
    required this.value,
    required this.style,
    super.key,
  });

  @override
  State<RollingText> createState() => _RollingTextState();
}

class _RollingTextState extends State<RollingText> {
  bool _up = true;

  @override
  void didUpdateWidget(RollingText old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _up = widget.value > old.value;
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Text(widget.text, style: widget.style);
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: const Cubic(0.16, 1, 0.3, 1),
      switchOutCurve: const Cubic(0.16, 1, 0.3, 1),
      // Old and new overlap in place, so the width never jumps mid-roll.
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.centerLeft,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, anim) {
        final incoming = child.key == ValueKey(widget.text);
        // A third of the line: enough to read as a roll, not a jump.
        final dy = (incoming == _up) ? 0.35 : -0.35;
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween(
              begin: Offset(0, dy),
              end: Offset.zero,
            ).animate(anim),
            child: child,
          ),
        );
      },
      child: Text(widget.text, key: ValueKey(widget.text), style: widget.style),
    );
  }
}

/// Big full-width pill button: white on black in the dark theme, black on
/// white in the light one. [color] is only for actions that are
/// dangerous or urgent (kDanger), with white text.
class PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final Color? color;
  const PrimaryButton({
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.color,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    final fg = color == null ? c.onInverse : Colors.white;
    // While `loading` is true, onTap is null so the button can't be tapped
    // twice (e.g. submitting a report twice), and a spinner replaces the
    // label. If onPressed itself is null, the button is shown half-faded
    // (opacity 0.5) to look disabled.
    return PressableScale(
      onTap: loading ? null : onPressed,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: onPressed == null ? 0.5 : 1,
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            color: color ?? c.inverse,
            borderRadius: BorderRadius.circular(26),
          ),
          alignment: Alignment.center,
          child: loading
              ? CupertinoActivityIndicator(color: fg)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (icon != null) ...[
                      const SizedBox(width: 8),
                      Icon(icon, color: fg, size: 18),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

/// The second button under a [PrimaryButton] (Cancel, Not now): the same
/// capsule in a quiet gray fill, like iOS sheets.
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const SecondaryButton({required this.label, this.onPressed, super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    return PressableScale(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(26),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: c.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 15,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }
}

/// A small capsule button in the accent tint (Apple's "tinted" style):
/// Retry, Call, Try again. Sits inside a row or card, not full width.
class TintedButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  const TintedButton({
    required this.label,
    this.icon,
    this.onPressed,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    return PressableScale(
      onTap: onPressed,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: c.accent.withValues(alpha: c.isDark ? 0.2 : 0.12),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: c.accent, size: 16),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: c.accent,
                fontWeight: FontWeight.w600,
                fontSize: 15,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small rounded colored label, e.g. "HIGH" or "Open".
class StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool solid;
  const StatusPill(this.label, this.color, {this.solid = false, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(
        color: solid ? color : color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: solid ? Colors.white : color,
          fontSize: 11,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Marks a section that still shows made-up demo data.
class SampleBadge extends StatelessWidget {
  const SampleBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    return Tooltip(
      message: 'Demo data — live readings coming soon',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          border: Border.all(color: c.textSecondary.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'SAMPLE',
          style: TextStyle(
            color: c.textSecondary,
            fontSize: 11,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Section title with an optional badge and "See all" style action.
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? badge;
  final String? actionLabel;
  final VoidCallback? onAction;
  const SectionHeader(
    this.title, {
    this.badge,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // Title + badge take all the free space, which pushes the action
          // ("See all") to the far right. (A Flexible title next to a
          // Spacer split the space in half, leaving "See all" mid-row on
          // wide screens.)
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: kDisplayFont,
                      color: c.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      letterSpacing: displayTracking(17),
                    ),
                  ),
                ),
                if (badge != null) ...[const SizedBox(width: 8), badge!],
              ],
            ),
          ),
          if (actionLabel != null)
            PressableScale(
              onTap: onAction,
              child: Row(
                children: [
                  Text(
                    actionLabel!,
                    style: TextStyle(
                      color: c.accent,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Icon(CupertinoIcons.chevron_right, color: c.accent, size: 18),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Round tinted icon, used in lists and cards.
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final bool squircle;
  const IconBadge(
    this.icon,
    this.color, {
    this.size = 40,
    this.squircle = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: squircle ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: squircle ? BorderRadius.circular(size * 0.32) : null,
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}

/// Small pulsing dot that says "this is live".
class LiveDot extends StatefulWidget {
  final Color color;
  const LiveDot({this.color = kSafe, super.key});

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  // Goes 0 -> 1 once (one ripple), then the dot stays still. Not a forever
  // loop: on the web any running animation redraws the WHOLE screen every
  // frame, which kept the CPU at 100% with nobody touching the app.
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..forward();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: 14,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) => Stack(
          alignment: Alignment.center,
          children: [
            // The expanding "ripple" ring behind the dot. As the value
            // goes 0 -> 1, it grows from 6 px to 14 px wide while its
            // opacity drops from 0.5 to 0, so it fades out as it grows.
            Container(
              width: 6 + 8 * _ctrl.value,
              height: 6 + 8 * _ctrl.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(alpha: 0.5 * (1 - _ctrl.value)),
              ),
            ),
            // The solid dot in the middle (doesn't move).
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated layered water waves — the "agos" (current) brand element.
class AnimatedWaves extends StatefulWidget {
  final double height;
  final List<Color> colors;
  const AnimatedWaves({
    this.height = 80,
    this.colors = const [
      Color(0x1A0A84FF),
      Color(0x260A84FF),
      Color(0x330A84FF),
    ],
    super.key,
  });

  @override
  State<AnimatedWaves> createState() => _AnimatedWavesState();
}

class _AnimatedWavesState extends State<AnimatedWaves>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary: the waves redraw ~60 times a second. This keeps
    // those redraws separate so the rest of the screen isn't redrawn too
    // (saves battery / keeps scrolling smooth).
    // CustomPaint hands the drawing to _WavePainter below.
    return IgnorePointer(
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: RepaintBoundary(
          child: CustomPaint(painter: _WavePainter(_ctrl, widget.colors)),
        ),
      ),
    );
  }
}

/// Draws the waves by hand on a canvas, one sine wave per color.
class _WavePainter extends CustomPainter {
  final Animation<double> anim;
  final List<Color> colors;
  // `repaint: anim` = call paint() again every time the animation ticks,
  // without rebuilding any widgets (cheaper than setState).
  _WavePainter(this.anim, this.colors) : super(repaint: anim);

  @override
  void paint(Canvas canvas, Size size) {
    // One filled wave shape per color, drawn back to front.
    for (var i = 0; i < colors.length; i++) {
      // phase = how far the wave has shifted sideways. anim.value goes
      // 0 -> 1, so this goes 0 -> 2π (one full wave length) per loop.
      // Even layers move right, odd layers move left (the ±1), and
      // "+ i * 1.3" starts each layer at a different spot so the waves
      // don't line up.
      final phase = anim.value * 2 * math.pi * (i.isEven ? 1 : -1) + i * 1.3;
      // amp = wave height (how tall the bumps are). Later layers are a bit
      // taller.
      final amp = size.height * (0.12 + i * 0.04);
      // base = the wave's middle line. Later layers sit lower, so the
      // front wave is at the bottom (like real layered water).
      final base = size.height * (0.35 + i * 0.18);
      // Start at the bottom-left corner, trace the wave's top edge from
      // left to right, then go down to the bottom-right corner and close
      // the shape, so the area under the wave gets filled.
      final path = Path()..moveTo(0, size.height);
      // Every 4 px across, compute the wave's height with sin().
      // x / size.width * 2π * (1.2 + i * 0.3) = how many bumps fit across
      // the screen (1.2 for the first layer, 1.5 for the next, ...).
      for (double x = 0; x <= size.width; x += 4) {
        final y =
            base +
            math.sin(x / size.width * 2 * math.pi * (1.2 + i * 0.3) + phase) *
                amp;
        path.lineTo(x, y);
      }
      path
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(path, Paint()..color = colors[i]);
    }
  }

  // Only needed when a new painter replaces the old one (e.g. the colors
  // changed with the theme). The animation itself repaints via `repaint:`.
  @override
  bool shouldRepaint(covariant _WavePainter old) => old.colors != colors;
}

/// Title row at the top of each tab.
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? badge; // sits right after the title, e.g. SampleBadge
  const PageHeader(
    this.title, {
    this.subtitle,
    this.trailing,
    this.badge,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    // Apple's Large Title: 34 bold. The trailing button centers on the
    // title block, so it lines up whether or not there's a subtitle.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontFamily: kDisplayFont,
                        color: c.textPrimary,
                        fontSize: 34,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: displayTracking(34),
                      ),
                    ),
                  ),
                  if (badge != null) ...[const SizedBox(width: 10), badge!],
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(color: c.textSecondary, fontSize: 15),
                ),
              ],
            ],
          ),
        ),
        // `?trailing` = add `trailing` to the list only if it isn't null
        // (Dart's "null-aware element"; same as `if (trailing != null) trailing!`).
        ?trailing,
      ],
    );
  }
}

/// Scaffold for screens opened on top of the tabs (with a back button).
class SubpageScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget? bottom;
  const SubpageScaffold({
    required this.title,
    required this.body,
    this.bottom,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PageBackground(
        child: SafeArea(
          // On wide screens, keep forms and text at a readable width in
          // the middle instead of stretching across the whole window.
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isWideScreen(context) ? 760 : double.infinity,
              ),
              child: _body(c, context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(AppColors c, BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 20, 4),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back',
                icon: Icon(CupertinoIcons.chevron_back, color: c.textPrimary),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: kDisplayFont,
                    color: c.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: displayTracking(20),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: body),
        ?bottom,
      ],
    );
  }
}

/// The page transition used when opening a screen on top of another:
/// the new page fades in while sliding in slightly from the right.
/// Use it like `Navigator.of(context).push(slideRoute(SomeScreen()))`.
///
/// `animation` goes 0 -> 1 when opening (and 1 -> 0 when going back).
/// Offset(0.06, 0) means "6% of the screen width to the right", so the
/// page starts a little to the right and slides into place (Offset.zero).
/// `<T>` is the type of value the page can return when it closes
/// (`Navigator.pop(context, value)`).
Route<T> slideRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.06, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Opens a rounded bottom sheet with a drag handle.
///
/// On tablets and desktops a bottom sheet looks out of place, so the same
/// content opens as a centered popup instead (at most [maxWidth] wide),
/// with a close button. The `builder` doesn't need to know which one:
/// `Navigator.of(sheet).pop()` closes either.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required Widget Function(BuildContext) builder,
  double maxWidth = 560,
}) {
  if (isWideScreen(context)) {
    return _showAppDialog<T>(context, builder: builder, maxWidth: maxWidth);
  }
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      final c = AppColors(sheetContext);
      // viewInsets.bottom = the height of the on-screen keyboard (0 when
      // it's closed). Padding by that amount pushes the sheet up above the
      // keyboard so text fields inside it aren't hidden.
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        // The sheet can be at most 88% of the screen height; anything
        // taller scrolls (SingleChildScrollView below).
        // Frosted glass: the page shows through, blurred, like iOS sheets.
        child: _SwipeDownToClose(
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: BackdropFilter(
              filter: kGlassBlur,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(sheetContext).size.height * 0.88,
                ),
                decoration: BoxDecoration(
                  color: c.surface.withValues(alpha: c.isDark ? 0.78 : 0.86),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  border: Border.all(color: c.border),
                ),
                child: SingleChildScrollView(
                  // Clamping (no bounce) on every phone, so pulling down at the
                  // top reaches _SwipeDownToClose instead of stretching the list.
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 18),
                          decoration: BoxDecoration(
                            color: c.textSecondary.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      builder(sheetContext),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// The wide-screen version of [showAppSheet]: a centered card over a dark
/// backdrop. Clicking the backdrop or pressing Esc closes it too.
Future<T?> _showAppDialog<T>(
  BuildContext context, {
  required Widget Function(BuildContext) builder,
  required double maxWidth,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (dialogContext, _, _) {
      final c = AppColors(dialogContext);
      final height = MediaQuery.sizeOf(dialogContext).height;
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
                maxHeight: height * 0.9,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: kGlassBlur,
                  child: CustomPaint(
                    foregroundPainter: GlassEdgePainter(
                      radius: 24,
                      dark: c.isDark,
                    ),
                    child: Material(
                      color: c.surface.withValues(alpha: c.isDark ? 0.8 : 0.88),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: IconButton(
                                tooltip: 'Close',
                                icon: Icon(
                                  CupertinoIcons.xmark,
                                  color: c.textSecondary,
                                ),
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(),
                              ),
                            ),
                          ),
                          Flexible(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                              child: builder(dialogContext),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (_, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Animated "done" popup, e.g. after submitting a report.
Future<void> showSuccessDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 350),
    pageBuilder: (dialogContext, _, _) {
      final c = AppColors(dialogContext);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          // An alert-sized box; without the cap it spans the whole window.
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Material(
              color: c.surface,
              borderRadius: BorderRadius.circular(28),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The green check "pops" in: its scale springs 0 -> 1,
                    // overshooting a little and bouncing back.
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 650),
                      curve: kBouncyCurve,
                      builder: (context, v, child) =>
                          Transform.scale(scale: v, child: child),
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: kSafe,
                        ),
                        child: const Icon(
                          CupertinoIcons.checkmark_alt,
                          color: Colors.white,
                          size: 42,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 20),
                    PrimaryButton(
                      label: 'Done',
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
    // How the whole dialog appears: fades in while growing from 90% to
    // 100% size on a snappy spring (slight overshoot at the end).
    transitionBuilder: (_, anim, _, child) => FadeTransition(
      opacity: anim,
      child: ScaleTransition(
        scale: Tween(
          begin: 0.9,
          end: 1.0,
        ).animate(CurvedAnimation(parent: anim, curve: kSnappyCurve)),
        child: child,
      ),
    ),
  );
}

/// Text field styled to match the app.
class AppTextField extends StatelessWidget {
  final String hint;
  final IconData? icon;
  final bool obscure;
  final Widget? suffix;
  final int maxLines;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  // Lets password managers fill the field (AutofillHints.email...).
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  const AppTextField({
    required this.hint,
    this.icon,
    this.obscure = false,
    this.suffix,
    this.maxLines = 1,
    this.controller,
    this.keyboardType,
    this.onChanged,
    this.autofillHints,
    this.textInputAction,
    this.onSubmitted,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: color, width: width),
        );
    return TextField(
      controller: controller,
      obscureText: obscure,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      autofillHints: autofillHints,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      style: TextStyle(color: c.textPrimary, fontSize: 15),
      cursorColor: c.accent,
      decoration: InputDecoration(
        filled: true,
        fillColor: c.surfaceAlt,
        prefixIcon: icon == null
            ? null
            : Icon(icon, color: c.textSecondary, size: 20),
        suffixIcon: suffix,
        hintText: hint,
        hintStyle: TextStyle(color: c.textSecondary, fontSize: 15),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: border(Colors.transparent),
        enabledBorder: border(Colors.transparent),
        focusedBorder: border(c.accent, 1.5),
      ),
    );
  }
}

/// Selectable chip used for categories and filters.
class SelectChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? color;
  const SelectChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.color,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    // Picked = the raised glass thumb of the segmented control (white at
    // 16% on dark, white with a soft shadow on light), never a glaring
    // solid white. A chip with its own [color] (a risk level) gets a soft
    // tint of that color instead.
    final picked = color != null
        ? color!.withValues(alpha: c.isDark ? 0.22 : 0.14)
        : (c.isDark ? Colors.white.withValues(alpha: 0.16) : Colors.white);
    final fg = selected
        ? (color == null ? c.textPrimary : c.readable(color!))
        : c.textSecondary;
    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? picked : c.surfaceAlt,
          borderRadius: BorderRadius.circular(40),
          border: Border.all(
            color: selected
                ? (c.isDark
                      ? Colors.white.withValues(alpha: 0.14)
                      : Colors.black.withValues(alpha: 0.06))
                : c.border,
          ),
          boxShadow: selected && !c.isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: fg,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small uppercase label above a group of fields.
class FieldLabel extends StatelessWidget {
  final String text;
  const FieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: c.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// Lets the user close a sheet by swiping it down, like a drawer.
///
/// Flutter's sheets can already be dragged down, but not when their
/// content scrolls (like a flood pin's details): the finger then scrolls
/// the list instead. So this listens to the list: when it's already at
/// the top and the finger keeps pulling down (an "overscroll"), the sheet
/// follows the finger. On release it closes if pulled far or fast enough,
/// otherwise it slides back up.
class _SwipeDownToClose extends StatefulWidget {
  final Widget child;
  const _SwipeDownToClose({required this.child});

  @override
  State<_SwipeDownToClose> createState() => _SwipeDownToCloseState();
}

class _SwipeDownToCloseState extends State<_SwipeDownToClose>
    with SingleTickerProviderStateMixin {
  static const _closeDistance = 120.0; // pixels pulled down
  static const _closeSpeed = 700.0; // pixels per second

  double _offset = 0;
  bool _closing = false;
  // Springs the sheet back up to 0 when it was let go too early, starting
  // at the finger's speed (no seam between the drag and the motion).
  late final AnimationController _back = AnimationController.unbounded(
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    _back.addListener(() => setState(() => _offset = _back.value));
  }

  @override
  void dispose() {
    _back.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification n) {
    // depth 0 = the sheet's own list, not a list inside it.
    if (_closing || n.depth != 0 || n.metrics.axis != Axis.vertical) {
      return false;
    }
    if (n is OverscrollNotification &&
        n.dragDetails != null &&
        n.overscroll < 0) {
      _back.stop();
      setState(() => _offset -= n.overscroll);
    } else if (n is ScrollUpdateNotification &&
        n.dragDetails != null &&
        _offset > 0 &&
        n.scrollDelta! > 0) {
      // Finger went back up while the sheet was pulled down: raise the
      // sheet first.
      setState(() => _offset = (_offset - n.scrollDelta!).clamp(0, 1e9));
    } else if (n is ScrollEndNotification && _offset > 0) {
      final speed = n.dragDetails?.primaryVelocity ?? 0;
      if (_offset > _closeDistance || speed > _closeSpeed) {
        _closing = true;
        Navigator.of(context).pop();
      } else {
        // Drawer / sheet spring (Apple: damping 0.8, response 0.3).
        _back.animateWith(
          SpringSimulation(
            const SpringDescription(mass: 1, stiffness: 439, damping: 33.5),
            _offset,
            0,
            -speed,
          ),
        );
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // The app scrolls with iOS bounce; a sheet keeps the clamping kind,
    // because pulling it down to close reads the overscroll.
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context)
          .copyWith(physics: const ClampingScrollPhysics()),
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: Transform.translate(
          offset: Offset(0, _offset.clamp(0, 1e9)),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Barangay picker used by the rescue, missing person and report forms,
/// and sign-up. [value] null = nothing picked yet (shows "Choose...").
class BarangayDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String> onChanged;
  const BarangayDropdown({
    required this.value,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text(
            'Choose your barangay',
            style: TextStyle(color: c.textSecondary, fontSize: 15),
          ),
          dropdownColor: c.surface,
          borderRadius: BorderRadius.circular(16),
          menuMaxHeight: 320,
          icon: Icon(CupertinoIcons.chevron_down, color: c.textSecondary),
          style: TextStyle(
            color: c.textPrimary,
            fontFamily: kFontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          items: [
            for (final b in kBarangays)
              DropdownMenuItem(value: b, child: Text('Brgy. $b')),
          ],
          onChanged: (v) => onChanged(v!),
        ),
      ),
    );
  }
}
