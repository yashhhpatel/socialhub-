import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialhub/features/media_library/data/api_media_repository.dart';
import 'package:socialhub/features/media_library/domain/media_item.dart';
import 'package:socialhub/features/publish/data/repositories/api_publish_repository.dart';
import 'package:socialhub/features/publish/domain/entities/publish_models.dart';
import 'package:socialhub/features/publish/domain/repositories/publish_repository.dart';
import 'package:socialhub/features/publish/presentation/widgets/carousel_composer.dart';

class _FakePublishRepo implements PublishRepository {
  String? socialAccountId;
  List<String>? mediaUrls;
  String? caption;
  DateTime? scheduledAt;
  int calls = 0;

  @override
  Future<void> publishCarousel({
    required String socialAccountId,
    required List<String> mediaUrls,
    String? caption,
    DateTime? scheduledAt,
  }) async {
    calls++;
    this.socialAccountId = socialAccountId;
    this.mediaUrls = mediaUrls;
    this.caption = caption;
    this.scheduledAt = scheduledAt;
  }

  @override
  Future<List<PublishableVariant>> variantsForAsset(String assetId) async => [];
  @override
  Future<List<PublishTarget>> targets() async => const [
        PublishTarget(
          id: 'sa_x',
          platform: 'x',
          externalAccountId: 'x1',
          status: 'connected',
        ),
      ];
  @override
  Future<PublishJob> publishNow({
    required String variantId,
    required String socialAccountId,
    String? caption,
  }) async =>
      throw UnimplementedError();
  @override
  Future<PublishJob> job(String jobId) async => throw UnimplementedError();
}

MediaItem _img(String id) => MediaItem(
      id: id,
      url: 'https://cdn.test/$id.png',
      publicId: id,
      type: 'image',
      name: id,
    );

Future<void> _open(
  WidgetTester tester, {
  required _FakePublishRepo publish,
  List<MediaItem>? media,
}) async {
  tester.view.physicalSize = const Size(1000, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        publishRepositoryProvider.overrideWithValue(publish),
        mediaLibraryProvider.overrideWith(
          (ref) async => media ?? [_img('a'), _img('b'), _img('c')],
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showCarouselComposer(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('publish is disabled until an account + 2 images are chosen',
      (tester) async {
    final publish = _FakePublishRepo();
    await _open(tester, publish: publish);

    // The composer opened.
    expect(find.text('New carousel post'), findsOneWidget);

    FilledButton publishButton() =>
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Publish'));

    // Nothing selected yet → disabled.
    expect(publishButton().onPressed, isNull);

    // Pick the X account.
    await tester.tap(find.widgetWithText(ChoiceChip, 'X'));
    await tester.pumpAndSettle();
    // One image only → still disabled.
    await tester.tap(find.byKey(const ValueKey('carousel-tile-a')));
    await tester.pumpAndSettle();
    expect(publishButton().onPressed, isNull);

    // Second image → enabled.
    await tester.tap(find.byKey(const ValueKey('carousel-tile-b')));
    await tester.pumpAndSettle();
    expect(publishButton().onPressed, isNotNull);
  });

  testWidgets('publishing posts the ordered urls to the chosen account',
      (tester) async {
    final publish = _FakePublishRepo();
    await _open(tester, publish: publish);

    await tester.tap(find.widgetWithText(ChoiceChip, 'X'));
    await tester.pumpAndSettle();
    // Select b then a — order should follow selection, not grid order.
    await tester.tap(find.byKey(const ValueKey('carousel-tile-b')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('carousel-tile-a')));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Publish'));
    await tester.pumpAndSettle();

    expect(publish.calls, 1);
    expect(publish.socialAccountId, 'sa_x');
    expect(publish.mediaUrls, [
      'https://cdn.test/b.png',
      'https://cdn.test/a.png',
    ]);
    expect(publish.scheduledAt, isNull);
  });
}
