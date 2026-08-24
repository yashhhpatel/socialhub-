/// A social account in the admin health view (Phase 21.5). No token data.
class AdminSocialAccount {
  const AdminSocialAccount({
    required this.id,
    required this.orgId,
    required this.orgName,
    required this.platform,
    required this.externalAccountId,
    required this.status,
    required this.expiresAt,
  });

  final String id;
  final String orgId;
  final String orgName;
  final String platform;
  final String externalAccountId;
  final String status;
  final DateTime? expiresAt;

  bool get needsReconnect => status != 'connected';

  factory AdminSocialAccount.fromJson(Map<String, dynamic> json) =>
      AdminSocialAccount(
        id: json['id'] as String,
        orgId: json['orgId'] as String? ?? '',
        orgName: json['orgName'] as String? ?? '',
        platform: json['platform'] as String? ?? '',
        externalAccountId: json['externalAccountId'] as String? ?? '',
        status: json['status'] as String? ?? '',
        expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? ''),
      );
}

class AdminSocialAccountList {
  const AdminSocialAccountList({
    required this.data,
    required this.total,
    required this.page,
    required this.limit,
  });

  final List<AdminSocialAccount> data;
  final int total;
  final int page;
  final int limit;

  int get totalPages => limit == 0 ? 1 : ((total + limit - 1) ~/ limit);

  factory AdminSocialAccountList.fromJson(Map<String, dynamic> json) =>
      AdminSocialAccountList(
        data: (json['data'] as List<dynamic>? ?? [])
            .map((e) => AdminSocialAccount.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: (json['total'] as num?)?.toInt() ?? 0,
        page: (json['page'] as num?)?.toInt() ?? 1,
        limit: (json['limit'] as num?)?.toInt() ?? 20,
      );
}
