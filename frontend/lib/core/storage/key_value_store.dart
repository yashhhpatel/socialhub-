// A tiny synchronous string key-value store, resolved per platform via a
// conditional import:
//
// - Web builds get the localStorage-backed implementation (persists across
//   page reloads) from key_value_store_web.dart.
// - Everything else (the Dart VM used by `flutter test`) gets an in-memory
//   stub from key_value_store_stub.dart, so importing this never drags
//   `dart:html` into a non-web target.
//
// Both implementations expose the same `KeyValueStore` API.
export 'key_value_store_stub.dart'
    if (dart.library.html) 'key_value_store_web.dart';
