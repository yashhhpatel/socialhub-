/// Undo/redo history for the editor (Milestone 3.5).
///
/// Deliberately a plain, generic, dependency-free class rather than a
/// StateNotifier: per docs/architecture — Flutter Web Application
/// Architecture §2, the editor's history logic is called out as something
/// that must be testable in isolation. Nothing here imports Flutter,
/// Riverpod, or the canvas models, so the whole undo/redo model can be
/// exercised in a unit test with plain strings (and is — see
/// test/unit/features/editor/state/history_controller_test.dart).
///
/// Model: this holds only the PAST and FUTURE. The *present* state lives
/// in CanvasController, which is the single source of truth for what's
/// on screen. That split is what keeps the two from drifting out of sync
/// — there is exactly one "current document" in the system, never a copy
/// here that has to be kept in step with the real one.
class EditorHistory<T> {
  EditorHistory({this.maxDepth = 100}) : assert(maxDepth > 0);

  /// Cap on retained undo steps. Canvas documents hold full layer lists,
  /// so an unbounded stack is a genuine memory leak across a long editing
  /// session — 100 steps is far more than a user will realistically walk
  /// back through, while keeping worst-case retention bounded.
  final int maxDepth;

  final List<T> _past = [];
  final List<T> _future = [];

  bool get canUndo => _past.isNotEmpty;
  bool get canRedo => _future.isNotEmpty;

  int get undoDepth => _past.length;
  int get redoDepth => _future.length;

  /// Records [previous] — the state as it was *before* the edit that is
  /// being applied right now — as a restorable point.
  ///
  /// Clears the redo stack, which is the standard linear-history
  /// behaviour: once you undo and then make a *different* edit, the
  /// branch you undid away from is no longer reachable. Keeping it would
  /// require a history tree, which is not what users expect from Ctrl+Z.
  void record(T previous) {
    _past.add(previous);
    if (_past.length > maxDepth) {
      // Drop the oldest step, not the newest — the far past is what's
      // safe to forget.
      _past.removeAt(0);
    }
    _future.clear();
  }

  /// Steps back one edit. [current] is the state being left behind, which
  /// moves onto the redo stack so the step is reversible.
  ///
  /// Returns null when there's nothing to undo, rather than throwing — a
  /// Ctrl+Z on a fresh document is a normal thing for a user to press,
  /// not an error.
  T? undo(T current) {
    if (_past.isEmpty) return null;
    final restored = _past.removeLast();
    _future.add(current);
    return restored;
  }

  /// Steps forward one previously-undone edit. Mirror image of [undo].
  T? redo(T current) {
    if (_future.isEmpty) return null;
    final restored = _future.removeLast();
    _past.add(current);
    return restored;
  }

  /// Drops all history. Used when the editor loads a different document
  /// — undoing across two unrelated assets would restore the *other*
  /// asset's content into this one.
  void clear() {
    _past.clear();
    _future.clear();
  }
}
