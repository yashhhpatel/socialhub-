class AdminAuditRow {
  const AdminAuditRow({
    required this.id,
    required this.orgId,
    required this.actorEmail,
    required this.method,
    required this.path,
    required this.targetId,
    required this.statusCode,
    required this.createdAt,
  });

  final String id;
  final String orgId;
  final String actorEmail;
  final String method;
  final String path;
  final String? targetId;
  final int statusCode;
  final DateTime? createdAt;

  factory AdminAuditRow.fromJson(Map<String, dynamic> json) => AdminAuditRow(
        id: json['id'] as String,
        orgId: json['orgId'] as String? ?? '',
        actorEmail: json['actorEmail'] as String? ?? '',
        method: json['method'] as String? ?? '',
        path: json['path'] as String? ?? '',
        targetId: json['targetId'] as String?,
        statusCode: (json['statusCode'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      );
}

class AdminAuditList {
  const AdminAuditList({
    required this.data,
    required this.total,
    required this.page,
    required this.limit,
  });

  final List<AdminAuditRow> data;
  final int total;
  final int page;
  final int limit;

  int get totalPages => limit == 0 ? 1 : ((total + limit - 1) ~/ limit);

  factory AdminAuditList.fromJson(Map<String, dynamic> json) => AdminAuditList(
        data: (json['data'] as List<dynamic>? ?? [])
            .map((e) => AdminAuditRow.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: (json['total'] as num?)?.toInt() ?? 0,
        page: (json['page'] as num?)?.toInt() ?? 1,
        limit: (json['limit'] as num?)?.toInt() ?? 25,
      );
}
