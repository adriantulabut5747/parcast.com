import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../data/demo_data.dart';

/// Esri map tile addresses for the non-web map (widgets/map_tiles.dart),
/// and the prefetcher for the web map below. Kept free of the map packages
/// so it can be part of the first download.
const _base = 'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas';

/// Tile address template, e.g. for the dark map's labels layer.
///
/// A web map isn't one big picture: it's a grid of small 256x256 images
/// ("tiles"). {z} is the zoom level, {x}/{y} the tile's column/row in the
/// grid. The map fills these in for every tile it needs on screen.
String esriTileTemplate({required bool dark, required bool labels}) {
  final style = dark ? 'Dark' : 'Light';
  final layer = labels ? 'Reference' : 'Base';
  return '$_base/World_${style}_Gray_$layer/MapServer/tile/{z}/{y}/{x}';
}

/// Website only: downloads what the Map tab needs first (MapLibre, the
/// style, the label font, and the tiles around the city center), so the
/// map shows up at once when the tab is opened. The responses are thrown
/// away: the point is that the browser now has them in its cache.
Future<void> prefetchStartingMapTiles({required bool dark}) async {
  const zoom = 13; // the Map tab opens at 13.3, which uses zoom-13 tiles

  final n = math.pow(2, zoom);
  final lat = kMabalacatCenter.latitude * math.pi / 180;
  final x = ((kMabalacatCenter.longitude + 180) / 360 * n).floor();
  final y =
      ((1 - math.log(math.tan(lat) + 1 / math.cos(lat)) / math.pi) / 2 * n)
          .floor();

  final urls = [
    'agos_map.js',
    'map/maplibre-gl.js',
    'map/maplibre-gl.css',
    'map/style-${dark ? 'dark' : 'light'}.json',
    for (final font in ['Regular', 'SemiBold', 'Bold'])
      'map/glyphs/Inter%20$font/0-255.pbf',
    // A 3x3 block of tiles around the center tile (dx, dy = -1, 0, +1).
    for (var dx = -1; dx <= 1; dx++)
      for (var dy = -1; dy <= 1; dy++)
        'map/tiles/$zoom/${x + dx}/${y + dy}.pbf',
  ];
  // All start at once; Future.wait waits for all of them.
  await Future.wait([
    for (final url in urls)
      http.get(Uri.parse(url)).then((_) {}, onError: (Object _) {}),
  ]);
}
