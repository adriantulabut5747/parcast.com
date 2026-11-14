// Getting a report photo ready to upload. The web version (canvas) is in
// photo_web.dart; phones and tests use photo_io.dart.
export 'photo_io.dart' if (dart.library.js_interop) 'photo_web.dart';
