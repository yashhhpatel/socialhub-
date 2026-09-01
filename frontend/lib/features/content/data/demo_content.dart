import '../domain/entities/content_asset_summary.dart';

/// Sample design library shown to signed-out visitors so the Content grid is
/// populated. Thumbnails use a public seeded placeholder-image service (each
/// falls back to the card's placeholder if it can't load). Never shown once a
/// session exists.
List<ContentAssetSummary> demoContentAssets() {
  final now = DateTime.now();
  ContentAssetSummary a(
    String id,
    String seed,
    String status,
    int variants,
    Duration ago,
  ) =>
      ContentAssetSummary(
        id: id,
        type: 'design',
        approvalStatus: status,
        updatedAt: now.subtract(ago),
        masterImageUrl: 'https://picsum.photos/seed/$seed/600/600',
        variantCount: variants,
      );

  return [
    a('9f2a71c4design', 'design-launch', 'approved', 5, const Duration(hours: 3)),
    a('4b8e05d1design', 'design-sale', 'pending', 3, const Duration(hours: 9)),
    a('c17d9a30design', 'design-quote', 'approved', 4, const Duration(days: 1)),
    a('2e6f88b2design', 'design-bts', 'draft', 0, const Duration(days: 2)),
    a('a30c4417design', 'design-event', 'approved', 2, const Duration(days: 4)),
    a('77b1e2f9design', 'design-review', 'pending', 1, const Duration(days: 6)),
  ];
}
