/// Matches the backend's Prisma `Platform` enum values exactly (see
/// backend/prisma/schema.prisma) — `.name` is used directly as the wire
/// value, no translation layer needed.
enum SocialPlatform { instagram, facebook, threads, x, linkedin }

extension SocialPlatformX on SocialPlatform {
  /// The exact string the backend expects/returns.
  String get apiValue => name;

  String get label => switch (this) {
        SocialPlatform.instagram => 'Instagram',
        SocialPlatform.facebook => 'Facebook',
        SocialPlatform.threads => 'Threads',
        SocialPlatform.x => 'X',
        SocialPlatform.linkedin => 'LinkedIn',
      };

  /// Only Instagram (Milestone 2.2) and X (Milestone 2.3) have a real
  /// backend adapter/route so far. Facebook/Threads/LinkedIn arrive in
  /// Phase 8 — shown in this screen as "coming soon" rather than omitted
  /// entirely, so the UI already communicates the full target platform
  /// set per the architecture doc's product vision.
  bool get isConnectable =>
      this == SocialPlatform.instagram || this == SocialPlatform.x;

  static SocialPlatform fromApiValue(String value) =>
      SocialPlatform.values.byName(value);
}
