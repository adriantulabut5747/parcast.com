"""Builds AgosAlert's own icons: the few flood-specific ones that
CupertinoIcons (the rest of the app's icons) doesn't have.

Run:  python tools/make_icons.py            (needs fonttools + skia-pathops)
      python tools/make_icons.py --preview out.png   (also needs Pillow)

Writes assets/fonts/AgosIcons.ttf and lib/widgets/agos_icons.dart.
Edit THIS file to change an icon, never the outputs.

How the icons are drawn (so they sit next to CupertinoIcons, which follow
Apple's SF Symbols style):
- A 24 x 24 grid, y pointing down. Content spans about y 2..22.
- Lines, not filled blobs: one stroke width (STROKE) with round ends and
  round corners, like SF Symbols "regular".
- The font copies CupertinoIcons' metrics (512 units per em, ascent 454,
  descent 74, same vertical center) so both fonts line up in a Row.
"""

import math
import os
import sys

import pathops
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT_OUT = os.path.join(ROOT, 'assets', 'fonts', 'AgosIcons.ttf')
DART_OUT = os.path.join(ROOT, 'lib', 'widgets', 'agos_icons.dart')

STROKE = 1.5  # matches CupertinoIcons' outline weight at 24 px
UPM, ASCENT, DESCENT = 512, 454, 74  # same as CupertinoIcons.ttf
K = 0.5523  # cubic handle length for a quarter circle


# ---------------------------------------------------------------- shapes
# Each shape is a list of contours; a contour is ('M', x, y) followed by
# ('L', x, y) / ('C', x1, y1, x2, y2, x, y), optionally ending in ('Z',).


def polyline(*pts, closed=False):
    c = [('M', *pts[0])] + [('L', *p) for p in pts[1:]]
    return [c + [('Z',)] if closed else c]


def wave(x0, x1, y, amp, periods):
    """A sine-like wave from x0 to x1 (half periods as cubic curves)."""
    half = (x1 - x0) / (periods * 2)
    c = [('M', x0, y)]
    for i in range(periods * 2):
        xa = x0 + i * half
        dy = -amp if i % 2 == 0 else amp  # crest first, then trough
        # Handles at 1/3 and 2/3 of the half period give a smooth hump.
        c.append(('C', xa + half * 0.36, y + dy * 1.33, xa + half * 0.64, y + dy * 1.33, xa + half, y))
    return [c]


def circle(cx, cy, r):
    k = r * K
    return [[
        ('M', cx + r, cy),
        ('C', cx + r, cy + k, cx + k, cy + r, cx, cy + r),
        ('C', cx - k, cy + r, cx - r, cy + k, cx - r, cy),
        ('C', cx - r, cy - k, cx - k, cy - r, cx, cy - r),
        ('C', cx + k, cy - r, cx + r, cy - k, cx + r, cy),
        ('Z',),
    ]]


def arc_points(cx, cy, r, a0, a1, steps=24):
    return [(cx + r * math.cos(a0 + (a1 - a0) * i / steps), cy + r * math.sin(a0 + (a1 - a0) * i / steps)) for i in range(steps + 1)]


def ring_sector(cx, cy, r_in, r_out, a0, a1):
    """A filled slice of a ring (used for the lifebuoy's colored bands)."""
    pts = arc_points(cx, cy, r_out, a0, a1) + arc_points(cx, cy, r_in, a1, a0)
    return polyline(*pts, closed=True)


# --------------------------------------------------------------- glyphs
# name: (stroked shapes, filled shapes)


def g_waves():
    return wave(2.5, 21.5, 7.5, 1.05, 3) + wave(2.5, 21.5, 12, 1.05, 3) + wave(2.5, 21.5, 16.5, 1.05, 3), []


def g_flood():
    # A house standing in water: roof with eaves, walls that vanish into the
    # first wave, a door half under water, a second wave below.
    house = polyline((3.4, 10.6), (12, 3.4), (20.6, 10.6)) + polyline((6.2, 8.6), (6.2, 14.0)) + polyline((17.8, 8.6), (17.8, 14.0))
    door = polyline((10.2, 14.0), (10.2, 10.6), (13.8, 10.6), (13.8, 14.0))
    water = wave(2.5, 21.5, 16.4, 1.0, 3) + wave(2.5, 21.5, 20.6, 1.0, 3)
    return house + door + water, []


LB = (12, 12, 9.4, 4.6)  # lifebuoy: center, outer radius, inner radius
BANDS = [math.radians(a) for a in (45, 135, 225, 315)]
BAND_HALF = math.radians(17)


def g_lifebuoy():
    cx, cy, ro, ri = LB
    lines = circle(cx, cy, ro) + circle(cx, cy, ri)
    for a in BANDS:  # each band is marked by its two edges
        for e in (a - BAND_HALF, a + BAND_HALF):
            lines += polyline((cx + ri * math.cos(e), cy + ri * math.sin(e)), (cx + ro * math.cos(e), cy + ro * math.sin(e)))
    return lines, []


def g_lifebuoy_fill():
    cx, cy, ro, ri = LB
    return circle(cx, cy, ro) + circle(cx, cy, ri), [ring_sector(cx, cy, ri, ro, a - BAND_HALF, a + BAND_HALF)[0] for a in BANDS]


def g_boat():
    # Rescue boat seen from the side: solid hull (stroked too, for round
    # corners; it sits in lists next to filled Cupertino icons) whose bow
    # rises to the right as if moving, a cabin with a slanted windshield,
    # a waterline below.
    hull = [[
        ('M', 2.8, 12.2), ('L', 21.2, 10.4),
        ('C', 20.6, 14.2, 18.8, 17.2, 15.8, 17.2),
        ('L', 6.0, 17.2), ('C', 4.2, 17.2, 3.2, 15.2, 2.8, 12.2), ('Z',),
    ]]
    cabin = polyline((6.6, 11.8), (6.6, 7.0), (12.6, 7.0), (15.4, 11.1))
    return hull + cabin + wave(2.5, 21.5, 21, 0.95, 3), hull


def g_landslide():
    # A rounded hill whose right side has broken off: the side stops in
    # mid-air and rocks tumble down to the ground. The open side and the
    # round top keep it from reading as a warning triangle.
    # The break is a jagged scar (not a smooth curve), so it reads as torn
    # earth; three rocks of falling size roll away down the right.
    hill = [[('M', 2.6, 20.6), ('C', 4.4, 14.8, 6.2, 5.4, 9.6, 5.4), ('C', 11.0, 5.4, 11.8, 6.4, 12.4, 7.6),
             ('L', 11.4, 9.6), ('L', 13.4, 11.2), ('L', 12.6, 13.4)]]
    ground = polyline((2.6, 20.6), (21.4, 20.6))
    rocks = circle(16.2, 12.6, 1.8) + circle(19.6, 16.4, 1.45) + circle(15.2, 17.8, 1.15)
    return hill + ground, rocks


def _pin():
    # A map pin (round head, point down) floating over a flat ground
    # ellipse: SF Symbols' "mappin.and.ellipse" idea, drawn in our weight.
    return [[
        ('M', 12, 17.0),
        ('C', 10.9, 15.5, 6.8, 12.2, 6.8, 8.6),
        ('C', 6.8, 5.7, 9.1, 3.4, 12, 3.4),
        ('C', 14.9, 3.4, 17.2, 5.7, 17.2, 8.6),
        ('C', 17.2, 12.2, 13.1, 15.5, 12, 17.0),
        ('Z',),
    ]]


def _ground():
    # The ellipse the pin stands over (flat circle, squashed).
    k = 0.5523
    cx, cy, rx, ry = 12, 19.7, 6.6, 1.7
    return [[
        ('M', cx + rx, cy),
        ('C', cx + rx, cy + ry * k, cx + rx * k, cy + ry, cx, cy + ry),
        ('C', cx - rx * k, cy + ry, cx - rx, cy + ry * k, cx - rx, cy),
        ('C', cx - rx, cy - ry * k, cx - rx * k, cy - ry, cx, cy - ry),
        ('C', cx + rx * k, cy - ry, cx + rx, cy - ry * k, cx + rx, cy),
        ('Z',),
    ]]


def g_map_pin():
    return _pin() + circle(12, 8.6, 1.9) + _ground(), []


def g_map_pin_fill():
    # Solid pin with the dot cut out (third item = holes).
    return _ground(), _pin(), circle(12, 8.6, 2.0)


def rrect(x0, y0, x1, y1, r):
    k = r * K
    return [[
        ('M', x0 + r, y0), ('L', x1 - r, y0), ('C', x1 - r + k, y0, x1, y0 + r - k, x1, y0 + r),
        ('L', x1, y1 - r), ('C', x1, y1 - r + k, x1 - r + k, y1, x1 - r, y1),
        ('L', x0 + r, y1), ('C', x0 + r - k, y1, x0, y1 - r + k, x0, y1 - r),
        ('L', x0, y0 + r), ('C', x0, y0 + r - k, x0 + r - k, y0, x0 + r, y0), ('Z',),
    ]]


def g_road_block():
    # A road barricade (sawhorse): a solid board with three diagonal
    # stripes cut out, two splayed legs, a warning lamp on top. Solid, so
    # it reads as a white glyph inside a 34 px map pin.
    board = rrect(2.6, 7.0, 21.4, 12.8, 1.3)
    legs = polyline((6.4, 12.8), (5.0, 20.4)) + polyline((17.6, 12.8), (19.0, 20.4))
    feet = polyline((3.4, 20.4), (6.6, 20.4)) + polyline((17.4, 20.4), (20.6, 20.4))
    lamp = circle(12, 4.4, 1.5)
    stripes = [polyline((x, 12.8), (x + 2.0, 12.8), (x + 4.6, 7.0), (x + 2.6, 7.0), closed=True)[0] for x in (4.4, 9.9, 15.4)]
    return legs + feet, board + lamp, stripes


GLYPHS = {
    'waves': g_waves,
    'flood': g_flood,
    'lifebuoy': g_lifebuoy,
    'lifebuoyFill': g_lifebuoy_fill,
    'boat': g_boat,
    'landslide': g_landslide,
    'mapPin': g_map_pin,
    'mapPinFill': g_map_pin_fill,
    'roadBlock': g_road_block,  # new glyphs go last so older code points stay put
}

DOCS = {
    'waves': 'Water / flood levels (three waves).',
    'flood': 'Flooding: a house standing in water.',
    'lifebuoy': 'Assistance (outline, for the unselected tab).',
    'lifebuoyFill': 'Assistance (filled bands, for the selected tab).',
    'boat': 'Rescue boat.',
    'landslide': 'Landslide: a slope breaking off into rocks.',
    'mapPin': 'Map (outline): a pin over the ground, for the closed Map tab.',
    'mapPinFill': 'Map (filled), for the open Map tab.',
    'roadBlock': 'Blocked road: a striped road barricade.',
}


# ---------------------------------------------------------------- build


def to_path(contours):
    p = pathops.Path()
    pen = p.getPen()
    for c in contours:
        for seg in c:
            if seg[0] == 'M':
                pen.moveTo(seg[1:])
            elif seg[0] == 'L':
                pen.lineTo(seg[1:])
            elif seg[0] == 'C':
                pen.curveTo(seg[1:3], seg[3:5], seg[5:7])
            else:
                pen.closePath()
        if c[-1][0] != 'Z':
            pen.endPath()
    return p


def outline(name):
    # A glyph returns (stroked, filled) or (stroked, filled, holes); holes
    # are cut out of everything else at the end.
    stroked, filled, *rest = GLYPHS[name]()
    holes = rest[0] if rest else []
    result = pathops.Path()
    for shape in stroked:
        p = to_path([shape])
        p.stroke(STROKE, pathops.LineCap.ROUND_CAP, pathops.LineJoin.ROUND_JOIN, 4)
        p.convertConicsToQuads()  # round caps come out as conics; fonts can't hold those
        result = pathops.op(result, p, pathops.PathOp.UNION)
    for shape in filled:
        result = pathops.op(result, to_path([shape]), pathops.PathOp.UNION)
    for shape in holes:
        result = pathops.op(result, to_path([shape]), pathops.PathOp.DIFFERENCE)
    return result


def build():
    names = list(GLYPHS)
    fb = FontBuilder(UPM, isTTF=True)
    fb.setupGlyphOrder(['.notdef'] + names)
    fb.setupCharacterMap({0xE000 + i: n for i, n in enumerate(names)})
    s = UPM / 24
    # Grid y 12 lands where CupertinoIcons' glyph centers sit (9 of 24
    # units above the baseline), so y_font = (21 - y) * s.
    glyphs = {'.notdef': TTGlyphPen(None).glyph()}
    for n in names:
        tt = TTGlyphPen(None)
        outline(n).draw(TransformPen(Cu2QuPen(tt, max_err=0.5, reverse_direction=True), (s, 0, 0, -s, 0, 21 * s)))
        glyphs[n] = tt.glyph()
    fb.setupGlyf(glyphs)
    glyf = fb.font['glyf']
    for n in glyphs:
        glyf[n].recalcBounds(glyf)
    # Every glyph is a full 24-unit square, so Icon() centers it like Cupertino's.
    fb.setupHorizontalMetrics({n: (UPM, getattr(glyf[n], 'xMin', 0)) for n in glyphs})
    fb.setupHorizontalHeader(ascent=ASCENT, descent=-DESCENT)
    fb.setupNameTable({'familyName': 'AgosIcons', 'styleName': 'Regular'})
    fb.setupOS2(sTypoAscender=ASCENT, sTypoDescender=-DESCENT, usWinAscent=ASCENT, usWinDescent=DESCENT)
    fb.setupPost()
    fb.save(FONT_OUT)

    lines = [
        '// GENERATED by tools/make_icons.py. Edit that script and rerun it;',
        '// never edit this file by hand.',
        '',
        "import 'package:flutter/widgets.dart';",
        '',
        "/// AgosAlert's own icons, for the flood-specific things CupertinoIcons",
        '/// has no icon for. Same style and metrics as CupertinoIcons.',
        'abstract final class AgosIcons {',
        "  static const _font = 'AgosIcons';",
    ]
    for i, n in enumerate(names):
        lines += ['', f'  /// {DOCS[n]}', f'  static const IconData {n} = IconData(0x{0xE000 + i:x}, fontFamily: _font);']
    lines.append('}')
    with open(DART_OUT, 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(lines) + '\n')
    print('wrote', FONT_OUT, 'and', DART_OUT)


def preview(out, cupertino_ttf, icons_dart):
    """Our glyphs next to real CupertinoIcons, to check weight and size."""
    import re

    from PIL import Image, ImageDraw, ImageFont

    cps = dict(re.findall(r'static const IconData (\w+) = IconData\(\s*(0x[0-9a-f]+)', open(icons_dart, encoding='utf-8').read()))
    refs = ['house', 'map', 'bell', 'drop', 'cloud_rain', 'person_3_fill', 'wind', 'hand_thumbsup']
    size, pad = 96, 24
    cols = max(len(GLYPHS), len(refs))
    img = Image.new('RGB', (pad + cols * (size + pad), 2 * (size + pad) + pad), 'white')
    d = ImageDraw.Draw(img)
    ours = ImageFont.truetype(FONT_OUT, size)
    theirs = ImageFont.truetype(cupertino_ttf, size)
    for row, (font, chars) in enumerate([(ours, [chr(0xE000 + i) for i in range(len(GLYPHS))]), (theirs, [chr(int(cps[r], 16)) for r in refs])]):
        for i, ch in enumerate(chars):
            x, y = pad + i * (size + pad), pad + row * (size + pad)
            d.rectangle([x, y, x + size, y + size], outline=(225, 225, 230))
            w = d.textlength(ch, font=font)
            d.text((x + (size - w) / 2, y), ch, font=font, fill='black')
    img.save(out)
    print('preview', out)


if __name__ == '__main__':
    build()
    if '--preview' in sys.argv:
        out = sys.argv[sys.argv.index('--preview') + 1]
        import glob

        pub = sorted(glob.glob(os.path.join(os.path.expanduser('~'), 'AppData', 'Local', 'Pub', 'Cache', 'hosted', 'pub.dev', 'cupertino_icons-*', 'assets', 'CupertinoIcons.ttf')))[-1]
        flutter_icons = os.path.join(os.path.dirname(os.path.dirname(os.path.realpath(os.popen('where flutter').read().split('\n')[0]))), 'packages', 'flutter', 'lib', 'src', 'cupertino', 'icons.dart')
        preview(out, pub, flutter_icons)
