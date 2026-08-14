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

  /// All five platforms now have a real backend adapter + connect/callback
  /// route (Instagram 2.2, X 2.3, Facebook 8.1, Threads 8.2, LinkedIn 8.3),
  /// so every one is connectable. Kept as an explicit flag rather than
  /// inlining `true` at call sites: the connect repository still uses it as
  /// a defensive guard, and a future platform added to the enum ahead of
  /// its backend route would set this to false without touching callers.
  bool get isConnectable => true;

  static SocialPlatform fromApiValue(String value) =>
      SocialPlatform.values.byName(value);
}
