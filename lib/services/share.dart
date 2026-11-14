// Browser-only features: the share menu (shareText) and reloadPage. The
// web versions are in share_web.dart; tests and phone builds get
// share_io.dart (no share menu, so the caller copies; no reload).
export 'share_io.dart' if (dart.library.js_interop) 'share_web.dart';
