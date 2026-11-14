"""Tugak in 3D: the dark green toad in a black mafia fedora (Nov 13 2026 concept).

Builds every part from code and exports web/tugak/tugak.glb for three.js.
Edit this script and rerun, never the .glb.

Run (Blender 5.2, headless):
  E:/Blender/blender-5.2.4-windows-x64/blender.exe -b --factory-startup -noaudio -P tools/tugak3d.py -- [--preview DIR] [--poses]

--preview DIR also renders front / 3-4 / side / low shots into DIR to check the model.
--poses also renders the landing page's poses (umbrella, phone, handset, pin, shrug, tip)
  and the props alone into landing/img/tugak/*.webp (transparent, cropped to the figure);
  the ones the app uses (APP_POSES) are also copied to assets/images/tugak/.

The parts are separate objects so the page can move them:
  Body, ArmL, ArmR, EyeL/EyeR (+ PupilL/R as children: turn the eye to look), LidL/LidR
  (rotate x to blink), Mouth (the line), MouthOpen (scale z 0..1 to talk), Nostrils, Hat.
Blender's front is -Y; the glTF export turns that into +Z (facing a three.js camera).
"""

import bpy, bmesh, math, os, random, sys
from mathutils import Euler, Matrix, Quaternion, Vector
from mathutils.bvhtree import BVHTree

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'web', 'tugak', 'tugak.glb')
ARGS = sys.argv[sys.argv.index('--') + 1 :] if '--' in sys.argv else []
PREVIEW = ARGS[ARGS.index('--preview') + 1] if '--preview' in ARGS else None
POSES = '--poses' in ARGS
ONLY = ARGS[ARGS.index('--only') + 1].split(',') if '--only' in ARGS else None  # --only umbrella,phone: render just these poses

# Colors from the approved 2D concept (sRGB hex).
COL = {
    'skin': '#3d5a34', 'belly': '#a3a874', 'wart': '#2a4024', 'lidEdge': '#1d2e1a',
    'eye': '#e0a630', 'eyeLit': '#ffd36a', 'eyeDark': '#7a4a0e', 'pupil': '#0b0b0b',
    'hat': '#151515', 'band': '#4a4a4d', 'mouth': '#16210f', 'inside': '#4a1a1c', 'tongue': '#a8484d',
}


def lin(h):
    """sRGB hex -> linear RGB (what Blender and glTF store)."""
    c = [int(h[i : i + 2], 16) / 255 for i in (1, 3, 5)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def mix(a, b, t):
    return tuple(x + (y - x) * t for x, y in zip(a, b))


def smooth(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def link(obj):
    bpy.context.scene.collection.objects.link(obj)
    return obj


def mesh_obj(name, bm):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    return link(bpy.data.objects.new(name, me))


def bake(obj):
    """Apply modifiers by re-reading the evaluated mesh."""
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(obj.evaluated_get(dg))
    obj.modifiers.clear()
    obj.data = me
    for p in me.polygons:
        p.use_smooth = True


def paint(obj, fn):
    """Per-vertex color: fn(local position, normal) -> linear rgb."""
    me = obj.data
    attr = me.color_attributes.new('Col', 'FLOAT_COLOR', 'POINT')
    for v in me.vertices:
        attr.data[v.index].color = (*fn(v.co, v.normal), 1.0)


for o in list(bpy.data.objects):
    bpy.data.objects.remove(o)

# ---------------------------------------------------------------- materials


def material(name, color=None, rough=0.5, coat=0.0, vcol=False, sheen=0.0):
    m = bpy.data.materials.new(name)
    try:
        m.use_nodes = True
    except Exception:
        pass
    nodes, links = m.node_tree.nodes, m.node_tree.links
    bsdf = nodes.get('Principled BSDF')
    if vcol:
        n = nodes.new('ShaderNodeVertexColor')
        n.layer_name = 'Col'
        links.new(n.outputs['Color'], bsdf.inputs['Base Color'])
    else:
        bsdf.inputs['Base Color'].default_value = (*lin(color), 1)
    bsdf.inputs['Roughness'].default_value = rough
    bsdf.inputs['Coat Weight'].default_value = coat
    bsdf.inputs['Sheen Weight'].default_value = sheen
    return m


SKIN = material('Skin', rough=0.62, coat=0.05, vcol=True)  # moist toad skin: a soft gloss
EYE = material('Eye', rough=0.12, coat=1.0, vcol=True)  # wet and glassy
PUPIL = material('Pupil', COL['pupil'], rough=0.1, coat=1.0)
FELT = material('Felt', COL['hat'], rough=0.62)
BAND = material('Band', COL['band'], rough=0.45)
MOUTH = material('MouthLine', COL['mouth'], rough=0.6)
INSIDE = material('Inside', rough=0.4, vcol=True)


# ---------------------------------------------------------------- soft body (metaballs)

K = 1 / 0.574  # a metaball's surface sits at ~0.574 x radius (measured, threshold 0.6)


def meta(name, blobs, res):
    """Blend ellipsoids into one smooth skin. blob = (center, (rx, ry, rz)) in surface units."""
    mb = bpy.data.metaballs.new(name)
    mb.resolution = mb.render_resolution = res
    for co, (rx, ry, rz) in blobs:
        e = mb.elements.new(type='ELLIPSOID')
        e.co, e.radius = co, K
        e.size_x, e.size_y, e.size_z = rx, ry, rz
    tmp = link(bpy.data.objects.new(name + '_mb', mb))
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(tmp.evaluated_get(dg))
    bpy.data.objects.remove(tmp)
    obj = link(bpy.data.objects.new(name, me))
    for p in me.polygons:
        p.use_smooth = True
    return obj


def mirror(blobs):
    out = []
    for (x, y, z), size in blobs:
        out.append(((x, y, z), size))
        if abs(x) > 1e-6:
            out.append(((-x, y, z), size))
    return out


EYE_R = 0.3

body = meta(
    'Body',
    mirror(
        [
            ((0, 0.1, 1.0), (1.18, 1.0, 1.02)),  # body
            ((0, -0.5, 0.95), (0.85, 0.5, 0.82)),  # belly
            ((0, -0.25, 2.2), (1.38, 1.05, 0.46)),  # broad flat head
            # skull: a short column of flat blobs that fills the hat's crown, so the hat sits on the head
            ((0, 0.1, 2.62), (0.64, 0.64, 0.22)),
            ((0, 0.16, 2.84), (0.75, 0.6, 0.2)),
            ((0, 0.08, 3.0), (0.46, 0.4, 0.18)),
            ((0, -0.85, 2.12), (0.8, 0.42, 0.3)),  # snout
            ((0.72, -0.42, 2.28), (0.3, 0.3, 0.3)),  # eye bump (the socket)
            ((0.95, -0.42, 2.66), (0.14, 0.14, 0.1)),  # brow ridge, outer (higher)
            ((0.52, -0.6, 2.58), (0.14, 0.14, 0.1)),  # brow ridge, inner (lower = the stare)
            ((1.18, 0.05, 2.05), (0.26, 0.42, 0.3)),  # gland behind the eye
            ((1.0, 0.25, 0.48), (0.55, 0.75, 0.45)),  # thigh
            ((1.15, -0.35, 0.12), (0.42, 0.6, 0.12)),  # foot
            ((0.88, -0.98, 0.08), (0.11, 0.16, 0.08)),  # toes
            ((1.18, -1.02, 0.08), (0.11, 0.16, 0.08)),
            ((1.48, -0.95, 0.08), (0.11, 0.16, 0.08)),
        ]
    ),
    res=0.04,
)
dec = body.modifiers.new('decimate', 'DECIMATE')
dec.ratio = 0.3
bake(body)

# Belly, warts, a darker back: painted as vertex colors.
random.seed(7)
spots = []
for v in random.sample(list(body.data.vertices), 900):
    if v.normal.y > -0.2 and v.co.z > 0.4 and len(spots) < 46:
        spots.append((v.co.copy(), random.uniform(0.045, 0.09)))


def skin_color(p, n):
    c = lin(COL['skin'])
    belly = smooth(-0.3, -0.7, n.y) * smooth(0.15, 0.4, p.z) * smooth(1.85, 1.5, p.z) * smooth(0.95, 0.55, abs(p.x))
    c = mix(c, lin(COL['belly']), belly)
    for s, r in spots:
        d = (p - s).length
        if d < r:
            c = mix(c, lin(COL['wart']), 0.75 * smooth(r, r * 0.4, d))
    return mix(c, lin(COL['lidEdge']), 0.25 * smooth(0.2, 0.9, n.z) * smooth(1.5, 2.6, p.z))  # darker on top


paint(body, skin_color)
body.data.materials.append(SKIN)
bvh = BVHTree.FromObject(body, bpy.context.evaluated_depsgraph_get())


def arm(name, s, fingers=True, bow=0.06):
    sh = Vector((s * 0.98, -0.55, 1.45))  # shoulder: the pivot
    wr = Vector((s * 1.0, -0.98, 0.22))
    blobs = []
    for i in range(13):
        t = i / 12
        p = sh.lerp(wr, t) + Vector((s * bow * math.sin(t * math.pi), 0, 0))  # elbow bow, outward
        r = 0.25 - 0.06 * t
        blobs.append((tuple(p), (r, r, r)))
    if not fingers:  # the landing poses that hold something add their own small fist (fist() below)
        blobs.append(((s * 1.0, -1.05, 0.12), (0.16, 0.16, 0.12)))
    else:
        blobs.append(((s * 1.0, -1.05, 0.09), (0.2, 0.2, 0.08)))  # palm
        for dx in (-0.17, 0.0, 0.17):  # three fingers spread forward
            blobs.append(((s * 1.0 + dx, -1.3 + abs(dx) * 0.5, 0.07), (0.085, 0.13, 0.07)))
    o = meta(name, blobs, res=0.035)
    o.modifiers.new('decimate', 'DECIMATE').ratio = 0.35
    bake(o)
    o.data.transform(Matrix.Translation(-sh))
    o.location = sh
    paint(o, lambda p, n: lin(COL['skin']))
    o.data.materials.append(SKIN)
    return o


arms = [arm('ArmR', 1), arm('ArmL', -1)]


# ---------------------------------------------------------------- eyes and lids


def sphere_bm(r, u=48, v=32):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=r)
    return bm


def eye_parts(s):
    side = 'R' if s > 0 else 'L'
    d = Vector((s * 0.35, -0.75, 0.55)).normalized()  # out of the socket: forward, up, a bit outward
    hit = bvh.ray_cast(Vector((s * 0.72, -0.42, 2.28)) + d * 3, -d)[0]
    c = hit - d * (EYE_R * 0.2)
    turn = Euler((0, 0, s * math.radians(-12)))  # each eye looks a little outward

    ball = mesh_obj('Eye' + side, sphere_bm(EYE_R, 40, 28))
    paint(
        ball,
        lambda p, n: mix(
            lin(COL['eyeDark']),
            mix(lin(COL['eye']), lin(COL['eyeLit']), smooth(0.75, 0.98, -n.y) * 0.5),
            smooth(-0.1, 0.6, -n.y),
        ),
    )
    ball.data.materials.append(EYE)
    ball.location, ball.rotation_euler = c, turn

    # Pupil: a horizontal lozenge lying exactly on the eyeball's surface.
    bm = bmesh.new()
    rings, around, R = 6, 32, EYE_R + 0.002
    center = bm.verts.new((0, -R, 0))
    grid = []
    for i in range(1, rings + 1):
        row = []
        for j in range(around):
            a = 2 * math.pi * j / around
            dx, dz = math.cos(a), math.sin(a)
            k = 1 / (abs(dx) / 0.17 + abs(dz) / 0.072)  # diamond, 0.17 wide x 0.072 tall
            x, z = dx * k * i / rings, dz * k * i / rings
            row.append(bm.verts.new((x, -math.sqrt(R * R - x * x - z * z), z)))
        grid.append(row)
    for j in range(around):
        bm.faces.new((center, grid[0][(j + 1) % around], grid[0][j]))
    for i in range(rings - 1):
        for j in range(around):
            a, b = grid[i][j], grid[i][(j + 1) % around]
            bm.faces.new((a, b, grid[i + 1][(j + 1) % around], grid[i + 1][j]))
    pupil = mesh_obj('Pupil' + side, bm)
    pupil.data.materials.append(PUPIL)
    pupil.parent = ball

    # Upper lid: the top half of a slightly bigger shell. Rotate x (+) to close it.
    bm = sphere_bm(EYE_R + 0.025, 40, 28)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -0.002], context='VERTS')
    lid = mesh_obj('Lid' + side, bm)
    lid.modifiers.new('solid', 'SOLIDIFY').thickness = 0.02
    bake(lid)
    lid.data.transform(Euler((0, s * -0.22, 0)).to_matrix().to_4x4())  # slants down toward the nose
    lid.data.transform(turn.to_matrix().to_4x4())
    paint(lid, lambda p, n: mix(lin(COL['skin']), lin(COL['lidEdge']), smooth(0.08, -0.02, (p - Vector((0, 0, 0))).z + 0.0)))
    lid.data.materials.append(SKIN)
    lid.location = c
    lid.rotation_euler = (-0.32, 0, 0)  # resting: heavy, about half shut (+x closes)
    return [ball, pupil, lid]


eyes = eye_parts(1) + eye_parts(-1)


# ---------------------------------------------------------------- mouth and nostrils


def on_skin(x, z, out=0.006):
    hit = bvh.ray_cast(Vector((x, -6, z)), Vector((0, 1, 0)))
    return hit[0] + hit[1] * out if hit[0] else None


def mouth():
    cu = bpy.data.curves.new('Mouth', 'CURVE')
    cu.dimensions, cu.bevel_depth, cu.bevel_resolution = '3D', 0.026, 3
    sp = cu.splines.new('POLY')
    pts = [p for p in (on_skin(t * 1.12, 1.97 - 0.13 * t * t) for t in [i / 30 - 1 for i in range(61)]) if p]
    sp.points.add(len(pts) - 1)
    for pt, p in zip(sp.points, pts):
        pt.co = (*p, 1)
    tmp = link(bpy.data.objects.new('Mouth_c', cu))
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(tmp.evaluated_get(dg))
    bpy.data.objects.remove(tmp)
    line = link(bpy.data.objects.new('Mouth', me))
    me.materials.append(MOUTH)
    for p in me.polygons:
        p.use_smooth = True

    # The open mouth: the bottom half of a flat ellipsoid hanging from the line.
    # Scale z from ~0 (shut) to 1 (talking).
    top = on_skin(0, 1.97)
    bm = sphere_bm(1.0, 48, 24)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z > 0.001], context='VERTS')
    bmesh.ops.scale(bm, vec=(0.7, 0.36, 0.3), verts=bm.verts)
    inside = mesh_obj('MouthOpen', bm)
    paint(inside, lambda p, n: mix(lin(COL['inside']), lin(COL['tongue']), smooth(0.15, 0.28, -p.z) * smooth(0.5, 0.1, abs(p.x)) * 0.8))
    inside.data.materials.append(INSIDE)
    inside.location = top + Vector((0, 0.3, 0))
    inside.scale = (1, 1, 0.02)
    return [line, inside]


def nostrils():
    bm = bmesh.new()
    for s in (1, -1):
        p = on_skin(s * 0.15, 2.25, out=-0.012)
        part = bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=1)
        bmesh.ops.scale(bm, vec=(0.04, 0.03, 0.026), verts=part['verts'])
        bmesh.ops.translate(bm, vec=p, verts=part['verts'])
    o = mesh_obj('Nostrils', bm)
    o.data.materials.append(MOUTH)
    return o


face = mouth() + [nostrils()]


# ---------------------------------------------------------------- the fedora

CROWN = dict(rx=0.6, ry=0.52, h=0.62, top=0.8)  # top = top ring size vs the base
BRIM = dict(rx=1.12, ry=1.0)
BAND_FIT = dict(grow=1.05, below=0.05)  # the band hugs the head and reaches a little below the crown
AROUND = 56


def pinch(u, t):
    """The two front pinches of a fedora crown."""
    t = max(t, 0)
    return sum(0.22 * t**1.5 * math.exp(-(((u - u0 + math.pi) % (2 * math.pi) - math.pi) / 0.32) ** 2) for u0 in (math.radians(-58), math.radians(-122)))


def brim_z(x, y):
    """Brim height: snapped down at the front, up at the back and the sides."""
    f = smooth(0, 1, math.hypot(x / BRIM['rx'], y / BRIM['ry']))
    return f * f * (-0.26 * max(0, -y / BRIM['ry']) ** 1.5 + 0.12 * max(0, y / BRIM['ry']) + 0.03 * (x / BRIM['rx']) ** 2)


def hat():
    bm = bmesh.new()
    rx, ry, h = CROWN['rx'], CROWN['ry'], CROWN['h']

    def ring(scale, z, t, zfn=None, grow=1.0):
        row = []
        for j in range(AROUND):
            u = 2 * math.pi * j / AROUND
            k = scale * (1 - pinch(u, t)) * grow
            x, y = math.cos(u) * rx * k, math.sin(u) * ry * k
            row.append(bm.verts.new((x, y, z if zfn is None else zfn(x, y))))
        return row

    def bridge(a, b, mat):
        for j in range(AROUND):
            f = bm.faces.new((a[j], a[(j + 1) % AROUND], b[(j + 1) % AROUND], b[j]))
            f.material_index = mat

    # crown walls, then the creased top
    rows = [ring(1 + (CROWN['top'] - 1) * i / 14, h * i / 14, i / 14) for i in range(15)]
    for i in range(1, 9):
        s = i / 9
        rows.append(
            ring(
                CROWN['top'] * math.cos(s * math.pi / 2),
                0,
                1,
                zfn=lambda x, y, s=s: h + 0.08 * math.sin(s * math.pi / 2) - 0.2 * math.exp(-((x / 0.17) ** 2)) * smooth(0, 0.7, s),
            )
        )
    for a, b in zip(rows, rows[1:]):
        bridge(a, b, 0)
    tip = bm.verts.new((0, 0, h + 0.08 - 0.2))
    for j in range(AROUND):
        bm.faces.new((rows[-1][j], rows[-1][(j + 1) % AROUND], tip)).material_index = 0

    # band around the base of the crown
    band = [ring(1 + (CROWN['top'] - 1) * t, h * t, t, grow=BAND_FIT['grow']) for t in (-BAND_FIT['below'] / h, 0.1, 0.2)]
    for a, b in zip(band, band[1:]):
        bridge(a, b, 1)

    # brim: snapped down at the front, up at the back and the sides
    brim = []
    for i in range(9):
        t = i / 8
        row = []
        for j in range(AROUND):
            u = 2 * math.pi * j / AROUND
            k = 0.97 * (1 - pinch(u, 0))
            x = math.cos(u) * (rx * k + (BRIM['rx'] - rx * k) * t)
            y = math.sin(u) * (ry * k + (BRIM['ry'] - ry * k) * t)
            row.append(bm.verts.new((x, y, brim_z(x, y))))
        brim.append(row)
    for a, b in zip(brim, brim[1:]):
        bridge(a, b, 0)

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    o = mesh_obj('Hat', bm)
    o.data.materials.append(FELT)
    o.data.materials.append(BAND)
    sol = o.modifiers.new('solid', 'SOLIDIFY')
    sol.thickness, sol.offset, sol.use_even_offset = 0.035, 0, True
    bake(o)
    return o


hat_obj = hat()
hat_obj.rotation_euler = (math.radians(5), math.radians(-5), 0)  # brim low over the eyes, cocked to one side
hat_obj.location = (0, 0.06, 0)


SINK = -0.07  # the brim presses this far into the lids' tops: its weight rests on them


def fit_hat():
    """Rest the brim on the eyes / lids / head. The crown is skipped: the skull goes up inside it."""
    dg = bpy.context.evaluated_depsgraph_get()
    under = []  # in world space
    names = []
    for o in [body] + [e for e in eyes if not e.name.startswith('Pupil')]:
        me = o.evaluated_get(dg).to_mesh()
        mw = o.matrix_world
        names.append(o.name)
        under.append(BVHTree.FromPolygons([mw @ v.co for v in me.vertices], [p.vertices[:] for p in me.polygons]))
        o.evaluated_get(dg).to_mesh_clear()
    mw = hat_obj.matrix_world
    need = -9.0
    for v in hat_obj.data.vertices:
        if math.hypot(v.co.x / CROWN['rx'], v.co.y / CROWN['ry']) < 1.06:
            continue  # crown + band
        w = mw @ v.co
        best = None
        for t, nm in zip(under, names):
            hit = t.ray_cast(Vector((w.x, w.y, 9)), Vector((0, 0, -1)))
            if hit[0] and (best is None or hit[0].z > best[0]):
                best = (hit[0].z, nm)
        if best is not None and best[0] - w.z + SINK > need:
            need, why = best[0] - w.z + SINK, (best[1], tuple(round(c, 2) for c in w))
    hat_obj.location.z += need
    print(f'hat lifted to z={hat_obj.location.z:.3f}, held up by {why}')

    # Check: the skull must reach up into the crown (no gap), but not poke out through its walls.
    bpy.context.view_layer.update()
    inv = hat_obj.matrix_world.inverted()
    top = under[0].ray_cast(Vector((0, 0.06, 9)), Vector((0, 0, -1)))[0].z
    out, worst = 0, 0.0
    for v in body.data.vertices:
        p = inv @ v.co  # in the hat's own space
        if 0.02 < p.z < CROWN['h']:  # the bottom 0.02 is inside the brim's thickness
            t = p.z / CROWN['h']
            scale = (1 + (CROWN['top'] - 1) * t) * (BAND_FIT['grow'] if t < 0.2 else 1)  # the band is wider, bottom 20%
            if math.hypot(p.x / (CROWN['rx'] * scale), p.y / (CROWN['ry'] * scale)) > 1 - pinch(math.atan2(p.y, p.x), t):
                out += 1
                worst = max(worst, p.z)
        # through the top of the brim, outside the band
        elif math.hypot(p.x / CROWN['rx'], p.y / CROWN['ry']) > BAND_FIT['grow'] and math.hypot(p.x / BRIM['rx'], p.y / BRIM['ry']) < 1:
            if p.z > brim_z(p.x, p.y) + 0.017:  # above the brim's top face (it's 0.035 thick)
                out += 1
                worst = max(worst, p.z)
    # gap under the crown's rim at the sides and back (at the front the snapped-down brim hides it)
    rim_gap = -9.0
    for j in range(AROUND):
        u = 2 * math.pi * j / AROUND
        if math.sin(u) < -0.3:
            continue
        w = hat_obj.matrix_world @ Vector((math.cos(u) * CROWN['rx'] * 0.97, math.sin(u) * CROWN['ry'] * 0.97, 0))
        hit = under[0].ray_cast(Vector((w.x, w.y, 9)), Vector((0, 0, -1)))[0]
        gap = w.z - BAND_FIT['below'] - (hit.z if hit else -9)  # measured from the band's bottom edge
        if gap > rim_gap:
            rim_gap, gap_at = gap, (round(w.x, 2), round(w.y, 2))
    print(f'skull top {top:.3f} vs hat base {hat_obj.location.z:.3f} (want +0.1..0.4), through the crown: {out} (highest {worst:.2f} above the base), rim gap {rim_gap:.3f} at {gap_at}')
    assert rim_gap < 0.01, 'gap under the crown rim: widen the skull'
    assert top > hat_obj.location.z + 0.05, 'hat floats: raise the skull'
    assert out == 0, 'skull pokes through the crown: narrow the skull'


bpy.context.view_layer.update()
fit_hat()


# ---------------------------------------------------------------- pivots
# The page moves parts by their PIVOT node (an empty), never the mesh node: the
# meshopt step below re-scales/offsets mesh nodes to pack the vertices, which
# would move their rotation point. Pivot names are the part names (EyeL, LidL,
# Hat...); the meshes inside are "<name>_mesh".


def pivot(obj, children=()):
    name = obj.name
    obj.name = name + '_mesh'
    e = link(bpy.data.objects.new(name, None))
    e.matrix_world = obj.matrix_world.copy()
    for o in (obj, *children):
        mw = o.matrix_world.copy()
        o.parent = e
        o.matrix_world = mw
    return e


bpy.context.view_layer.update()
for o in list(bpy.data.objects):
    if o.name.startswith('Pupil'):
        mw = o.matrix_world.copy()  # parent = None alone drops the eye's transform: the pupils fell to the origin
        o.parent = None  # re-parented to its eye's pivot below
        o.matrix_world = mw
bpy.context.view_layer.update()
pupils = {o.name[-1]: o for o in bpy.data.objects if o.name.startswith('Pupil')}
for o in list(bpy.data.objects):
    if o.type != 'MESH':
        continue
    if o.name in ('EyeL', 'EyeR'):
        pivot(o, [pupils[o.name[-1]]])
    elif o.name in ('Body', 'ArmL', 'ArmR', 'LidL', 'LidR', 'Hat', 'MouthOpen'):
        pivot(o)
bpy.context.view_layer.update()


# ---------------------------------------------------------------- export

os.makedirs(os.path.dirname(OUT), exist_ok=True)
RAW = OUT.replace('.glb', '.raw.glb')
opts = dict(filepath=RAW, export_format='GLB', export_yup=True, export_apply=True)
try:
    bpy.ops.export_scene.gltf(**opts, export_vertex_color='ACTIVE')
except TypeError:
    bpy.ops.export_scene.gltf(**opts)
tris = sum(len(p.vertices) - 2 for o in bpy.data.objects if o.type == 'MESH' for p in o.data.polygons)
print({o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in bpy.data.objects if o.type == 'MESH'})
# Pack it: quantized + meshopt-compressed (~4x smaller; three.js decodes it with MeshoptDecoder).
import subprocess

subprocess.run(f'npx -y @gltf-transform/cli@4.1.1 meshopt "{RAW}" "{OUT}"', shell=True, check=True)
os.remove(RAW)
print(f'wrote {OUT} ({os.path.getsize(OUT) // 1024} KB, {tris} triangles)')


# ---------------------------------------------------------------- renders: the app's still picture (+ previews)

sc = bpy.context.scene
for eng in ('BLENDER_EEVEE', 'BLENDER_EEVEE_NEXT'):
    try:
        sc.render.engine = eng
        break
    except TypeError:
        pass
sc.world = bpy.data.worlds.new('w')
try:
    sc.world.use_nodes = True
except Exception:
    pass
bg = sc.world.node_tree.nodes.get('Background')
if bg:
    bg.inputs['Color'].default_value = (*lin('#2a2c33'), 1)
    bg.inputs['Strength'].default_value = 0.6
try:
    sc.view_settings.view_transform = 'AgX'
except TypeError:
    pass


def light(name, loc, power, size):
    ld = bpy.data.lights.new(name, 'AREA')
    ld.energy, ld.size = power, size
    o = link(bpy.data.objects.new(name, ld))
    o.location = loc
    o.rotation_euler = (Vector((0, 0, 1.6)) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()


light('key', (-4.5, -5.5, 6.5), 1100, 4)  # top left, like the app's glass edges
light('fill', (5, -4, 2), 160, 5)
light('rim', (2.5, 5, 5), 900, 3)

cam = link(bpy.data.objects.new('cam', bpy.data.cameras.new('cam')))
cam.data.lens = 60
sc.camera = cam


def shoot(path, loc, look, w, h, transparent):
    sc.render.resolution_x, sc.render.resolution_y = w, h
    sc.render.film_transparent = transparent
    cam.location = loc
    cam.rotation_euler = (Vector(look) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


# Square portrait on a transparent background: TugakImage (empty states, I'm safe,
# phone builds and tests, where there's no 3D scene).
shoot(os.path.join(ROOT, 'assets', 'images', 'tugak.png'), (3.2, -10.5, 1.2), (0, 0, 1.75), 512, 512, True)

if PREVIEW:
    os.makedirs(PREVIEW, exist_ok=True)
    views = {
        'front': ((0, -11.5, 2.0), (0, 0, 1.55)),
        'three_quarter': ((7.5, -8.8, 3.0), (0, 0, 1.55)),
        'side': ((11.5, 0, 2.0), (0, 0, 1.55)),
        'low': ((2.4, -9.5, 0.4), (0, 0, 1.75)),
    }
    for name, (loc, look) in views.items():
        shoot(os.path.join(PREVIEW, name + '.png'), loc, look, 640, 720, False)
    print('previews in', PREVIEW)


# ---------------------------------------------------------------- landing page poses (--poses)
# Tugak explains each section of the landing page (landing/index.html), holding the
# thing it's about. Only the pivots move (arms are stiff: one rotation at the shoulder),
# plus props built here. Each pose is rendered on a transparent background, cropped to
# what's drawn, and saved as WebP in landing/img/tugak/.

if POSES:
    import numpy as np

    POSE_DIR = os.path.join(ROOT, 'landing', 'img', 'tugak')
    os.makedirs(POSE_DIR, exist_ok=True)
    # The app shows these too (TugakImage(pose: ...) in lib/widgets/tugak.dart): empty
    # states, the login screen, Help & FAQ, Be ready.
    APP_POSES = ('phone', 'think', 'handset', 'tip')
    APP_DIR = os.path.join(ROOT, 'assets', 'images', 'tugak')
    os.makedirs(APP_DIR, exist_ok=True)
    P = {n: bpy.data.objects[n] for n in ('ArmL', 'ArmR', 'EyeL', 'EyeR', 'LidL', 'LidR', 'Hat', 'MouthOpen')}
    for o in P.values():
        o.rotation_mode = 'QUATERNION'
    REST = {n: (o.location.copy(), o.rotation_quaternion.copy(), o.scale.copy()) for n, o in P.items()}
    TUGAK = [o for o in bpy.data.objects if o.type in ('MESH', 'EMPTY')]
    ARM_DIR = Vector((0.02, -0.5, -1.36)).normalized()  # shoulder -> palm at rest (see arm())
    ARM_LEN = 1.45

    # A cool blue rim from behind on the left: the landing page is a starry navy night.
    light('rimBlue', (-5, 6, 3.5), 900, 4)
    bpy.data.objects['rimBlue'].data.color = lin('#7fb4ff')

    def reset():
        for n, (l, q, s) in REST.items():
            P[n].location, P[n].rotation_quaternion, P[n].scale = l.copy(), q.copy(), s.copy()

    def aim(side, d, twist=0.0, reach=1.0):
        """Point arm `side` ('R' = +x, 'L' = -x) along d; twist turns the hand around the arm. Returns the palm.
        The arms have no elbow: reach < 1 shortens the arm along its length (its local z) instead,
        which reads as a bent arm without thinning it."""
        o = P['Arm' + side]
        d = Vector(d).normalized()
        v = Vector((ARM_DIR.x, ARM_DIR.y, ARM_DIR.z * reach))
        o.scale = (1, 1, reach)
        o.rotation_quaternion = Quaternion(d, twist) @ v.normalized().rotation_difference(d)
        return o.location + d * ARM_LEN * v.length

    def reach_to(side, at, twist=0.0, stretch=1.0):
        """Aim arm `side` so the palm lands on `at` (shortening it when it's closer than an arm's length;
        `stretch` > 1 lets it grow that much longer to get there)."""
        d = Vector(at) - P['Arm' + side].location
        k = d.length / ARM_LEN
        r = math.sqrt(max(0.05, (k * k - ARM_DIR.x**2 - ARM_DIR.y**2) / ARM_DIR.z**2))
        assert r <= stretch + 0.01, f'arm {side} is {r:.2f}x too short for {tuple(at)}'
        return aim(side, d, twist, min(stretch, r))

    def look(yaw=0.0, pitch=0.0):
        """Eyes: yaw > 0 = toward +x, pitch > 0 = up."""
        for n in ('EyeL', 'EyeR'):
            P[n].rotation_quaternion = REST[n][1] @ Quaternion((0, 0, 1), yaw) @ Quaternion((1, 0, 0), pitch)

    def lids(delta):
        """delta < 0 opens wider, > 0 closes (rest = about half shut)."""
        for n in ('LidL', 'LidR'):
            P[n].rotation_quaternion = REST[n][1] @ Quaternion((1, 0, 0), delta)

    def mouth_open(k):
        P['MouthOpen'].scale.z = k  # 0.02 = shut, 1 = wide (same as scene.js)

    def tube(name, pts, r, mat):
        cu = bpy.data.curves.new(name, 'CURVE')
        cu.dimensions, cu.bevel_depth, cu.bevel_resolution = '3D', r, 4
        cu.use_fill_caps = True
        sp = cu.splines.new('POLY')
        sp.points.add(len(pts) - 1)
        for pt, p in zip(sp.points, pts):
            pt.co = (*p, 1)
        tmp = link(bpy.data.objects.new(name + '_c', cu))
        dg = bpy.context.evaluated_depsgraph_get()
        me = bpy.data.meshes.new_from_object(tmp.evaluated_get(dg))
        bpy.data.objects.remove(tmp)
        o = link(bpy.data.objects.new(name, me))
        me.materials.append(mat)
        for p in me.polygons:
            p.use_smooth = True
        return o

    def group(name, objs):
        e = link(bpy.data.objects.new(name, None))
        for o in objs:
            o.parent = e
        return e

    def place(e, at, x_axis=None, z_axis=None):
        """Move group e to `at`, its local z along z_axis (and local x as close to x_axis as possible)."""
        z = Vector(z_axis or (0, 0, 1)).normalized()
        x = Vector(x_axis or (1, 0, 0))
        x = (x - z * x.dot(z)).normalized()
        m = Matrix((x, z.cross(x), z)).transposed().to_4x4()
        m.translation = at
        e.matrix_world = m

    def mat2(name, hexc, rough, coat=0.0, metal=0.0, emit_img=None):
        m = material(name, hexc, rough=rough, coat=coat)
        bsdf = m.node_tree.nodes.get('Principled BSDF')
        bsdf.inputs['Metallic'].default_value = metal
        if emit_img:
            tex = m.node_tree.nodes.new('ShaderNodeTexImage')
            tex.image = bpy.data.images.load(emit_img)
            m.node_tree.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
            m.node_tree.links.new(tex.outputs['Color'], bsdf.inputs['Emission Color'])
            bsdf.inputs['Emission Strength'].default_value = 0.85
        return m

    BLUE = mat2('Blue', '#0A84FF', 0.3, coat=0.8)  # kBlue, the app's accent
    WHITE = mat2('White', '#F5F5F7', 0.35, coat=0.4)
    BAKELITE = mat2('Bakelite', '#141416', 0.2, coat=1.0)
    STEEL = mat2('Steel', '#2c2e33', 0.3, metal=0.9)
    FRAME = mat2('Frame', '#3a3f4b', 0.28, coat=0.5, metal=0.85)

    # ---- props, each a group with its origin where the hand holds it

    def make_umbrella():
        """Open umbrella in kBlue, 8 ribs. Origin = the grip, shaft up +z."""
        bm = bmesh.new()
        R, H, L, N, RINGS = 2.0, 1.2, 3.1, 96, 16
        apex = bm.verts.new((0, 0, L))
        rows = []
        for i in range(1, RINGS + 1):
            t = i / RINGS
            row = []
            for j in range(N):
                u = 2 * math.pi * j / N
                gap = 1 - abs(math.cos(4 * u))  # 0 on a rib, 1 between two
                r = R * t * (1 - 0.08 * t**3 * gap)  # the scallops between ribs
                row.append(bm.verts.new((math.cos(u) * r, math.sin(u) * r, L - H * t**2.2 + 0.1 * t**3 * gap)))  # a dome, not a disc
            rows.append(row)
        for j in range(N):
            bm.faces.new((apex, rows[0][j], rows[0][(j + 1) % N]))
        for a, b in zip(rows, rows[1:]):
            for j in range(N):
                bm.faces.new((a[j], b[j], b[(j + 1) % N], a[(j + 1) % N]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        can = mesh_obj('Canopy', bm)
        can.data.materials.append(BLUE)
        can.modifiers.new('s', 'SOLIDIFY').thickness = 0.03
        bake(can)
        parts = [can, tube('Shaft', [(0, 0, -0.2), (0, 0, L + 0.22)], 0.04, STEEL)]
        hook = [(0, 0, -0.15), (0, 0, -0.45)] + [(0.2 - 0.2 * math.cos(a), 0, -0.45 - 0.2 * math.sin(a)) for a in [k * math.pi / 12 for k in range(13)]]
        parts.append(tube('Handle', hook, 0.06, BAKELITE))
        return group('Umbrella', parts)

    def rounded_box(name, w, h, d, r, mat):
        """Box w (x) by h (z), d thick (y), corners rounded in the x-z plane."""
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1)
        bmesh.ops.scale(bm, vec=(w, d, h), verts=bm.verts)
        edges = [e for e in bm.edges if abs((e.verts[0].co - e.verts[1].co).normalized().y) > 0.9]
        bmesh.ops.bevel(bm, geom=edges, offset=r, segments=10, profile=0.5, affect='EDGES')
        o = mesh_obj(name, bm)
        o.data.materials.append(mat)
        b = o.modifiers.new('b', 'BEVEL')
        b.width, b.segments, b.limit_method = min(d * 0.4, 0.02), 3, 'ANGLE'
        bake(o)
        return o

    def make_phone(shot):
        """A phone showing an app screenshot. Origin = its bottom edge; screen faces -y."""
        W, H, D = 0.8, 1.6, 0.085
        body = rounded_box('PhoneBody', W, H, D, 0.13, FRAME)
        sw, sh = W - 0.07, H - 0.07
        bm = bmesh.new()
        bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=0.5)
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(90), 3, 'X'))
        bmesh.ops.scale(bm, vec=(sw, 1, sh), verts=bm.verts)
        uv = bm.loops.layers.uv.new()
        for f in bm.faces:
            for lp in f.loops:
                lp[uv].uv = (lp.vert.co.x / sw + 0.5, lp.vert.co.z / sh + 0.5)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        screen = mesh_obj('Screen', bm)
        screen.data.materials.append(mat2('ScreenImg', '#000000', 0.15, coat=1.0, emit_img=shot))
        screen.location = (0, -D / 2 - 0.002, 0)
        # round the screen's corners: cut it with a rounded box (boolean intersect)
        cutter = rounded_box('Cut', sw, sh, 0.05, 0.1, BAKELITE)
        cutter.location = screen.location
        bo = screen.modifiers.new('round', 'BOOLEAN')
        bo.operation, bo.object, bo.solver = 'INTERSECT', cutter, 'EXACT'
        bake(screen)
        bpy.data.objects.remove(cutter)
        island = mesh_obj('Island', sphere_bm(1, 24, 12))
        island.scale = (0.11, 0.01, 0.03)
        island.location = (0, -D / 2 - 0.006, sh / 2 - 0.07)
        island.data.materials.append(BAKELITE)
        for o in (body, screen, island):
            o.location.z += H / 2
        return group('Phone', [body, screen, island])

    def make_handset():
        """Old phone receiver, black bakelite. Origin = the middle of the grip; cups face -z."""
        bar = [(x, 0, 0.2 * (1 - (x / 0.62) ** 2)) for x in [i / 16 * 1.24 - 0.62 for i in range(17)]]
        parts = [tube('Grip', bar, 0.1, BAKELITE)]
        for s in (-1, 1):
            # flared cups at both ends, tipped in toward the face
            bm = bmesh.new()
            bmesh.ops.create_cone(bm, cap_ends=True, segments=40, radius1=0.27, radius2=0.13, depth=0.2)
            cup = mesh_obj('Cup', bm)
            b = cup.modifiers.new('b', 'BEVEL')
            b.width, b.segments, b.limit_method = 0.04, 4, 'ANGLE'
            bake(cup)
            cup.location = (s * 0.66, 0, -0.04)
            cup.rotation_euler = (0, s * math.radians(28), 0)
            cup.data.materials.append(BAKELITE)
            parts.append(cup)
        return group('Handset', parts)

    def make_cord(a, b, sag=0.6, turns=26, r=0.055):
        """Coiled phone cord from a to b, sagging in the middle."""
        a, b = Vector(a), Vector(b)
        pts = []
        n = turns * 12
        for i in range(n + 1):
            t = i / n
            c = a.lerp(b, t) + Vector((0, 0, -sag * 4 * t * (1 - t)))
            tan = (b - a) + Vector((0, 0, -sag * 4 * (1 - 2 * t)))
            n1 = tan.cross(Vector((0, 1, 0))).normalized()
            n2 = tan.normalized().cross(n1)
            ang = 2 * math.pi * turns * t
            pts.append(tuple(c + (n1 * math.cos(ang) + n2 * math.sin(ang)) * r))
        return tube('Cord', pts, 0.016, BAKELITE)

    def make_pin():
        """Big map pin in kBlue with a white dot. Origin = its point, on the ground."""
        prof = [(0.0, 0.0), (0.06, 0.12), (0.17, 0.5), (0.31, 0.95), (0.46, 1.38), (0.58, 1.8), (0.63, 2.15), (0.6, 2.42), (0.5, 2.66), (0.32, 2.84), (0.0, 2.92)]
        bm = bmesh.new()
        vs = [bm.verts.new((x, 0, z)) for x, z in prof]
        es = [bm.edges.new((p, q)) for p, q in zip(vs, vs[1:])]
        bmesh.ops.spin(bm, geom=vs + es, cent=(0, 0, 0), axis=(0, 0, 1), angle=2 * math.pi, steps=72, use_merge=True)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        body = mesh_obj('PinBody', bm)
        body.data.materials.append(BLUE)
        body.modifiers.new('sub', 'SUBSURF').levels = 2
        bake(body)
        dot = mesh_obj('PinDot', sphere_bm(1, 40, 20))
        dot.scale = (0.25, 0.08, 0.25)
        dot.location = (0, -0.6, 2.2)
        dot.data.materials.append(WHITE)
        return group('Pin', [body, dot])

    # ---- shooting: camera around a look point, then crop to the drawn pixels

    def crop_save(png, out):
        img = bpy.data.images.load(png)
        w, h = img.size
        px = np.empty(w * h * 4, dtype=np.float32)
        img.pixels.foreach_get(px)
        px = px.reshape(h, w, 4)
        ys, xs = np.nonzero(px[:, :, 3] > 0.004)
        pad = 6
        y0, y1 = max(0, ys.min() - pad), min(h, ys.max() + pad + 1)
        x0, x1 = max(0, xs.min() - pad), min(w, xs.max() + pad + 1)
        if x0 == 0 or y0 == 0 or x1 == w or y1 == h:
            print(f'WARNING {os.path.basename(out)}: touches the frame edge, widen the shot')
        crop = np.ascontiguousarray(px[y0:y1, x0:x1])
        o = bpy.data.images.new(os.path.basename(out), x1 - x0, y1 - y0, alpha=True)
        o.pixels.foreach_set(crop.ravel())
        o.filepath_raw = out
        o.file_format = 'WEBP'
        try:
            o.save(quality=86)
        except TypeError:
            o.save()
        bpy.data.images.remove(img)
        bpy.data.images.remove(o)
        os.remove(png)
        print(f'wrote {out} ({x1 - x0}x{y1 - y0})')

    def pose_shot(name, look_at, az=17.0, el=4.0, dist=13.0, lens=55, size=1500):
        if ONLY and name not in ONLY:
            return
        cam.data.lens = lens
        a, e = math.radians(az), math.radians(el)
        loc = Vector(look_at) + Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e))) * dist
        png = os.path.join(POSE_DIR, name + '.png')
        shoot(png, tuple(loc), look_at, size, size, True)
        crop_save(png, os.path.join(POSE_DIR, name + '.webp'))
        if name in APP_POSES:
            import shutil
            shutil.copy(os.path.join(POSE_DIR, name + '.webp'), APP_DIR)

    def drop(*groups):
        for g in groups:
            for c in list(g.children):
                bpy.data.objects.remove(c)
            bpy.data.objects.remove(g)

    def show_tugak(on):
        for o in TUGAK:
            o.hide_render = not on

    shots = os.path.join(ROOT, 'landing', 'img')

    # ---- holding things: a fingerless arm + a small fist built round the prop.
    # Adrian (Nov 14 2026): the flat, spread fingers didn't read as holding anything,
    # and were too big; a toad has short fingers.

    def grip_arm(side, bow=0.06):
        """Give arm `side` its fingerless mesh (`bow`: how far the elbow bends out). Returns the old
        mesh data (put it back after the pose)."""
        o = bpy.data.objects['Arm' + side + '_mesh']
        tmp = arm('ArmGrip', 1 if side == 'R' else -1, fingers=False, bow=bow)
        old, o.data = o.data, tmp.data
        bpy.data.objects.remove(tmp)
        return old

    def skin_blob(name, blobs):
        o = meta(name, [(tuple(c), (r, r, r) if isinstance(r, float) else r) for c, r in blobs], res=0.02)
        paint(o, lambda p, n: lin(COL['skin']))
        o.data.materials.append(SKIN)
        return o

    def fist(c, axis, toward, via, rr, spread=0.12, fr=0.06):
        """Three short fingers curled round a bar through c along `axis`: the palm on the `toward` side
        (the wrist), the fingers going round past `via` so their tips end on the far side, the thumb opposite."""
        a = Vector(axis).normalized()
        n = Vector(toward)
        n = (n - a * n.dot(a)).normalized()
        b = Vector(via)
        b = (b - a * b.dot(a) - n * b.dot(n)).normalized()
        at = lambda th, r: c + (n * math.cos(math.radians(th)) + b * math.sin(math.radians(th))) * r
        blobs = [(at(0, rr + 0.05), 0.15)]  # palm
        for h in (-spread, 0.0, spread):
            for i, th in enumerate((60, 105, 150, 190)):
                blobs.append((at(th, rr) + a * h, fr * (1 - 0.1 * i)))  # tapering to the tip
        blobs += [(at(-80, rr) + a * spread * 0.8, fr), (at(-95, rr) + a * spread * 1.7, fr * 0.85)]  # thumb
        return skin_blob('Fist', blobs)

    # 1. Weather: under a kBlue umbrella, leaning it back over his hat.
    reset()
    old = grip_arm('R')
    d = Vector((0.3, -0.9, 0.2))
    palm = aim('R', d, twist=0.4, reach=0.8)
    shaft = Vector((-0.3, 0.4, 1))
    grip = palm + d.normalized() * 0.17  # the shaft runs just past the palm
    u = make_umbrella()
    place(u, grip - shaft.normalized() * 0.15, x_axis=(1, 0, 0), z_axis=tuple(shaft))
    f = fist(grip, shaft, -d, (1, 0, 0), rr=0.1)
    look(-0.12, 0.05)
    pose_shot('umbrella', (0.3, 0, 2.5), az=18, dist=16)
    drop(u)
    bpy.data.objects.remove(f)
    P['ArmR'].children[0].data = old

    # 2. Reports: holds up a phone showing the flood map, a little proud of it.
    reset()
    old = grip_arm('R')
    palm = aim('R', (0.25, -0.9, 0.12), twist=-0.3)
    ph = make_phone(os.path.join(shots, 'map-dark.webp'))  # the flood map (the Reports feed only has test posts so far)
    # The phone stands in his cupped palm; three short fingers curl up over its front edge.
    D = 0.085
    cup = Vector((0, 0.03, -0.1))  # the palm, in the phone's own space (origin = bottom edge)
    place(ph, (0, 0, 0), x_axis=(math.cos(math.radians(-25)), math.sin(math.radians(-25)), 0), z_axis=(0, 0.12, 1))
    bpy.context.view_layer.update()
    ph.matrix_world.translation = palm - ph.matrix_world.to_3x3() @ cup
    bpy.context.view_layer.update()
    M = ph.matrix_world
    blobs = [(M @ cup, (0.2, 0.15, 0.12))]
    for x in (-0.13, 0.0, 0.13):
        blobs += [(M @ Vector((x, -D / 2 - 0.03, -0.02)), 0.06), (M @ Vector((x, -D / 2 - 0.045, 0.07)), 0.055), (M @ Vector((x, -D / 2 - 0.035, 0.14)), 0.048)]
    blobs.append((M @ Vector((-0.3, D / 2 + 0.05, 0.12)), 0.06))  # thumb, behind
    f = skin_blob('Fist', blobs)
    look(0.22, 0.08)
    pose_shot('phone', (0.4, 0, 1.75), az=-14, dist=13)
    drop(ph)
    bpy.data.objects.remove(f)
    P['ArmR'].children[0].data = old

    # 3. Hotlines: on the line, receiver to the side of his head, cord down to the floor.
    reset()
    ear, mouth_pt = Vector((1.5, -0.4, 2.5)), Vector((1.2, -1.7, 1.85))
    mid = (ear + mouth_pt) / 2
    hand = mid + Vector((0.3, 0.05, 0.05))  # the hand wraps the grip from outside
    reach_to('R', hand, twist=0.9)
    hs = make_handset()
    place(hs, mid + Vector((0.1, 0, 0)), x_axis=tuple(mouth_pt - ear), z_axis=(1, 0.1, 0.1))
    bpy.context.view_layer.update()
    cord = make_cord(hs.matrix_world @ Vector((0.66, 0, -0.12)), (2.3, -1.6, 0.05), sag=0.35)
    look(-0.18, 0.0)
    lids(0.08)
    mouth_open(0.3)
    pose_shot('handset', (0.8, 0, 1.55), az=22, dist=15)  # wide enough for the cord and his far foot
    drop(hs)
    bpy.data.objects.remove(cord)

    # 4. Coverage: one hand on a big map pin standing next to him.
    reset()
    pin = make_pin()
    place(pin, (2.75, -0.55, 0), x_axis=(1, 0.12, 0))
    aim('R', (1.25, -0.2, 0.55), twist=0.0)
    look(0.05, 0.0)
    pose_shot('pin', (1.3, 0, 1.6), az=-8, dist=15)
    drop(pin)

    # 5. FAQ: thinking it over, a fist under his chin (knuckles up, like The Thinker), eyes up
    # and away. (Was a flat open hand at his mouth: read as a wave, Nov 14 2026.)
    reset()
    old = grip_arm('L')
    c = Vector((-0.4, -1.55, 1.86))  # knuckles against his chin, under the mouth's corner
    rr = 0.09
    f = fist(c, (1, 0.2, 0), (0, 0.3, -1), (0, -1, 0), rr=rr, fr=0.07)  # wrist below, fingers curl forward
    reach_to('L', c + Vector((0, 0.3, -1)).normalized() * (rr + 0.05))
    look(0.2, 0.25)
    lids(0.04)
    pose_shot('think', (0, 0, 1.6), az=-16, dist=13)
    bpy.data.objects.remove(f)
    P['ArmL'].children[0].data = old

    # 6. The end: tips his hat, a fist round its brim. The hand goes to the real brim edge
    # (Adrian, Nov 14 2026: the old raised arm stopped at his cheek and never touched the hat,
    # which floated, and the flat spread fingers looked broken). His head is tall: the brim
    # sits ~1.8 from the shoulder and the arm is 1.45, so he tilts the hat down to meet his
    # hand (turned round the hat's own middle, not the pivot on the floor) and the arm
    # stretches a little.
    reset()
    old = grip_arm('R', bow=0.38)  # the elbow out, or the raised arm runs through his cheek
    hat_m = bpy.data.objects['Hat_mesh']
    H = hat_m.matrix_world
    centre = H @ (sum((v.co for v in hat_m.data.vertices), Vector()) / len(hat_m.data.vertices))
    turn = Quaternion((0, 1, 0), 0.2) @ Quaternion((1, 0, 0), -0.06)  # his side down, the front up a touch
    P['Hat'].matrix_world = Matrix.Translation(centre) @ turn.to_matrix().to_4x4() @ Matrix.Translation(-centre) @ P['Hat'].matrix_world
    bpy.context.view_layer.update()
    H = hat_m.matrix_world
    up = (P['Hat'].matrix_world.to_3x3() @ Vector((0, 0, 1))).normalized()
    side = Vector((1, -0.45, 0)).normalized()  # grab the brim on his right, a little toward the front
    edge = max((H @ v.co for v in hat_m.data.vertices), key=lambda p: p.dot(side))
    out = edge - centre
    out = (out - up * out.dot(up)).normalized()  # outward along the brim
    along = up.cross(out).normalized()  # the brim edge's direction there
    c = edge - out * 0.06  # the fist's bar runs just inside the edge
    rr = 0.09
    palm_side = (-up + out * 0.5).normalized()  # palm under the brim, from outside
    f = fist(c, along, palm_side, out, rr=rr, fr=0.07)
    reach_to('R', c + palm_side * (rr + 0.05), stretch=1.2)
    lids(-0.22)
    mouth_open(0.25)
    pose_shot('tip', (0.15, 0, 1.95), az=14, dist=13.5)
    bpy.data.objects.remove(f)
    P['ArmR'].children[0].data = old

    # 7. The hero's still: his rest pose from the front, like landing/tugak.js's camera
    # (three.js fov 30 = a 67 mm lens). Shown until the live 3D Tugak is ready, and if it can't be.
    reset()
    pose_shot('hero', (0, 0, 1.75), az=0, el=2, dist=12.4, lens=67, size=1200)

    # 8. The props alone, floating around the hero.
    reset()
    show_tugak(False)
    u = make_umbrella()
    place(u, (0, 0, 0), x_axis=(1, 0, 0.2), z_axis=(0.35, -0.2, 1))
    pose_shot('prop-umbrella', (0.55, 0, 1.8), az=10, el=8, dist=13, size=900)
    drop(u)
    pin = make_pin()
    place(pin, (0, 0, 0), x_axis=(1, 0.3, 0), z_axis=(0.25, 0, -1))  # upside down, falling like a drop (Adrian, Nov 14 2026)
    pose_shot('prop-pin', (0.3, 0, -1.5), az=0, el=6, dist=12, size=900)
    drop(pin)
    hs = make_handset()
    place(hs, (0, 0, 1), x_axis=(1, 0, 0.5), z_axis=(0, 1, 0.2))
    pose_shot('prop-handset', (0, 0, 1), az=0, el=10, dist=8, size=900)
    drop(hs)
    print('poses in', POSE_DIR)
