import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialhub/core/network/auth_token_store.dart';
import 'package:socialhub/features/content/data/repositories/api_content_repository.dart';
import 'package:socialhub/features/content/domain/entities/content_asset_summary.dart';
import 'package:socialhub/features/content/domain/repositories/content_repository.dart';
import 'package:socialhub/features/content/presentation/screens/content_screen.dart';
import 'package:socialhub/features/content/presentation/state/content_library_controller.dart';
import 'package:socialhub/features/editor/canvas/models/canvas_document.dart';

/// Fake repo: records delete calls and can be told to fail.
class _FakeRepo implements ContentRepository {
  int deleteCalls = 0;
  bool fail = false;

  @override
  Future<void> deleteAsset(String assetId) async {
    deleteCalls++;
    if (fail) throw Exception('server error');
  }

  @override
  Future<List<ContentAssetSummary>> list() async => const [];
  @override
  Future<String> createAsset({required CanvasDocument document}) async => 'x';
  @override
  Future<CanvasDocument> loadCanvas(String assetId) async =>
      const CanvasDocument(width: 1080, height: 1080);
  @override
  Future<void> saveCanvas({
    required String assetId,
    required CanvasDocument document,
  }) async {}
  @override
  Future<void> uploadMasterRender({
    required String assetId,
    required Uint8List pngBytes,
  }) async {}
  @override
  Future<List<({String platform, String? renderedMediaUrl, String status})>>
      generateVariants({
    required String assetId,
    required List<String> platforms,
  }) async =>
          const [];
}

ContentAssetSummary _asset(String id) => ContentAssetSummary(
      id: id,
      type: 'image',
      approvalStatus: 'draft',
      updatedAt: DateTime(2026),
    );

Widget _host(_FakeRepo repo, List<ContentAssetSummary> assets) => ProviderScope(
      overrides: [
        // Signed in, so delete runs the real action rather than the demo's
        // route-to-login gate.
        authTokenStoreProvider.overrideWith(
          (ref) => const AuthTokens(accessToken: 't', refreshToken: 'r'),
        ),
        contentRepositoryProvider.overrideWithValue(repo),
        contentLibraryProvider.overrideWith((ref) async => assets),
      ],
      child: const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: ContentScreen())),
      ),
    );

void main() {
  const id1 = 'ff438eb2aaaa';
  const id2 = 'c0606f5cbbbb';

  testWidgets('each card has a delete button', (tester) async {
    await tester.pumpWidget(_host(_FakeRepo(), [_asset(id1), _asset(id2)]));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Delete'), findsNWidgets(2));
  });

  testWidgets('confirm dialog shows the design name; confirming removes it',
      (tester) async {
    final repo = _FakeRepo();
    await tester.pumpWidget(_host(repo, [_asset(id1), _asset(id2)]));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Delete').first);
    await tester.pumpAndSettle();

    // Confirmation with the draft name.
    expect(find.text('Delete design?'), findsOneWidget);
    expect(find.textContaining('Design ff438eb2'), findsWidgets);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(repo.deleteCalls, 1);
    // The design is gone from the grid; the other remains.
    expect(find.text('Design ff438eb2'), findsNothing);
    expect(find.text('Design c0606f5c'), findsOneWidget);
    // Success feedback.
    expect(find.textContaining('deleted'), findsOneWidget);
  });

  testWidgets('cancel deletes nothing', (tester) async {
    final repo = _FakeRepo();
    await tester.pumpWidget(_host(repo, [_asset(id1)]));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Delete').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(repo.deleteCalls, 0);
    expect(find.text('Design ff438eb2'), findsOneWidget);
    expect(find.text('Delete design?'), findsNothing); // dialog closed
  });

  testWidgets('failure keeps the design and shows an error (no freeze)',
      (tester) async {
    final repo = _FakeRepo()..fail = true;
    await tester.pumpWidget(_host(repo, [_asset(id1)]));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Delete').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(repo.deleteCalls, 1);
    // Dialog is closed (no lingering barrier), design still present + its
    // delete button is interactive again.
    expect(find.text('Delete design?'), findsNothing);
    expect(find.text('Design ff438eb2'), findsOneWidget);
    expect(find.byTooltip('Delete'), findsOneWidget);
    expect(find.textContaining('Delete failed'), findsOneWidget);
  });
}
