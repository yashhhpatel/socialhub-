/// A template gallery card (Milestone 9.4) — no canvas payload, matching
/// the backend's list response which omits it to keep the list light.
class TemplateSummary {
  const TemplateSummary({
    required this.id,
    required this.name,
    this.category,
    this.thumbnailUrl,
    this.isOwn = false,
  });

  final String id;
  final String name;
  final String? category;
  final String? thumbnailUrl;

  /// Whether the current org owns this template — the only ones it may delete.
  /// Always true in the library; per-row in the marketplace.
  final bool isOwn;

  factory TemplateSummary.fromJson(Map<String, dynamic> json) =>
      TemplateSummary(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String?,
        thumbnailUrl: json['thumbnailUrl'] as String?,
        isOwn: json['isOwn'] as bool? ?? false,
      );
}

/// A full template including the canvas payload to clone into a new design.
class TemplateDetail {
  const TemplateDetail({
    required this.id,
    required this.name,
    required this.canvasJson,
    this.category,
    this.thumbnailUrl,
  });

  final String id;
  final String name;
  final String? category;
  final String? thumbnailUrl;

  /// The editor-owned canvas payload — passed straight to
  /// CanvasDocument.fromJson when starting a design from this template.
  final Map<String, dynamic> canvasJson;

  factory TemplateDetail.fromJson(Map<String, dynamic> json) => TemplateDetail(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String?,
        thumbnailUrl: json['thumbnailUrl'] as String?,
        canvasJson: json['canvasJson'] as Map<String, dynamic>,
      );
}
