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
  testWidgets('tapping an image thumbnail opens a larger, zoomable preview',
      (tester) async {
    await _pump(tester, [_img('photo.png')]);

    // No dialog until the thumbnail is tapped.
    expect(find.byType(Dialog), findsNothing);

    await tester.tap(find.byType(Image).first);
    await tester.pumpAndSettle();

    // A preview dialog opens with a zoomable image and a close control.
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byTooltip('Close'), findsOneWidget);

    // Closing dismisses it.
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });
}
