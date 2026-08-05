import 'dart:typed_data';

import '../../../editor/canvas/models/canvas_document.dart';
import '../entities/content_asset_summary.dart';

/// Persistence contract for content assets, backed by the Milestone 3.1
/// endpoints (`POST /content/assets`, `GET /content/assets/:id`,
/// `PATCH /content/assets/:id`), extended in 3.6 with the library list,
/// canvas export, and 4.1's variant generation.
///
/// Interface lives in domain/, implementation in data/, per
/// docs/architecture — Flutter Web Application Architecture §3: the
/// editor's autosave controller depends on this abstraction, which is
/// what lets its debounce/retry behaviour be tested against a fake
/// without a running backend.
///
/// Note this takes and returns a CanvasDocument, not a raw JSON map —
/// serialization is the repository's job, so the editor never has to
/// think about wire format.
abstract class ContentRepository {
  /// Persists the given canvas state against an existing asset. This is
  /// the autosave call.
  Future<void> saveCanvas({required String assetId, required CanvasDocument document});

  /// Loads a saved asset's canvas so the editor can reopen it exactly as
  /// it was last saved.
  Future<CanvasDocument> loadCanvas(String assetId);

  /// Content library listing, newest-edited first.
  Future<List<ContentAssetSummary>> list();

  /// Creates a blank asset and returns its id, so the caller can route
  /// straight into the editor for it.
  Future<String> createAsset({required CanvasDocument document});

  /// Uploads a flattened PNG render of the canvas and attaches it to the
  /// asset as its master image — the precondition for variant generation
  /// (Milestone 4.1).
  ///
  /// Takes raw bytes rather than a File so it works identically on web
  /// (where the canvas is rasterized in memory and never touches a
  /// filesystem) and any future non-web target.
  Future<void> uploadMasterRender({
    required String assetId,
    required Uint8List pngBytes,
  });

  /// Fans the asset out into per-platform renditions. Returns each
  /// variant's platform and rendered URL.
  Future<List<({String platform, String? renderedMediaUrl, String status})>>
      generateVariants({required String assetId, required List<String> platforms});
}
