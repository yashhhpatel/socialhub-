import 'dart:typed_data';

import 'package:dio/dio.dart';
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
import 'package:socialhub/features/editor/canvas/models/canvas_layer.dart';
import 'package:socialhub/features/media_library/data/api_media_repository.dart';
import 'package:socialhub/features/media_library/data/file_picker.dart';
import 'package:socialhub/features/media_library/domain/media_item.dart';

/// Captures the created design so the test can inspect the layer built from the
/// upload; every other method is a harmless stub.
class _FakeContentRepo implements ContentRepository {
  CanvasDocument? created;

  @override
  Future<String> createAsset({required CanvasDocument document}) async {
    created = document;
    return 'new_asset_id';
  }

  @override
  Future<List<ContentAssetSummary>> list() async => const [];
  @override
  Future<void> deleteAsset(String assetId) async {}
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

class _FakeMediaRepo extends ApiMediaRepository {
  _FakeMediaRepo() : super(Dio());

  @override
  Future<List<MediaItem>> list() async => const [];

  @override
  Future<MediaItem> upload({
    required Uint8List bytes,
    required String name,
    required String mimeType,
  }) async =>
      MediaItem(
        id: 'm1',
        url: 'https://cdn.test/$name',
        publicId: 'p1',
        type: mimeType.startsWith('video/') ? 'video' : 'image',
        name: name,
      );
}

Widget _host({required List<Override> overrides}) {
  final router = GoRouter(
    initialLocation: '/content',
    routes: [
      GoRoute(
        path: '/content',
        builder: (_, __) =>
            const Scaffold(body: SingleChildScrollView(child: ContentScreen())),
      ),
      GoRoute(
        path: '/editor/:id',
        builder: (_, state) => Text('EDITOR ${state.pathParameters['id']}'),
      ),
      GoRoute(path: '/login', builder: (_, __) => const Text('LOGIN PAGE')),
    ],
  );
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(routerConfig: router),
  );
}

const _loggedIn = AuthTokens(accessToken: 'a', refreshToken: 'r');

void main() {
  testWidgets('an Upload button sits on the Content header', (tester) async {
    await tester.pumpWidget(_host(overrides: [
      contentLibraryProvider.overrideWith((ref) async => const []),
    ],),);
    await tester.pumpAndSettle();
    expect(find.text('Upload'), findsOneWidget);
  });

  testWidgets('logged out: Upload routes to login and never opens the picker',
      (tester) async {
    var pickerCalled = false;
    await tester.pumpWidget(_host(overrides: [
      authTokenStoreProvider.overrideWith((ref) => null),
      contentLibraryProvider.overrideWith((ref) async => const []),
      filePickerProvider.overrideWithValue(() async {
        pickerCalled = true;
        return null;
      }),
    ],),);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();

    expect(find.text('LOGIN PAGE'), findsOneWidget);
    expect(pickerCalled, isFalse);
  });

  testWidgets(
      'logged in: uploading creates a design with the image and opens the editor',
      (tester) async {
    final content = _FakeContentRepo();
    await tester.pumpWidget(_host(overrides: [
      authTokenStoreProvider.overrideWith((ref) => _loggedIn),
      contentLibraryProvider.overrideWith((ref) async => const []),
      mediaRepositoryProvider.overrideWithValue(_FakeMediaRepo()),
      contentRepositoryProvider.overrideWithValue(content),
      // Bytes that don't decode → the artboard falls back to 1080×1080, which
      // keeps the test deterministic without bundling a real image.
      filePickerProvider.overrideWithValue(() async => PickedFile(
            bytes: Uint8List.fromList([1, 2, 3, 4]),
            name: 'photo.png',
            mimeType: 'image/png',
          ),),
    ],),);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();

    // A design was created from the upload: one image layer pointing at the
    // uploaded URL.
    final doc = content.created;
    expect(doc, isNotNull);
    expect(doc!.layers, hasLength(1));
    final layer = doc.layers.single;
    expect(layer, isA<ImageCanvasLayer>());
    expect((layer as ImageCanvasLayer).imageUrl, 'https://cdn.test/photo.png');

    // And the editor opened on the new asset.
    expect(find.text('EDITOR new_asset_id'), findsOneWidget);
  });
}
