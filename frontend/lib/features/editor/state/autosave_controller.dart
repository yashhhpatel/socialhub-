import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../content/data/repositories/api_content_repository.dart';
import '../../content/domain/repositories/content_repository.dart';
import '../canvas/models/canvas_document.dart';

/// What the editor's save indicator is currently showing.
enum AutosaveStatus {
  /// Nothing has changed since the last successful save (or since load).
  idle,

  /// Edits are buffered and the debounce timer is counting down.
  pending,

  /// A PATCH is in flight.
  saving,

  /// Last save completed successfully.
  saved,

  /// Last save failed. The buffered document is retained, so the next
  /// edit (or an explicit flush) retries it.
  error,
}

class AutosaveState {
  const AutosaveState({this.status = AutosaveStatus.idle, this.errorMessage});

  final AutosaveStatus status;
  final String? errorMessage;
}

/// Debounced autosave for the editor (Milestone 3.5).
///
/// Why debounce rather than save on every change: dragging a layer emits
/// a state change per pointer frame. Saving each one would mean ~60 PATCH
/// requests per second per user — this is called out as both a UX and a
/// performance measure in docs/architecture — Flutter Web Application
/// Architecture §12.
///
/// Ordering guarantee: only one request is ever in flight. If edits land
/// while a save is running, they're buffered and flushed immediately
/// after it completes, rather than fired concurrently — two overlapping
/// PATCHes to the same asset can otherwise complete out of order and
/// persist the OLDER document as the final state, silently reverting the
/// user's most recent work.
class AutosaveController extends StateNotifier<AutosaveState> {
  AutosaveController({
    required ContentRepository repository,
    required String assetId,
    this.debounceDuration = const Duration(milliseconds: 800),
  })  : _repository = repository,
        _assetId = assetId,
        super(const AutosaveState());

  final ContentRepository _repository;
  final String _assetId;
  final Duration debounceDuration;

  Timer? _debounceTimer;
  CanvasDocument? _pendingDocument;
  bool _saveInFlight = false;

  /// Called on every canvas change. Resets the debounce window, so a
  /// continuous stream of edits produces exactly one save once the user
  /// pauses.
  void onDocumentChanged(CanvasDocument document) {
    _pendingDocument = document;
    state = const AutosaveState(status: AutosaveStatus.pending);

    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounceDuration, flush);
  }

  /// Saves any buffered document immediately, bypassing the debounce.
  /// Called on Ctrl+S and before navigating away from the editor, so a
  /// user who leaves within the debounce window doesn't lose that edit.
  Future<void> flush() async {
    _debounceTimer?.cancel();

    if (_pendingDocument == null) return;

    // A save is already running — leave the buffer in place. The
    // in-flight save's completion handler picks it up.
    if (_saveInFlight) return;

    final document = _pendingDocument!;
    _pendingDocument = null;
    _saveInFlight = true;
    state = const AutosaveState(status: AutosaveStatus.saving);

    try {
      await _repository.saveCanvas(assetId: _assetId, document: document);
      if (!mounted) return;
      state = const AutosaveState(status: AutosaveStatus.saved);
    } catch (error) {
      if (!mounted) return;
      // Re-buffer the document we failed to save, but only if no newer
      // edit arrived while the request was in flight — that newer one
      // supersedes it and must not be overwritten by this rollback.
      _pendingDocument ??= document;
      state = const AutosaveState(
        status: AutosaveStatus.error,
        errorMessage: 'Could not save. Your changes are kept and will retry.',
      );
    } finally {
      _saveInFlight = false;
      // Edits that arrived mid-save (or the re-buffered failed one) are
      // flushed now, preserving the one-request-at-a-time guarantee.
      if (mounted && _pendingDocument != null && state.status != AutosaveStatus.error) {
        unawaited(flush());
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

/// One autosave controller per asset being edited.
final autosaveControllerProvider = StateNotifierProvider.autoDispose
    .family<AutosaveController, AutosaveState, String>((ref, assetId) {
  return AutosaveController(
    repository: ref.watch(contentRepositoryProvider),
    assetId: assetId,
  );
});
