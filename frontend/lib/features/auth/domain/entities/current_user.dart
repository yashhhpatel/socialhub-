import '../../../../core/auth/app_role.dart';

/// The signed-in user, as returned by GET /users/me. The backend re-reads
/// this from the DB each call, so `role` here is always current — which is
/// what role-gated UI should key off (not the possibly-stale role baked into
/// the JWT at login).
class CurrentUser {
  const CurrentUser({
    required this.id,
    required this.email,
    required this.role,
    required this.orgId,
    required this.emailVerified,
  });

  final String id;
  final String email;
  final AppRole role;
  final String orgId;

  /// Whether the user has confirmed their email (Phase 17.1). Drives the
  /// "verify your email" banner; defaults to true for older API responses
  /// that predate the field, so the banner never shows spuriously.
  final bool emailVerified;

  bool get isAdmin => role.isAtLeast(AppRole.admin);
  bool get isEditor => role.isAtLeast(AppRole.editor);

  factory CurrentUser.fromJson(Map<String, dynamic> json) => CurrentUser(
        id: json['id'] as String,
        email: json['email'] as String,
        role: AppRoleX.fromApi(json['role'] as String),
        orgId: json['orgId'] as String,
        emailVerified: json['emailVerified'] as bool? ?? true,
      );
}
