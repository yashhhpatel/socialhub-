/// Non-web fallback for [KeyValueStore] (used by the Dart VM under
/// `flutter test`). In-memory only — no persistence — which is exactly what
/// tests want, and keeps `dart:html` out of the non-web build.
class KeyValueStore {
  const KeyValueStore._();

  static final Map<String, String> _mem = {};

  static String? read(String key) => _mem[key];

  static void write(String key, String value) => _mem[key] = value;

  static void remove(String key) => _mem.remove(key);
}
