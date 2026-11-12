"""Tugak, the AgosAlert frog ("tugak" = frog in Kapampangan).

Draws Tugak as SVG for each weather mood. Run it to get a preview sheet:
    python tools/tugak.py            -> build/tugak_sheet.png

The Flutter painter (lib/widgets/tugak.dart) draws the same shapes with the
same numbers; change both together.

Coordinates: a 120 x 120 box, Tugak sitting in the middle facing you.
"""

import pathlib
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"

# Skin colors per mood: (top, bottom, belly). The weather changes his color:
# baked yellow-green in the heat, deep glossy green when wet, dusky at night.
SKIN = {
    "fine": ("#6CC66A", "#3F9A4C", "#D7F0B4"),
    "hot": ("#B5C95A", "#8C9F3A", "#F1EFC0"),
    "cloudy": ("#5DB277", "#3C8658", "#CFEBC4"),
    "rain": ("#2DB86A", "#13804A", "#BDF0C9"),
    "storm": ("#2E9E7A", "#17694F", "#B9E6D8"),
    "night": ("#4E8C78", "#2F5E50", "#B7D3C5"),
}

INK = "#1D1D1F"


def eye(cx: float, cy: float, mood: str, top: str) -> str:
    """One eye bump on top of the head, with a mood-specific eye."""
    bump = f'<circle cx="{cx}" cy="{cy}" r="13" fill="{top}"/>'
    if mood == "night" and cx < 60:  # asleep... mostly: left eye closed
        return bump + f'<path d="M{cx - 6} {cy + 1} q6 5 12 0" fill="none" stroke="{INK}" stroke-width="2.4" stroke-linecap="round"/>'
    if mood == "rain":  # delighted: closed, curved up (^ ^)
        return bump + f'<path d="M{cx - 6} {cy + 3} q6 -7 12 0" fill="none" stroke="{INK}" stroke-width="2.6" stroke-linecap="round"/>'
    white = f'<circle cx="{cx}" cy="{cy}" r="{10 if mood == "storm" else 9}" fill="#fff"/>'
    if mood == "storm":  # alarmed: tiny pupils
        pupil = f'<circle cx="{cx}" cy="{cy}" r="2.6" fill="{INK}"/>'
    elif mood == "cloudy":  # looking up at the sky
        pupil = f'<circle cx="{cx + 2}" cy="{cy - 3}" r="4.6" fill="{INK}"/><circle cx="{cx + 3.6}" cy="{cy - 4.8}" r="1.4" fill="#fff"/>'
    else:
        pupil = f'<circle cx="{cx}" cy="{cy + 1}" r="4.8" fill="{INK}"/><circle cx="{cx + 1.8}" cy="{cy - 1}" r="1.5" fill="#fff"/>'
    lid = ""
    if mood in ("hot", "night"):  # half-closed lid: too hot / too sleepy
        lid = f'<path d="M{cx - 10} {cy} A10 10 0 0 1 {cx + 10} {cy} Z" fill="{top}"/><path d="M{cx - 9.5} {cy} H{cx + 9.5}" stroke="{INK}" stroke-opacity=".5" stroke-width="1.4"/>'
    return bump + white + pupil + lid


def mouth(mood: str) -> str:
    if mood == "rain":  # big open grin
        return f'<path d="M45 68 Q60 86 75 68 Z" fill="#7A1F2B"/><path d="M53 76 Q60 81 67 76 Q60 84 53 76Z" fill="#E86A7A"/>'
    if mood == "storm":  # small "o"
        return f'<ellipse cx="60" cy="73" rx="4.2" ry="5" fill="#7A1F2B"/>'
    if mood == "hot":  # flat, unimpressed
        return f'<path d="M50 71 H70" stroke="{INK}" stroke-width="2.4" stroke-linecap="round"/>'
    if mood == "night":
        return f'<path d="M53 71 q7 4 14 0" fill="none" stroke="{INK}" stroke-width="2.2" stroke-linecap="round"/>'
    if mood == "cloudy":
        return f'<path d="M50 71 q10 4 20 -1" fill="none" stroke="{INK}" stroke-width="2.4" stroke-linecap="round"/>'
    return f'<path d="M46 68 Q60 80 74 68" fill="none" stroke="{INK}" stroke-width="2.6" stroke-linecap="round"/>'


def extras(mood: str) -> tuple[str, str]:
    """(drawn behind Tugak, drawn in front of Tugak) for each mood."""
    drop = lambda x, y, s=1: (  # noqa: E731 - a water drop with a shine
        f'<g transform="translate({x} {y}) scale({s})"><path d="M0 -6 C-2 -2 -4 0 -4 2.5 A4 4 0 0 0 4 2.5 C4 0 2 -2 0 -6Z" fill="#8FD0FF"/>'
        f'<circle cx="-1.3" cy="2" r="1.1" fill="#fff" fill-opacity=".9"/></g>'
    )
    if mood == "hot":  # a salakot (woven farmer's hat) and a sweat drop
        hat = (
            '<path d="M22 40 Q60 2 98 40 Q60 48 22 40Z" fill="#D8B267"/>'
            '<path d="M22 40 Q60 48 98 40" fill="none" stroke="#A9843E" stroke-width="2"/>'
            '<path d="M60 9 L44 38 M60 9 L76 38 M60 9 V43" stroke="#B8924A" stroke-width="1.2"/>'
            '<circle cx="60" cy="9" r="2.4" fill="#A9843E"/>'
        )
        return "", hat + drop(88, 60, 0.9)
    if mood in ("rain", "storm"):  # a banana leaf held up as an umbrella
        leaf = (
            '<path d="M14 34 Q58 -6 108 26 Q62 20 14 34Z" fill="#2E8B3E"/>'
            '<path d="M14 34 Q60 10 108 26" fill="none" stroke="#1E6B2C" stroke-width="2"/>'
            '<path d="M36 25 l-6 -9 M54 18 l-3 -10 M72 16 l1 -10 M90 19 l4 -9" stroke="#1E6B2C" stroke-width="1.4" stroke-linecap="round"/>'
        )
        rain = "".join(drop(x, y, 0.8) for x, y in ((10, 60), (110, 52), (16, 92), (104, 88)))
        body_drops = drop(40, 82, 0.7) + drop(80, 92, 0.6) + drop(66, 56, 0.55)
        puddle = '<ellipse cx="60" cy="112" rx="46" ry="5" fill="#8FD0FF" fill-opacity=".35"/>' if mood == "storm" else ""
        return puddle + rain, leaf + body_drops
    if mood == "night":
        z = (
            f'<text x="88" y="30" font-family="Inter, sans-serif" font-weight="800" font-size="14" fill="{INK}" fill-opacity=".55">z</text>'
            f'<text x="98" y="18" font-family="Inter, sans-serif" font-weight="800" font-size="10" fill="{INK}" fill-opacity=".4">z</text>'
        )
        return "", z
    return "", ""


def tugak(mood: str) -> str:
    top, bottom, belly = SKIN[mood]
    back, front = extras(mood)
    wet = mood in ("rain", "storm")
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 120">
  <defs>
    <linearGradient id="skin-{mood}" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="{top}"/><stop offset="1" stop-color="{bottom}"/>
    </linearGradient>
  </defs>
  {back}
  <ellipse cx="60" cy="111" rx="34" ry="4" fill="#000" fill-opacity=".14"/>
  <!-- back legs, folded at the sides -->
  <ellipse cx="27" cy="96" rx="13" ry="10" fill="{bottom}"/>
  <ellipse cx="93" cy="96" rx="13" ry="10" fill="{bottom}"/>
  <!-- body + head: one squat bean -->
  <path d="M60 46 C88 46 100 62 99 82 C98 102 82 110 60 110 C38 110 22 102 21 82 C20 62 32 46 60 46Z" fill="url(#skin-{mood})"/>
  <ellipse cx="60" cy="92" rx="24" ry="15" fill="{belly}"/>
  <!-- front feet with three toes each -->
  <g fill="{top}">
    <ellipse cx="45" cy="107" rx="8" ry="4.5"/><ellipse cx="75" cy="107" rx="8" ry="4.5"/>
    <circle cx="38" cy="108" r="2.4"/><circle cx="45" cy="110" r="2.4"/><circle cx="52" cy="108" r="2.4"/>
    <circle cx="68" cy="108" r="2.4"/><circle cx="75" cy="110" r="2.4"/><circle cx="82" cy="108" r="2.4"/>
  </g>
  {eye(43, 46, mood, top)}
  {eye(77, 46, mood, top)}
  <ellipse cx="36" cy="66" rx="5" ry="3" fill="#FF7A8A" fill-opacity=".35"/>
  <ellipse cx="84" cy="66" rx="5" ry="3" fill="#FF7A8A" fill-opacity=".35"/>
  {mouth(mood)}
  <!-- shine on his head: stronger when he's wet -->
  <ellipse cx="46" cy="58" rx="9" ry="4" transform="rotate(-20 46 58)" fill="#fff" fill-opacity="{'.45' if wet else '.18'}"/>
  {front}
</svg>"""


LINES = {
    "fine": "No rain in sight, so the roads stay dry today. Sad for me, great for you.",
    "hot": "Drink water and stay in the shade. I'm a frog, and even I'm drying up.",
    "cloudy": "Clouds are gathering, so keep an umbrella nearby. I'm just here hoping.",
    "rain": "Rain! Best day ever for me, but watch the streets that flood first.",
    "storm": "Heavy rain: stay indoors and check the flood map. Too much water, even for me.",
    "night": "Quiet night. Charge your phone before bed, I'll keep one eye on the rain.",
}


def main() -> None:
    cards = "".join(
        f'<figure><div class="art">{tugak(m)}</div><figcaption><b>{m}</b><span>{LINES[m]}</span></figcaption></figure>'
        for m in SKIN
    )
    html = f"""<!doctype html><html><head><meta charset="utf-8"><style>
@font-face {{ font-family: Inter; font-weight: 400; src: url('{(ROOT / "assets/fonts/Inter-Regular.ttf").as_uri()}'); }}
@font-face {{ font-family: Inter; font-weight: 800; src: url('{(ROOT / "assets/fonts/Inter-ExtraBold.ttf").as_uri()}'); }}
body {{ margin: 0; background: #000; font-family: Inter; color: #F5F5F7; }}
.grid {{ display: grid; grid-template-columns: repeat(3, 300px); gap: 16px; padding: 24px; }}
figure {{ margin: 0; padding: 16px; border-radius: 24px; background: linear-gradient(#2C2C2E, #161618);
  box-shadow: inset 0 1px 0 rgba(255,255,255,.18); }}
.art svg {{ width: 160px; height: 160px; display: block; margin: 0 auto; }}
figcaption {{ display: grid; gap: 4px; font-size: 13px; line-height: 1.4; }}
figcaption b {{ text-transform: uppercase; font-size: 11px; letter-spacing: .08em; color: #98989F; }}
</style></head><body><div class="grid">{cards}</div></body></html>"""
    out = ROOT / "build/tugak_sheet.png"
    out.parent.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        src = pathlib.Path(tmp, "sheet.html")
        src.write_text(html, encoding="utf-8")
        subprocess.run(
            [CHROME, "--headless=new", "--hide-scrollbars", "--force-device-scale-factor=1",
             "--window-size=996,740", f"--screenshot={out}", src.as_uri()],
            check=True, capture_output=True,
        )
    print(out)


if __name__ == "__main__":
    main()
