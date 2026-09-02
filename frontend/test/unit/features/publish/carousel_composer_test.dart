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
  final publishedAccountIds = <String>[];

  @override
  Future<void> publishCarousel({
    required String socialAccountId,
    required List<String> mediaUrls,
    String? caption,
    DateTime? scheduledAt,
  }) async {
    calls++;
    publishedAccountIds.add(socialAccountId);
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
        PublishTarget(
          id: 'sa_ig',
          platform: 'instagram',
          externalAccountId: 'ig1',
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
  testWidgets('publish is disabled until an account + at least 1 image is chosen',
      (tester) async {
    final publish = _FakePublishRepo();
    await _open(tester, publish: publish);

    // The composer opened.
    expect(find.text('Create Post'), findsOneWidget);

    FilledButton publishButton() =>
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Publish'));

    // Nothing selected yet → disabled.
    expect(publishButton().onPressed, isNull);

    // Pick the X account — still no images, so still disabled.
    await tester.tap(find.widgetWithText(FilterChip, 'X'));
    await tester.pumpAndSettle();
    expect(publishButton().onPressed, isNull);

    // A single image is enough for a carousel now → enabled.
    await tester.tap(find.byKey(const ValueKey('carousel-tile-a')));
    await tester.pumpAndSettle();
    expect(publishButton().onPressed, isNotNull);
  });

  testWidgets('a single image can be published as a carousel', (tester) async {
    final publish = _FakePublishRepo();
    await _open(tester, publish: publish);

    await tester.tap(find.widgetWithText(FilterChip, 'X'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('carousel-tile-a')));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Publish'));
    await tester.pumpAndSettle();

    expect(publish.calls, 1);
    expect(publish.socialAccountId, 'sa_x');
    expect(publish.mediaUrls, ['https://cdn.test/a.png']);
  });

  testWidgets('publishing posts the ordered urls to the chosen account',
      (tester) async {
    final publish = _FakePublishRepo();
    await _open(tester, publish: publish);

    await tester.tap(find.widgetWithText(FilterChip, 'X'));
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

  testWidgets('caption and hashtags are combined into the published caption',
      (tester) async {
    final publish = _FakePublishRepo();
    await _open(tester, publish: publish);

    await tester.tap(find.widgetWithText(FilterChip, 'X'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('carousel-tile-a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('carousel-tile-b')));
    await tester.pumpAndSettle();

    final captionField = find.widgetWithText(TextField, 'Caption (optional)');
    final hashtagField = find.widgetWithText(TextField, 'Hashtags (optional)');
    await tester.ensureVisible(captionField);
    await tester.enterText(captionField, 'Launch day!');
    await tester.ensureVisible(hashtagField);
    await tester.enterText(hashtagField, 'launch, #Sale marketing');
    await tester.pumpAndSettle();

    final publishBtn = find.widgetWithText(FilledButton, 'Publish');
    await tester.ensureVisible(publishBtn);
    await tester.tap(publishBtn);
    await tester.pumpAndSettle();

    // Caption, blank line, then normalised hashtags (deduped, each #-prefixed).
    expect(publish.caption, 'Launch day!\n\n#launch #Sale #marketing');
  });

  testWidgets('selecting multiple platforms publishes to each of them',
      (tester) async {
    final publish = _FakePublishRepo();
    await _open(tester, publish: publish);

    // Choose BOTH connected accounts.
    await tester.tap(find.widgetWithText(FilterChip, 'X'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Instagram'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('carousel-tile-a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('carousel-tile-b')));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Publish'));
    await tester.pumpAndSettle();

    // The same carousel was published to both accounts.
    expect(publish.calls, 2);
    expect(publish.publishedAccountIds, containsAll(['sa_x', 'sa_ig']));
  });
}
