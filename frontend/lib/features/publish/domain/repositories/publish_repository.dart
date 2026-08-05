import '../entities/publish_models.dart';

abstract class PublishRepository {
  /// The asset's per-platform renditions (Milestone 4.1), which are what
  /// actually get published.
  Future<List<PublishableVariant>> variantsForAsset(String assetId);

  /// Connected accounts available as publish destinations.
  Future<List<PublishTarget>> targets();

  /// Sends one variant to one account. Irreversible — this creates a real
  /// public post.
  Future<PublishJob> publishNow({
    required String variantId,
    required String socialAccountId,
  });

  Future<PublishJob> job(String jobId);
}
