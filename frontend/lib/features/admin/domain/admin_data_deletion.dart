class AdminDataDeletionRow {
  const AdminDataDeletionRow({
    required this.id,
    required this.platform,
    required this.confirmationCode,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String platform;
  final String confirmationCode;
  final String status;
  final DateTime? createdAt;

  factory AdminDataDeletionRow.fromJson(Map<String, dynamic> json) =>
      AdminDataDeletionRow(
        id: json['id'] as String,
        platform: json['platform'] as String? ?? '',
        confirmationCode: json['confirmationCode'] as String? ?? '',
        status: json['status'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      );
}

class AdminDataDeletionList {
  const AdminDataDeletionList({
    required this.data,
    required this.total,
    required this.page,
    required this.limit,
  });

  final List<AdminDataDeletionRow> data;
  final int total;
  final int page;
  final int limit;

  factory AdminDataDeletionList.fromJson(Map<String, dynamic> json) =>
      AdminDataDeletionList(
        data: (json['data'] as List<dynamic>? ?? [])
            .map((e) => AdminDataDeletionRow.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: (json['total'] as num?)?.toInt() ?? 0,
        page: (json['page'] as num?)?.toInt() ?? 1,
        limit: (json['limit'] as num?)?.toInt() ?? 25,
      );
}
