/// Generates an AI caption for a design (Milestone 5.3).
///
/// Owned by the publish feature rather than imported from features/ai_suite,
/// for the same reason PublishTarget is a publish-owned projection of a
/// social account: per docs/architecture — Flutter Web Application
/// Architecture §1, a feature never reaches into another feature's
/// internals. What publish needs is "give me caption text for this asset",
/// which is a narrower question than the AI suite's eventual surface.
abstract class CaptionRepository {
  /// Returns generated caption text for the asset.
  ///
  /// [tone] is optional; omitting it lets the model take its cue from the
  /// design itself, which is what the backend prompt does by default.
  Future<String> generate({required String assetId, String? tone});
}

/// The tones POST /ai/caption accepts.
///
/// Mirrors CaptionTone in backend/src/ai/prompts/caption.prompt.ts exactly —
/// the backend validates against this list with @IsIn, so a value that
/// drifts out of sync here becomes a 400 the user cannot act on. Kept as
/// plain strings because they cross the wire as-is.
const captionTones = <String>[
  'casual',
  'professional',
  'playful',
  'inspirational',
  'bold',
];
