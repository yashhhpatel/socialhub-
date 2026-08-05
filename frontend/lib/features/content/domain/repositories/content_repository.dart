import '../../../editor/canvas/models/canvas_document.dart';

/// Persistence contract for content assets, backed by the Milestone 3.1
/// endpoints (`POST /content/assets`, `GET /content/assets/:id`,
/// `PATCH /content/assets/:id`).
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
}
