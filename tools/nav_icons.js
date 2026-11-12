// Bottom-nav icons for AgosAlert, drawn as SVG in the app's iOS style:
// flat 2D shapes, soft gradients, NO outlines, one light from the top left
// (same as GlassEdgePainter and Tugak), a soft shadow under each object.
// iOS system colors (blue 0A84FF, cyan 64D2FF, green 34C759, purple AF52DE,
// yellow FFD60A). Rendered to assets/images/nav_<name>.png by
// tools/nav_icons.py. Edit this file and rerun that; never edit the PNGs.
//
// navIcon(name) returns an <svg> string, viewBox 0 0 128 128.
// Names: weather, map, reports, help.

const lin = (id, a, b, x1 = 0, y1 = 0, x2 = 0, y2 = 1) =>
  `<linearGradient id="${id}" x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}"><stop offset="0" stop-color="${a}"/><stop offset="1" stop-color="${b}"/></linearGradient>`;

// Soft drop shadow (light from the top left, so it falls down-right).
const SHADOW = `<filter id="sh" x="-20%" y="-20%" width="140%" height="150%"><feDropShadow dx="1.5" dy="4" stdDeviation="4" flood-color="#0b1a33" flood-opacity="0.28"/></filter>`;

// A thin white shine along a shape's top-left edge.
const shine = (d, o = 0.55) => `<path d="${d}" fill="none" stroke="#fff" stroke-width="2.5" stroke-linecap="round" opacity="${o}"/>`;

const drop = (x, y, s) =>
  `<path d="M${x} ${y - 11 * s} C${x + 3 * s} ${y - 5 * s} ${x + 8 * s} ${y} ${x + 8 * s} ${y + 4 * s} A${8 * s} ${8 * s} 0 0 1 ${x - 8 * s} ${y + 4 * s} C${x - 8 * s} ${y} ${x - 3 * s} ${y - 5 * s} ${x} ${y - 11 * s}Z"/>`;

const ICONS = {
  // Sun behind a cloud, two raindrops (like the iOS Weather glyphs, drawn).
  weather: () =>
    `<defs>${SHADOW}${lin('wSun', '#FFE680', '#FF9F0A', 0, 0, 0.6, 1)}${lin('wCloud', '#FFFFFF', '#D5E1EE')}${lin('wDrop', '#64D2FF', '#0A84FF')}</defs>` +
    `<circle cx="84" cy="40" r="25" fill="url(#wSun)" filter="url(#sh)"/>` +
    shine('M66 30 A22 22 0 0 1 80 18', 0.6) +
    `<g fill="url(#wDrop)" filter="url(#sh)">${drop(44, 110, 0.95)}${drop(72, 114, 0.8)}</g>` +
    `<g fill="url(#wCloud)" filter="url(#sh)"><circle cx="38" cy="74" r="21"/><circle cx="63" cy="62" r="26"/><circle cx="91" cy="77" r="17"/><rect x="17" y="72" width="91" height="28" rx="14"/></g>` +
    shine('M22 74 A17 17 0 0 1 40 56 M45 48 A22 22 0 0 1 80 52', 0.9),

  // A folded map: land, the river (agos = current), a purple pin.
  map: () => {
    const panels = ['M16 30 L48 22 L48 102 L16 110Z', 'M48 22 L80 30 L80 110 L48 102Z', 'M80 30 L112 22 L112 102 L80 110Z'];
    const river = 'M12 86 C30 70 44 92 62 78 S92 52 116 58';
    return (
      `<defs>${SHADOW}${lin('mPin', '#D58CFF', '#8E3BD9')}${lin('mRiver', '#64D2FF', '#0A84FF', 0, 0, 1, 0)}` +
      `<clipPath id="mClip">${panels.map((d) => `<path d="${d}"/>`).join('')}</clipPath></defs>` +
      `<g filter="url(#sh)"><path d="${panels[0]}" fill="#F7F8FA"/><path d="${panels[1]}" fill="#E1E6EC"/><path d="${panels[2]}" fill="#F7F8FA"/></g>` +
      `<g clip-path="url(#mClip)">` +
      `<path d="M16 30 L48 22 L48 60 C36 64 26 52 16 58Z" fill="#8BD88F"/>` +
      `<path d="M48 22 L80 30 L80 46 C70 50 58 40 48 46Z" fill="#6CC573"/>` +
      `<path d="M80 80 C92 76 100 90 112 84 L112 102 L80 110Z" fill="#8BD88F"/>` +
      `<path d="${river}" fill="none" stroke="url(#mRiver)" stroke-width="9" stroke-linecap="round"/>` +
      // the middle panel faces away from the light
      `<path d="${panels[1]}" fill="#0b1a33" opacity="0.08"/>` +
      `</g>` +
      `<path d="M90 70 C80 56 74 49 74 40 A16 16 0 0 1 106 40 C106 49 100 56 90 70Z" fill="url(#mPin)" filter="url(#sh)"/>` +
      `<circle cx="90" cy="40" r="6" fill="#fff"/>` +
      shine('M79 33 A12 12 0 0 1 88 26', 0.7)
    );
  },

  // A silver camera with a photo of a flooded street behind it.
  reports: () =>
    `<defs>${SHADOW}${lin('rBody', '#F5F5F8', '#BFC3CC')}${lin('rTop', '#E6E7EC', '#A9AEB8')}${lin('rSky', '#64D2FF', '#C8EEFF')}${lin('rWater', '#3FA2FF', '#0A64D8')}` +
    `<radialGradient id="rGlass" cx="0.38" cy="0.35" r="0.75"><stop offset="0" stop-color="#5AB0FF"/><stop offset="0.55" stop-color="#1B3E78"/><stop offset="1" stop-color="#0A1428"/></radialGradient>` +
    `<radialGradient id="rRing" cx="0.4" cy="0.35" r="0.8"><stop offset="0" stop-color="#5A5F6B"/><stop offset="1" stop-color="#22252C"/></radialGradient></defs>` +
    `<g transform="translate(2 9) rotate(-9 49 35)" filter="url(#sh)">` +
    `<rect x="18" y="4" width="62" height="62" rx="6" fill="#fff"/>` +
    `<rect x="25" y="11" width="48" height="42" rx="3" fill="url(#rSky)"/>` +
    `<path d="M34 30 L46 19 L58 30Z" fill="#FF9F0A"/><rect x="37" y="30" width="18" height="12" fill="#F2E6D0"/>` +
    `<path d="M25 38 C31 35 35 41 41 38 S51 35 57 38 S67 41 73 38 L73 53 L25 53Z" fill="url(#rWater)"/>` +
    `</g>` +
    `<g filter="url(#sh)"><rect x="38" y="51" width="34" height="18" rx="6" fill="url(#rTop)"/><rect x="20" y="62" width="96" height="56" rx="14" fill="url(#rBody)"/></g>` +
    shine('M28 64 H104', 0.9) +
    `<rect x="97" y="70" width="11" height="7" rx="2.5" fill="#FFD60A"/>` +
    `<circle cx="68" cy="90" r="22" fill="url(#rRing)"/>` +
    `<circle cx="68" cy="90" r="15" fill="url(#rGlass)"/>` +
    `<ellipse cx="62" cy="84" rx="5" ry="3" transform="rotate(-35 62 84)" fill="#fff" opacity="0.8"/>`,

  // A green first-aid kit with a white cross (safety-sign colors).
  help: () =>
    `<defs>${SHADOW}${lin('hBox', '#4CD964', '#1F9D45')}${lin('hHandle', '#D1D1D6', '#8E8E93')}</defs>` +
    `<rect x="44" y="20" width="40" height="28" rx="10" fill="none" stroke="url(#hHandle)" stroke-width="8" filter="url(#sh)"/>` +
    `<rect x="12" y="38" width="104" height="76" rx="16" fill="url(#hBox)" filter="url(#sh)"/>` +
    `<rect x="12" y="38" width="104" height="18" rx="9" fill="#fff" opacity="0.14"/>` +
    `<path d="M12 56 H116" stroke="#0b3a1c" stroke-width="2" opacity="0.18"/>` +
    shine('M18 54 V52 A12 12 0 0 1 30 40 H98', 0.6) +
    `<path d="M57 62 H71 V75 H84 V89 H71 V102 H57 V89 H44 V75 H57Z" fill="#fff"/>`,
};

function navIcon(name) {
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">${ICONS[name]()}</svg>`;
}
