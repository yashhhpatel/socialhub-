/// A row in the admin organizations list (Phase 21.3).
class AdminOrgListItem {
  const AdminOrgListItem({
    required this.id,
    required this.name,
    required this.planTier,
    required this.subscriptionStatus,
    required this.memberCount,
    required this.socialAccountCount,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String planTier;
  final String? subscriptionStatus;
  final int memberCount;
  final int socialAccountCount;
  final DateTime? createdAt;

  factory AdminOrgListItem.fromJson(Map<String, dynamic> json) => AdminOrgListItem(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        planTier: json['planTier'] as String? ?? 'free',
        subscriptionStatus: json['subscriptionStatus'] as String?,
        memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
        socialAccountCount: (json['socialAccountCount'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      );
}

/// Paginated list envelope.
class AdminOrgList {
  const AdminOrgList({
    required this.data,
    required this.total,
    required this.page,
    required this.limit,
  });

  final List<AdminOrgListItem> data;
  final int total;
  final int page;
  final int limit;

  int get totalPages => limit == 0 ? 1 : ((total + limit - 1) ~/ limit);

  factory AdminOrgList.fromJson(Map<String, dynamic> json) => AdminOrgList(
        data: (json['data'] as List<dynamic>? ?? [])
            .map((e) => AdminOrgListItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: (json['total'] as num?)?.toInt() ?? 0,
        page: (json['page'] as num?)?.toInt() ?? 1,
        limit: (json['limit'] as num?)?.toInt() ?? 20,
      );
}

class AdminOrgMember {
  const AdminOrgMember({
    required this.id,
    required this.email,
    required this.role,
    required this.emailVerified,
    required this.mfaEnabled,
    required this.isPlatformAdmin,
  });

  final String id;
  final String email;
  final String role;
  final bool emailVerified;
  final bool mfaEnabled;
  final bool isPlatformAdmin;

  factory AdminOrgMember.fromJson(Map<String, dynamic> json) => AdminOrgMember(
        id: json['id'] as String,
        email: json['email'] as String? ?? '',
        role: json['role'] as String? ?? '',
        emailVerified: json['emailVerified'] as bool? ?? false,
        mfaEnabled: json['mfaEnabled'] as bool? ?? false,
        isPlatformAdmin: json['isPlatformAdmin'] as bool? ?? false,
      );
}

class AdminOrgDetail {
  const AdminOrgDetail({
    required this.id,
    required this.name,
    required this.planTier,
    required this.requiresApproval,
    required this.subscriptionStatus,
    required this.createdAt,
    required this.members,
    required this.usage,
    required this.limits,
    required this.activity,
  });

  final String id;
  final String name;
  final String planTier;
  final bool requiresApproval;
  final String? subscriptionStatus;
  final DateTime? createdAt;
  final List<AdminOrgMember> members;
  final Map<String, int> usage;
  final Map<String, int> limits;
  final Map<String, int> activity;

  factory AdminOrgDetail.fromJson(Map<String, dynamic> json) {
    Map<String, int> ints(String key) {
      final m = json[key] as Map<String, dynamic>? ?? {};
      return m.map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0));
    }

    return AdminOrgDetail(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      planTier: json['planTier'] as String? ?? 'free',
      requiresApproval: json['requiresApproval'] as bool? ?? false,
      subscriptionStatus: json['subscriptionStatus'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      members: (json['members'] as List<dynamic>? ?? [])
          .map((e) => AdminOrgMember.fromJson(e as Map<String, dynamic>))
          .toList(),
      usage: ints('usage'),
      limits: ints('limits'),
      activity: ints('activity'),
    );
  }
}
