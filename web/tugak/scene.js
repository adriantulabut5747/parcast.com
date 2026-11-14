// ============================================================
// Tugak's room: the 3D scene at the top of the Weather tab.
// ============================================================
//
// Flutter puts an empty <div> on the page (lib/widgets/tugak_stage_web.dart)
// and this module draws into it with three.js (web/tugak/three/, pinned, served
// with the app). Dart talks to it through window.agosTugak.create(div, opts, cb)
// and the handle's methods: setWeather(json), say(text), pointer(x, y),
// tap(x, y), setActive(active, visible), setTheme(dark), setReserve(json), destroy().
//
// setReserve({left, top, bottom, bubble}) (Nov 14 2026, the stage became the
// "now" card): CSS px of the stage that Flutter covers with the live readings.
// Tugak is framed in what's left, as if the canvas were only that part
// (camera.setViewOffset), and his bubble goes to the free corner: 'side' =
// bottom left, tail pointing right at him; 'below' = across the bottom, tail up.
//
// The dark stage (Nov 14 2026, Adrian: the cream room pulled the eye away from
// him and clashed with the dark glass UI): Tugak on a navy floor that fades
// into the landing hero's night, in a soft kBlue pool, like a product shot. Behind his head, a soft
// pool of the weather Flutter sends: sky colors, the sun's glow or the moon,
// rain, lightning, stars (no clouds: on the dark stage every try read as
// clutter; the cloud % is in the card beside him). A warm unseen lamp lights him at
// night. Tugak himself is web/tugak/tugak.glb (tools/tugak3d.py): he breathes,
// blinks, follows the pointer with his eyes, talks while his line types out,
// tips his hat when tapped.
//
// Input never comes from the <div> (it has pointer-events: none, so a swipe
// over the scene still scrolls the page on phones): Flutter sends pointer
// moves and taps in.

import * as THREE from './three/three.module.min.js';
import { GLTFLoader } from './three/GLTFLoader.js';
import { MeshoptDecoder } from './three/meshopt_decoder.module.js';
import { RoomEnvironment } from './three/RoomEnvironment.js';

const MODEL = new URL('./tugak.glb', import.meta.url).href;

// ---------------------------------------------------------------- the look

// Sky colors (top, horizon) per kind of weather. Tuned by eye against the app's
// graphite UI: deep, a little desaturated, never neon.
const SKIES = {
  clear: ['#2a74cc', '#a8d2f2'],
  partly: ['#3a80c8', '#b4cfe6'],
  overcast: ['#66778c', '#aeb8c4'],
  rain: ['#475569', '#8793a3'],
  storm: ['#232b38', '#4b5566'],
  dusk: ['#36518f', '#f0a56c'],
  night: ['#060a1a', '#1b2645'],
  nightRain: ['#0b111d', '#212a39'],
};
// The backdrop (Nov 14 2026): the landing hero's night, a hair lighter than the
// page (kBgDark #05060C), with the hero's kBlue pool behind him (POOL).
const STAGE = '#070a1c';
const FLOOR = '#05071a'; // a hair darker than STAGE: lit, it meets the backdrop without a seam
const POOL = '#0a84ff';

const CSS = `
@font-face{font-family:TgInter;font-weight:500;src:url(assets/assets/fonts/Inter-Regular.ttf)}
@font-face{font-family:TgInter;font-weight:600;src:url(assets/assets/fonts/Inter-SemiBold.ttf)}
@font-face{font-family:TgInter;font-weight:800;src:url(assets/assets/fonts/Inter-ExtraBold.ttf)}
.tg-stage{position:absolute;inset:0;overflow:hidden;pointer-events:none;opacity:0;transition:opacity .6s ease}
.tg-stage.tg-ready{opacity:1}
.tg-stage canvas{display:block;width:100%;height:100%}
.tg-bubble{position:absolute;left:0;top:0;max-width:300px;padding:11px 15px 13px;border-radius:20px;
  font:600 15px/1.38 TgInter,-apple-system,system-ui,sans-serif;letter-spacing:-.1px;color:#f5f5f7;
  background:rgba(18,20,32,.78);border:1px solid rgba(255,255,255,.1);
  box-shadow:0 10px 30px rgba(0,0,0,.25),inset 0 1px 0 rgba(255,255,255,.14);
  backdrop-filter:blur(24px) saturate(180%);-webkit-backdrop-filter:blur(24px) saturate(180%);
  opacity:0;transform:translateY(6px) scale(.97);transform-origin:0 100%;
  transition:opacity .35s ease,transform .45s cubic-bezier(.2,1.3,.4,1);will-change:transform}
.tg-bubble.tg-on{opacity:1;transform:none}
.tg-bubble b{display:block;font-weight:800;font-size:11px;letter-spacing:.1em;color:#0a84ff;margin-bottom:3px}
.tg-light .tg-bubble{color:#1d1d1f;background:#fff;border-color:rgba(0,0,0,.08);
  box-shadow:0 10px 30px rgba(0,0,0,.28);backdrop-filter:none;-webkit-backdrop-filter:none}
.tg-light .tg-bubble b{color:#0066cc}
.tg-bubble i{position:absolute;left:-7px;bottom:16px;width:14px;height:14px;transform:rotate(45deg);
  background:inherit;border-left:inherit;border-bottom:inherit;backdrop-filter:none;-webkit-backdrop-filter:none;border-radius:0 0 0 4px;
  clip-path:polygon(0 0,0 100%,100% 100%)}
.tg-narrow .tg-bubble i{left:50%;bottom:-8px;margin-left:-7px;border-left:none;border-right:inherit;border-radius:0 0 4px 0;clip-path:polygon(100% 0,100% 100%,0 100%)}
.tg-narrow .tg-bubble{max-width:none;font-size:13px;padding:9px 13px 11px}
.tg-side .tg-bubble i{left:auto;right:-8px;top:50%;bottom:auto;margin-top:-7px;border-left:none;border-bottom:none;
  border-top:inherit;border-right:inherit;border-radius:0 4px 0 0;clip-path:polygon(0 0,100% 0,100% 100%)}
.tg-below .tg-bubble{max-width:none;font-size:13px;padding:9px 13px 11px}
.tg-below .tg-bubble i{left:50%;top:-8px;bottom:auto;margin-left:-7px;border-left:inherit;border-bottom:none;
  border-top:inherit;border-radius:4px 0 0 0;clip-path:polygon(0 0,100% 0,0 100%)}
`;

let cssAdded = false;
function addCss() {
  if (cssAdded) return;
  cssAdded = true;
  const s = document.createElement('style');
  s.textContent = CSS;
  document.head.appendChild(s);
}

const col = (h) => new THREE.Color(h);
const lerp = (a, b, t) => a + (b - a) * t;
const clamp = (x, a, b) => Math.min(b, Math.max(a, x));
const damp = (a, b, k, dt) => lerp(a, b, 1 - Math.exp(-k * dt)); // frame-rate independent ease
const rand = (a, b) => a + Math.random() * (b - a);

// What the sky should look like for one hour of weather (from Flutter).
function skyFor(w) {
  const code = w.code ?? 0;
  const rain = w.rain ?? 0;
  const storm = code >= 95 || rain >= 7.5;
  const wet = storm || code >= 51 || rain >= 0.1;
  const overcast = (w.cloud ?? 0) >= 75 || code === 3 || code === 45 || code === 48;
  const h = w.hour ?? 12;
  const dusk = w.isDay && ((h >= 5.3 && h < 6.8) || (h >= 17.2 && h < 18.6));
  let kind;
  if (!w.isDay) kind = wet ? 'nightRain' : 'night';
  else if (storm) kind = 'storm';
  else if (wet) kind = 'rain';
  else if (overcast) kind = 'overcast';
  else if (dusk) kind = 'dusk';
  else kind = (w.cloud ?? 0) >= 35 ? 'partly' : 'clear';
  return {
    kind,
    storm,
    wet,
    night: !w.isDay,
    rain: storm ? Math.max(rain, 8) : wet ? Math.max(rain, 0.6) : 0,
    cloud: clamp(w.cloud ?? 0, 0, 100),
    wind: w.wind ?? 6,
    hour: h,
    mood: w.mood ?? 'stern',
  };
}

// ---------------------------------------------------------------- building blocks

function canvasTexture(size, draw) {
  const c = document.createElement('canvas');
  c.width = c.height = size;
  draw(c.getContext('2d'), size);
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  t.anisotropy = 4;
  return t;
}

// ---------------------------------------------------------------- the scene

function create(container, optsJson, cb) {
  addCss();
  const opts = JSON.parse(optsJson || '{}');
  const motion = !window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  const root = document.createElement('div');
  root.className = 'tg-stage' + (opts.dark === false ? ' tg-light' : '');
  container.appendChild(root);

  let renderer;
  try {
    renderer = new THREE.WebGLRenderer({ antialias: true, powerPreference: 'low-power' });
  } catch (e) {
    cb.onError?.('WebGL is not available');
    return { setWeather() {}, say() {}, pointer() {}, tap() {}, setActive() {}, setTheme() {}, setReserve() {}, destroy() { root.remove(); } };
  }
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.5));
  renderer.toneMapping = THREE.NeutralToneMapping;
  renderer.toneMappingExposure = 1.0;
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  root.appendChild(renderer.domElement);

  const bubble = document.createElement('div');
  bubble.className = 'tg-bubble';
  bubble.setAttribute('aria-hidden', 'true'); // Flutter's Semantics reads the line
  bubble.innerHTML = '<i></i><b>TUGAK</b><span></span>';
  root.appendChild(bubble);
  const bubbleText = bubble.querySelector('span');

  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(30, 1, 0.1, 2500);
  const pmrem = new THREE.PMREMGenerator(renderer);
  scene.environment = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;
  scene.environmentIntensity = 0.45;
  scene.background = col(STAGE);
  scene.fog = new THREE.Fog(col(STAGE), 16, 45); // the floor and far rain fade into the backdrop

  // --- backdrop: navy night, the kBlue pool, and a soft pool of the sky's colors behind his head
  const skyU = {
    top: { value: col(SKIES.clear[0]) },
    horizon: { value: col(SKIES.clear[1]) },
    stage: { value: col(STAGE) },
    pool: { value: col(POOL) },
    sunDir: { value: new THREE.Vector3(0.3, 0.5, -1).normalize() },
    glow: { value: col('#fff3d6') },
    glowAmt: { value: 0.35 },
    flash: { value: 0 },
  };
  const sky = new THREE.Mesh(
    new THREE.SphereGeometry(1200, 32, 16),
    new THREE.ShaderMaterial({
      uniforms: skyU,
      side: THREE.BackSide,
      depthWrite: false,
      fog: false,
      vertexShader: 'varying vec3 vDir; void main(){ vDir = normalize(position); gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0); }',
      fragmentShader: `
        uniform vec3 top, horizon, stage, pool, glow, sunDir; uniform float glowAmt, flash; varying vec3 vDir;
        void main(){
          vec3 d = normalize(vDir);
          vec3 skyc = mix(horizon, top, pow(smoothstep(-0.02, 0.75, d.y), 0.8));
          // strongest right behind him, gone at the card's edges and down at the floor line
          float m = pow(max(dot(d, normalize(vec3(0.0, 0.08, -1.0))), 0.0), 50.0) * smoothstep(-0.01, 0.12, d.y);
          // the landing hero's kBlue pool: wide and faint (in linear light 0.05 is plenty)
          float pm = pow(max(dot(d, normalize(vec3(0.0, 0.1, -1.0))), 0.0), 7.0) * smoothstep(0.0, 0.35, d.y); // gone at the horizon, where the fogged floor meets it
          vec3 c = mix(stage, pool, pm * 0.05);
          c = mix(c, skyc, m * 0.18); // the mix is in linear light: small numbers already show
          c += glow * pow(max(dot(d, sunDir), 0.0), 18.0) * glowAmt * 0.5 * m;
          c = mix(c, vec3(0.86, 0.9, 1.0), flash * (0.3 + 0.7 * m));
          gl_FragColor = vec4(c, 1.0);
          #include <colorspace_fragment>
        }`,
    })
  );
  scene.add(sky);

  // --- the sun (only its glow shows) and the moon
  const sun = new THREE.Object3D();
  const moonMat = new THREE.MeshBasicMaterial({ color: col('#e6ecff'), fog: false, transparent: true });
  const moon = new THREE.Mesh(new THREE.CircleGeometry(11, 40), moonMat);
  scene.add(sun, moon);

  // --- stars
  const starGeo = new THREE.BufferGeometry();
  const sp = [];
  for (let i = 0; i < 700; i++) {
    const a = Math.random() * Math.PI * 2;
    const y = rand(0.08, 1);
    const r = Math.sqrt(1 - y * y);
    sp.push(Math.cos(a) * r * 1100, y * 1100, Math.sin(a) * r * 1100);
  }
  starGeo.setAttribute('position', new THREE.Float32BufferAttribute(sp, 3));
  const starMat = new THREE.PointsMaterial({ color: 0xffffff, size: 1.6, sizeAttenuation: false, transparent: true, opacity: 0, fog: false, depthWrite: false });
  scene.add(new THREE.Points(starGeo, starMat));

  // --- the floor he sits on
  // no sheen: a shiny floor turns gray at the horizon
  const floor = new THREE.Mesh(new THREE.PlaneGeometry(400, 400), new THREE.MeshStandardMaterial({ color: col(FLOOR), roughness: 1, envMapIntensity: 0 }));
  floor.rotation.x = -Math.PI / 2;
  floor.receiveShadow = true;
  scene.add(floor);

  // a warm light at night (an unseen lamp up front, right)
  const lampLight = new THREE.PointLight(col('#ffd3a3'), 0, 22, 2);
  lampLight.position.set(4, 5.5, 5);
  scene.add(lampLight);

  // --- light: one key from the top left (like the app's glass edges), sky fill,
  // and a rim from behind in the sky's color
  const hemi = new THREE.HemisphereLight(col('#cfe3ff'), col('#1c2238'), 0.9);
  const key = new THREE.DirectionalLight(col('#fff4e2'), 2.4);
  key.position.set(-6, 10, 7);
  key.castShadow = true;
  key.shadow.mapSize.set(1024, 1024);
  key.shadow.camera.left = key.shadow.camera.bottom = -8;
  key.shadow.camera.right = key.shadow.camera.top = 8;
  key.shadow.camera.near = 1;
  key.shadow.camera.far = 30;
  key.shadow.radius = 4;
  key.shadow.bias = -0.0006;
  key.target.position.set(0, 1, 0);
  scene.add(hemi, key, key.target);
  const rimLight = new THREE.DirectionalLight(col('#cfe0ff'), 1.4);
  rimLight.position.set(0, 3.2, -14); // low: lights his edges, not the floor
  rimLight.target.position.set(0, 1.5, 0);
  scene.add(rimLight, rimLight.target);

  // --- rain: short lines falling behind him
  const RAIN_N = 1600;
  const rainPos = new Float32Array(RAIN_N * 6);
  const rainSeed = new Float32Array(RAIN_N * 4); // x, y, z, speed
  for (let i = 0; i < RAIN_N; i++) {
    rainSeed.set([rand(-26, 26), rand(-6, 16), rand(-40, -2), rand(0.8, 1.2)], i * 4);
  }
  const rainGeo = new THREE.BufferGeometry();
  rainGeo.setAttribute('position', new THREE.BufferAttribute(rainPos, 3));
  const rainMat = new THREE.LineBasicMaterial({ color: col('#cfd9e8'), transparent: true, opacity: 0, depthWrite: false });
  const rainLines = new THREE.LineSegments(rainGeo, rainMat);
  rainLines.frustumCulled = false;
  scene.add(rainLines);

  // ---------------------------------------------------------------- Tugak
  const tugak = new THREE.Group();
  scene.add(tugak);
  const parts = {}; // pivots by name: Body, EyeL/R, LidL/R, ArmL/R, Hat, MouthOpen
  const base = {}; // their rest pose
  const hitMeshes = [];
  let ready = false;

  const loader = new GLTFLoader();
  loader.setMeshoptDecoder(MeshoptDecoder);
  loader.load(
    MODEL,
    (gltf) => {
      tugak.add(gltf.scene);
      gltf.scene.traverse((o) => {
        if (o.isMesh) {
          o.castShadow = true;
          o.receiveShadow = true;
          hitMeshes.push(o);
        }
        if (['Body', 'EyeL', 'EyeR', 'LidL', 'LidR', 'ArmL', 'ArmR', 'Hat', 'MouthOpen'].includes(o.name)) {
          parts[o.name] = o;
          base[o.name] = { p: o.position.clone(), q: o.quaternion.clone(), s: o.scale.clone() };
        }
      });
      ready = true;
      layout();
      requestFrame();
      // Show the first drawn frame, not an empty canvas.
      requestAnimationFrame(() => {
        root.classList.add('tg-ready');
        cb.onReady?.();
      });
    },
    undefined,
    (err) => cb.onError?.(String(err && err.message ? err.message : err))
  );

  // ---------------------------------------------------------------- state

  let sky0 = skyFor(opts.weather || { isDay: true, hour: 12, cloud: 30 });
  const cur = {
    top: col(SKIES[sky0.kind][0]),
    horizon: col(SKIES[sky0.kind][1]),
    cover: sky0.cloud,
    rain: sky0.rain,
    night: sky0.night ? 1 : 0,
    wet: sky0.wet ? 1 : 0,
    hour: sky0.hour,
  };
  let target = sky0;
  let lidRest = 0; // added to the model's resting lid angle, by mood
  const pointerAt = new THREE.Vector2(0, 0);
  const gaze = new THREE.Vector2(0, 0);
  let blinkT = 2;
  let blinkPhase = -1;
  let tipT = -1;
  let talkUntil = 0;
  let flash = 0;
  let nextFlash = 3;
  let typing = null;
  let active = true;
  let visible = true;
  let onScreen = true;
  let raf = 0;
  let last = performance.now();
  let narrow = false;
  let reserve = { left: 0, top: 0, bottom: 0, bubble: '', ...opts.reserve };

  function setWeather(json) {
    const w = JSON.parse(json);
    target = skyFor(w);
    lidRest = { stern: 0, alert: -0.3, sleepy: 0.32, wet: 0.05 }[target.mood] ?? 0;
    requestFrame();
  }

  // Types the line out while his mouth moves.
  function say(text) {
    clearInterval(typing);
    bubbleText.textContent = '';
    bubble.classList.add('tg-on');
    const chars = [...String(text)];
    const start = performance.now();
    talkUntil = start + (motion ? chars.length * 33 : 0);
    typing = setInterval(() => {
      const i = motion ? Math.min(chars.length, Math.floor((performance.now() - start) / 33) + 1) : chars.length;
      bubbleText.textContent = chars.slice(0, i).join('');
      placeBubble();
      if (i >= chars.length) clearInterval(typing);
    }, 33);
    requestFrame();
  }

  function pointer(x, y) {
    pointerAt.set(clamp(x, -1, 1), clamp(y, -1, 1));
    requestFrame();
  }

  // x, y in -1..1 over the stage. Returns what was hit: 'tugak' or ''.
  const ray = new THREE.Raycaster();
  function tap(x, y) {
    pointer(x, y);
    ray.setFromCamera(new THREE.Vector2(x, y), camera);
    if (ray.intersectObjects(hitMeshes, false).length) {
      if (motion) tipT = 0;
      requestFrame();
      return 'tugak';
    }
    return '';
  }

  function setActive(a, v) {
    active = a;
    visible = v;
    requestFrame();
  }

  function setTheme(dark) {
    root.classList.toggle('tg-light', !dark);
  }

  function setReserve(json) {
    reserve = { left: 0, top: 0, bottom: 0, bubble: '', ...JSON.parse(json) };
    layout();
    placeBubble();
  }

  // ---------------------------------------------------------------- framing

  let W = 1;
  let H = 1;
  function layout() {
    W = Math.max(1, container.clientWidth);
    H = Math.max(1, container.clientHeight);
    renderer.setSize(W, H, false);
    // the part Flutter leaves free (setReserve): Tugak is framed in that
    const Wa = Math.max(1, W - reserve.left);
    const Ha = Math.max(1, H - reserve.top - reserve.bottom);
    const a = Wa / Ha;
    narrow = !reserve.bubble && a < 1.15;
    root.classList.toggle('tg-narrow', narrow);
    root.classList.toggle('tg-side', reserve.bubble === 'side');
    root.classList.toggle('tg-below', reserve.bubble === 'below');
    camera.fov = 30;
    if (reserve.left || reserve.top || reserve.bottom) camera.setViewOffset(Wa, Ha, -reserve.left, -reserve.top, W, H);
    else {
      camera.clearViewOffset();
      camera.aspect = a;
    }
    // Tugak in the middle; a little further back on narrow screens.
    const look = new THREE.Vector3(0, 2.35, 0);
    const dist = (a < (reserve.bubble ? 0.75 : 0.9) ? 13.6 : 12.4) / (reserve.zoom || 1); // beside the readings he only needs his own half; zoom: phones
    camera.position.set(0, 1.9, dist);
    camera.lookAt(look);
    camera.updateProjectionMatrix();
    camera.userData.look = look;
    camera.userData.y = 1.9;
    requestFrame();
  }
  const ro = new ResizeObserver(layout);
  ro.observe(container);
  const io = new IntersectionObserver((e) => {
    onScreen = e[e.length - 1].isIntersecting;
    requestFrame();
  });
  io.observe(container);
  const onVis = () => requestFrame();
  document.addEventListener('visibilitychange', onVis);

  const headPt = new THREE.Vector3();
  function placeBubble() {
    if (!ready) return;
    const s = bubble.style;
    s.transform = s.bottom = s.maxWidth = '';
    // 'auto', not '': the stylesheet's top: 0 would come back and stretch it
    if (reserve.bubble === 'side') {
      s.top = 'auto';
      s.right = '';
      s.left = '16px';
      s.bottom = Math.max(16, reserve.bottom) + 'px';
      s.maxWidth = Math.max(160, reserve.left - 30) + 'px';
      return;
    }
    if (reserve.bubble === 'below') {
      s.top = 'auto';
      s.left = s.right = '12px';
      s.bottom = '12px';
      return;
    }
    if (narrow) {
      s.left = s.right = s.top = '12px';
      return;
    }
    s.right = '';
    headPt.set(1.45, 3.0, 0.4).applyMatrix4(tugak.matrixWorld).project(camera);
    const x = (headPt.x * 0.5 + 0.5) * W + 18;
    const y = (-headPt.y * 0.5 + 0.5) * H - bubble.offsetHeight + 8;
    bubble.style.left = clamp(x, 8, W - bubble.offsetWidth - 8) + 'px';
    bubble.style.top = clamp(y, 8, H - bubble.offsetHeight - 8) + 'px';
  }

  // ---------------------------------------------------------------- animation

  const q = new THREE.Quaternion();
  const e3 = new THREE.Euler();
  const tmp = new THREE.Vector3();
  const box = new THREE.Box3();

  function running() {
    return active && visible && onScreen && !document.hidden;
  }

  function requestFrame() {
    if (!raf && running()) raf = requestAnimationFrame(frame);
  }

  function frame(now) {
    raf = 0;
    const dt = Math.min(0.05, (now - last) / 1000);
    last = now;
    const t = now / 1000;
    let busy = update(dt, t, now);
    renderer.render(scene, camera);
    placeBubble();
    // Keep drawing while something moves; with reduced motion only until it settles.
    if (motion || busy) requestFrame();
  }

  function update(dt, t, now) {
    let busy = false;
    const k = 2.2; // how fast the sky follows the scrubber
    const s = target;
    // sky
    cur.top.lerp(col(SKIES[s.kind][0]), 1 - Math.exp(-k * dt));
    cur.horizon.lerp(col(SKIES[s.kind][1]), 1 - Math.exp(-k * dt));
    cur.cover = damp(cur.cover, s.cloud, k, dt);
    cur.rain = damp(cur.rain, s.rain, k, dt);
    cur.night = damp(cur.night, s.night ? 1 : 0, k, dt);
    cur.wet = damp(cur.wet, s.wet ? 1 : 0, k * 0.5, dt);
    cur.hour = damp(cur.hour, s.hour, k, dt);
    busy ||= Math.abs(cur.cover - s.cloud) > 0.5 || Math.abs(cur.night - (s.night ? 1 : 0)) > 0.01 || Math.abs(cur.hour - s.hour) > 0.02;

    skyU.top.value.copy(cur.top);
    skyU.horizon.value.copy(cur.horizon);

    // sun / moon across the sky with the hour (we look east-ish: morning on the right)
    const h = cur.hour;
    const dayArc = clamp((h - 6) / 12, 0, 1);
    const nightArc = clamp(((h + 24 - 18) % 24) / 12, 0, 1);
    const place = (obj, arc, dist) => {
      const a = lerp(0.15, Math.PI - 0.15, arc);
      tmp.set(Math.cos(a) * 0.85, Math.sin(a) * 0.55 + 0.08, -1).normalize().multiplyScalar(dist);
      obj.position.copy(tmp);
      obj.lookAt(camera.position);
    };
    place(sun, dayArc, 900);
    place(moon, nightArc, 900);
    const clearness = clamp(1 - cur.cover / 90, 0, 1) * (1 - cur.wet);
    moonMat.opacity = cur.night * lerp(0.15, 0.8, clearness);
    skyU.sunDir.value.copy(cur.night > 0.5 ? moon.position : sun.position).normalize();
    skyU.glowAmt.value = lerp(0.45, 0.2, cur.night) * lerp(0.2, 1, clearness);
    starMat.opacity = cur.night * clearness * 0.6;

    // light
    const dim = lerp(1, 0.55, cur.wet) * lerp(1, 0.75, clamp(cur.cover / 100, 0, 1));
    key.intensity = lerp(2.6 * dim, 0.9, cur.night); // moonlight at night: he must still read
    key.color.copy(col('#fff1dc')).lerp(col('#9fb4ff'), cur.night);
    hemi.intensity = lerp(1.0, 0.3, cur.night);
    hemi.color.copy(cur.horizon).lerp(col('#ffffff'), 0.4);
    scene.environmentIntensity = lerp(0.5, 0.1, cur.night);
    lampLight.intensity = cur.night * 22;
    // the sky behind him rims his edges in its color
    const daylight = (1 - cur.night) * lerp(1, 0.55, cur.wet);
    rimLight.intensity = lerp(0.25, 1.6 * daylight, 1 - cur.night) + (flash > 0 ? 3 * flash : 0);
    rimLight.color.copy(cur.horizon).lerp(col('#ffffff'), 0.35);

    // rain
    const heavy = clamp(cur.rain / 8, 0, 1);
    const showN = Math.round(RAIN_N * clamp(cur.rain / 4, 0, 1) * (0.35 + 0.65 * heavy));
    rainMat.opacity = cur.rain > 0.05 ? lerp(0.32, 0.55, heavy) * lerp(1, 0.7, cur.night) : 0;
    rainGeo.setDrawRange(0, showN * 2);
    if (showN > 0) {
      const len = lerp(0.45, 0.95, heavy);
      const slant = clamp(target.wind / 40, 0, 0.6);
      for (let i = 0; i < showN; i++) {
        const o = i * 4;
        if (motion) {
          rainSeed[o + 1] -= dt * 22 * rainSeed[o + 3];
          rainSeed[o] += dt * 22 * slant * rainSeed[o + 3];
          if (rainSeed[o + 1] < -6) {
            rainSeed[o + 1] = 16;
            rainSeed[o] = rand(-26, 26);
          }
        }
        const x = rainSeed[o], y = rainSeed[o + 1], z = rainSeed[o + 2];
        rainPos.set([x, y, z, x - slant * len, y + len, z], i * 6);
      }
      rainGeo.attributes.position.needsUpdate = true;
    }

    // lightning
    if (target.storm && motion) {
      nextFlash -= dt;
      if (nextFlash < 0) {
        flash = 1;
        nextFlash = rand(3.5, 9);
      }
    }
    if (flash > 0) {
      flash = Math.max(0, flash - dt * 4.5);
      const f = flash > 0.55 ? 1 : flash > 0.3 ? 0.25 : flash;
      skyU.flash.value = f * 0.35;
      hemi.intensity += f * 2.5;
      busy = true;
    } else skyU.flash.value = 0;

    if (ready) busy = animateTugak(dt, t, now) || busy;
    // camera: a slow sway against the pointer = depth
    const look = camera.userData.look;
    if (look) {
      const sway = motion ? 1 : 0;
      camera.position.x = damp(camera.position.x, look.x - pointerAt.x * 0.45 * sway, 3, dt);
      camera.position.y = damp(camera.position.y, camera.userData.y + pointerAt.y * 0.2 * sway, 3, dt);
      camera.lookAt(look);
    }
    return busy;
  }

  function setPart(name, { rot = null, pos = null, scl = null } = {}) {
    const p = parts[name];
    if (!p) return;
    const b = base[name];
    p.quaternion.copy(b.q);
    if (rot) p.quaternion.multiply(q.setFromEuler(e3.set(rot[0], rot[1], rot[2])));
    p.position.copy(b.p);
    if (pos) p.position.add(tmp.set(pos[0], pos[1], pos[2]));
    p.scale.copy(b.s);
    if (scl) p.scale.multiply(tmp.set(scl[0], scl[1], scl[2]));
  }

  function animateTugak(dt, t, now) {
    let busy = false;
    // breathing: a slow rise and a fuller belly
    const br = motion ? Math.sin(t * 1.7) : 0;
    tugak.scale.set(1, 1 + br * 0.006, 1);
    setPart('Body', { scl: [1 + br * 0.01, 1, 1 + br * 0.014] });

    // eyes follow the pointer, a little lag
    gaze.x = damp(gaze.x, pointerAt.x, 6, dt);
    gaze.y = damp(gaze.y, pointerAt.y, 6, dt);
    const yaw = gaze.x * 0.32;
    const pitch = -gaze.y * 0.2;
    setPart('EyeL', { rot: [pitch, yaw, 0] });
    setPart('EyeR', { rot: [pitch, yaw, 0] });
    tugak.rotation.y = damp(tugak.rotation.y, gaze.x * 0.1, 3, dt);

    // blinking: every 2.5-6 s, now and then twice
    if (motion) {
      blinkT -= dt;
      if (blinkT < 0 && blinkPhase < 0) {
        blinkPhase = 0;
        blinkT = Math.random() < 0.2 ? 0.28 : rand(2.5, 6);
      }
    }
    let close = 0;
    if (blinkPhase >= 0) {
      blinkPhase += dt / 0.17;
      close = Math.sin(Math.min(1, blinkPhase) * Math.PI);
      if (blinkPhase >= 1) blinkPhase = -1;
    }
    const lid = lidRest + close * 1.5;
    setPart('LidL', { rot: [lid, 0, 0] });
    setPart('LidR', { rot: [lid, 0, 0] });

    // talking while the line types out
    const talking = now < talkUntil;
    const open = talking ? 0.35 + 0.65 * Math.abs(Math.sin(t * 17) * Math.sin(t * 6.3)) : 0.02;
    const mo = parts.MouthOpen;
    if (mo) {
      const cs = mo.userData.open ?? 0.02;
      mo.userData.open = damp(cs, open, 25, dt);
      setPart('MouthOpen', { scl: [1, 1, 1] });
      // the model's open mouth is scaled along Blender's z = three's y
      mo.scale.y = base.MouthOpen.s.y * (mo.userData.open / 0.02);
    }

    // hat tip: lift and tilt the hat, raise the right arm, then settle
    if (tipT >= 0) {
      tipT += dt / 1.3;
      const u = Math.sin(Math.min(1, tipT) * Math.PI);
      setPart('Hat', { rot: [-0.32 * u, 0, -0.12 * u], pos: [0.1 * u, 0.32 * u, 0.08 * u] });
      setPart('ArmR', { rot: [-2.5 * u, 0, 0.35 * u] });
      if (tipT >= 1) tipT = -1;
      busy = true;
    } else {
      setPart('Hat');
      setPart('ArmR');
    }

    return busy || talking || blinkPhase >= 0;
  }

  function destroy() {
    cancelAnimationFrame(raf);
    clearInterval(typing);
    ro.disconnect();
    io.disconnect();
    document.removeEventListener('visibilitychange', onVis);
    renderer.dispose();
    pmrem.dispose();
    root.remove();
  }

  layout();
  return { setWeather, say, pointer, tap, setActive, setTheme, setReserve, destroy };
}

window.agosTugak = { create };
