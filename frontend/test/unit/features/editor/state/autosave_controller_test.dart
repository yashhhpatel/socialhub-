import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialhub/features/content/domain/entities/content_asset_summary.dart';
import 'package:socialhub/features/content/domain/repositories/content_repository.dart';
import 'package:socialhub/features/editor/canvas/models/canvas_document.dart';
import 'package:socialhub/features/editor/state/autosave_controller.dart';

/// Records every save it receives and lets the test control when each one
/// completes — needed to exercise the "edit arrives while a save is in
/// flight" ordering guarantee.
class _FakeContentRepository implements ContentRepository {
  final List<CanvasDocument> saved = [];
  bool shouldFail = false;

  /// When set, saveCanvas waits on this before completing.
  Future<void>? gate;

  @override
  Future<void> saveCanvas({
    required String assetId,
    required CanvasDocument document,
  }) async {
    if (gate != null) await gate;
    if (shouldFail) throw Exception('network down');
    saved.add(document);
  }

  @override
  Future<CanvasDocument> loadCanvas(String assetId) async =>
      const CanvasDocument(width: 1, height: 1);

  // Milestone 3.6 additions. These tests only exercise autosave, so the
  // rest of the contract is stubbed out rather than faked in detail —
  // any accidental call fails loudly instead of silently succeeding.
  @override
  Future<List<ContentAssetSummary>> list() async =>
      throw UnimplementedError('not exercised by autosave tests');

  @override
  Future<String> createAsset({required CanvasDocument document}) async =>
      throw UnimplementedError('not exercised by autosave tests');

  @override
  Future<void> deleteAsset(String assetId) async =>
      throw UnimplementedError('not exercised by autosave tests');

  @override
  Future<void> uploadMasterRender({
    required String assetId,
    required Uint8List pngBytes,
  }) async =>
      throw UnimplementedError('not exercised by autosave tests');

  @override
  Future<List<({String platform, String? renderedMediaUrl, String status})>>
      generateVariants({
    required String assetId,
    required List<String> platforms,
  }) async =>
          throw UnimplementedError('not exercised by autosave tests');
}

void main() {
  group('AutosaveController', () {
    late _FakeContentRepository repository;

    const docA = CanvasDocument(width: 1080, height: 1080);
    const docB = CanvasDocument(width: 1920, height: 1080);

    AutosaveController build({Duration debounce = const Duration(milliseconds: 50)}) =>
        AutosaveController(
          repository: repository,
          assetId: 'asset_1',
          debounceDuration: debounce,
        );

    setUp(() => repository = _FakeContentRepository());

    test('starts idle', () {
      expect(build().state.status, AutosaveStatus.idle);
    });

    test('goes pending immediately on a change, before the debounce fires', () {
      final controller = build();
      controller.onDocumentChanged(docA);

      expect(controller.state.status, AutosaveStatus.pending);
      expect(repository.saved, isEmpty, reason: 'must not save on every keystroke/frame');
    });

    test('saves once the debounce window elapses', () async {
      final controller = build();
      controller.onDocumentChanged(docA);

      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(repository.saved.length, 1);
      expect(controller.state.status, AutosaveStatus.saved);
    });

    test('collapses a burst of rapid edits into ONE save, keeping the last', () async {
      final controller = build();
      controller.onDocumentChanged(docA);
      controller.onDocumentChanged(docA);
      controller.onDocumentChanged(docB); // the latest wins

      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(repository.saved.length, 1, reason: 'debounce should coalesce the burst');
      expect(repository.saved.single.width, 1920);
    });

    test('flush saves immediately without waiting for the debounce', () async {
      final controller = build(debounce: const Duration(seconds: 30));
      controller.onDocumentChanged(docA);

      await controller.flush();

      expect(repository.saved.length, 1);
      expect(controller.state.status, AutosaveStatus.saved);
    });

    test('flush with nothing buffered is a harmless no-op', () async {
      final controller = build();
      await controller.flush();
      expect(repository.saved, isEmpty);
      expect(controller.state.status, AutosaveStatus.idle);
    });

    test('reports error status when the save fails', () async {
      repository.shouldFail = true;
      final controller = build();
      controller.onDocumentChanged(docA);

      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(controller.state.status, AutosaveStatus.error);
      expect(controller.state.errorMessage, isNotNull);
    });

    test('retains the unsaved document after a failure, and saves it on retry', () async {
      repository.shouldFail = true;
      final controller = build();
      controller.onDocumentChanged(docA);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(controller.state.status, AutosaveStatus.error);

      // Network recovers; the user's work must not have been dropped.
      repository.shouldFail = false;
      await controller.flush();

      expect(repository.saved.length, 1);
      expect(controller.state.status, AutosaveStatus.saved);
    });

    test('never runs two saves concurrently — the later edit is saved last', () async {
      final gate = Completer<void>();
      repository.gate = gate.future;

      final controller = build();
      controller.onDocumentChanged(docA);
      await Future<void>.delayed(const Duration(milliseconds: 80)); // save now in flight

      // An edit lands mid-flight. It must be buffered, not fired
      // concurrently — two overlapping PATCHes can land out of order and
      // persist the older document as final.
      controller.onDocumentChanged(docB);
      expect(repository.saved, isEmpty, reason: 'first save has not completed yet');

      repository.gate = null;
      gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(repository.saved.length, 2);
      expect(repository.saved.last.width, 1920, reason: 'the newest edit must win');
    });

    test('cancels a pending debounce on dispose rather than firing after teardown', () async {
      final controller = build(debounce: const Duration(milliseconds: 50));
      controller.onDocumentChanged(docA);
      controller.dispose();

      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(repository.saved, isEmpty);
    });
  });
}
