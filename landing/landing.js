/* ============================================================
   AgosAlert landing page behaviour. No libraries.
   The live 3D Tugak in the hero is a separate module (tugak.js).
   ============================================================ */
(function () {
  'use strict';

  var reduceMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;
  var $ = function (id) { return document.getElementById(id); };
  var all = function (sel) { return document.querySelectorAll(sel); };

  /* Where the app lives, relative to this page. 'guest' skips the app's
     login screen (lib/services/session.dart). The app picks its own theme. */
  function appUrl(as) { return 'app/' + (as === 'guest' ? '?as=guest' : ''); }

  /* ---------------- Night sky ----------------
     Three layers of stars as box-shadows on one tiny dot each (drawn once,
     no canvas loop), plus a few sparkles. Sized for big monitors; the
     .sky clips the rest. */

  function starLayer(el, count, alpha) {
    var w = Math.max(screen.width, innerWidth, 1600), h = Math.max(screen.height, innerHeight, 1000);
    var out = [];
    for (var i = 0; i < count; i++) {
      var x = Math.round(Math.random() * w), y = Math.round(Math.random() * h);
      var a = (alpha * (0.4 + Math.random() * 0.6)).toFixed(2);
      // a few stars tinted the app's blue / indigo, the rest white
      var c = Math.random() < 0.12 ? '120,180,255' : Math.random() < 0.08 ? '160,158,255' : '255,255,255';
      out.push(x + 'px ' + y + 'px rgba(' + c + ',' + a + ')');
    }
    el.style.boxShadow = out.join(',');
  }
  starLayer(document.querySelector('.stars.s1'), 260, 0.55);
  starLayer(document.querySelector('.stars.s2'), 90, 0.8);
  starLayer(document.querySelector('.stars.s3'), 34, 1);
  var sky = document.querySelector('.sky');
  for (var s = 0; s < 9; s++) {
    var sp = document.createElement('i');
    sp.className = 'spark';
    sp.style.left = (Math.random() * 96 + 2) + '%';
    sp.style.top = (Math.random() * 90 + 4) + '%';
    sp.style.animationDelay = (-Math.random() * 4).toFixed(2) + 's';
    sp.style.transform = 'scale(' + (0.5 + Math.random() * 0.7).toFixed(2) + ')';
    if (Math.random() < 0.4) sp.style.setProperty('--c', '#7fb4ff');
    sky.appendChild(sp);
  }

  /* ---------------- Kapampangan greeting + phone clocks ----------------
     By the time in Mabalacat (Asia/Manila), whatever the visitor's zone. */

  var greetings = [
    // [from hour, until hour, Kapampangan, English]
    [5, 11, 'Mayap a abak!', 'Good morning, Mabalacat.'],
    [11, 13, 'Mayap a ugtu!', 'Good noon, Mabalacat.'],
    [13, 18, 'Mayap a gatpanapun!', 'Good afternoon, Mabalacat.'],
  ];
  var night = ['Mayap a bengi!', 'Good evening, Mabalacat.'];

  function manilaTime() {
    var parts = new Intl.DateTimeFormat('en-US', {
      timeZone: 'Asia/Manila', hour: 'numeric', minute: '2-digit', hourCycle: 'h23',
    }).formatToParts(new Date());
    var get = function (type) { return +parts.filter(function (p) { return p.type === type; })[0].value; };
    return { h: get('hour'), m: get('minute') };
  }

  function updateClock() {
    var t = manilaTime(), g = night;
    greetings.forEach(function (row) { if (t.h >= row[0] && t.h < row[1]) g = [row[2], row[3]]; });
    $('greeting').innerHTML = '<span class="kap">' + g[0] + '</span> ' + g[1];
    var clock = (t.h % 12 || 12) + ':' + String(t.m).padStart(2, '0');
    all('.sb-time').forEach(function (el) { el.textContent = clock; });
  }
  updateClock();
  setInterval(updateClock, 30 * 1000);

  /* ---------------- Marquees ----------------
     Each track holds its list twice: the CSS loop slides by exactly one
     copy, so it never jumps. */

  var barangays = [
    'Atlu-Bola', 'Bical', 'Bundagul', 'Cacutud', 'Calumpang', 'Camachiles',
    'Dapdap', 'Dau', 'Dolores', 'Duquit', 'Lakandula', 'Mabiga',
    'Macapagal Village', 'Mamatitang', 'Mangalit', 'Marcos Village',
    'Mawaque', 'Paralayunan', 'Poblacion', 'San Francisco', 'San Joaquin',
    'Santa Ines', 'Santa Maria', 'Santo Rosario', 'Sapang Balen',
    'Sapang Biabas', 'Tabun',
  ];
  function spans(list) { return list.map(function (b) { return '<span>' + b + '</span>'; }).join(''); }
  var half = Math.ceil(barangays.length / 2);
  var rowA = barangays.slice(0, half), rowB = barangays.slice(half);
  $('mqA').innerHTML = spans(rowA.concat(rowA));
  $('mqB').innerHTML = spans(rowB.concat(rowB));
  $('barangayList').textContent = 'Covers all 27 barangays: ' + barangays.join(', ') + '.';

  var photoTrack = $('photoTrack');
  Array.prototype.slice.call(photoTrack.children).forEach(function (img) {
    var copy = img.cloneNode(true);
    copy.alt = '';
    copy.setAttribute('aria-hidden', 'true');
    photoTrack.appendChild(copy);
  });

  /* ---------------- Tugak's bubbles ----------------
     Each bubble types its line out the first time it scrolls into view,
     like he's saying it. Screen readers get the whole line at once
     (aria-label); the typed copy is hidden from them. The hero tells
     tugak.js to move his mouth while it types. */

  function typeLine(bubble, text) {
    var span = bubble.querySelector('.say-text');
    bubble.setAttribute('aria-label', 'Tugak says: ' + text);
    span.setAttribute('aria-hidden', 'true');
    bubble.classList.add('shown');
    clearInterval(bubble._typing);
    if (reduceMotion) { span.textContent = text; return; }
    var chars = Array.from(text), i = 0;
    span.textContent = '';
    bubble.classList.add('typing');
    if (bubble.id === 'heroSay') {
      document.dispatchEvent(new CustomEvent('tugak-talk', { detail: chars.length * 32 }));
    }
    bubble._typing = setInterval(function () {
      span.textContent = chars.slice(0, ++i).join('');
      if (i >= chars.length) { clearInterval(bubble._typing); bubble.classList.remove('typing'); }
    }, 32);
  }

  var sayer = new IntersectionObserver(function (entries) {
    entries.forEach(function (e) {
      if (!e.isIntersecting) return;
      sayer.unobserve(e.target);
      var b = e.target;
      setTimeout(function () { typeLine(b, b.dataset.line); }, 150);
    });
  }, { rootMargin: '0px 0px -5% 0px' });
  all('.say:not(#heroSay)').forEach(function (b) {
    b.dataset.line = b.querySelector('.say-text').textContent;
    sayer.observe(b);
  });

  /* ---------------- Live weather ----------------
     Same request and the same rules as lib/services/weather.dart. */

  var WEATHER_URL = 'https://api.open-meteo.com/v1/forecast'
    + '?latitude=15.2236&longitude=120.5714'
    + '&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m,is_day'
    + '&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max,precipitation_sum'
    + '&forecast_days=1&timezone=Asia%2FManila';

  // weatherInfo() in weather.dart: WMO code -> label + CupertinoIcons name.
  function weatherInfo(code, isDay) {
    if (code === 0) return isDay ? ['Clear sky', 'sun_max_fill'] : ['Clear night', 'moon_fill'];
    if (code <= 2) return ['Partly cloudy', isDay ? 'cloud_fill' : 'cloud_moon_fill'];
    if (code === 3) return ['Overcast', 'cloud_fill'];
    if (code <= 48) return ['Foggy', 'cloud_fog_fill'];
    if (code <= 57) return ['Drizzle', 'cloud_drizzle_fill'];
    if (code <= 67) return ['Rain', 'drop_fill'];
    if (code <= 77) return ['Snow', 'snow'];
    if (code <= 82) return ['Rain showers', 'umbrella_fill'];
    return ['Thunderstorm', 'cloud_bolt_rain_fill'];
  }

  // weatherGradient() in weather.dart: the card's colors match the sky.
  function weatherGradient(code, isDay) {
    if (code >= 95) return ['#1A2033', '#07090F'];
    if (code >= 51) return ['#1B2B42', '#09111D'];
    if (!isDay) return ['#16194A', '#05061A'];
    if (code >= 3) return ['#1E3150', '#0A1426'];
    return ['#1C3D72', '#081633'];
  }

  // floodOutlook in weather.dart, word for word:
  //   high     - 30 mm+ of rain today, or a storm with a 60%+ rain chance
  //   moderate - 10 mm+, or a 70%+ rain chance
  //   low      - everything else
  // Stormy WMO codes: 95+ thunderstorm, 65 heavy rain, 82 violent showers.
  function floodOutlook(code, rainSum, rainChance) {
    var stormy = code >= 95 || code === 65 || code === 82;
    if (rainSum >= 30 || (stormy && rainChance >= 60)) return ['high', 'High risk'];
    if (rainSum >= 10 || rainChance >= 70) return ['moderate', 'Moderate risk'];
    return ['low', 'Low risk'];
  }

  // tugakLine() in lib/widgets/tugak.dart, for the data this page has
  // (no hourly forecast here): what to do first; a dry joke only when
  // nothing is wrong, never on a high outlook.
  function tugakLine(code, isDay, outlook, rainChance) {
    if (outlook === 'high') return 'Heavy rain today. Keep your go-bag by the door and stay off low streets.';
    if (code >= 51) return 'It’s raining now. Skip the shortcuts by the creek.';
    if (outlook === 'moderate' || rainChance >= 50) return 'Rain likely later today. Bring the umbrella, not the excuses.';
    if (!isDay) return 'No rain tonight. Charge your phone and sleep. I’ve got the watch.';
    return 'Dry roads for now. Go run your errands, I’ll hold the fort.';
  }

  function formatTime(iso) {
    // "2026-09-28T21:00" is already Manila time (timezone=Asia/Manila).
    var hh = +iso.slice(11, 13), mm = iso.slice(14, 16);
    return (hh % 12 || 12) + ':' + mm + ' ' + (hh < 12 ? 'AM' : 'PM');
  }

  function countUp(el, to) {
    if (reduceMotion) { el.textContent = Math.round(to); return; }
    var start = performance.now(), dur = 1100;
    (function frame(now) {
      var p = Math.min(1, (now - start) / dur);
      el.textContent = Math.round(to * (1 - Math.pow(1 - p, 3)));
      if (p < 1) requestAnimationFrame(frame);
    })(start);
  }

  var card = $('weatherCard'), heroSay = $('heroSay');
  var firstLoad = true, lastLine = '';

  function showWeather(json) {
    var cur = json.current, day = json.daily;
    var code = cur.weather_code, isDay = cur.is_day === 1;
    var info = weatherInfo(code, isDay), grad = weatherGradient(code, isDay);
    var max = Math.round(day.temperature_2m_max[0]), min = Math.round(day.temperature_2m_min[0]);
    var rainChance = day.precipitation_probability_max[0] || 0;
    var rainSum = (day.precipitation_sum[0] || 0).toFixed(1);

    card.style.background = 'linear-gradient(135deg, ' + grad[0] + ', ' + grad[1] + ')';
    $('wTime').textContent = formatTime(cur.time);
    $('wLabel').textContent = info[0];
    $('wIcon').dataset.i = info[1];
    $('wSub').textContent = 'H ' + max + '°  ·  L ' + min + '°  ·  Feels ' + Math.round(cur.apparent_temperature) + '°';
    $('wRainChance').textContent = rainChance + '%';
    $('wRainSum').textContent = rainSum + ' mm';
    $('wHumidity').textContent = cur.relative_humidity_2m + '%';
    $('wWind').textContent = Math.round(cur.wind_speed_10m) + ' km/h';

    var temp = cur.temperature_2m;
    if (firstLoad) setTimeout(function () { countUp($('wTemp'), temp); }, reduceMotion ? 0 : 900);
    else $('wTemp').textContent = Math.round(temp);
    firstLoad = false;
    card.dataset.state = 'ready';

    var outlook = floodOutlook(code, day.precipitation_sum[0] || 0, rainChance);
    $('outlookChip').dataset.risk = outlook[0];
    $('oLevel').textContent = outlook[1];

    // 01 Weather: the same numbers, and which rule matched today.
    $('hwChance').textContent = rainChance + '%';
    $('hwSum').textContent = rainSum + ' mm';
    $('hwCode').textContent = code + ' · ' + info[0].toLowerCase();
    $('hwTime').textContent = 'Live · updated ' + formatTime(cur.time);
    all('.rule').forEach(function (r) { r.classList.toggle('is-today', r.dataset.level === outlook[0]); });

    $('weatherText').textContent = 'Live weather in Mabalacat City: ' + Math.round(temp) + ' degrees, '
      + info[0].toLowerCase() + ', ' + rainChance + '% chance of rain today. Flood outlook today: '
      + outlook[1].toLowerCase() + '.';

    var line = tugakLine(code, isDay, outlook[0], rainChance);
    if (line !== lastLine) {
      lastLine = line;
      setTimeout(function () { typeLine(heroSay, line); }, reduceMotion ? 0 : 1300); // after the hero's entrance
    }
  }

  function loadWeather() {
    var ctrl = new AbortController();
    var timer = setTimeout(function () { ctrl.abort(); }, 10000);
    fetch(WEATHER_URL, { signal: ctrl.signal })
      .then(function (res) {
        if (!res.ok) throw new Error('Weather API returned ' + res.status);
        return res.json();
      })
      .then(showWeather)
      .catch(function () {
        // Keep the last good reading if there is one. Otherwise say so
        // everywhere a number would be: a dash that never fills in looks broken.
        if (card.dataset.state === 'ready') return;
        card.dataset.state = 'error';
        $('wTemp').textContent = '–';
        $('wLabel').textContent = 'Weather unavailable';
        $('wSub').textContent = 'Couldn’t reach Open-Meteo. Reload to try again.';
        ['wRainChance', 'wRainSum', 'wHumidity', 'wWind', 'hwChance', 'hwSum', 'hwCode'].forEach(function (id) {
          $(id).textContent = '–';
        });
        $('outlookChip').dataset.risk = 'error';
        $('oLevel').textContent = 'Unavailable';
        $('hwTime').textContent = 'Couldn’t reach Open-Meteo just now. Reload the page to try again.';
        document.querySelector('.reading-foot .live-dot').hidden = true;
        typeLine(heroSay, 'I can’t reach the weather right now. Reload in a bit, or open the app.');
      })
      .finally(function () { clearTimeout(timer); });
  }
  loadWeather();
  setInterval(loadWeather, 10 * 60 * 1000); // Open-Meteo updates every 15 min

  /* ---------------- Toast ---------------- */

  var toast = $('toast'), toastTimer;
  function showToast(text, link) {
    toast.innerHTML = '';
    var span = document.createElement('span');
    span.textContent = text;
    toast.appendChild(span);
    if (link) {
      var a = document.createElement('a');
      a.href = link.href;
      a.textContent = link.label;
      toast.appendChild(a);
    }
    toast.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(function () { toast.classList.remove('show'); }, 5000);
  }

  all('.store').forEach(function (btn) {
    btn.addEventListener('click', function () {
      showToast('The ' + btn.dataset.store + ' app is coming soon.', { label: 'Use the web app →', href: appUrl('guest') });
    });
  });

  /* ---------------- Open-the-app popup ----------------
     No email or password here: the app has its own login screen. */

  var modal = $('loginModal');
  var choices = modal.querySelectorAll('.choice');

  function openLogin() {
    if (modal.open) return;
    modal.classList.remove('closing');
    modal.showModal();
  }
  function closeLogin() {
    if (!modal.open || modal.classList.contains('closing')) return;
    if (reduceMotion) { modal.close(); return; }
    modal.classList.add('closing');
    modal.querySelector('.modal-card').addEventListener('animationend', function () {
      modal.classList.remove('closing');
      modal.close();
    }, { once: true });
  }

  all('[data-open-app]').forEach(function (b) { b.addEventListener('click', openLogin); });
  all('[data-guest]').forEach(function (b) { b.addEventListener('click', function () { location.href = appUrl('guest'); }); });
  $('closeLogin').addEventListener('click', closeLogin);
  modal.addEventListener('cancel', function (e) { e.preventDefault(); closeLogin(); });
  modal.addEventListener('click', function (e) { if (e.target === modal) closeLogin(); });

  choices.forEach(function (btn) {
    btn.addEventListener('click', function () {
      btn.classList.add('loading');
      choices.forEach(function (b) { b.disabled = true; });
      setTimeout(function () { location.href = appUrl(btn.dataset.as); }, reduceMotion ? 0 : 500);
    });
  });
  // Back button: the page comes back from memory with the spinner still going.
  addEventListener('pageshow', function (e) {
    if (!e.persisted) return;
    choices.forEach(function (b) { b.classList.remove('loading'); b.disabled = false; });
  });

  /* ---------------- Pop-in on scroll ----------------
     Only small things (Tugak, the phones, the SOS badge, the map's dots)
     pop, as soon as they enter the screen. Text never waits. */

  var popper = new IntersectionObserver(function (entries) {
    entries.forEach(function (e) {
      if (e.isIntersecting) { e.target.classList.add('in'); popper.unobserve(e.target); }
    });
  });
  all('.pop, .city-map').forEach(function (el) { popper.observe(el); });

  /* ---------------- "Four tabs" on phones: 2 pages + dots ----------------
     The CSS makes the row a paged scroller (2 phones a page); the dots
     jump to a page and follow the swipe. Hidden on wider screens. */

  var parade = $('parade');
  var dots = all('#paradeDots button');
  dots.forEach(function (d, i) {
    d.addEventListener('click', function () {
      parade.scrollTo({ left: i * (parade.scrollWidth - parade.clientWidth), behavior: 'smooth' });
    });
  });
  parade.addEventListener('scroll', function () {
    var page = Math.round(parade.scrollLeft / Math.max(1, parade.scrollWidth - parade.clientWidth));
    dots.forEach(function (d, i) { d.setAttribute('aria-current', i === page ? 'true' : 'false'); });
  }, { passive: true });

  /* ---------------- 03 Hotlines ---------------- */

  var hotItems = all('#hotList li');
  hotItems.forEach(function (li) {
    li.style.setProperty('--tint', li.dataset.color);
    var number = li.querySelector('.hot-num').textContent;
    li.querySelector('.hot-copy').addEventListener('click', function () {
      navigator.clipboard.writeText(number).then(
        function () { showToast('Copied ' + number + '.'); },
        function () { showToast('Couldn’t copy. The number is ' + number + '.'); }
      );
    });
  });

  // One .vcf file with a contact card per hotline.
  $('saveContacts').addEventListener('click', function () {
    var cards = Array.prototype.map.call(hotItems, function (li) {
      return ['BEGIN:VCARD', 'VERSION:3.0',
        'FN:' + li.dataset.name, 'N:;' + li.dataset.name + ';;;',
        'ORG:Emergency hotline (Mabalacat)',
        'TEL;TYPE=VOICE:' + li.dataset.tel,
        'NOTE:Saved from AgosAlert', 'END:VCARD'].join('\r\n');
    });
    var blob = new Blob([cards.join('\r\n') + '\r\n'], { type: 'text/vcard' });
    var a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = 'Mabalacat emergency hotlines.vcf';
    document.body.appendChild(a); a.click(); a.remove();
    setTimeout(function () { URL.revokeObjectURL(a.href); }, 1000);
    showToast('Contacts file downloaded. Open it to add all five numbers.');
  });
})();
