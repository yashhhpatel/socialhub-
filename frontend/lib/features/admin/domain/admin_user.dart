/// A row in the admin users list (Phase 21.4).
class AdminUserListItem {
  const AdminUserListItem({
    required this.id,
    required this.email,
    required this.role,
    required this.orgId,
    required this.orgName,
    required this.emailVerified,
    required this.mfaEnabled,
    required this.isPlatformAdmin,
    required this.hasPassword,
    required this.hasGoogle,
    required this.createdAt,
  });

  final String id;
  final String email;
  final String role;
  final String orgId;
  final String orgName;
  final bool emailVerified;
  final bool mfaEnabled;
  final bool isPlatformAdmin;
  final bool hasPassword;
  final bool hasGoogle;
  final DateTime? createdAt;

  String get signInMethod {
    if (hasGoogle && hasPassword) return 'Google + password';
    if (hasGoogle) return 'Google';
    if (hasPassword) return 'Password';
    return '—';
  }

  factory AdminUserListItem.fromJson(Map<String, dynamic> json) =>
      AdminUserListItem(
        id: json['id'] as String,
        email: json['email'] as String? ?? '',
        role: json['role'] as String? ?? '',
        orgId: json['orgId'] as String? ?? '',
        orgName: json['orgName'] as String? ?? '',
        emailVerified: json['emailVerified'] as bool? ?? false,
        mfaEnabled: json['mfaEnabled'] as bool? ?? false,
        isPlatformAdmin: json['isPlatformAdmin'] as bool? ?? false,
        hasPassword: json['hasPassword'] as bool? ?? false,
        hasGoogle: json['hasGoogle'] as bool? ?? false,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      );
}

class AdminUserList {
  const AdminUserList({
    required this.data,
    required this.total,
    required this.page,
    required this.limit,
  });

  final List<AdminUserListItem> data;
  final int total;
  final int page;
  final int limit;

  int get totalPages => limit == 0 ? 1 : ((total + limit - 1) ~/ limit);

  factory AdminUserList.fromJson(Map<String, dynamic> json) => AdminUserList(
        data: (json['data'] as List<dynamic>? ?? [])
            .map((e) => AdminUserListItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: (json['total'] as num?)?.toInt() ?? 0,
        page: (json['page'] as num?)?.toInt() ?? 1,
        limit: (json['limit'] as num?)?.toInt() ?? 20,
      );
}

class AdminUserDetail extends AdminUserListItem {
  const AdminUserDetail({
    required super.id,
    required super.email,
    required super.role,
    required super.orgId,
    required super.orgName,
    required super.emailVerified,
    required super.mfaEnabled,
    required super.isPlatformAdmin,
    required super.hasPassword,
    required super.hasGoogle,
    required super.createdAt,
    required this.orgPlanTier,
  });

  final String orgPlanTier;

  factory AdminUserDetail.fromJson(Map<String, dynamic> json) {
    final base = AdminUserListItem.fromJson(json);
    return AdminUserDetail(
      id: base.id,
      email: base.email,
      role: base.role,
      orgId: base.orgId,
      orgName: base.orgName,
      emailVerified: base.emailVerified,
      mfaEnabled: base.mfaEnabled,
      isPlatformAdmin: base.isPlatformAdmin,
      hasPassword: base.hasPassword,
      hasGoogle: base.hasGoogle,
      createdAt: base.createdAt,
      orgPlanTier: json['orgPlanTier'] as String? ?? 'free',
    );
  }
}
