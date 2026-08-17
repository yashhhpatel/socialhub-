// Web implementation of [KeyValueStore], backed by the browser's
// localStorage so values survive a page reload.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class KeyValueStore {
  const KeyValueStore._();

  static String? read(String key) => html.window.localStorage[key];

  static void write(String key, String value) =>
      html.window.localStorage[key] = value;

  static void remove(String key) => html.window.localStorage.remove(key);
}
