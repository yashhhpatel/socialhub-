/// A publish job in the admin view (Phase 21.7).
class AdminPublishJob {
  const AdminPublishJob({
    required this.id,
    required this.orgName,
    required this.platform,
    required this.status,
    required this.attemptCount,
    required this.lastError,
    required this.scheduledAt,
  });

  final String id;
  final String orgName;
  final String platform;
  final String status;
  final int attemptCount;
  final String? lastError;
  final DateTime? scheduledAt;

  bool get isPublished => status == 'published';

  factory AdminPublishJob.fromJson(Map<String, dynamic> json) => AdminPublishJob(
        id: json['id'] as String,
        orgName: json['orgName'] as String? ?? '',
        platform: json['platform'] as String? ?? '',
        status: json['status'] as String? ?? '',
        attemptCount: (json['attemptCount'] as num?)?.toInt() ?? 0,
        lastError: json['lastError'] as String?,
        scheduledAt: DateTime.tryParse(json['scheduledAt'] as String? ?? ''),
      );
}

class AdminPublishJobList {
  const AdminPublishJobList({
    required this.data,
    required this.total,
    required this.page,
    required this.limit,
  });

  final List<AdminPublishJob> data;
  final int total;
  final int page;
  final int limit;

  int get totalPages => limit == 0 ? 1 : ((total + limit - 1) ~/ limit);

  factory AdminPublishJobList.fromJson(Map<String, dynamic> json) =>
      AdminPublishJobList(
        data: (json['data'] as List<dynamic>? ?? [])
            .map((e) => AdminPublishJob.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: (json['total'] as num?)?.toInt() ?? 0,
        page: (json['page'] as num?)?.toInt() ?? 1,
        limit: (json['limit'] as num?)?.toInt() ?? 20,
      );
}
