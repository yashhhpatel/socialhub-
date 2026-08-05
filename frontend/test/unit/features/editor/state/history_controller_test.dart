import 'package:flutter_test/flutter_test.dart';
import 'package:socialhub/features/editor/state/history_controller.dart';

/// Exercised with plain strings, not CanvasDocuments — EditorHistory is
/// generic and knows nothing about the canvas, and testing it that way
/// keeps these cases about the undo/redo *model* rather than about
/// document construction.
void main() {
  group('EditorHistory', () {
    test('starts with nothing to undo or redo', () {
      final history = EditorHistory<String>();
      expect(history.canUndo, isFalse);
      expect(history.canRedo, isFalse);
    });

    test('undo on empty history returns null rather than throwing', () {
      final history = EditorHistory<String>();
      expect(history.undo('current'), isNull);
    });

    test('redo on empty history returns null rather than throwing', () {
      final history = EditorHistory<String>();
      expect(history.redo('current'), isNull);
    });

    test('record makes the previous state restorable', () {
      final history = EditorHistory<String>()..record('a');
      expect(history.canUndo, isTrue);
      expect(history.undo('b'), 'a');
    });

    test('undo moves the current state onto the redo stack', () {
      final history = EditorHistory<String>()..record('a');
      history.undo('b');

      expect(history.canRedo, isTrue);
      expect(history.redo('a'), 'b');
    });

    test('walks back and forward through several steps in order', () {
      final history = EditorHistory<String>()
        ..record('v1')
        ..record('v2')
        ..record('v3');

      // Current state is v4 (three edits applied on top of v1).
      expect(history.undo('v4'), 'v3');
      expect(history.undo('v3'), 'v2');
      expect(history.undo('v2'), 'v1');
      expect(history.canUndo, isFalse);

      expect(history.redo('v1'), 'v2');
      expect(history.redo('v2'), 'v3');
      expect(history.redo('v3'), 'v4');
      expect(history.canRedo, isFalse);
    });

    test('recording a new edit after an undo discards the redo branch', () {
      final history = EditorHistory<String>()
        ..record('v1')
        ..record('v2');

      history.undo('v3'); // back to v2, redo now holds v3
      expect(history.canRedo, isTrue);

      history.record('v2'); // a NEW edit from v2
      expect(history.canRedo, isFalse, reason: 'the v3 branch is no longer reachable');
    });

    test('drops the OLDEST entry once maxDepth is exceeded', () {
      final history = EditorHistory<String>(maxDepth: 3)
        ..record('v1')
        ..record('v2')
        ..record('v3')
        ..record('v4'); // pushes v1 out

      expect(history.undoDepth, 3);
      expect(history.undo('v5'), 'v4');
      expect(history.undo('v4'), 'v3');
      expect(history.undo('v3'), 'v2');
      // v1 is gone — capped, not unbounded.
      expect(history.canUndo, isFalse);
    });

    test('clear drops both stacks', () {
      final history = EditorHistory<String>()..record('a');
      history.undo('b');
      expect(history.canUndo || history.canRedo, isTrue);

      history.clear();
      expect(history.canUndo, isFalse);
      expect(history.canRedo, isFalse);
    });
  });
}
