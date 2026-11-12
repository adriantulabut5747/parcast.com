"""Renders Tugak, the AgosAlert mascot, to PNG files for the app.

The drawing itself lives in tools/tugak.js (SVG built in JavaScript, so the
same file can be pasted into a web page to preview it). This script loads it
in headless Chrome and screenshots each mood on a see-through background:

    python tools/tugak.py              -> assets/images/tugak_<mood>.png
    python tools/tugak.py --preview    -> also build/tugak_sheet.png (all moods)

Edit tugak.js and rerun this; never edit the PNGs by hand.
Needs Google Chrome (path below) and Pillow (pip install pillow).
"""

import pathlib
import subprocess
import sys
import tempfile

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
MOODS = ["fine", "rain", "storm", "night"]
SIZE = 360  # px; shown at most ~130 px wide in the app, so this covers 2.5x screens


def shoot(html: str, out: pathlib.Path, width: int, height: int) -> None:
    with tempfile.TemporaryDirectory() as tmp:
        page = pathlib.Path(tmp) / "page.html"
        page.write_text(html, encoding="utf-8")
        subprocess.run(
            [
                CHROME,
                "--headless=new",
                "--hide-scrollbars",
                "--default-background-color=00000000",  # see-through PNG
                f"--window-size={width},{height}",
                f"--screenshot={out}",
                page.as_uri(),
            ],
            check=True,
            capture_output=True,
        )


def main() -> None:
    js = (ROOT / "tools" / "tugak.js").read_text(encoding="utf-8")
    images = ROOT / "assets" / "images"
    for mood in MOODS:
        out = images / f"tugak_{mood}.png"
        html = f"""<meta charset="utf-8"><style>html,body{{margin:0;background:transparent}}svg{{display:block}}</style>
<body><script>{js}
document.body.innerHTML = tugak({{ mood: '{mood}' }}).replace('<svg', '<svg width="{SIZE}" height="{SIZE}"');</script>"""
        shoot(html, out, SIZE, SIZE)
        # Full color: the soft shading bands if cut down to a 256-color palette.
        Image.open(out).convert("RGBA").save(out, optimize=True)
        print("wrote", out.relative_to(ROOT), f"{out.stat().st_size // 1024} KB")

    if "--preview" in sys.argv:
        (ROOT / "build").mkdir(exist_ok=True)
        tiles = "".join(
            f'<div style="background:{bg};border-radius:16px;display:grid;place-items:center">'
            f'<img src="{(images / f"tugak_{m}.png").as_uri()}" width="220"></div>'
            for m in MOODS
            for bg in ["#111113", "#f5f4f1"]
        )
        html = f'<body style="margin:0;padding:16px;background:#2a2a2e;display:grid;grid-template-columns:repeat(4,240px);gap:12px">{tiles}</body>'
        out = ROOT / "build" / "tugak_sheet.png"
        shoot(html, out, 1040, 520)
        print("wrote", out.relative_to(ROOT))


if __name__ == "__main__":
    main()
