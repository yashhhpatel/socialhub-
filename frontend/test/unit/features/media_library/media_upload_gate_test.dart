import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:socialhub/core/network/auth_token_store.dart';
import 'package:socialhub/features/media_library/data/api_media_repository.dart';
import 'package:socialhub/features/media_library/data/file_picker.dart';
import 'package:socialhub/features/media_library/domain/media_item.dart';
import 'package:socialhub/features/media_library/presentation/screens/media_library_screen.dart';

/// Stateful fake repository so uploads never hit the network but still show up
/// in the persisted list on the next fetch (the screen re-reads after upload).
class _FakeMediaRepo extends ApiMediaRepository {
  _FakeMediaRepo() : super(Dio());

  final List<MediaItem> _items = [];

  @override
  Future<List<MediaItem>> list() async => List.of(_items);

  @override
  Future<MediaItem> upload({
    required Uint8List bytes,
    required String name,
    required String mimeType,
  }) async {
    final item = MediaItem(
      id: 'id_${_items.length}',
      url: 'https://cdn.test/$name',
      publicId: 'p1',
      type: mimeType.startsWith('video/') ? 'video' : 'image',
      name: name,
    );
    _items.insert(0, item);
    return item;
  }

  @override
  Future<void> delete(String id) async {
    _items.removeWhere((e) => e.id == id);
  }
}

/// Router hosting the Media screen (inside a Scaffold + scroll, like AppShell)
/// and a stub login route so a redirect is observable.
Widget _host({
  required List<Override> overrides,
}) {
  final router = GoRouter(
    initialLocation: '/media-library',
    routes: [
      GoRoute(
        path: '/media-library',
        builder: (_, __) => const Scaffold(
          body: SingleChildScrollView(child: MediaLibraryScreen()),
        ),
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
  testWidgets(
    'logged out: Upload is clickable, routes to login, and never opens the picker',
    (tester) async {
      var pickerCalled = false;
      final overrides = <Override>[
        // Token store defaults to null (logged out); make it explicit.
        authTokenStoreProvider.overrideWith((ref) => null),
        filePickerProvider.overrideWithValue(() async {
          pickerCalled = true;
          return null;
        }),
      ];
      await tester.pumpWidget(_host(overrides: overrides));
      await tester.pumpAndSettle();

      // The Upload button (a FilledButton.icon) is visible; its label is unique.
      final upload = find.text('Upload');
      expect(upload, findsOneWidget);

      await tester.tap(upload);
      await tester.pumpAndSettle();

      // Redirected to login, and the file picker was NOT opened.
      expect(find.text('LOGIN PAGE'), findsOneWidget);
      expect(pickerCalled, isFalse);
    },
  );

  testWidgets(
    'logged in: Upload opens the picker and does not redirect',
    (tester) async {
      var pickerCalled = false;
      final overrides = <Override>[
        authTokenStoreProvider.overrideWith((ref) => _loggedIn),
        mediaRepositoryProvider.overrideWithValue(_FakeMediaRepo()),
        filePickerProvider.overrideWithValue(() async {
          pickerCalled = true;
          return null; // user cancels — nothing to upload
        }),
      ];
      await tester.pumpWidget(_host(overrides: overrides));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Upload'));
      await tester.pumpAndSettle();

      // Picker opened, stayed on the Media page (no login redirect).
      expect(pickerCalled, isTrue);
      expect(find.text('LOGIN PAGE'), findsNothing);
      expect(find.text('Media Library'), findsOneWidget);
    },
  );

  testWidgets(
    'logged in: a picked file is uploaded and shown in the grid',
    (tester) async {
      final overrides = <Override>[
        authTokenStoreProvider.overrideWith((ref) => _loggedIn),
        mediaRepositoryProvider.overrideWithValue(_FakeMediaRepo()),
        filePickerProvider.overrideWithValue(
          () async => PickedFile(
            bytes: Uint8List.fromList([1, 2, 3]),
            name: 'photo.png',
            mimeType: 'image/png',
          ),
        ),
      ];
      await tester.pumpWidget(_host(overrides: overrides));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Upload'));
      await tester.pumpAndSettle();

      // The uploaded item appears (name rendered on its card) after the list
      // refreshes from the persisted store.
      expect(find.text('photo.png'), findsOneWidget);
      expect(find.text('LOGIN PAGE'), findsNothing);
    },
  );

  testWidgets(
    'logged in: an existing library item can be deleted',
    (tester) async {
      final repo = _FakeMediaRepo();
      await repo.upload(
        bytes: Uint8List.fromList([1]),
        name: 'old.png',
        mimeType: 'image/png',
      );
      final overrides = <Override>[
        authTokenStoreProvider.overrideWith((ref) => _loggedIn),
        mediaRepositoryProvider.overrideWithValue(repo),
        filePickerProvider.overrideWithValue(() async => null),
      ];
      await tester.pumpWidget(_host(overrides: overrides));
      await tester.pumpAndSettle();

      expect(find.text('old.png'), findsOneWidget);

      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('old.png'), findsNothing);
      expect(find.text('No uploads yet'), findsOneWidget);
    },
  );
}
