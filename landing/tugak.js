// ============================================================
// The live 3D Tugak in the landing page's hero.
// ============================================================
//
// The same model and three.js as the app's Weather tab (web/tugak/, served at
// app/tugak/ next to this page by the deploy), so there's one copy of each.
// No backdrop here: a transparent canvas over the page's night sky. He
// breathes, blinks, follows the pointer with his eyes, talks while his
// bubble types (landing.js sends 'tugak-talk'), and tips his hat when
// clicked. Motions are the app's (web/tugak/scene.js, animateTugak).
//
// Until the model is drawn, and if anything fails (no WebGL, no app/
// folder), the still image img/tugak/hero.webp stays (tools/tugak3d.py
// --poses renders it from the same angle).
//
// Only draws while the hero is on screen and the tab is visible.

import * as THREE from './app/tugak/three/three.module.min.js';
import { GLTFLoader } from './app/tugak/three/GLTFLoader.js';
import { MeshoptDecoder } from './app/tugak/three/meshopt_decoder.module.js';
import { RoomEnvironment } from './app/tugak/three/RoomEnvironment.js';

const box = document.getElementById('tugak3d');
const motion = !matchMedia('(prefers-reduced-motion: reduce)').matches;
const damp = (a, b, k, dt) => a + (b - a) * (1 - Math.exp(-k * dt));
const rand = (a, b) => a + Math.random() * (b - a);

function start() {
  let renderer;
  try {
    renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true, powerPreference: 'low-power' });
  } catch (e) {
    return; // no WebGL: the still image stays
  }
  renderer.setClearColor(0x000000, 0);
  renderer.setPixelRatio(Math.min(devicePixelRatio || 1, 1.75));
  renderer.toneMapping = THREE.NeutralToneMapping;
  box.appendChild(renderer.domElement);

  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(30, 1, 0.1, 100);
  const pmrem = new THREE.PMREMGenerator(renderer);
  scene.environment = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;
  scene.environmentIntensity = 0.5;

  // Lights like the Blender renders: warm key from the top left (the app's
  // light direction), a cool kBlue-ish rim from behind left, a soft fill.
  scene.add(new THREE.HemisphereLight(0xcfe3ff, 0x1a1d2a, 0.9));
  const key = new THREE.DirectionalLight(0xfff1dc, 2.6);
  key.position.set(-6, 10, 7);
  const rim = new THREE.DirectionalLight(0x7fb4ff, 2.4);
  rim.position.set(-5, 3.5, -6);
  const rim2 = new THREE.DirectionalLight(0xcfe0ff, 1.2);
  rim2.position.set(5, 4, -8);
  const fill = new THREE.DirectionalLight(0xffffff, 0.5);
  fill.position.set(5, 2, 4);
  scene.add(key, rim, rim2, fill);

  const tugak = new THREE.Group();
  scene.add(tugak);
  const parts = {};
  const base = {};
  let ready = false;
  let center = new THREE.Vector3();
  let size = new THREE.Vector3(1, 1, 1);

  const loader = new GLTFLoader();
  loader.setMeshoptDecoder(MeshoptDecoder);
  loader.load(
    new URL('./app/tugak/tugak.glb', import.meta.url).href,
    (gltf) => {
      tugak.add(gltf.scene);
      gltf.scene.traverse((o) => {
        if (['Body', 'EyeL', 'EyeR', 'LidL', 'LidR', 'ArmL', 'ArmR', 'Hat', 'MouthOpen'].includes(o.name)) {
          parts[o.name] = o;
          base[o.name] = { p: o.position.clone(), q: o.quaternion.clone(), s: o.scale.clone() };
        }
      });
      const bb = new THREE.Box3().setFromObject(tugak);
      bb.getCenter(center);
      bb.getSize(size);
      ready = true;
      layout();
      frame(performance.now());
      requestAnimationFrame(() => box.classList.add('ready'));
    },
    undefined,
    () => renderer.domElement.remove() // keep the still image
  );

  // Frame him like the still: centered, feet at the bottom, a little margin.
  let W = 1, H = 1;
  function layout() {
    W = Math.max(1, box.clientWidth);
    H = Math.max(1, box.clientHeight);
    renderer.setSize(W, H, false);
    camera.aspect = W / H;
    const half = Math.max(size.y / 2, size.x / 2 / camera.aspect) * 1.04;
    const dist = half / Math.tan(THREE.MathUtils.degToRad(camera.fov / 2)) + size.z / 2;
    camera.position.set(center.x, center.y + 0.15, center.z + dist);
    camera.lookAt(center.x, center.y, center.z);
    camera.updateProjectionMatrix();
    requestFrame();
  }
  new ResizeObserver(layout).observe(box);

  // ---- input: eyes follow the pointer anywhere on the page; click = hat tip
  const pointer = new THREE.Vector2();
  const gaze = new THREE.Vector2();
  addEventListener('pointermove', (e) => {
    const r = box.getBoundingClientRect();
    pointer.set(
      THREE.MathUtils.clamp((e.clientX - (r.left + r.width / 2)) / (innerWidth / 2), -1, 1),
      THREE.MathUtils.clamp((e.clientY - (r.top + r.height * 0.35)) / (innerHeight / 2), -1, 1)
    );
    requestFrame();
  });
  let tipT = -1;
  box.addEventListener('click', () => {
    if (motion) tipT = 0;
    requestFrame();
  });
  let talkUntil = 0;
  document.addEventListener('tugak-talk', (e) => {
    talkUntil = performance.now() + (motion ? e.detail : 0);
    requestFrame();
  });

  // ---- only draw while visible
  let onScreen = true;
  let raf = 0;
  let last = performance.now();
  new IntersectionObserver((e) => {
    onScreen = e[e.length - 1].isIntersecting;
    requestFrame();
  }).observe(box);
  document.addEventListener('visibilitychange', () => requestFrame());
  function requestFrame() {
    if (!raf && ready && onScreen && !document.hidden) raf = requestAnimationFrame(frame);
  }
  function frame(now) {
    raf = 0;
    const dt = Math.min(0.05, (now - last) / 1000);
    last = now;
    const busy = animate(dt, now / 1000, now);
    renderer.render(scene, camera);
    if (motion || busy) requestFrame();
  }

  // ---- the motions (same numbers as scene.js)
  const q = new THREE.Quaternion();
  const e3 = new THREE.Euler();
  const tmp = new THREE.Vector3();
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

  let blinkT = 2;
  let blinkPhase = -1;
  function animate(dt, t, now) {
    let busy = false;
    const br = motion ? Math.sin(t * 1.7) : 0;
    tugak.scale.set(1, 1 + br * 0.006, 1);
    setPart('Body', { scl: [1 + br * 0.01, 1, 1 + br * 0.014] });

    gaze.x = damp(gaze.x, pointer.x, 6, dt);
    gaze.y = damp(gaze.y, pointer.y, 6, dt);
    setPart('EyeL', { rot: [-gaze.y * 0.2, gaze.x * 0.32, 0] });
    setPart('EyeR', { rot: [-gaze.y * 0.2, gaze.x * 0.32, 0] });
    tugak.rotation.y = damp(tugak.rotation.y, gaze.x * 0.18, 3, dt);
    busy ||= Math.abs(gaze.x - pointer.x) + Math.abs(gaze.y - pointer.y) > 0.002;

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
    setPart('LidL', { rot: [close * 1.5, 0, 0] });
    setPart('LidR', { rot: [close * 1.5, 0, 0] });

    const talking = now < talkUntil;
    const mo = parts.MouthOpen;
    if (mo) {
      const open = talking ? 0.35 + 0.65 * Math.abs(Math.sin(t * 17) * Math.sin(t * 6.3)) : 0.02;
      mo.userData.open = damp(mo.userData.open ?? 0.02, open, 25, dt);
      setPart('MouthOpen');
      mo.scale.y = base.MouthOpen.s.y * (mo.userData.open / 0.02); // Blender's z = three's y
    }

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
}

if (box) start();
