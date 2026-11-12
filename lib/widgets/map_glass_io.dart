import 'package:flutter/widgets.dart';

/// Off the web, Flutter draws the map itself, so its own blur works:
/// nothing to add.
class MapGlass extends StatelessWidget {
  final Widget child;
  final double radius;
  final bool blur;
  final bool enabled;
  const MapGlass({
    required this.child,
    this.radius = 0,
    this.blur = true,
    this.enabled = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) => child;
}
