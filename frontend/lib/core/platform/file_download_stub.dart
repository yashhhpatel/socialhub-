/// Non-web fallback for [downloadTextFile] (used by the Dart VM under
/// `flutter test`). A no-op — there's no browser to hand a file to — which
/// keeps `dart:html` out of the non-web build.
void downloadTextFile({
  required String filename,
  required String content,
  String mimeType = 'application/json',
}) {
  // Intentionally empty on non-web targets.
}
