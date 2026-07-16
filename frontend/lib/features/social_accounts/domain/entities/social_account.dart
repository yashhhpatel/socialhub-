import 'social_platform.dart';

/// Mirrors backend/src/social-accounts/dto/social-account-summary.dto.ts
/// exactly. Never carries any token — the backend deliberately never
/// serializes accessTokenEnc/refreshTokenEnc, even encrypted, into any
/// API response (see that DTO's doc comment).
class SocialAccount {
  const SocialAccount({
    required this.id,
    required this.platform,
    required this.externalAccountId,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
  });

  final String id;
  final SocialPlatform platform;
  final String externalAccountId;

  /// One of 'connected' | 'expired' | 'revoked' | 'error' — kept as a
  /// raw string rather than a Dart enum for now, since nothing in the UI
  /// yet branches on anything beyond "is this the connected account for
  /// this platform" (see social_accounts_screen.dart). Promote to an enum
  /// if/when status-specific UI (e.g. a distinct "reconnect" flow for
  /// 'expired') is actually built.
  final String status;

  final DateTime? expiresAt;
  final DateTime createdAt;

  factory SocialAccount.fromJson(Map<String, dynamic> json) {
    return SocialAccount(
      id: json['id'] as String,
      platform: SocialPlatformX.fromApiValue(json['platform'] as String),
      externalAccountId: json['externalAccountId'] as String,
      status: json['status'] as String,
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
