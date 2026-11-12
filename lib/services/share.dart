// Opens the phone's share menu. The web version is in share_web.dart; tests
// and phone builds get share_io.dart (no share menu, so the caller copies).
export 'share_io.dart' if (dart.library.js_interop) 'share_web.dart';
