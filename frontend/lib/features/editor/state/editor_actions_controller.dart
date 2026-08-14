import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_message.dart';
import '../../content/data/repositories/api_content_repository.dart';
import '../canvas/models/canvas_document.dart';
import '../canvas/rendering/canvas_exporter.dart';

/// Loads a saved asset's canvas so the editor can reopen it (3.6).
///
/// family(assetId) + autoDispose: one document per asset, released when
/// the editor route is left, matching the scoping discipline in
/// docs/architecture — Flutter Web Application Architecture §2.
final editorDocumentProvider =
    FutureProvider.autoDispose.family<CanvasDocument, String>((ref, assetId) {
  return ref.watch(contentRepositoryProvider).loadCanvas(assetId);
});

enum EditorActionStatus { idle, exporting, generating, done, failed }

class EditorActionState {
  const EditorActionState({this.status = EditorActionStatus.idle, this.message});

  final EditorActionStatus status;
  final String? message;

  bool get busy =>
      status == EditorActionStatus.exporting || status == EditorActionStatus.generating;
}

/// Drives the editor's two publish-pipeline actions: exporting the canvas
/// to a master render, and fanning that render out into per-platform
/// variants (Milestone 4.1's endpoint, finally given a button).
class EditorActionsController extends StateNotifier<EditorActionState> {
  EditorActionsController(this._ref, this._assetId) : super(const EditorActionState());

  final Ref _ref;
  final String _assetId;

  /// Rasterizes the canvas and attaches it to the asset as its master
  /// render. This is the precondition for variant generation — the
  /// backend 422s without it.
  Future<bool> exportMasterRender(CanvasDocument document) async {
    state = const EditorActionState(status: EditorActionStatus.exporting);
    try {
      final png = await CanvasExporter.toPng(document);
      await _ref
          .read(contentRepositoryProvider)
          .uploadMasterRender(assetId: _assetId, pngBytes: png);
      if (!mounted) return false;
      state = EditorActionState(
        status: EditorActionStatus.done,
        message: 'Design exported (${(png.lengthInBytes / 1024).round()} KB).',
      );
      return true;
    } catch (error) {
      if (!mounted) return false;
      state = EditorActionState(
        status: EditorActionStatus.failed,
        message: 'Export failed: ${describeApiError(error)}',
      );
      return false;
    }
  }

  /// Generates renditions for all five supported platforms. Every platform
  /// now has a backend adapter (Phase 8), so each produces a variant that
  /// can actually be published — a platform without one would 422.
  Future<void> generateVariants() async {
    state = const EditorActionState(status: EditorActionStatus.generating);
    try {
      final variants = await _ref.read(contentRepositoryProvider).generateVariants(
        assetId: _assetId,
        platforms: const ['instagram', 'x', 'facebook', 'threads', 'linkedin'],
      );
      if (!mounted) return;
      state = EditorActionState(
        status: EditorActionStatus.done,
        message: 'Generated ${variants.length} platform variants: '
            '${variants.map((v) => v.platform).join(', ')}.',
      );
    } catch (error) {
      if (!mounted) return;
      state = EditorActionState(
        status: EditorActionStatus.failed,
        message: describeApiError(error),
      );
    }
  }
}

final editorActionsProvider = StateNotifierProvider.autoDispose
    .family<EditorActionsController, EditorActionState, String>(
  (ref, assetId) => EditorActionsController(ref, assetId),
);
