/// A persisted media-library item (Phase 19). Backed by the server's
/// `MediaAsset` table, so it survives across sessions.
class MediaItem {
  const MediaItem({
    required this.id,
    required this.url,
    required this.publicId,
    required this.type,
    required this.name,
    this.posterUrl,
  });

  final String id;
  final String url;
  final String publicId;
  final String type;
  final String name;
  final String? posterUrl;

  bool get isVideo => type == 'video';

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      id: json['id'] as String,
      url: json['url'] as String,
      publicId: json['publicId'] as String,
      type: json['type'] as String? ?? 'image',
      name: json['name'] as String? ?? 'Untitled',
      posterUrl: json['posterUrl'] as String?,
    );
  }
}
