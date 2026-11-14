import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Shrinks a photo to at most 1600 px on its long side and saves it as a
/// JPEG (quality 0.8), with the browser's own image code: a 4000 px phone
/// photo of several MB becomes ~300 KB, quick to upload on mobile data.
/// Also turns PNG/WebP into JPEG and drops the location the camera hid
/// in the file (EXIF), which other people shouldn't get.
Future<Uint8List> shrinkPhoto(Uint8List bytes) async {
  final blob = web.Blob(<JSAny>[bytes.toJS].toJS);
  final bitmap = await web.window.createImageBitmap(blob).toDart;
  final scale = math.min(1.0, 1600 / math.max(bitmap.width, bitmap.height));
  final w = (bitmap.width * scale).round();
  final h = (bitmap.height * scale).round();
  final canvas = web.OffscreenCanvas(w, h);
  final ctx = canvas.getContext('2d')! as web.OffscreenCanvasRenderingContext2D;
  ctx.drawImage(bitmap, 0, 0, w, h);
  bitmap.close();
  final jpeg = await canvas
      .convertToBlob(web.ImageEncodeOptions(type: 'image/jpeg', quality: 0.8))
      .toDart;
  return (await jpeg.arrayBuffer().toDart).toDart.asUint8List();
}

/// The browser's picker would resize on a canvas and lose the photo's
/// date, so the web build picks the original and shrinks it itself.
const bool kPickerResizes = false;
