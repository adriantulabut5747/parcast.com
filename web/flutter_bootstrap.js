// Custom Flutter startup script. `flutter build web` / `flutter run` fill in
// the two {{...}} lines with Flutter's own loader code.
{{flutter_js}}
{{flutter_build_config}}

(function () {
  const loader = document.getElementById('loader');
  const status = document.getElementById('loaderStatus');
  const bar = document.getElementById('loaderBar');
  const fills = [
    document.getElementById('fillBack'),
    document.getElementById('fillFront'),
  ];

  // Each loading stage raises the water in the logo, moves the top
  // progress bar, and updates the text.
  function stage(percent, text) {
    if (bar) bar.style.width = percent + '%';
    fills.forEach(function (f, i) {
      // `top` is where the water's surface is: 100% = empty (below the
      // drop), smaller = higher. At 100% loaded it's 8%: the drop is full
      // up to its pointed tip, with the wave still showing.
      // fills[0] is the back wave (i = 0, no change) and fills[1] the
      // front wave (i = 1), which `i * 4` lifts 4% higher.
      if (f) f.style.top = (100 - percent * 0.92 - i * 4) + '%';
    });
    if (status && text) status.textContent = text;
  }

  // Fills the water to the top, then fades the loading screen out (the
  // `done` CSS class, 0.4 s later) and finally deletes it from the page
  // (0.6 s after that, once the fade has finished). `hidden` stops it from
  // running twice, since both the event and the safety timer call it.
  let hidden = false;
  function hideLoader() {
    if (hidden || !loader) return;
    hidden = true;
    stage(100, 'Ready');
    setTimeout(function () {
      loader.classList.add('done');
      setTimeout(function () { loader.remove(); }, 600);
    }, 400);
  }

  stage(20, 'Checking the waters…');

  // Flutter fires this event after drawing the app for the first time.
  window.addEventListener('flutter-first-frame', hideLoader);

  // Flutter's start-up has 3 steps; we move the progress along after each:
  //   1. download main.dart.js (the app)  -> onEntrypointLoaded runs
  //   2. initializeEngine(): start Flutter's drawing engine
  //   3. runApp(): run main() in lib/main.dart
  _flutter.loader.load({
    onEntrypointLoaded: async function (engineInitializer) {
      stage(60, 'Reading the forecast…');
      const appRunner = await engineInitializer.initializeEngine();
      stage(85, 'Almost there…');
      await appRunner.runApp();
      // Safety net in case the first-frame event is missed.
      setTimeout(hideLoader, 1500);
    },
  });
})();
