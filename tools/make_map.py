"""Builds everything the Map tab draws, into web/map/ (served with the app).

    python tools/make_map.py            # all steps
    python tools/make_map.py style      # only rebuild the style files

Needs: pip install pmtiles freetype-py numpy scipy

Steps (each one writes its own folder, so a step can be rerun alone):

  tiles   Map data for Mabalacat only, cut out of the Protomaps world map
          (OpenStreetMap data). Only the needed tiles are downloaded, using
          HTTP range requests on the big world file. Saved as plain
          tiles/{z}/{x}/{y}.pbf files: any static host (GitHub Pages,
          `flutter run`) can serve them, no special server or plugin needed.
  terrain Elevation tiles (AWS Terrain Tiles, Terrarium PNGs) for the 3D
          ground and the hill shading.
  glyphs  The map's label font: Inter (same as the app), turned into the
          SDF "glyph" files MapLibre needs to draw text.
  lib     MapLibre GL JS itself (pinned version), so the app never loads
          code from someone else's server.
  style   style-light.json / style-dark.json: every color and line width
          of the map. To experiment visually, open a style in Maputnik
          (https://maplibre.org/maputnik/), then copy the values you like
          back into STYLE below. Never edit the JSON files by hand.

Re-run `tiles` now and then to pick up new roads and buildings (the data is
a snapshot of the day it was downloaded).
"""

import gzip
import io
import json
import math
import os
import sys
import urllib.request
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'web', 'map')

# Same box as kMabalacatBounds in lib/screens/map_tab.dart: the map can't be
# dragged outside it. (south, west, north, east)
CITY = (15.130, 120.490, 15.300, 120.670)
# Detail zooms (13-15) cover the city plus a small margin. Lower zooms cover a
# much bigger area, so a tilted 3D view still has land up to the horizon.
DETAIL_PAD = 0.03
HORIZON_PAD = 0.2
DETAIL_ZOOMS = range(13, 16)  # Protomaps stops at 15; MapLibre enlarges it
HORIZON_ZOOMS = range(8, 13)

MAPLIBRE_VERSION = '5.24.0'  # v6 is ES-modules only; v5 is one plain .js file
UA = {'User-Agent': 'agosalert-map-builder'}


def fetch(url, headers=None):
    req = urllib.request.Request(url, headers={**UA, **(headers or {})})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read()


def tile_range(z, box):
    """Columns/rows of the zoom-z tiles that touch box (s, w, n, e)."""
    s, w, n, e = box
    n2 = 2**z

    def x(lon):
        return int((lon + 180) / 360 * n2)

    def y(lat):
        r = math.radians(lat)
        return int((1 - math.asinh(math.tan(r)) / math.pi) / 2 * n2)

    return range(x(w), x(e) + 1), range(y(n), y(s) + 1)


def pad(box, p):
    s, w, n, e = box
    return (s - p, w - p, n + p, e + p)


def all_tiles():
    for zooms, p in ((HORIZON_ZOOMS, HORIZON_PAD), (DETAIL_ZOOMS, DETAIL_PAD)):
        for z in zooms:
            xs, ys = tile_range(z, pad(CITY, p))
            for x in xs:
                for y in ys:
                    yield z, x, y


# ------------------------------------------------------------------ tiles
def step_tiles():
    import shutil

    from pmtiles.reader import Reader

    shutil.rmtree(os.path.join(OUT, 'tiles'), ignore_errors=True)

    builds = json.loads(fetch('https://build-metadata.protomaps.dev/builds.json'))
    url = 'https://build.protomaps.com/' + builds[-1]['key']
    print('tiles from', url)
    cache = {}

    def get_bytes(offset, length):
        key = (offset, length)
        if key not in cache:
            cache[key] = fetch(url, {'Range': f'bytes={offset}-{offset + length - 1}'})
        return cache[key]

    reader = Reader(get_bytes)
    reader.header()  # warm the cache before the threads start

    def one(t):
        z, x, y = t
        data = reader.get(z, x, y)
        if not data:
            return 0
        if data[:2] == b'\x1f\x8b':
            data = gzip.decompress(data)
        path = os.path.join(OUT, 'tiles', str(z), str(x), f'{y}.pbf')
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'wb') as f:
            f.write(data)
        return len(data)

    tiles = list(all_tiles())
    with ThreadPoolExecutor(8) as pool:
        sizes = list(pool.map(one, tiles))
    meta = reader.metadata()
    with open(os.path.join(OUT, 'tiles', 'source.json'), 'w') as f:
        json.dump({'url': url, 'attribution': meta.get('attribution', ''), 'version': meta.get('version')}, f, indent=1)
    print(f'  {sum(1 for s in sizes if s)} tiles, {sum(sizes) / 1e6:.1f} MB')


# ---------------------------------------------------------------- terrain
TERRAIN_ZOOMS = range(8, 13)


def step_terrain():
    def one(t):
        z, x, y = t
        data = fetch(f'https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png')
        path = os.path.join(OUT, 'terrain', str(z), str(x), f'{y}.png')
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'wb') as f:
            f.write(data)
        return len(data)

    tiles = []
    for z in TERRAIN_ZOOMS:
        xs, ys = tile_range(z, pad(CITY, HORIZON_PAD if z < 11 else DETAIL_PAD + 0.05))
        tiles += [(z, x, y) for x in xs for y in ys]
    with ThreadPoolExecutor(8) as pool:
        sizes = list(pool.map(one, tiles))
    print(f'  terrain: {len(tiles)} tiles, {sum(sizes) / 1e6:.1f} MB')


# ----------------------------------------------------------------- glyphs
# MapLibre draws text from "SDF glyphs": each letter as a small grayscale
# picture of its distance to the outline, at 24 px with a 3 px border, packed
# 256 characters per .pbf file. We only make the ranges Latin text needs.
GLYPH_RANGES = [(0, 255), (256, 511), (8192, 8447)]
FONTS = {
    'Inter Regular': 'Inter-Regular.ttf',
    'Inter SemiBold': 'Inter-SemiBold.ttf',
    'Inter Bold': 'Inter-Bold.ttf',
}


def _varint(n):
    out = bytearray()
    while True:
        b = n & 0x7F
        n >>= 7
        if n:
            out.append(b | 0x80)
        else:
            out.append(b)
            return bytes(out)


def _field(num, wire, payload):
    key = _varint((num << 3) | wire)
    if wire == 0:
        return key + _varint(payload)
    return key + _varint(len(payload)) + payload


def _sint(n):  # zigzag, for sint32 fields (left, top)
    return (n << 1) ^ (n >> 31)


def step_glyphs():
    import freetype
    import numpy as np
    from scipy.ndimage import distance_transform_edt

    SIZE, BUFFER, CUTOFF, RADIUS, SCALE = 24, 3, 0.25, 8, 8
    for stack, file in FONTS.items():
        face = freetype.Face(os.path.join(ROOT, 'assets', 'fonts', file))
        # Rendered 8x bigger, then shrunk: a smoother distance field.
        face.set_pixel_sizes(0, SIZE * SCALE)
        ascender = face.size.ascender / 64 / SCALE
        for lo, hi in GLYPH_RANGES:
            glyphs = b''
            for code in range(lo, hi + 1):
                if not face.get_char_index(code):
                    continue
                face.load_char(code, freetype.FT_LOAD_RENDER | freetype.FT_LOAD_TARGET_NORMAL)
                g = face.glyph
                bm = g.bitmap
                advance = round(g.advance.x / 64 / SCALE)
                msg = _field(1, 0, code)
                if bm.width and bm.rows:
                    img = np.array(bm.buffer, dtype=np.uint8).reshape(bm.rows, bm.pitch)[:, : bm.width]
                    left = math.floor(g.bitmap_left / SCALE)
                    top_px = math.ceil(g.bitmap_top / SCALE)
                    w = math.ceil((g.bitmap_left + bm.width) / SCALE) - left
                    h = top_px - math.floor((g.bitmap_top - bm.rows) / SCALE)
                    # Place the big bitmap on a grid aligned to the small one.
                    big = np.zeros(((h + 2 * BUFFER) * SCALE, (w + 2 * BUFFER) * SCALE), np.float64)
                    ox = g.bitmap_left - left * SCALE + BUFFER * SCALE
                    oy = top_px * SCALE - g.bitmap_top + BUFFER * SCALE
                    big[oy : oy + bm.rows, ox : ox + bm.width] = img / 255
                    inside = big > 0.5
                    dist = distance_transform_edt(~inside) - distance_transform_edt(inside)
                    dist = dist.reshape(h + 2 * BUFFER, SCALE, w + 2 * BUFFER, SCALE).mean(axis=(1, 3)) / SCALE
                    sdf = np.clip(255 - 255 * (dist / RADIUS + CUTOFF), 0, 255).astype(np.uint8)
                    msg += _field(2, 2, sdf.tobytes())
                    msg += _field(3, 0, w) + _field(4, 0, h)
                    msg += _field(5, 0, _sint(left)) + _field(6, 0, _sint(top_px - round(ascender)))
                else:
                    msg += _field(3, 0, 0) + _field(4, 0, 0) + _field(5, 0, 0) + _field(6, 0, _sint(-round(ascender)))
                msg += _field(7, 0, advance)
                glyphs += _field(3, 2, msg)
            fontstack = _field(1, 2, stack.encode()) + _field(2, 2, f'{lo}-{hi}'.encode()) + glyphs
            path = os.path.join(OUT, 'glyphs', stack, f'{lo}-{hi}.pbf')
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, 'wb') as f:
                f.write(_field(1, 2, fontstack))
    print('  glyphs:', ', '.join(FONTS))


# -------------------------------------------------------------------- lib
def step_lib():
    base = f'https://cdn.jsdelivr.net/npm/maplibre-gl@{MAPLIBRE_VERSION}/dist/'
    for name in ('maplibre-gl.js', 'maplibre-gl.css'):
        with open(os.path.join(OUT, name), 'wb') as f:
            f.write(fetch(base + name))
    print('  maplibre-gl', MAPLIBRE_VERSION)


# ------------------------------------------------------------------ style
# Two palettes, same layers. Black/white like the app; color only where it
# means something: water is blue (rivers flood), parks a faint green. Roads
# are plain white/graphite, the way Apple Maps keeps them quiet.
PALETTE = {
    'light': {
        'background': '#F2F2F4',
        'earth': '#F2F2F4',
        'park': '#DDEBD9',
        'wood': '#D6E6D2',
        'urban': '#ECECEF',
        'industrial': '#E8E7EC',
        'school': '#E9E6F0',
        'hospital': '#F3E3E3',
        'water': '#A9CFF5',
        'water_line': '#8DBDEE',
        'water_label': '#3B78B8',
        'road_minor': '#FFFFFF',
        'road_minor_case': '#E2E2E7',
        'road_major': '#FFFFFF',
        'road_major_case': '#D5D5DC',
        'highway': '#FFE3A3',
        'highway_case': '#E9C677',
        'rail': '#C7C7CF',
        'boundary': '#B7B7C2',
        'building': '#E1E1E6',
        'building_top': '#EAEAEE',
        'building_side': '#D3D3DA',
        'building_line': '#D2D2D9',
        'label': '#3A3A3C',
        'label_minor': '#6E6E73',
        'halo': '#FFFFFF',
        'poi': '#8E8E93',
        'hillshade_shadow': '#5A5A6E',
        'hillshade_highlight': '#FFFFFF',
        'sky': '#DCE8F5',
        'horizon': '#F2F2F4',
    },
    'dark': {
        'background': '#000000',
        'earth': '#0B0B0D',
        'park': '#0F1A12',
        'wood': '#0E1A10',
        'urban': '#0F0F12',
        'industrial': '#111114',
        'school': '#131219',
        'hospital': '#1A1012',
        'water': '#0B2742',
        'water_line': '#123A61',
        'water_label': '#5EA8F0',
        'road_minor': '#2A2A2F',
        'road_minor_case': '#0B0B0D',
        'road_major': '#3A3A40',
        'road_major_case': '#0B0B0D',
        'highway': '#5C4A26',
        'highway_case': '#0B0B0D',
        'rail': '#2C2C31',
        'boundary': '#3A3A42',
        'building': '#18181B',
        'building_top': '#1F1F23',
        'building_side': '#141417',
        'building_line': '#232328',
        'label': '#D1D1D6',
        'label_minor': '#8E8E93',
        'halo': '#000000',
        'poi': '#8E8E93',
        'hillshade_shadow': '#000000',
        'hillshade_highlight': '#2A2A30',
        'sky': '#05070B',
        'horizon': '#0B0B0D',
    },
}

FONT = ['Inter Regular']
FONT_SEMI = ['Inter SemiBold']
FONT_BOLD = ['Inter Bold']


def interp(*stops):
    """Exponential zoom curve: interp(12, 0.5, 18, 12)."""
    return ['interpolate', ['exponential', 1.6], ['zoom'], *stops]


def interp_by(prop, cases, default):
    """A zoom curve whose widths depend on a property, e.g. rivers wider
    than streams. MapLibre wants the zoom curve outermost, so each zoom
    stop holds a `match`. All curves must use the same zooms."""
    out = ['interpolate', ['exponential', 1.6], ['zoom']]
    for i in range(0, len(default), 2):
        out += [default[i], ['match', ['get', prop], *[v for k, w in cases.items() for v in (k, w[i + 1])], default[i + 1]]]
    return out


def detail(kinds):
    return ['in', ['get', 'kind_detail'], ['literal', kinds]]


def geom(kind):
    """Matches Polygon and MultiPolygon (or LineString and MultiLineString)."""
    return ['in', ['geometry-type'], ['literal', [kind, 'Multi' + kind]]]


def road_layers(p):
    """Roads: casing (the darker outline) under every fill, minor first."""
    kinds = [
        # kind filter, fill color, casing color, width stops (zoom, px)
        ('path', ['==', ['get', 'kind'], 'path'], p['road_minor'], p['road_minor_case'], (15, 0.5, 18, 3)),
        ('minor', ['==', ['get', 'kind'], 'minor_road'], p['road_minor'], p['road_minor_case'], (13, 0.6, 16, 5, 18, 16)),
        ('medium', ['all', ['==', ['get', 'kind'], 'major_road'], detail(['secondary', 'tertiary', 'secondary_link', 'tertiary_link'])],
         p['road_major'], p['road_major_case'], (11, 0.6, 16, 7, 18, 20)),
        ('major', ['all', ['==', ['get', 'kind'], 'major_road'], ['!', detail(['secondary', 'tertiary', 'secondary_link', 'tertiary_link'])]],
         p['road_major'], p['road_major_case'], (9, 0.8, 16, 9, 18, 26)),
        ('highway', ['==', ['get', 'kind'], 'highway'], p['highway'], p['highway_case'], (8, 1, 16, 11, 18, 32)),
    ]
    out = []
    not_tunnel = ['!', ['to-boolean', ['get', 'is_tunnel']]]
    for name, f, fill, case, w in kinds:
        out.append({
            'id': f'road-{name}-case', 'type': 'line', 'source': 'base', 'source-layer': 'roads',
            'filter': ['all', f, not_tunnel],
            'layout': {'line-cap': 'round', 'line-join': 'round'},
            'paint': {'line-color': case, 'line-width': interp(*[v + 1.6 if i % 2 else v for i, v in enumerate(w)]), 'line-opacity': ['interpolate', ['linear'], ['zoom'], 12, 0, 13.5, 1]},
        })
    for name, f, fill, case, w in kinds:
        out.append({
            'id': f'road-{name}', 'type': 'line', 'source': 'base', 'source-layer': 'roads',
            'filter': ['all', f, not_tunnel],
            'layout': {'line-cap': 'round', 'line-join': 'round'},
            'paint': {'line-color': fill, 'line-width': interp(*w)},
        })
    return out


def build_style(theme):
    p = PALETTE[theme]
    with open(os.path.join(OUT, 'tiles', 'source.json')) as f:
        attribution = json.load(f)['attribution']
    s, w, n, e = pad(CITY, HORIZON_PAD)
    landuse = lambda kinds: ['in', ['get', 'kind'], ['literal', kinds]]  # noqa: E731
    layers = [
        {'id': 'background', 'type': 'background', 'paint': {'background-color': p['background']}},
        {'id': 'earth', 'type': 'fill', 'source': 'base', 'source-layer': 'earth', 'paint': {'fill-color': p['earth']}},
        {'id': 'landuse-urban', 'type': 'fill', 'source': 'base', 'source-layer': 'landuse',
         'filter': landuse(['residential', 'neighbourhood', 'commercial', 'retail']),
         'paint': {'fill-color': p['urban']}},
        {'id': 'landuse-industrial', 'type': 'fill', 'source': 'base', 'source-layer': 'landuse',
         'filter': landuse(['industrial', 'railway', 'military', 'aerodrome', 'runway', 'apron', 'taxiway']),
         'paint': {'fill-color': p['industrial']}},
        {'id': 'landuse-school', 'type': 'fill', 'source': 'base', 'source-layer': 'landuse',
         'filter': landuse(['school', 'university', 'college', 'kindergarten']), 'paint': {'fill-color': p['school']}},
        {'id': 'landuse-hospital', 'type': 'fill', 'source': 'base', 'source-layer': 'landuse',
         'filter': landuse(['hospital']), 'paint': {'fill-color': p['hospital']}},
        {'id': 'landuse-park', 'type': 'fill', 'source': 'base', 'source-layer': 'landuse',
         'filter': landuse(['park', 'playground', 'golf_course', 'pitch', 'garden', 'cemetery', 'grass', 'recreation_ground', 'grassland', 'meadow', 'farmland', 'orchard']),
         'paint': {'fill-color': p['park']}},
        {'id': 'landuse-wood', 'type': 'fill', 'source': 'base', 'source-layer': 'landuse',
         'filter': landuse(['wood', 'forest', 'nature_reserve', 'national_park', 'protected_area', 'scrub', 'wetland']),
         'paint': {'fill-color': p['wood']}},
        {'id': 'hillshade', 'type': 'hillshade', 'source': 'dem',
         'paint': {'hillshade-shadow-color': p['hillshade_shadow'], 'hillshade-highlight-color': p['hillshade_highlight'],
                   'hillshade-accent-color': p['hillshade_shadow'],
                   'hillshade-exaggeration': 0.35 if theme == 'light' else 0.5, 'hillshade-illumination-direction': 315}},
        {'id': 'water', 'type': 'fill', 'source': 'base', 'source-layer': 'water',
         'filter': geom('Polygon'), 'paint': {'fill-color': p['water']}},
        {'id': 'waterway', 'type': 'line', 'source': 'base', 'source-layer': 'water',
         'filter': geom('LineString'),
         'layout': {'line-cap': 'round', 'line-join': 'round'},
         'paint': {'line-color': p['water_line'],
                   'line-width': interp_by('kind', {'river': (10, 1, 14, 3, 18, 14)}, (10, 0.2, 14, 1.2, 18, 5))}},
        {'id': 'boundary', 'type': 'line', 'source': 'base', 'source-layer': 'boundaries',
         'filter': ['<=', ['to-number', ['get', 'kind_detail'], 99], 8],
         'paint': {'line-color': p['boundary'], 'line-width': 1, 'line-dasharray': [3, 2]}},
        {'id': 'runway', 'type': 'line', 'source': 'base', 'source-layer': 'roads',
         'filter': ['==', ['get', 'kind'], 'aeroway'],
         'paint': {'line-color': p['road_major'], 'line-width': interp_by('kind_detail', {'runway': (11, 2, 16, 30, 18, 90)}, (11, 0.3, 16, 8, 18, 30))}},
        {'id': 'rail', 'type': 'line', 'source': 'base', 'source-layer': 'roads',
         'filter': ['==', ['get', 'kind'], 'rail'],
         'paint': {'line-color': p['rail'], 'line-width': interp(12, 0.6, 18, 3), 'line-dasharray': [2, 2]}},
        *road_layers(p),
        # Flat footprints, faded in from zoom 14 (the 2D view).
        {'id': 'building', 'type': 'fill', 'source': 'base', 'source-layer': 'buildings', 'minzoom': 14,
         'paint': {'fill-color': p['building'], 'fill-outline-color': p['building_line'],
                   'fill-opacity': ['interpolate', ['linear'], ['zoom'], 14, 0, 15, 1]}},
        # 3D blocks. Invisible until the app turns 3D on (map_view_web.dart
        # sets the opacity). OSM rarely has heights here, so an unknown
        # building is drawn 1-2 storeys (5 m), like most houses in town.
        {'id': 'building-3d', 'type': 'fill-extrusion', 'source': 'base', 'source-layer': 'buildings', 'minzoom': 14,
         'paint': {'fill-extrusion-color': p['building_top'],
                   'fill-extrusion-height': ['interpolate', ['linear'], ['zoom'], 14, 0, 15.5, ['coalesce', ['get', 'height'], 5]],
                   'fill-extrusion-base': ['coalesce', ['get', 'min_height'], 0],
                   'fill-extrusion-opacity': 0, 'fill-extrusion-vertical-gradient': True}},
        # Labels: water, roads, places. Text halos keep them readable on any fill.
        {'id': 'water-label', 'type': 'symbol', 'source': 'base', 'source-layer': 'water', 'minzoom': 13,
         'filter': ['all', geom('LineString'), ['has', 'name']],
         'layout': {'symbol-placement': 'line', 'text-field': ['get', 'name'], 'text-font': FONT_SEMI,
                    'text-size': 12, 'text-letter-spacing': 0.08, 'symbol-spacing': 400},
         'paint': {'text-color': p['water_label'], 'text-halo-color': p['halo'], 'text-halo-width': 1.4}},
        {'id': 'road-label', 'type': 'symbol', 'source': 'base', 'source-layer': 'roads', 'minzoom': 14,
         'filter': ['has', 'name'],
         'layout': {'symbol-placement': 'line', 'text-field': ['get', 'name'], 'text-font': FONT,
                    'text-size': interp(14, 10, 18, 13), 'symbol-spacing': 350, 'text-max-angle': 30},
         'paint': {'text-color': p['label_minor'], 'text-halo-color': p['halo'], 'text-halo-width': 1.6}},
        {'id': 'poi', 'type': 'symbol', 'source': 'base', 'source-layer': 'pois', 'minzoom': 15.5,
         'filter': ['all', ['has', 'name'], ['in', ['get', 'kind'], ['literal', [
             'school', 'hospital', 'clinic', 'townhall', 'place_of_worship', 'police', 'fire_station', 'marketplace',
             'university', 'college', 'stadium', 'bus_station']]]],
         'layout': {'text-field': ['get', 'name'], 'text-font': FONT_SEMI, 'text-size': 11, 'text-max-width': 8},
         'paint': {'text-color': p['poi'], 'text-halo-color': p['halo'], 'text-halo-width': 1.4}},
        {'id': 'place-neighbourhood', 'type': 'symbol', 'source': 'base', 'source-layer': 'places', 'minzoom': 13,
         # Barangays and smaller places (OSM tags some barangays as towns).
         'filter': ['!', ['in', ['get', 'kind_detail'], ['literal', ['city', 'town']]]],
         'layout': {'text-field': ['get', 'name'], 'text-font': FONT_SEMI, 'text-size': interp(13, 10, 17, 12.5),
                    'text-transform': 'uppercase', 'text-letter-spacing': 0.12, 'text-max-width': 8, 'text-padding': 6},
         'paint': {'text-color': p['label_minor'], 'text-halo-color': p['halo'], 'text-halo-width': 1.6,
                   'text-opacity': 0.85}},
        {'id': 'place-town', 'type': 'symbol', 'source': 'base', 'source-layer': 'places',
         'filter': ['in', ['get', 'kind_detail'], ['literal', ['city', 'town']]],
         'layout': {'text-field': ['get', 'name'], 'text-font': FONT_BOLD, 'text-size': interp(10, 13, 14, 18),
                    'text-max-width': 8},
         'paint': {'text-color': p['label'], 'text-halo-color': p['halo'], 'text-halo-width': 2}},
    ]
    return {
        'version': 8,
        'name': f'AgosAlert {theme}',
        'glyphs': 'map/glyphs/{fontstack}/{range}.pbf',
        'sources': {
            'base': {'type': 'vector', 'tiles': ['map/tiles/{z}/{x}/{y}.pbf'], 'minzoom': min(HORIZON_ZOOMS),
                     'maxzoom': max(DETAIL_ZOOMS), 'bounds': [w, s, e, n], 'attribution': attribution},
            'dem': {'type': 'raster-dem', 'tiles': ['map/terrain/{z}/{x}/{y}.png'], 'encoding': 'terrarium',
                    'tileSize': 256, 'minzoom': min(TERRAIN_ZOOMS), 'maxzoom': max(TERRAIN_ZOOMS), 'bounds': [w, s, e, n],
                    'attribution': 'Terrain: <a href="https://registry.opendata.aws/terrain-tiles/">Mapzen / AWS Terrain Tiles</a>'},
        },
        'sky': {'sky-color': p['sky'], 'horizon-color': p['horizon'], 'fog-color': p['horizon'],
                'sky-horizon-blend': 0.6, 'horizon-fog-blend': 0.8, 'fog-ground-blend': 0.75, 'atmosphere-blend': 0},
        'layers': layers,
    }


def step_style():
    for theme in PALETTE:
        with open(os.path.join(OUT, f'style-{theme}.json'), 'w') as f:
            json.dump(build_style(theme), f, separators=(',', ':'))
    print('  styles: light, dark')


STEPS = {'tiles': step_tiles, 'terrain': step_terrain, 'glyphs': step_glyphs, 'lib': step_lib, 'style': step_style}

if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    for name in sys.argv[1:] or STEPS:
        print(name)
        STEPS[name]()
