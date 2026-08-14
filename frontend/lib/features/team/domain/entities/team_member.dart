import '../../../../core/auth/app_role.dart';

/// A member of the org (GET /organizations/:orgId/members).
class TeamMember {
  const TeamMember({required this.id, required this.email, required this.role});

  final String id;
  final String email;
  final AppRole role;

  factory TeamMember.fromJson(Map<String, dynamic> json) => TeamMember(
        id: json['id'] as String,
        email: json['email'] as String,
        role: AppRoleX.fromApi(json['role'] as String),
      );
}

/// A pending invitation (GET /organizations/:orgId/invites).
class TeamInvite {
  const TeamInvite({
    required this.id,
    required this.email,
    required this.role,
    required this.status,
    this.expiresAt,
  });

  final String id;
  final String email;
  final AppRole role;
  final String status;
  final DateTime? expiresAt;

  factory TeamInvite.fromJson(Map<String, dynamic> json) => TeamInvite(
        id: json['id'] as String,
        email: json['email'] as String,
        role: AppRoleX.fromApi(json['role'] as String),
        status: json['status'] as String,
        expiresAt: json['expiresAt'] == null
            ? null
            : DateTime.tryParse(json['expiresAt'] as String),
      );
}
