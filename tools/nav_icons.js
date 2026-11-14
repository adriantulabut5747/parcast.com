// Bottom-nav icons for AgosAlert, drawn as SVG. Nov 13 2026 redraw in the
// style of Apple's own app icons: few, bold shapes that still read at the
// closed size (~30 px); soft top-lit gradients; NO outlines and no thin
// shine strokes; one light from the top left (same as GlassEdgePainter and
// Tugak), so every object gets the same soft shadow down-right. Same
// subjects as the desktop top nav (cloud_sun, map, news, lifebuoy), so a
// tab looks like the same thing on every screen size.
// Colors: iOS system blues and grays. Red only on the lifebuoy (Help is the
// SOS tab); no green (it means "safe / low risk" in this app).
// Rendered to assets/images/nav_<name>.png by tools/nav_icons.py.
// Edit this file and rerun that; never edit the PNGs.
//
// navIcon(name) returns an <svg> string, viewBox 0 0 128 128.
// Names: weather, map, reports, help.

const lin = (id, a, b, x1 = 0, y1 = 0, x2 = 0, y2 = 1) =>
  `<linearGradient id="${id}" x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}"><stop offset="0" stop-color="${a}"/><stop offset="1" stop-color="${b}"/></linearGradient>`;

// Soft drop shadow (light from the top left, so it falls down-right).
const SHADOW = `<filter id="sh" x="-25%" y="-25%" width="150%" height="160%"><feDropShadow dx="1.5" dy="4" stdDeviation="4.5" flood-color="#06142b" flood-opacity="0.3"/></filter>`;

// A soft light spot from the top left, laid over a shape (clipped to it).
const GLOW = `<radialGradient id="glow" cx="0.3" cy="0.2" r="0.7"><stop offset="0" stop-color="#fff" stop-opacity="0.45"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient>`;

const drop = (x, y, s) =>
  `<path d="M${x} ${y - 12 * s} C${x + 3 * s} ${y - 6 * s} ${x + 8 * s} ${y - 1 * s} ${x + 8 * s} ${y + 4 * s} A${8 * s} ${8 * s} 0 0 1 ${x - 8 * s} ${y + 4 * s} C${x - 8 * s} ${y - 1 * s} ${x - 3 * s} ${y - 6 * s} ${x} ${y - 12 * s}Z"/>`;

const ICONS = {
  // Sun behind a cloud, two raindrops (the desktop's cloud_sun, plus rain).
  weather: () => {
    const cloud = '<circle cx="40" cy="74" r="20"/><circle cx="66" cy="60" r="27"/><circle cx="93" cy="76" r="17"/><rect x="20" y="70" width="90" height="30" rx="15"/>';
    return (
      `<defs>${SHADOW}${GLOW}${lin('wSun', '#FFE15A', '#FF9F0A', 0.2, 0, 0.7, 1)}<linearGradient id="wCloud" gradientUnits="userSpaceOnUse" x1="0" y1="34" x2="0" y2="100"><stop offset="0" stop-color="#FFFFFF"/><stop offset="1" stop-color="#C9D6E5"/></linearGradient>${lin('wDrop', '#5AC8FA', '#0A6CFF')}` +
      `</defs>` +
      `<circle cx="88" cy="40" r="24" fill="url(#wSun)" filter="url(#sh)"/>` +
      `<circle cx="88" cy="40" r="24" fill="url(#glow)"/>` +
      `<g fill="url(#wDrop)" filter="url(#sh)">${drop(46, 112, 0.95)}${drop(74, 116, 0.8)}</g>` +
      // one gradient for the whole cloud (in page units), so its puffs blend
    `<g fill="url(#wCloud)" filter="url(#sh)">${cloud}</g>`
    );
  },

  // A folded map: sand land, the river (agos = current), a blue pin.
  map: () => {
    const panels = ['M14 32 L47 23 L47 103 L14 112Z', 'M47 23 L81 32 L81 112 L47 103Z', 'M81 32 L114 23 L114 103 L81 112Z'];
    const river = 'M10 92 C28 76 44 96 62 82 S92 58 118 64';
    return (
      `<defs>${SHADOW}${GLOW}${lin('mPin', '#4DA3FF', '#0040DD')}${lin('mRiver', '#7FD8FF', '#0A84FF', 0, 0, 1, 0)}${lin('mLand', '#FBF8F2', '#E9E3D6')}` +
      `<clipPath id="mClip">${panels.map((d) => `<path d="${d}"/>`).join('')}</clipPath></defs>` +
      `<g filter="url(#sh)" fill="url(#mLand)">${panels.map((d) => `<path d="${d}"/>`).join('')}</g>` +
      `<g clip-path="url(#mClip)">` +
      // two roads, then the river over them
      `<path d="M30 20 L40 120 M70 18 C76 50 96 70 124 80" stroke="#fff" stroke-width="7" fill="none"/>` +
      `<path d="M30 20 L40 120 M70 18 C76 50 96 70 124 80" stroke="#d9d2c3" stroke-width="7" fill="none" opacity="0.35" transform="translate(0.8 1.2)"/>` +
      `<path d="${river}" fill="none" stroke="url(#mRiver)" stroke-width="12" stroke-linecap="round"/>` +
      // the folds: the middle panel faces away from the light
      `<path d="${panels[1]}" fill="#3b2f1a" opacity="0.09"/>` +
      `<path d="${panels[2]}" fill="#fff" opacity="0.12"/>` +
      `</g>` +
      `<g filter="url(#sh)"><path d="M88 74 C77 60 70 52 70 41 A18 18 0 0 1 106 41 C106 52 99 60 88 74Z" fill="url(#mPin)"/></g>` +
      `<path d="M88 74 C77 60 70 52 70 41 A18 18 0 0 1 106 41 C106 52 99 60 88 74Z" fill="url(#glow)"/>` +
      `<circle cx="88" cy="41" r="7" fill="#fff"/>`
    );
  },

  // Two photo posts stacked: the front one shows a flooded street (the
  // desktop's news icon, as photos, since every report is a photo).
  reports: () =>
    `<defs>${SHADOW}${GLOW}${lin('rCard', '#FFFFFF', '#E4E7EC')}${lin('rSky', '#8FD3FF', '#D8F0FF')}${lin('rWater', '#3A9BFF', '#0A5BD8')}` +
    `<clipPath id="rPhoto"><rect x="30" y="38" width="76" height="56" rx="7"/></clipPath></defs>` +
    // back card
    `<g transform="rotate(-10 64 68)" filter="url(#sh)"><rect x="18" y="24" width="88" height="88" rx="14" fill="#C7CDD6"/></g>` +
    // front card
    `<g filter="url(#sh)"><rect x="24" y="30" width="88" height="88" rx="14" fill="url(#rCard)"/></g>` +
    `<g clip-path="url(#rPhoto)">` +
    `<rect x="30" y="38" width="76" height="56" fill="url(#rSky)"/>` +
    `<path d="M44 66 L60 52 L76 66Z" fill="#5E6B7E"/><rect x="48" y="66" width="24" height="16" fill="#E3D5BE"/>` +
    `<path d="M30 76 C40 71 46 80 56 75 S72 70 82 75 S98 80 106 75 L106 94 L30 94Z" fill="url(#rWater)"/>` +
    `</g>` +
    // caption lines under the photo
    `<rect x="30" y="101" width="44" height="6" rx="3" fill="#AEB5C0"/><rect x="78" y="101" width="18" height="6" rx="3" fill="#D3D8DF"/>`,

  // A lifebuoy: white ring with four red bands (Help = SOS + rescue).
  help: () => {
    const R = 46,
      r = 21,
      c = 64;
    const band = (a) => {
      const h = 0.36; // half the band's angle, in radians
      const p = (rad, t) => `${(c + rad * Math.cos(t)).toFixed(2)} ${(c + rad * Math.sin(t)).toFixed(2)}`;
      return `M${p(R, a - h)} A${R} ${R} 0 0 1 ${p(R, a + h)} L${p(r, a + h)} A${r} ${r} 0 0 0 ${p(r, a - h)}Z`;
    };
    const ring = `M${c - R} ${c} a${R} ${R} 0 1 0 ${2 * R} 0 a${R} ${R} 0 1 0 ${-2 * R} 0Z M${c - r} ${c} a${r} ${r} 0 1 1 ${2 * r} 0 a${r} ${r} 0 1 1 ${-2 * r} 0Z`;
    return (
      `<defs>${SHADOW}${GLOW}${lin('hRing', '#FFFFFF', '#DCE1E8')}${lin('hBand', '#FF6A5F', '#D70015')}` +
      `<radialGradient id="hTube" cx="0.5" cy="0.5" r="0.5"><stop offset="0.45" stop-color="#000" stop-opacity="0.16"/><stop offset="0.62" stop-color="#000" stop-opacity="0"/><stop offset="0.86" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity="0.16"/></radialGradient></defs>` +
      `<path d="${ring}" fill="url(#hRing)" fill-rule="evenodd" filter="url(#sh)"/>` +
      `<path d="${[1, 3, 5, 7].map((k) => band((k * Math.PI) / 4)).join('')}" fill="url(#hBand)"/>` +
      // round tube: darker at both edges, light on the top left
      `<path d="${ring}" fill="url(#hTube)" fill-rule="evenodd"/>` +
      `<path d="${ring}" fill="url(#glow)" fill-rule="evenodd"/>`
    );
  },
};

function navIcon(name) {
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">${ICONS[name]()}</svg>`;
}
