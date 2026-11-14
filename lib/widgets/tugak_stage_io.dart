import 'package:flutter/widgets.dart';

import 'tugak.dart';
import 'tugak_stage.dart';

/// Tugak's terrace outside the browser (tests, a phone build): no three.js
/// here, so his still picture on the sky with his line. Tapping him gives
/// a tip, like in the 3D scene.
class TugakStage extends StatelessWidget {
  final TugakWeather weather;
  final String line;
  final ValueChanged<StageTap>? onTap;
  final StageReserve? reserve; // the part the live readings cover
  const TugakStage({
    required this.weather,
    required this.line,
    this.onTap,
    this.reserve,
    super.key,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => onTap?.call(StageTap.tugak),
    child: TugakStill(weather: weather, line: line, reserve: reserve),
  );
}
