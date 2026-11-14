/// No share menu outside the browser yet: returns false so the caller
/// copies the text instead.
/// shortcut: phone builds could use the share_plus package; add it when
/// the app ships as a real Android/iOS app.
Future<bool> shareText(String text) async => false;

/// Only the browser can reload (share_web.dart); elsewhere it does nothing.
void reloadPage() {}
