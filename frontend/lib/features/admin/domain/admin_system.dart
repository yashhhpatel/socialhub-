class AdminHealth {
  const AdminHealth({
    required this.db,
    required this.redis,
    required this.uptimeSeconds,
    required this.sentryConfigured,
  });
  final bool db;
  final bool redis;
  final int uptimeSeconds;
  final bool sentryConfigured;

  factory AdminHealth.fromJson(Map<String, dynamic> j) => AdminHealth(
        db: j['db'] as bool? ?? false,
        redis: j['redis'] as bool? ?? false,
        uptimeSeconds: (j['uptimeSeconds'] as num?)?.toInt() ?? 0,
        sentryConfigured: j['sentryConfigured'] as bool? ?? false,
      );
}

class AdminQueueStat {
  const AdminQueueStat({
    required this.name,
    required this.waiting,
    required this.active,
    required this.completed,
    required this.failed,
    required this.delayed,
  });
  final String name;
  final int waiting;
  final int active;
  final int completed;
  final int failed;
  final int delayed;

  factory AdminQueueStat.fromJson(Map<String, dynamic> j) => AdminQueueStat(
        name: j['name'] as String? ?? '',
        waiting: (j['waiting'] as num?)?.toInt() ?? 0,
        active: (j['active'] as num?)?.toInt() ?? 0,
        completed: (j['completed'] as num?)?.toInt() ?? 0,
        failed: (j['failed'] as num?)?.toInt() ?? 0,
        delayed: (j['delayed'] as num?)?.toInt() ?? 0,
      );
}

class AdminRecentError {
  const AdminRecentError({
    required this.actorEmail,
    required this.method,
    required this.path,
    required this.statusCode,
    required this.createdAt,
  });
  final String actorEmail;
  final String method;
  final String path;
  final int statusCode;
  final DateTime? createdAt;

  factory AdminRecentError.fromJson(Map<String, dynamic> j) => AdminRecentError(
        actorEmail: j['actorEmail'] as String? ?? '',
        method: j['method'] as String? ?? '',
        path: j['path'] as String? ?? '',
        statusCode: (j['statusCode'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? ''),
      );
}
