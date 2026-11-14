# AgosAlert logo: usage guide

**The idea (Nov 13 2026):** the A of AgosAlert whose crossbar is a wave running past
both legs, like a current through it. "Agos" (current) and the A of "Alert" in one sign.
The A is cut around the wave by a thin gap so the two never merge at small sizes.
(Replaced the "!" with a wave dot.)

Every file here and every logo PNG in the app comes from `python tools/make_logo.py`.
Change the numbers in that script and rerun; never edit the SVGs or PNGs by hand.

## Files

| File | Use |
| --- | --- |
| `agosalert-mark.svg` | The symbol on light backgrounds (black A, blue wave) |
| `agosalert-mark-reversed.svg` | The symbol on dark backgrounds (white A, slightly thinner) |
| `agosalert-mark-black.svg` / `-white.svg` | One colour: print, stamps, embroidery, photos |
| `agosalert-mark-small.svg` | Heavier cut for **32 px and below** |
| `agosalert-icon.svg` / `-icon-small.svg` | App icon: the mark on a black rounded square |
| `agosalert-horizontal.svg` / `-reversed.svg` | Main lockup: symbol + "agosalert." |
| `agosalert-stacked.svg` | Square spaces (posters, profile cards) |
| `board.html`, `board/slide-*.png` | Presentation board with mockups (**still shows the old "!" mark**; not made by make_logo.py) |

## Colour

| | HEX | RGB | Notes |
| --- | --- | --- | --- |
| Blue (wave, wordmark dot) | `#0A84FF` | 10 132 255 | = `kBlue`. CMYK ≈ 96 48 0 0, nearest Pantone ≈ 2727 C (check against a swatch book before printing) |
| Black | `#000000` | 0 0 0 | The A on light backgrounds, app icon tile |
| Text | `#1D1D1F` | 29 29 31 | Wordmark letters on light backgrounds |
| White | `#FFFFFF` | 255 255 255 | The A and letters on dark backgrounds |

Blue is only ever the wave and the dot. Everything else is black or white.

## Type

Wordmark: Inter ExtraBold, tracking −4.5 %, all lowercase, converted to outlines (SIL Open Font
License, so logo use is allowed). The wordmark is not typed: use the files.

## Clear space and minimum size

- Clear space on every side: the height of the wave (crest to trough).
- Symbol: at least 16 px. Use the small cut at 32 px and below.
- Horizontal lockup: at least 18 px tall (≈ 80 px wide); below that, use the symbol alone.

## Don't

- Recolour the A blue or the wave anything but blue (or the one-colour versions).
- Put the colour mark on a busy photo: use the one-colour white version on a dark scrim.
- Stretch, rotate, outline, add shadows, glows or gradients.
- Rebuild the wordmark in another font or retype it.
- Bring back the old water drop, the glossy circle or the "!" mark.
- Shorten the wave to fit inside the legs: running past them is what keeps it visible at 16 px.

## Open items

- No trademark search done. Do one before any official use.
- The wordmark outlines skip Inter's kerning (it barely kerns these letters).
