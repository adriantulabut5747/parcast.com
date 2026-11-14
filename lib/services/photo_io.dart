import 'dart:typed_data';

/// Phones: image_picker already shrank the photo (maxWidth in the form),
/// so it goes up as it is.
Future<Uint8List> shrinkPhoto(Uint8List bytes) async => bytes;

/// Phones resize while picking; the browser can't (it would lose the
/// photo's date), so the form only asks for maxWidth here.
const bool kPickerResizes = true;
