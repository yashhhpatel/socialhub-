import 'dart:typed_data';

/// A file the user chose in the browser: raw bytes + its name and MIME type.
///
/// Pure Dart (no `dart:html`) so it can be imported from the web picker, the
/// VM stub, and tests alike.
class PickedFile {
  const PickedFile({
    required this.bytes,
    required this.name,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String name;
  final String mimeType;
}
