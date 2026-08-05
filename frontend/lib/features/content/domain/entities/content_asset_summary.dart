/// A row in the content library list (Milestone 3.6).
///
/// Deliberately NOT the full asset: the library renders dozens of these
/// and has no use for each one's canvasJson, which is the single largest
/// field on the record. The editor loads the full document separately
/// via ContentRepository.loadCanvas when a design is actually opened.
class ContentAssetSummary {
  const ContentAssetSummary({
    required this.id,
    required this.type,
    required this.approvalStatus,
    required this.updatedAt,
    this.masterImageUrl,
    this.variantCount = 0,
  });

  final String id;
  final String type;
  final String approvalStatus;
  final DateTime updatedAt;

  /// Thumbnail for the library grid — null until the design has been
  /// exported at least once (see the editor's Export action).
  final String? masterImageUrl;

  final int variantCount;

  /// True once the asset has a render, which is the precondition for
  /// generating platform variants (the backend 422s otherwise — see
  /// VariantGeneratorService.assertRenderable).
  bool get canGenerateVariants => masterImageUrl != null;

  factory ContentAssetSummary.fromJson(Map<String, dynamic> json) {
    return ContentAssetSummary(
      id: json['id'] as String,
      type: json['type'] as String,
      approvalStatus: json['approvalStatus'] as String,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      masterImageUrl: json['masterImageUrl'] as String?,
      variantCount: (json['variants'] as List<dynamic>?)?.length ?? 0,
    );
  }
}
