"""Draws the AgosAlert logo and writes every logo file the app uses.

The mark ("Current Alert"): an exclamation mark whose dot is a wave, so
the alert is the water. Black (or white) stem, kBlue wave. The wordmark is
the mark + "agosalert." in Inter ExtraBold (turned into outlines here) with
a blue dot. Everything is built from circles and arcs, no hand-drawn curves.

Edit the numbers here and rerun; never edit the PNGs or SVGs by hand:
    python tools/make_logo.py

Writes: brand/*.svg (masters), assets/images/logo_*.png, web favicon and
PWA icons, and the landing page copies. Needs Google Chrome (renders the
SVGs to PNG), Pillow and fontTools.
"""

import math
import pathlib
import subprocess
import tempfile

from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
FONT = ROOT / "assets/fonts/Inter-ExtraBold.ttf"
BLUE = "#0A84FF"  # kBlue in lib/theme.dart
INK = "#000000"
PAPER = "#FFFFFF"
TEXT_LIGHT = "#1D1D1F"  # wordmark text on light pages (as before)


def f(n: float) -> str:
    return f"{n:.2f}".rstrip("0").rstrip(".")


def stem(cx, y1, r1, y2, r2) -> str:
    """The exclamation stem: a circle of radius r1 at the top joined to a
    smaller one (r2) lower down by their exact tangent lines (a taper)."""
    s = (r1 - r2) / (y2 - y1)
    c = math.sqrt(1 - s * s)
    return (
        f"M{f(cx - r1 * c)} {f(y1 + r1 * s)}A{f(r1)} {f(r1)} 0 1 1 {f(cx + r1 * c)} {f(y1 + r1 * s)}"
        f"L{f(cx + r2 * c)} {f(y2 + r2 * s)}A{f(r2)} {f(r2)} 0 0 1 {f(cx - r2 * c)} {f(y2 + r2 * s)}Z"
    )


def wave(cx, cy, a, amp, t) -> str:
    """One wave as a filled shape of even thickness t: a crest arc and a
    trough arc of the same radius meeting at (cx, cy), round ends. a = a
    quarter of the wave's length, amp = how far the crest rises."""
    b = (a * a - amp * amp) / (2 * amp)
    R, h = b + amp, t / 2
    ux, uy = a / R, b / R
    c1, c2 = (cx - a, cy + b), (cx + a, cy - b)

    def p(c, r, sx, sy):
        return f"{f(c[0] + r * sx * ux)} {f(c[1] + r * sy * uy)}"

    return (
        f"M{p(c1, R + h, -1, -1)}A{f(R + h)} {f(R + h)} 0 0 1 {p(c1, R + h, 1, -1)}"
        f"A{f(R - h)} {f(R - h)} 0 0 0 {p(c2, R - h, 1, 1)}"
        f"A{f(h)} {f(h)} 0 0 1 {p(c2, R + h, 1, 1)}"
        f"A{f(R + h)} {f(R + h)} 0 0 1 {p(c2, R + h, -1, 1)}"
        f"A{f(R - h)} {f(R - h)} 0 0 0 {p(c1, R - h, -1, -1)}"
        f"A{f(h)} {f(h)} 0 0 1 {p(c1, R + h, -1, -1)}Z"
    )


def mark_paths(small=False, thin=0.0):
    """(stem path, wave path) on a 256 grid. small = the heavier cut for
    32 px and below. thin = units taken off for white-on-dark (light
    shapes on dark look heavier)."""
    if small:
        return stem(128, 42, 32 - thin, 112, 26 - thin), wave(128, 198, 33, 15, 44 - 2 * thin)
    return stem(128, 42, 26 - thin, 138, 20 - thin), wave(128, 200, 29, 16, 36 - 2 * thin)


def mark_svg(ink=INK, accent=BLUE, small=False, thin=0.0, box="0 0 256 256", extra="") -> str:
    s, w = mark_paths(small, thin)
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{box}"><title>AgosAlert</title>{extra}'
        f'<path fill="{ink}" d="{s}"/><path fill="{accent}" d="{w}"/></svg>'
    )


def tile_svg(bg, ink, small=False, thin=0.0) -> str:
    """App icon: the mark on a rounded square (iOS-like corner, 22.4%)."""
    s, w = mark_paths(small, thin)
    k = 0.8 if small else 0.74  # how much of the tile the 256 mark grid fills
    off = 128 * (1 - k)
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256"><title>AgosAlert</title>'
        f'<rect width="256" height="256" rx="57.3" fill="{bg}"/>'
        f'<g transform="translate({f(off)} {f(off + 4)}) scale({k})">'
        f'<path fill="{ink}" d="{s}"/><path fill="{BLUE}" d="{w}"/></g></svg>'
    )


# ---- Wordmark: "agosalert." as outlines (no live text in the masters) ----

_font = TTFont(FONT)
_glyphs = _font.getGlyphSet()
_cmap = _font.getBestCmap()
_upm = _font["head"].unitsPerEm


def text_path(text, x, baseline, size, tracking=-0.045):
    """Outline of [text] in Inter ExtraBold. Returns (path, end x).
    shortcut: no GPOS kerning (Inter barely kerns these lowercase pairs);
    add uharfbuzz shaping if the wordmark ever changes."""
    scale, out = size / _upm, []
    for ch in text:
        g = _glyphs[_cmap[ord(ch)]]
        pen = SVGPathPen(_glyphs, ntos=f)
        g.draw(TransformPen(pen, (scale, 0, 0, -scale, x, baseline)))
        out.append(pen.getCommands())
        x += g.width * scale + tracking * size
    return "".join(out), x - tracking * size


TEXT_SIZE = 170
MARK_LEFT = 50  # left edge of the wave on the 256 grid (with a little air)


def horizontal_svg(ink, text, thin=0.0) -> str:
    """Mark + wordmark side by side, 256 high, text x-height centred on the mark."""
    s, w = mark_paths(False, thin)
    word, end = text_path("agosalert", 236, 172, TEXT_SIZE)
    dot, end = text_path(".", end - 0.045 * TEXT_SIZE, 172, TEXT_SIZE)
    width = end + 8
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{MARK_LEFT} 0 {f(width - MARK_LEFT)} 256">'
        f"<title>AgosAlert</title>"
        f'<path fill="{ink}" d="{s}"/><path fill="{BLUE}" d="{w}"/>'
        f'<path fill="{text}" d="{word}"/><path fill="{BLUE}" d="{dot}"/></svg>'
    )


def stacked_svg(ink, text) -> str:
    s, w = mark_paths()
    size = 120
    word, end = text_path("agosalert", 0, 0, size)
    dot, end = text_path(".", end - 0.045 * size, 0, size)
    x0 = 128 - end / 2
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{f(x0 - 8)} 0 {f(end + 16)} 400">'
        f"<title>AgosAlert</title>"
        f'<path fill="{ink}" d="{s}"/><path fill="{BLUE}" d="{w}"/>'
        f'<g transform="translate({f(x0)} 352)"><path fill="{text}" d="{word}"/><path fill="{BLUE}" d="{dot}"/></g></svg>'
    )


# ---- Rendering ----


def render(svg: str, out: pathlib.Path, height: int, pad: float = 0) -> Image.Image:
    """Renders [svg] in headless Chrome with a see-through background,
    crops to what was drawn, and saves it [height] px tall (plus [pad] of
    its height as empty margin on every side)."""
    html = (
        "<!doctype html><html><head><meta charset='utf-8'><style>"
        "html,body{margin:0;background:transparent}svg{height:720px;width:auto;display:block}"
        f"</style></head><body>{svg}</body></html>"
    )
    with tempfile.TemporaryDirectory() as tmp:
        src = pathlib.Path(tmp, "logo.html")
        src.write_text(html, encoding="utf-8")
        shot = pathlib.Path(tmp, "shot.png")
        subprocess.run(
            [CHROME, "--headless=new", "--hide-scrollbars", "--default-background-color=00000000",
             "--force-device-scale-factor=1", "--window-size=3000,720", f"--screenshot={shot}", src.as_uri()],
            check=True, capture_output=True,
        )
        im = Image.open(shot).convert("RGBA")
    box = im.getchannel("A").getbbox()
    assert box, f"nothing was drawn for {out.name}"
    im = im.crop(box)
    inner = round(height / (1 + 2 * pad))
    im = im.resize((round(im.width * inner / im.height), inner), Image.LANCZOS)
    if pad:
        canvas = Image.new("RGBA", (im.width + height - inner, height), (0, 0, 0, 0))
        canvas.alpha_composite(im, ((height - inner) // 2, (height - inner) // 2))
        im = canvas
    im.save(out, optimize=True)
    print(f"{out.relative_to(ROOT)}  {im.width}x{im.height}")
    return im


def main() -> None:
    brand = ROOT / "brand"
    brand.mkdir(exist_ok=True)
    masters = {
        "agosalert-mark.svg": mark_svg(),
        "agosalert-mark-reversed.svg": mark_svg(ink=PAPER, thin=1),
        "agosalert-mark-black.svg": mark_svg(accent=INK),
        "agosalert-mark-white.svg": mark_svg(ink=PAPER, accent=PAPER, thin=1),
        "agosalert-mark-small.svg": mark_svg(small=True),
        "agosalert-icon.svg": tile_svg(INK, PAPER, thin=1),
        "agosalert-icon-small.svg": tile_svg(INK, PAPER, small=True, thin=1),
        "agosalert-horizontal.svg": horizontal_svg(INK, TEXT_LIGHT),
        "agosalert-horizontal-reversed.svg": horizontal_svg(PAPER, PAPER, thin=1),
        "agosalert-stacked.svg": stacked_svg(INK, TEXT_LIGHT),
    }
    for name, svg in masters.items():
        (brand / name).write_text(svg + "\n", encoding="utf-8")
        print(f"brand/{name}")

    images = ROOT / "assets/images"
    # Round-icon slot (About screen, landing login popup): the app icon tile.
    # Light pages get the black tile, dark pages a white one so it doesn't vanish.
    render(tile_svg(INK, PAPER, thin=1), images / "logo_icon.png", 384)
    render(tile_svg(PAPER, INK), images / "logo_icon_dark.png", 384)
    render(horizontal_svg(INK, TEXT_LIGHT), images / "logo_wordmark.png", 96)
    render(horizontal_svg(PAPER, PAPER, thin=1), images / "logo_wordmark_dark.png", 96)

    # Browser tab + home-screen icons. The favicon uses the heavier small cut.
    render(tile_svg(INK, PAPER, small=True, thin=1), ROOT / "web/favicon.png", 64)
    for size in (192, 512):
        render(tile_svg(INK, PAPER, thin=1), ROOT / f"web/icons/Icon-{size}.png", size)
        # Maskable: phones crop these to any shape, so the mark stays inside
        # the middle ~60% of a full black square.
        mask = mark_svg(ink=PAPER, thin=1, box="-86 -86 428 428", extra='<rect x="-86" y="-86" width="428" height="428"/>')
        render(mask, ROOT / f"web/icons/Icon-maskable-{size}.png", size)

    # The landing page uses its own copies.
    landing = ROOT / "landing/img"
    for name in ("logo_icon.png", "logo_icon_dark.png", "logo_wordmark.png", "logo_wordmark_dark.png"):
        (landing / name).write_bytes((images / name).read_bytes())
    (landing / "favicon.png").write_bytes((ROOT / "web/favicon.png").read_bytes())


if __name__ == "__main__":
    main()
