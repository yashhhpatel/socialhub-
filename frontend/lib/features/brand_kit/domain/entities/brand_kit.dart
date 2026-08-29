/// An org's reusable brand assets (Milestone 9.3) — the colours, fonts and
/// logo applied across designs. Mirrors the backend BrandKitDto
/// (backend/src/brand-kits/dto/brand-kit.dto.ts).
///
/// Deliberately a plain value type with no dependency on the editor's
/// canvas model: the transform that applies a kit to a design lives in the
/// editor feature (which owns that model), so the dependency runs
/// editor -> brand_kit, never the other way.
class BrandKit {
  const BrandKit({
    required this.id,
    this.colors = const [],
    this.fonts = const [],
    this.logoUrl,
    this.logoPublicId,
  });

  final String id;

  /// Hex colours, e.g. `#1A2B3C`. By convention the first is the primary
  /// brand colour; a second, when present, is treated as the accent.
  final List<String> colors;

  /// Font-family names, first being the primary.
  final List<String> fonts;

  final String? logoUrl;
  final String? logoPublicId;

  bool get isEmpty => colors.isEmpty && fonts.isEmpty && logoUrl == null;

  String? get primaryColor => colors.isNotEmpty ? colors.first : null;

  /// The accent — the second colour if there is one, otherwise the primary,
  /// otherwise null. Used so shapes and text don't collapse to one colour
  /// when a kit defines two.
  String? get accentColor =>
      colors.length > 1 ? colors[1] : (colors.isNotEmpty ? colors.first : null);

  String? get primaryFont => fonts.isNotEmpty ? fonts.first : null;

  factory BrandKit.fromJson(Map<String, dynamic> json) => BrandKit(
        id: json['id'] as String,
        colors: [
          for (final c in (json['colors'] as List<dynamic>? ?? [])) c as String,
        ],
        fonts: [
          for (final f in (json['fonts'] as List<dynamic>? ?? [])) f as String,
        ],
        logoUrl: json['logoUrl'] as String?,
        logoPublicId: json['logoPublicId'] as String?,
      );
}
