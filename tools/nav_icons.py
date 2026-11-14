"""Renders the bottom-nav icons (tools/nav_icons.js) to PNG files:

    python tools/nav_icons.py            -> assets/images/nav_<name>.png
    python tools/nav_icons.py --preview  -> also build/nav_icons_sheet.png

Edit nav_icons.js and rerun this; never edit the PNGs by hand.
Needs Google Chrome and Pillow.
"""

import pathlib
import subprocess
import sys
import tempfile

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"


def shoot(html: str, out: pathlib.Path, width: int, height: int) -> None:
    """Headless Chrome screenshot of [html] on a see-through background."""
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

NAMES = ["weather", "map", "reports", "help"]
SIZE = 192  # px; shown at most ~60 px in the app, so this covers 3x screens


def main() -> None:
    js = (ROOT / "tools" / "nav_icons.js").read_text(encoding="utf-8")
    images = ROOT / "assets" / "images"
    for name in NAMES:
        out = images / f"nav_{name}.png"
        html = f"""<meta charset="utf-8"><style>html,body{{margin:0;background:transparent}}svg{{display:block}}</style>
<body><script>{js}
document.body.innerHTML = navIcon('{name}').replace('<svg', '<svg width="{SIZE}" height="{SIZE}"');</script>"""
        shoot(html, out, SIZE, SIZE)
        Image.open(out).convert("RGBA").save(out, optimize=True)
        print("wrote", out.relative_to(ROOT), f"{out.stat().st_size // 1024} KB")

    if "--preview" in sys.argv:
        (ROOT / "build").mkdir(exist_ok=True)
        tiles = "".join(
            f'<div style="background:{bg};display:grid;place-items:center">'
            f'<img src="{(images / f"nav_{n}.png").as_uri()}" width="{w}"></div>'
            for bg in ["#1c1c1f", "#f4f3f0"]
            for w in [150, 56]
            for n in NAMES
        )
        html = f'<body style="margin:0;padding:12px;background:#222;display:grid;grid-template-columns:repeat(4,170px);grid-auto-rows:170px;gap:8px">{tiles}</body>'
        out = ROOT / "build" / "nav_icons_sheet.png"
        shoot(html, out, 730, 740)
        print("wrote", out.relative_to(ROOT))


if __name__ == "__main__":
    main()
