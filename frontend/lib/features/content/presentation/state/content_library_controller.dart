import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/demo/demo_mode.dart';
import '../../../editor/canvas/models/canvas_document.dart';
import '../../data/demo_content.dart';
import '../../data/repositories/api_content_repository.dart';
import '../../domain/entities/content_asset_summary.dart';

/// Content library listing (Milestone 3.6).
///
/// A FutureProvider rather than a StateNotifier: this is server-derived
/// read-only data, which per docs/architecture — Flutter Web Application
/// Architecture §2 is exactly the case FutureProvider exists for — it
/// gives loading/error/data states for free instead of each screen
/// reinventing them.
final contentLibraryProvider = FutureProvider.autoDispose<List<ContentAssetSummary>>(
  (ref) {
    if (ref.watch(demoModeProvider)) return Future.value(demoContentAssets());
    return ref.watch(contentRepositoryProvider).list();
  },
);

/// Creates a blank 1080x1080 design and returns its id.
///
/// Takes WidgetRef, not Ref — this is called from a screen's callback,
/// not from inside a provider body.
///
/// The default artboard matches Instagram's square spec — the most
/// common starting point, and the one platform variant that needs no
/// cropping at all.
Future<String> createBlankAsset(WidgetRef ref) {
  return ref.read(contentRepositoryProvider).createAsset(
        document: const CanvasDocument(width: 1080, height: 1080),
      );
}
