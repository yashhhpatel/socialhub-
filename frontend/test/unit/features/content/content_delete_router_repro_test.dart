import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:socialhub/core/network/auth_token_store.dart';
import 'package:socialhub/features/content/data/repositories/api_content_repository.dart';
import 'package:socialhub/features/content/domain/entities/content_asset_summary.dart';
import 'package:socialhub/features/content/domain/repositories/content_repository.dart';
import 'package:socialhub/features/content/presentation/screens/content_screen.dart';
import 'package:socialhub/features/content/presentation/state/content_library_controller.dart';
import 'package:socialhub/features/editor/canvas/models/canvas_document.dart';

/// Reproduces the real app's routing: ContentScreen lives inside a ShellRoute
/// (nested navigator), with a top-level /editor route the card taps into. This
/// is the environment the plain-MaterialApp test skipped.
class _FakeRepo implements ContentRepository {
  int deleteCalls = 0;
  bool fail = false;

  @override
  Future<void> deleteAsset(String assetId) async {
    deleteCalls++;
    if (fail) throw Exception('server 500');
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

Widget _host(_FakeRepo repo, List<ContentAssetSummary> assets) {
  final router = GoRouter(
    initialLocation: '/content',
    routes: [
      // Top-level editor route (outside the shell), like the real app.
      GoRoute(
        path: '/editor/:id',
        builder: (_, __) => const Scaffold(body: Text('EDITOR OPENED')),
      ),
      ShellRoute(
        builder: (_, __, child) =>
            Scaffold(body: SingleChildScrollView(child: child)),
        routes: [
          GoRoute(path: '/content', builder: (_, __) => const ContentScreen()),
        ],
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      authTokenStoreProvider.overrideWith(
        (ref) => const AuthTokens(accessToken: 't', refreshToken: 'r'),
      ),
      contentRepositoryProvider.overrideWithValue(repo),
      contentLibraryProvider.overrideWith((ref) async => assets),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  const id1 = 'ff438eb2aaaa';

  testWidgets('delete inside a ShellRoute: opens dialog, does NOT navigate',
      (tester) async {
    final repo = _FakeRepo();
    await tester.pumpWidget(_host(repo, [_asset(id1)]));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();

    // Tapping delete must not open the editor (card InkWell must not fire).
    expect(find.text('EDITOR OPENED'), findsNothing);
    expect(find.text('Delete design?'), findsOneWidget);
  });

  testWidgets('confirm deletes, dialog closes, app stays interactive',
      (tester) async {
    final repo = _FakeRepo();
    await tester.pumpWidget(_host(repo, [_asset(id1)]));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(repo.deleteCalls, 1);
    // The dialog route (and therefore its own barrier) is gone: the app is
    // not frozen behind a stranded modal. NB: a routed MaterialApp always has
    // a transparent, non-dismissible background ModalBarrier per route, so we
    // assert on the dialog itself, not on find.byType(ModalBarrier).
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Delete design?'), findsNothing);
    // The deleted card is gone; feedback shown; the editor never opened.
    expect(find.text('Design ff438eb2'), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('EDITOR OPENED'), findsNothing);
  });

  testWidgets('failure closes dialog, keeps draft, app stays interactive',
      (tester) async {
    final repo = _FakeRepo()..fail = true;
    await tester.pumpWidget(_host(repo, [_asset(id1)]));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Delete design?'), findsNothing);
    expect(find.text('Design ff438eb2'), findsOneWidget);
    expect(find.textContaining('Delete failed'), findsOneWidget);
    // Delete button is interactive again (spinner cleared).
    expect(find.byTooltip('Delete'), findsOneWidget);
  });
}
