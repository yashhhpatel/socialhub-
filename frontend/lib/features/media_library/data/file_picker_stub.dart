import 'picked_file.dart';

/// Non-web stub (the Dart VM used by `flutter test`). Keeps `dart:html` out of
/// non-web targets, mirroring core/storage's key_value_store split. Never
/// invoked in practice — this is a web-only app, and tests override the
/// picker provider — so it fails loudly if it ever is.
Future<PickedFile?> pickImageOrVideo() async {
  throw UnsupportedError('File picking is only available on the web.');
}
