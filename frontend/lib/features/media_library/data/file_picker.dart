import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'file_picker_stub.dart'
    if (dart.library.html) 'file_picker_web.dart' as impl;
import 'picked_file.dart';

export 'picked_file.dart';

/// Opens the file chooser and returns the picked file (or null if cancelled).
typedef FilePicker = Future<PickedFile?> Function();

/// The platform file picker, injected so screens don't import `dart:html`
/// directly and tests can override it with a fake (no real dialog). Resolves
/// to the web implementation in web builds and the stub on the VM, via the
/// conditional import above.
final filePickerProvider = Provider<FilePicker>((ref) => impl.pickImageOrVideo);
