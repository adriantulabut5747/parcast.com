import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Put this around anything that floats over the web map (cards, buttons,
/// the bottom nav while the Map tab is open).
///
/// The web map is a real HTML element, not something Flutter draws, so:
/// - Flutter's blur (BackdropFilter) can't see it: glass over the map
///   would show no blur at all. This puts an HTML <div> with the
///   browser's own blur (CSS backdrop-filter) right behind [child].
/// - Taps on Flutter widgets over it would ALSO reach the map (a button
///   press would pan it). The <div> sits between them and catches those.
///
/// [blur] false = only catch taps (nothing to see through, e.g. a solid
/// button). [enabled] false = just [child] (e.g. the nav on other tabs).
class MapGlass extends StatelessWidget {
  final Widget child;
  final double radius;
  final bool blur;
  final bool enabled;
  const MapGlass({
    required this.child,
    this.radius = 0,
    this.blur = true,
    this.enabled = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // Same widget tree whether enabled or not, so turning it on or off
    // never rebuilds [child] from scratch (it would lose its state).
    return Stack(
      children: [
        Positioned.fill(
          child: !enabled
              ? const SizedBox.shrink()
              : HtmlElementView.fromTagName(
                  // ValueKey: a new <div> when the look changes.
                  key: ValueKey('$blur$radius'),
                  tagName: 'div',
                  // Only-catch-taps <div>s draw nothing, which lets Flutter skip
                  // extra drawing work for them.
                  isVisible: blur,
                  onElementCreated: (el) {
                    final s = (el as web.HTMLElement).style
                      ..width = '100%'
                      ..height = '100%'
                      ..borderRadius = '${radius}px';
                    if (blur) {
                      // Same recipe as kGlassBlur (blur 24, saturate 1.8).
                      s.setProperty(
                        'backdrop-filter',
                        'blur(24px) saturate(180%)',
                      );
                      s.setProperty(
                        '-webkit-backdrop-filter',
                        'blur(24px) saturate(180%)',
                      );
                      _untransform(el);
                    }
                  },
                ),
        ),
        child,
      ],
    );
  }
}

/// Chrome bug (seen Nov 2026 on 1x screens, not on 2x): the blur stops
/// working when the <div>'s holder is placed with a CSS `transform`, which
/// is how Flutter places every HTML view that isn't at the top-left
/// corner. So whenever Flutter sets a plain "move by x, y" transform on
/// the holder, this swaps it for the same move done with left/top.
///
/// shortcut: if Flutter ever moves a glass back to exactly (0, 0) it writes
/// `transform: none`, and the old left/top would stay. None of the app's
/// glass ever does; handle it here if one does.
void _untransform(web.HTMLElement div) {
  Future<void>(() async {
    // The holder (Flutter's "slot") exists once the <div> is on the page.
    for (var i = 0; i < 120 && !div.isConnected; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
    final holder = div.parentElement?.assignedSlot?.parentElement;
    if (holder == null || !holder.isA<web.HTMLElement>()) return;
    final slot = holder as web.HTMLElement;
    final move = RegExp(
      r'^matrix\(1, 0, 0, 1, (-?[\d.e+-]+), (-?[\d.e+-]+)\)$',
    );
    void fix() {
      final s = slot.style;
      final m = move.firstMatch(s.transform);
      if (m != null) {
        s.transform = 'none';
        s.left = '${m[1]}px';
        s.top = '${m[2]}px';
      } else if (s.transform != 'none') {
        // A scale or other change: let Flutter's transform do it all.
        s.left = '';
        s.top = '';
      }
    }

    fix();
    web.MutationObserver(
      ((JSArray<web.MutationRecord> _, web.MutationObserver _) => fix()).toJS,
    ).observe(
      slot,
      web.MutationObserverInit(
        attributes: true,
        attributeFilter: ['style'.toJS].toJS,
      ),
    );
  });
}
