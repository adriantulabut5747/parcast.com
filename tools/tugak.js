// Tugak, the AgosAlert mascot ("tugak" = frog in Kapampangan).
// Nov 12 2026 redraw: iOS / Animoji style to match the app's glass look:
// soft shading, no outlines, one light from the top left (the same light
// GlassEdgePainter uses), glossy eyes. Still the grown-up toad: bronze
// skin, gold eyes with a toad's horizontal pupils, calm half-lidded look,
// navy rescue jacket. No shades any more (they were the old comic look).
//
// Drawn as SVG in a 240 x 240 box. tools/tugak.py renders it to
// assets/images/tugak_<mood>.png; edit THIS file and rerun that, never the PNGs.
//
// tugak({ mood }) -> SVG text. mood: fine | rain | storm | night
//   fine   relaxed lids, a small one-sided smirk
//   rain   hood up, lids up a bit, drops on the hood and skin
//   storm  hood up, eyes wide open, flat mouth (serious)
//   night  heavy lids, cool moonlight from the side
function tugak(opts = {}) {
  const mood = opts.mood || 'fine';
  const night = mood === 'night';
  const hood = mood === 'rain' || mood === 'storm';
  const id = 't' + Math.random().toString(36).slice(2, 8);
  const u = (name) => `url(#${id}${name})`;

  // How far each lid comes down: 0 = eye wide open, 1 = shut.
  const lid = { fine: 0.4, rain: 0.3, storm: 0.1, night: 0.6 }[mood];
  // Moonlight is cool and violet; daylight rim is a pale sky blue.
  const rim = night ? '#9aa6ff' : '#cfe6ff';

  const head =
    'M24 134 C22 102 58 86 120 86 C182 86 218 102 216 134 C214 170 176 190 120 190 C64 190 26 170 24 134 Z';
  const eyes = [
    [80, 86],
    [160, 86],
  ];
  const R = 26; // eye radius
  const dome = R + 7; // the skin bump each eye sits in

  let s = `<svg viewBox="0 0 240 240" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Tugak the frog">
<defs>
  <!-- One skin gradient in page space, so head and eye bumps share the light. -->
  <radialGradient id="${id}skin" gradientUnits="userSpaceOnUse" cx="86" cy="70" r="170">
    <stop offset="0" stop-color="${night ? '#b39c7e' : '#d9b27a'}"/>
    <stop offset=".45" stop-color="${night ? '#7d6650' : '#a7773f'}"/>
    <stop offset="1" stop-color="${night ? '#33261d' : '#4a2f15'}"/>
  </radialGradient>
  <linearGradient id="${id}jaw" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#f1dfbd" stop-opacity="0"/><stop offset=".35" stop-color="#ecd7b0" stop-opacity=".9"/><stop offset="1" stop-color="#c9a679"/>
  </linearGradient>
  <radialGradient id="${id}iris" cx=".42" cy=".38" r=".75">
    <stop offset="0" stop-color="#ffe08f"/><stop offset=".55" stop-color="#e0a234"/><stop offset=".9" stop-color="#8f560e"/><stop offset="1" stop-color="#5a3406"/>
  </radialGradient>
  <linearGradient id="${id}lidShade" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity=".45"/>
  </linearGradient>
  <linearGradient id="${id}jacket" gradientUnits="userSpaceOnUse" x1="60" y1="170" x2="180" y2="240">
    <stop offset="0" stop-color="#36557a"/><stop offset=".5" stop-color="#22385a"/><stop offset="1" stop-color="#121f35"/>
  </linearGradient>
  <linearGradient id="${id}hood" gradientUnits="userSpaceOnUse" x1="40" y1="40" x2="200" y2="190">
    <stop offset="0" stop-color="#3b5d86"/><stop offset=".6" stop-color="#1f3354"/><stop offset="1" stop-color="#101b2e"/>
  </linearGradient>
  <linearGradient id="${id}band" x1="0" y1="0" x2="1" y2="0">
    <stop offset="0" stop-color="#9aa4ae"/><stop offset=".35" stop-color="#f4f7fa"/><stop offset=".6" stop-color="#c9d1d8"/><stop offset="1" stop-color="#7d8792"/>
  </linearGradient>
  <linearGradient id="${id}rim" gradientUnits="userSpaceOnUse" x1="120" y1="0" x2="230" y2="0">
    <stop offset="0" stop-color="${rim}" stop-opacity="0"/><stop offset="1" stop-color="${rim}" stop-opacity="${night ? 0.75 : 0.5}"/>
  </linearGradient>
  <radialGradient id="${id}drop" cx=".35" cy=".3" r=".8">
    <stop offset="0" stop-color="#fff"/><stop offset=".4" stop-color="#d6ecff" stop-opacity=".9"/><stop offset="1" stop-color="#7fb3e6" stop-opacity=".55"/>
  </radialGradient>
  <filter id="${id}blur4"><feGaussianBlur stdDeviation="4"/></filter>
  <filter id="${id}blur2"><feGaussianBlur stdDeviation="2"/></filter>
  <filter id="${id}blur1"><feGaussianBlur stdDeviation="1"/></filter>
  <clipPath id="${id}headClip"><path d="${head}"/>${eyes.map(([x, y]) => `<circle cx="${x}" cy="${y}" r="${dome}"/>`).join('')}</clipPath>
</defs>`;

  // ---- ground shadow and jacket ----
  s += `<ellipse cx="120" cy="238" rx="104" ry="9" fill="#000" opacity=".35" filter="${u('blur4')}"/>`;
  if (hood) {
    // Hood up: frames the head, its opening a darker inside.
    s += `<path d="M8 180 C4 112 44 50 120 50 C196 50 236 112 232 180 L212 206 L28 206 Z" fill="${u('hood')}"/>
<path d="M22 168 C18 110 58 62 120 62 C182 62 222 110 218 168 Z" fill="#0a1220" opacity=".75"/>
<path d="M20 132 C24 92 60 58 112 54" stroke="#fff" stroke-opacity=".2" stroke-width="3" fill="none" stroke-linecap="round"/>`;
  }
  s += `<path d="M14 240 C18 200 58 176 120 176 C182 176 222 200 226 240 Z" fill="${u('jacket')}"/>
<path d="M18 222 C64 210 176 210 222 222 L224 234 C176 222 64 222 16 234 Z" fill="${u('band')}"/>
<path d="M20 234 C64 222 176 222 222 234 L222 236 C176 225 64 225 20 237 Z" fill="#000" opacity=".25"/>
<path d="M120 196 L120 240" stroke="#0c1628" stroke-width="2.4"/>
<path d="M120 196 L120 240" stroke="#5d7ea6" stroke-width="1" opacity=".5" transform="translate(1.6 0)"/>
<rect x="114" y="206" width="12" height="7" rx="2" fill="#c9d1d8"/>
<path d="M78 178 C92 192 106 198 120 200 C134 198 148 192 162 178 L170 186 C154 204 136 210 120 210 C104 210 86 204 70 186 Z" fill="#2e4b70"/>
<path d="M70 186 C86 204 104 210 120 210 C136 210 154 204 170 186" stroke="#7d9cc4" stroke-width="1.4" fill="none" opacity=".6"/>`;
  // The head's shadow on the collar.
  s += `<defs><clipPath id="${id}jk"><path d="M14 240 C18 200 58 176 120 176 C182 176 222 200 226 240 Z"/></clipPath></defs>
<ellipse clip-path="${u('jk')}" cx="120" cy="190" rx="84" ry="13" fill="#000" opacity=".5" filter="${u('blur4')}"/>`;

  // ---- head ----
  s += `<g>
  ${eyes.map(([x, y]) => `<circle cx="${x}" cy="${y}" r="${dome}" fill="${u('skin')}"/>`).join('')}
  <path d="${head}" fill="${u('skin')}"/>
  <g clip-path="${u('headClip')}">
    <!-- lower jaw: lighter throat under the mouth -->
    <path d="M40 146 C70 162 170 162 200 146 L216 200 L24 200 Z" fill="${u('jaw')}" opacity=".8"/>
    <!-- soft shading where the eye bumps meet the head -->
    ${eyes.map(([x, y]) => `<ellipse cx="${x}" cy="${y + dome - 2}" rx="${dome - 4}" ry="6" fill="#000" opacity=".16" filter="${u('blur2')}"/>`).join('')}
    <!-- toad bumps, faint -->
    ${[
      [54, 120, 4],
      [66, 132, 3],
      [182, 122, 4],
      [174, 134, 3],
      [100, 104, 3],
      [142, 104, 3],
      [196, 140, 2.5],
      [44, 140, 2.5],
    ]
      .map(
        ([x, y, r]) =>
          `<circle cx="${x + 0.8}" cy="${y + 1}" r="${r}" fill="#000" opacity=".12"/><circle cx="${x}" cy="${y}" r="${r}" fill="#fff" opacity=".1"/>`,
      )
      .join('')}
    <!-- rim light on the right edge (the sky behind him) -->
    <path d="${head}" fill="none" stroke="${u('rim')}" stroke-width="6" filter="${u('blur1')}"/>
    <!-- big soft top highlight -->
    <ellipse cx="96" cy="98" rx="70" ry="18" fill="#fff" opacity=".12" filter="${u('blur4')}"/>
  </g>`;

  // nostrils
  s += `<ellipse cx="110" cy="126" rx="3" ry="2" fill="#2b2310" opacity=".7"/><ellipse cx="130" cy="126" rx="3" ry="2" fill="#2b2310" opacity=".7"/>`;

  // mouth: long, low, with a lit lower lip; a one-sided smirk unless serious
  const mouth =
    mood === 'storm'
      ? 'M44 150 C80 156 160 156 196 150'
      : mood === 'night'
        ? 'M44 148 C80 158 160 158 196 148'
        : 'M44 148 C80 158 156 158 186 150 C192 148 196 144 198 140';
  s += `<path d="${mouth}" stroke="#2e2510" stroke-width="3.2" fill="none" stroke-linecap="round"/>
<path d="${mouth}" stroke="#fff" stroke-width="1.4" fill="none" stroke-linecap="round" opacity=".22" transform="translate(0 3)"/>`;

  // ---- eyes ----
  eyes.forEach(([cx, cy], i) => {
    const top = cy - R;
    const lidY = top + 2 * R * lid;
    // Lids tilt down toward the middle a touch: calm, a bit dry.
    const tilt = mood === 'storm' ? 0 : 3;
    const [yl, yr] = i === 0 ? [lidY - tilt, lidY + tilt] : [lidY + tilt, lidY - tilt];
    const look = -3; // pupils glance left, toward his speech bubble
    s += `<defs><clipPath id="${id}e${i}"><circle cx="${cx}" cy="${cy}" r="${R}"/></clipPath></defs>
<circle cx="${cx}" cy="${cy}" r="${R}" fill="${u('iris')}"/>
<g clip-path="${u('e' + i)}">
  <!-- horizontal pupil -->
  <rect x="${cx + look - R * 0.6}" y="${cy - R * 0.19}" width="${R * 1.2}" height="${R * 0.38}" rx="${R * 0.19}" fill="#120a02"/>
  <!-- lower lid -->
  <path d="M${cx - R - 2} ${cy + R * 0.7} C${cx - R / 2} ${cy + R * 0.5} ${cx + R / 2} ${cy + R * 0.5} ${cx + R + 2} ${cy + R * 0.7} L${cx + R + 2} ${cy + R + 2} L${cx - R - 2} ${cy + R + 2} Z" fill="${u('skin')}"/>
  <!-- upper lid, with its soft shadow on the eye -->
  <polygon points="${cx - R - 2},${yl + 7} ${cx + R + 2},${yr + 7} ${cx + R + 2},${yr} ${cx - R - 2},${yl}" fill="${u('lidShade')}"/>
  <polygon points="${cx - R - 2},${yl} ${cx + R + 2},${yr} ${cx + R + 2},${top - 4} ${cx - R - 2},${top - 4}" fill="${u('skin')}"/>
  <path d="M${cx - R - 2} ${yl} L${cx + R + 2} ${yr}" stroke="#fff" stroke-opacity=".28" stroke-width="1.6"/>
</g>
<!-- glossy cornea: big soft highlight + a sharp catchlight -->
<g clip-path="${u('e' + i)}">
  <ellipse cx="${cx - 10}" cy="${Math.max(cy - 10, lidY + 9)}" rx="6" ry="3.6" fill="#fff" opacity=".85" filter="${u('blur1')}"/>
  <path d="M${cx + R * 0.35} ${cy + R * 0.85} A${R - 3} ${R - 3} 0 0 0 ${cx + R * 0.85} ${cy + R * 0.3}" stroke="#ffd98a" stroke-width="2" fill="none" opacity=".55"/>
</g>
<circle cx="${cx}" cy="${cy}" r="${R}" fill="none" stroke="#3a2008" stroke-opacity=".35" stroke-width="2.5" filter="${u('blur1')}"/>`;
  });
  s += `</g>`;

  // ---- weather extras ----
  if (hood) {
    // Hood's front edge over the forehead, a drawstring tip on each side.
    s += `<path d="M40 176 L36 204" stroke="#c9d1d8" stroke-width="2.2" stroke-linecap="round"/><rect x="32" y="202" width="7" height="10" rx="3" fill="#c9d1d8"/>
<path d="M200 176 L204 204" stroke="#c9d1d8" stroke-width="2.2" stroke-linecap="round"/><rect x="201" y="202" width="7" height="10" rx="3" fill="#c9d1d8"/>`;
    const drops = [
      [20, 142, 0.8],
      [120, 66, 0.6],
      [222, 154, 0.7],
    ];
    s += drops
      .map(
        ([x, y, k]) =>
          `<path transform="translate(${x} ${y}) scale(${k})" d="M0 -9 C3 -4 6 -1 6 3 A6 6 0 0 1 -6 3 C-6 -1 -3 -4 0 -9 Z" fill="${u('drop')}"/>`,
      )
      .join('');
  }
  return s + '</svg>';
}
