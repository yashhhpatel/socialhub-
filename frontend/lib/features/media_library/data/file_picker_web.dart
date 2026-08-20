import 'dart:async';
import 'dart:typed_data';
// This is a web-only app; dart:html is the dependency-free way to open a
// native file chooser and read bytes for upload.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'picked_file.dart';

/// Opens the browser file chooser (images and videos) and returns the chosen
/// file's bytes, or null if the user cancels. Web implementation, selected via
/// the conditional import in file_picker.dart.
Future<PickedFile?> pickImageOrVideo() async {
  final input = html.FileUploadInputElement()
    ..accept = 'image/*,video/*'
    ..multiple = false;
  input.click();

  await input.onChange.first;
  final file = input.files?.isNotEmpty == true ? input.files!.first : null;
  if (file == null) return null;

  final reader = html.FileReader();
  reader.readAsArrayBuffer(file);
  await reader.onLoadEnd.first;

  final result = reader.result;
  final Uint8List bytes = result is Uint8List
      ? result
      : (result as ByteBuffer).asUint8List();

  return PickedFile(
    bytes: bytes,
    name: file.name,
    // Browsers usually provide the type; fall back so multer still gets one.
    mimeType: file.type.isNotEmpty ? file.type : 'application/octet-stream',
  );
}
