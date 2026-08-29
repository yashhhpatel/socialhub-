import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialhub/core/network/auth_token_store.dart';
import 'package:socialhub/features/media_library/data/api_media_repository.dart';
import 'package:socialhub/features/media_library/domain/media_item.dart';
import 'package:socialhub/features/media_library/presentation/screens/media_library_screen.dart';

MediaItem _img(String name) => MediaItem(
      id: name,
      url: 'https://cdn.test/$name',
      publicId: name,
      type: 'image',
      name: name,
    );

MediaItem _vid(String name) => MediaItem(
      id: name,
      url: 'https://cdn.test/$name',
      publicId: name,
      type: 'video',
      name: name,
    );

Future<void> _pump(WidgetTester tester, List<MediaItem> items) async {
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authTokenStoreProvider.overrideWith(
          (ref) => const AuthTokens(accessToken: 't', refreshToken: 'r'),
        ),
        mediaLibraryProvider.overrideWith((ref) async => items),
      ],
      child: const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: MediaLibraryScreen())),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final library = [_img('photo.png'), _vid('clip.mp4'), _img('banner.jpg')];

  testWidgets('renders controls with the full count', (tester) async {
    await _pump(tester, library);
    expect(find.text('Showing 3 of 3'), findsOneWidget);
    expect(find.text('photo.png'), findsOneWidget);
    expect(find.text('clip.mp4'), findsOneWidget);
  });

  testWidgets('search narrows the grid by name', (tester) async {
    await _pump(tester, library);
    await tester.enterText(find.byType(TextField), 'photo');
    await tester.pumpAndSettle();

    expect(find.text('Showing 1 of 3'), findsOneWidget);
    expect(find.text('photo.png'), findsOneWidget);
    expect(find.text('clip.mp4'), findsNothing);
  });

  testWidgets('the Videos filter shows only videos', (tester) async {
    await _pump(tester, library);
    await tester.tap(find.text('Videos'));
    await tester.pumpAndSettle();

    expect(find.text('Showing 1 of 3'), findsOneWidget);
    expect(find.text('clip.mp4'), findsOneWidget);
    expect(find.text('photo.png'), findsNothing);
  });

  testWidgets('a search with no matches shows the no-matches state',
      (tester) async {
    await _pump(tester, library);
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();

    expect(find.text('No media matches your search'), findsOneWidget);
    expect(find.text('Showing 0 of 3'), findsOneWidget);
  });
}
