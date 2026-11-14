// ============================================================
// AgosAlert map: MapLibre GL (WebGL vector map) inside the Flutter app.
// ============================================================
//
// Flutter can't draw a 3D vector map itself, so the Map tab puts a plain
// <div> in the page (an HtmlElementView, see lib/widgets/agos_map_web.dart)
// and this file draws the map into it. Dart talks to it through
// window.agosMap: load() once, then create() a map and call its methods.
//
// Everything the map shows is served with the app (web/map/, built by
// tools/make_map.py): tiles, terrain, label font, styles, MapLibre itself.
// Nothing is fetched from anyone else's server.
//
// Pins are DOM elements (MapLibre "markers"), not Flutter widgets: they move
// in the same frame as the map, so they never lag behind a drag, and CSS
// gives them their spring and pulse animations.
(function () {
  'use strict';

  let loading = null;

  // Adds MapLibre's script + CSS and this file's own CSS, once.
  function load() {
    if (loading) return loading;
    loading = new Promise((resolve, reject) => {
      const css = document.createElement('link');
      css.rel = 'stylesheet';
      css.href = 'map/maplibre-gl.css';
      document.head.appendChild(css);
      const style = document.createElement('style');
      style.textContent = CSS;
      document.head.appendChild(style);
      const js = document.createElement('script');
      js.src = 'map/maplibre-gl.js';
      js.onload = () => resolve();
      js.onerror = () => {
        loading = null;
        reject(new Error('MapLibre failed to load'));
      };
      document.head.appendChild(js);
    });
    return loading;
  }

  // Flutter's font assets, reused for the pins' text and icons.
  const CSS = `
@font-face{font-family:AgInter;font-weight:500;src:url(assets/assets/fonts/Inter-Regular.ttf)}
@font-face{font-family:AgInter;font-weight:600;src:url(assets/assets/fonts/Inter-SemiBold.ttf)}
@font-face{font-family:AgInter;font-weight:700;src:url(assets/assets/fonts/Inter-Bold.ttf)}
@font-face{font-family:AgInter;font-weight:800;src:url(assets/assets/fonts/Inter-ExtraBold.ttf)}
@font-face{font-family:AgCupertino;src:url(assets/packages/cupertino_icons/assets/CupertinoIcons.ttf)}
@font-face{font-family:AgIcons;src:url(assets/assets/fonts/AgosIcons.ttf)}

.ag-map{position:absolute;inset:0;transition:filter .35s ease;--surface:#1C1C1E;--text:#F5F5F7;--muted:#98989F;--halo:#000}
.ag-map.ag-light{--surface:#fff;--text:#1D1D1F;--muted:#6E6E73;--halo:#fff}
/* Behind a sheet or popup the map softly blurs, like iOS. */
.ag-map.ag-inactive{filter:blur(7px) saturate(1.3);pointer-events:none}
.ag-map.ag-hidden{pointer-events:none}
.ag-map .maplibregl-canvas{outline:none}

.ag-pin{width:0;height:0;cursor:pointer;-webkit-tap-highlight-color:transparent}
.ag-pin *{box-sizing:border-box}
.ag-pin.ag-off{display:none}
.ag-drop{position:absolute;left:0;top:0;animation:ag-drop .7s cubic-bezier(.34,1.56,.64,1) both;animation-delay:var(--delay,0s)}
@keyframes ag-drop{from{opacity:0;transform:translateY(-26px)}to{opacity:1;transform:none}}

/* Soft contact shadow where the pin touches the ground. */
.ag-shadow{position:absolute;left:-9px;top:-3px;width:18px;height:6px;border-radius:50%;background:rgba(0,0,0,.35);filter:blur(2px)}
/* High-risk pins send out a ring on the ground, like a radar ping. */
.ag-ring{position:absolute;left:-36px;top:-16px;width:72px;height:32px;border-radius:50%;background:var(--c);opacity:0;animation:ag-ping 2s cubic-bezier(.2,.6,.35,1) infinite}
@keyframes ag-ping{0%{transform:scale(.15);opacity:.55}100%{transform:scale(1.25);opacity:0}}

/* The balloon: tip exactly on the spot, white icon in the round head. */
.ag-head{position:absolute;left:-17px;bottom:0;width:34px;height:43px;transform-origin:50% 100%;transition:transform .45s cubic-bezier(.34,1.56,.64,1)}
.ag-head svg{position:absolute;inset:0;width:100%;height:100%;overflow:visible;filter:drop-shadow(0 3px 5px rgba(0,0,0,.35))}
.ag-head path{fill:var(--c);stroke:#fff;stroke-width:2.2}
.ag-glyph{position:absolute;left:0;right:0;top:7px;text-align:center;color:#fff;font-size:17px;line-height:20px;font-style:normal}
.ag-pin:hover .ag-head{transform:scale(1.08)}
.ag-pin.ag-sel .ag-head{transform:scale(1.32)}

/* Shelters: a rounded square badge, so they never read as a flood pin. */
.ag-shelter .ag-head{left:-16px;bottom:-16px;width:32px;height:32px;transform-origin:50% 50%}
.ag-shelter .ag-badge{position:absolute;inset:0;border-radius:10px;background:var(--c);border:2.2px solid #fff;box-shadow:0 3px 8px rgba(0,0,0,.35)}
.ag-shelter .ag-glyph{top:6px;font-size:16px}
.ag-shelter .ag-shadow{display:none}

/* Label under the pin: depth chip, then the place name. */
.ag-label{position:absolute;left:0;top:7px;transform:translateX(-50%);display:flex;flex-direction:column;align-items:center;gap:2px;pointer-events:none;white-space:nowrap;font-family:AgInter,system-ui,sans-serif}
.ag-shelter .ag-label{top:20px}
.ag-chip{display:flex;align-items:center;gap:5px;padding:3px 8px 3px 6px;border-radius:20px;background:var(--surface);color:var(--text);font-size:11.5px;font-weight:800;letter-spacing:-.01em;font-variant-numeric:tabular-nums;box-shadow:0 2px 6px rgba(0,0,0,.25),inset 0 0 0 .5px rgba(127,127,127,.25)}
.ag-chip i{width:7px;height:7px;border-radius:50%;background:var(--c)}
.ag-name{font-size:11px;font-weight:600;color:var(--muted);text-shadow:0 0 2px var(--halo),0 0 2px var(--halo),0 0 3px var(--halo)}
/* Shelter names only once zoomed in (they're long). */
.ag-shelter .ag-name{opacity:0;transition:opacity .25s}
.ag-near .ag-shelter .ag-name,.ag-shelter.ag-sel .ag-name{opacity:1}
.ag-pin.ag-sel .ag-name{color:var(--text)}

/* MapLibre's credits button: small glass, out of the way. */
.ag-map .maplibregl-ctrl-bottom-right{bottom:var(--ag-pb,0px)}
.ag-map .maplibregl-ctrl-attrib{font-family:AgInter,system-ui,sans-serif;font-size:10px}
.ag-map .maplibregl-ctrl.maplibregl-ctrl-attrib.maplibregl-compact{background:var(--surface);color:var(--muted);border-radius:12px;opacity:.9;min-height:24px}
.ag-map .maplibregl-ctrl-attrib a{color:var(--muted)}
.ag-dark .maplibregl-ctrl-attrib-button{filter:invert(1)}
@media (prefers-reduced-motion:reduce){.ag-drop,.ag-ring,.ag-head{animation:none!important;transition:none!important}}
`;

  // The balloon outline (34 x 43 box, tip at the bottom middle). Same shape
  // as the old Flutter pin.
  const BALLOON = 'M17 42C14 34 1 29 1 17A16 16 0 1 1 33 17C33 29 20 34 17 42Z';

  // A circle of `meters` around [lng, lat], as a GeoJSON polygon.
  function circle(lng, lat, meters) {
    const pts = [];
    const dLat = meters / 111320;
    const dLng = meters / (111320 * Math.cos((lat * Math.PI) / 180));
    for (let i = 0; i <= 64; i++) {
      const a = (i / 64) * 2 * Math.PI;
      pts.push([lng + dLng * Math.cos(a), lat + dLat * Math.sin(a)]);
    }
    return [pts];
  }

  function create(container, o, cb) {
    const opts = JSON.parse(o);
    const root = document.createElement('div');
    root.className = 'ag-map';
    container.appendChild(root);
    let theme = opts.theme;
    let pins = [];
    let zones = [];
    let selected = null;
    let want3d = false;
    let didLoad = false;
    const markers = new Map();
    const hidden = new Set();

    const map = new maplibregl.Map({
      container: root,
      style: `map/style-${theme}.json`,
      center: opts.center,
      zoom: opts.zoom,
      minZoom: opts.minZoom,
      maxZoom: 18.5,
      maxPitch: 65,
      maxBounds: opts.bounds,
      interactive: opts.interactive,
      attributionControl: opts.interactive ? { compact: true } : false,
      fadeDuration: 180,
      // The style lists its files relative to the app (map/tiles/...).
      // Tiles are fetched inside a Web Worker, where a relative address
      // means nothing, so turn every address into a full one first.
      transformRequest: (url) => ({ url: new URL(url, document.baseURI).href }),
    });
    root.classList.add(`ag-${theme}`);
    // A still preview (Report screen): touches go to the page around it,
    // so it can still be scrolled with a finger on the map.
    if (!opts.interactive) root.style.pointerEvents = 'none';
    // Two fingers can turn the map; the app then shows a compass (Flutter
    // side) to turn it back north.

    // ---- layers that aren't in the style file (re-added after a theme switch)
    function addOwnLayers() {
      if (!map.getSource('zones')) {
        map.addSource('zones', { type: 'geojson', data: zonesGeo() });
        const before = map.getLayer('building') ? 'building' : undefined;
        map.addLayer(
          {
            id: 'zones-fill',
            type: 'fill',
            source: 'zones',
            paint: { 'fill-color': ['get', 'color'], 'fill-opacity': 0.16 },
          },
          before,
        );
        map.addLayer(
          {
            id: 'zones-line',
            type: 'line',
            source: 'zones',
            paint: {
              'line-color': ['get', 'color'],
              'line-opacity': 0.7,
              'line-width': ['interpolate', ['linear'], ['zoom'], 13, 1, 17, 2.5],
              'line-dasharray': [2, 1.5],
            },
          },
          before,
        );
      }
      if (!map.getSource('dem3d')) {
        // Terrain needs its own copy of the elevation source (sharing the
        // hill-shading one makes MapLibre warn and draw it worse).
        const dem = map.getStyle().sources.dem;
        if (dem) map.addSource('dem3d', { ...dem });
      }
      zonesVisible();
      apply3d(map.getPitch());
    }

    // Where the map draws a place's name ("San Francisco" -> its OSM place
    // point), from the tiles already loaded; null if it isn't loaded.
    function placeLabel(name) {
      const want = name.toLowerCase();
      const f = map
        .querySourceFeatures('base', { sourceLayer: 'places' })
        .find((f) => f.geometry.type === 'Point' && String(f.properties.name || '').toLowerCase().replace(/^(barangay|brgy\.?)\s+/, '') === want);
      return f ? f.geometry.coordinates : null;
    }

    function zonesGeo() {
      return {
        type: 'FeatureCollection',
        features: zones.map((z) => ({
          type: 'Feature',
          properties: { color: z.color },
          geometry: { type: 'Polygon', coordinates: circle(z.lng, z.lat, z.radius) },
        })),
      };
    }

    function zonesVisible() {
      const v = hidden.has('flood') ? 'none' : 'visible';
      for (const id of ['zones-fill', 'zones-line']) if (map.getLayer(id)) map.setLayoutProperty(id, 'visibility', v);
    }

    // 3D buildings fade in with the tilt, so the flat view stays clean and
    // fast, and tilting (with two fingers, or the 3D button) raises them.
    let terrainOn = false;
    function apply3d(pitch) {
      const t = Math.max(0, Math.min(1, (pitch - 8) / 22));
      if (map.getLayer('building-3d')) {
        map.setPaintProperty('building-3d', 'fill-extrusion-opacity', 0.94 * t);
        map.setPaintProperty('building', 'fill-opacity', ['interpolate', ['linear'], ['zoom'], 14, 0, 15, 1 - t]);
      }
      const on = pitch > 12;
      if (on !== terrainOn && map.getSource('dem3d')) {
        terrainOn = on;
        map.setTerrain(on ? { source: 'dem3d', exaggeration: 1.3 } : null);
      }
    }

    // ---- pins
    function glyph(p) {
      const i = document.createElement('i');
      i.className = 'ag-glyph';
      i.style.fontFamily = p.font === 'AgosIcons' ? 'AgIcons' : 'AgCupertino';
      i.textContent = String.fromCodePoint(p.glyph);
      return i;
    }

    function pinElement(p, index) {
      const el = document.createElement('div');
      el.className = `ag-pin ag-${p.kind}`;
      el.style.setProperty('--c', p.color);
      el.setAttribute('role', 'button');
      el.setAttribute('aria-label', p.a11y);
      el.tabIndex = 0;
      const drop = document.createElement('div');
      drop.className = 'ag-drop';
      drop.style.setProperty('--delay', `${0.05 * index}s`);
      if (p.pulse) {
        const r = document.createElement('div');
        r.className = 'ag-ring';
        drop.appendChild(r);
      }
      const shadow = document.createElement('div');
      shadow.className = 'ag-shadow';
      drop.appendChild(shadow);
      const head = document.createElement('div');
      head.className = 'ag-head';
      if (p.kind === 'shelter') {
        const b = document.createElement('div');
        b.className = 'ag-badge';
        head.appendChild(b);
      } else {
        head.innerHTML = `<svg viewBox="0 0 34 43"><path d="${BALLOON}"/></svg>`;
      }
      head.appendChild(glyph(p));
      drop.appendChild(head);
      const label = document.createElement('div');
      label.className = 'ag-label';
      if (p.chip) {
        const chip = document.createElement('div');
        chip.className = 'ag-chip';
        chip.innerHTML = '<i></i>';
        chip.appendChild(document.createTextNode(p.chip));
        label.appendChild(chip);
      }
      // Flood pins sit on their barangay, which the map already names, so
      // they only carry the depth. Shelters show their name up close.
      if (p.kind === 'shelter') {
        const name = document.createElement('div');
        name.className = 'ag-name';
        name.textContent = p.title;
        label.appendChild(name);
      }
      drop.appendChild(label);
      el.appendChild(drop);
      const tap = (e) => {
        e.stopPropagation();
        cb.onPinTap(p.id);
      };
      el.addEventListener('click', tap);
      el.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' || e.key === ' ') tap(e);
      });
      return el;
    }

    function setPins(json) {
      pins = JSON.parse(json);
      for (const m of markers.values()) m.remove();
      markers.clear();
      pins.forEach((p, i) => {
        const m = new maplibregl.Marker({
          element: pinElement(p, i),
          anchor: 'center',
          pitchAlignment: 'viewport',
          rotationAlignment: 'viewport',
          subpixelPositioning: true,
        })
          .setLngLat([p.lng, p.lat])
          .addTo(map);
        markers.set(p.id, m);
      });
      markersVisible();
      select(selected);
      // First time: frame all the pins (unless asked to show one spot).
      if (opts.fit && pins.length > 1) {
        opts.fit = false;
        const b = new maplibregl.LngLatBounds();
        for (const p of pins) b.extend([p.lng, p.lat]);
        // After 'load', when the map surely knows its real size.
        const fit = () => {
          map.resize();
          map.fitBounds(b, { padding: 40, maxZoom: 14, duration: 0 });
        };
        // (map.loaded() is no use here: it turns false again while tiles load.)
        if (didLoad) fit();
        else map.once('load', fit);
      }
    }

    function markersVisible() {
      for (const p of pins) markers.get(p.id)?.getElement().classList.toggle('ag-off', hidden.has(p.kind));
    }

    function select(id) {
      selected = id;
      for (const [pid, m] of markers) {
        const el = m.getElement();
        el.classList.toggle('ag-sel', pid === id);
        // The picked pin is drawn above the others.
        el.style.zIndex = pid === id ? '2' : '';
      }
    }

    // ---- camera
    function camera() {
      cb.onCamera(map.getBearing(), map.getPitch());
    }
    map.on('rotate', camera);
    map.on('moveend', () => {
      const c = map.getCenter();
      cb.onMoveEnd(c.lat, c.lng);
    });
    map.on('pitch', () => {
      apply3d(map.getPitch());
      camera();
    });
    map.on('zoom', () => root.classList.toggle('ag-near', map.getZoom() >= 14.6));
    map.on('style.load', addOwnLayers);
    map.once('load', () => {
      didLoad = true;
      map.setLight({ anchor: 'viewport', position: [1.2, 200, 35], intensity: 0.32, color: '#ffffff' });
      // The credits start folded into their (i) button.
      root.querySelector('.maplibregl-compact-show')?.classList.remove('maplibregl-compact-show');
      cb.onReady();
    });
    map.on('error', (e) => {
      // A missing tile outside the downloaded area is normal; anything else
      // goes to the console for debugging.
      if (!(e && e.sourceId)) console.warn('AgosAlert map:', e && e.error);
    });

    const ease = { duration: 900, easing: (t) => 1 - Math.pow(1 - t, 3) };

    return {
      setTheme(t) {
        if (t === theme) return;
        root.classList.replace(`ag-${theme}`, `ag-${t}`);
        theme = t;
        terrainOn = false;
        map.setStyle(`map/style-${t}.json`);
      },
      setPins,
      setZones(json) {
        zones = JSON.parse(json);
        map.getSource('zones')?.setData(zonesGeo());
      },
      setHidden(kind, off) {
        if (off) hidden.add(kind);
        else hidden.delete(kind);
        markersVisible();
        zonesVisible();
      },
      select,
      flyTo(lng, lat, zoom, place) {
        // A barangay search lands on the name the map prints (its OSM place
        // point), not our own center, which can sit a few blocks away.
        const at = (place && placeLabel(place)) || [lng, lat];
        map.flyTo({ center: at, zoom: Math.max(zoom, map.getZoom()), duration: 1100, essential: true });
      },
      jumpTo(lng, lat, zoom) {
        map.jumpTo({ center: [lng, lat], zoom });
      },
      zoomBy(d) {
        map.easeTo({ zoom: map.getZoom() + d, ...ease, duration: 350 });
      },
      reset(lng, lat, zoom) {
        map.easeTo({ center: [lng, lat], zoom, bearing: want3d ? -18 : 0, pitch: want3d ? 58 : 0, ...ease });
      },
      set3d(on) {
        want3d = on;
        map.easeTo({
          pitch: on ? 58 : 0,
          bearing: on ? map.getBearing() || -18 : 0,
          zoom: on ? Math.max(map.getZoom(), 15) : map.getZoom(),
          ...ease,
          duration: 1200,
        });
      },
      resetNorth() {
        map.easeTo({ bearing: 0, ...ease, duration: 500 });
      },
      setPadding(top, right, bottom, left) {
        map.setPadding({ top, right, bottom, left });
        // The credits button sits just above the bottom panel.
        root.style.setProperty('--ag-pb', `${bottom}px`);
      },
      setActive(active, visible) {
        root.classList.toggle('ag-inactive', !active && visible);
        root.classList.toggle('ag-hidden', !visible);
      },
      resize() {
        map.resize();
      },
      destroy() {
        map.remove();
        root.remove();
      },
    };
  }

  window.agosMap = { load, create };
})();
