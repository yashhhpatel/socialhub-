import '../entities/publish_models.dart';

abstract class PublishRepository {
  /// The asset's per-platform renditions (Milestone 4.1), which are what
  /// actually get published.
  Future<List<PublishableVariant>> variantsForAsset(String assetId);

  /// Connected accounts available as publish destinations.
  Future<List<PublishTarget>> targets();

  /// Sends one variant to one account. Irreversible — this creates a real
  /// public post.
  ///
  /// [caption] overrides the variant's stored caption for this attempt
  /// (Milestone 5.3). Null means "use whatever the variant already has";
  /// an empty string means "post without a caption" — the backend
  /// distinguishes the two deliberately.
  Future<PublishJob> publishNow({
    required String variantId,
    required String socialAccountId,
    String? caption,
  });

  /// Publishes (or, when [scheduledAt] is set, schedules) an ordered set of
  /// media-library image URLs as one native carousel/album post. Irreversible
  /// on publish. The per-platform item ceiling is enforced by the backend.
  Future<void> publishCarousel({
    required String socialAccountId,
    required List<String> mediaUrls,
    String? caption,
    DateTime? scheduledAt,
  });

  Future<PublishJob> job(String jobId);
}
