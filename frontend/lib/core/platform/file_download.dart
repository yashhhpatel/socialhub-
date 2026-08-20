// Trigger a browser download of an in-memory text file, resolved per platform
// via a conditional import (same approach as core/storage/key_value_store):
//
// - Web builds get the real implementation (Blob + object URL + a synthetic
//   anchor click) from file_download_web.dart.
// - Everything else (the Dart VM under `flutter test`) gets a no-op stub, so
//   importing this never drags `dart:html` into a non-web target.
export 'file_download_stub.dart'
    if (dart.library.html) 'file_download_web.dart';
