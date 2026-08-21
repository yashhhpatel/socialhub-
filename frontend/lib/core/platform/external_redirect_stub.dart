/// Non-web fallback for [redirectToExternal] (used by the Dart VM under
/// `flutter test`). A no-op — there's no browser tab to navigate — which keeps
/// `dart:html` out of the non-web build.
void redirectToExternal(String url) {
  // Intentionally empty on non-web targets.
}
