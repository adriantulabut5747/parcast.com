import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// Opens the browser's share menu (on phones: Messenger, Viber, SMS...).
/// Returns false when the browser has no share menu (most desktop
/// browsers), so the caller can copy the text instead. Closing the menu
/// without picking an app still counts as done (true).
Future<bool> shareText(String text) async {
  final nav = web.window.navigator;
  if (!nav.has('share')) return false;
  try {
    await nav.share(web.ShareData(text: text)).toDart;
  } catch (_) {
    // AbortError = the user closed the menu. Nothing else to do.
  }
  return true;
}

/// Loads the page again. Used when a split-off part of the app fails to
/// download, which happens when a new version was published while this
/// tab was open: the old app asks for part files that no longer exist,
/// and only a reload gets the new app with matching parts.
void reloadPage() => web.window.location.reload();
