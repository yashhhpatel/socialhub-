/// A recommended posting slot (GET /ai/best-time). Day/hour are UTC from the
/// backend; the label localizes for display.
class BestTimeSlot {
  const BestTimeSlot({
    required this.dayOfWeek,
    required this.hour,
    required this.averageEngagement,
    required this.sampleCount,
  });

  /// 0 = Sunday … 6 = Saturday (UTC).
  final int dayOfWeek;

  /// 0–23 (UTC).
  final int hour;
  final double averageEngagement;
  final int sampleCount;

  static const _days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  /// A human label in the viewer's local time. The backend gives UTC
  /// weekday+hour; we anchor to the most recent matching UTC instant and
  /// convert, so "Mon 14:00 UTC" reads as whatever the user's clock shows.
  String get localLabel {
    final now = DateTime.now().toUtc();
    // Walk back to the most recent UTC day matching dayOfWeek at `hour`.
    var candidate = DateTime.utc(now.year, now.month, now.day, hour);
    while (candidate.weekday % 7 != dayOfWeek) {
      candidate = candidate.subtract(const Duration(days: 1));
    }
    final local = candidate.toLocal();
    final minute = local.minute.toString().padLeft(2, '0');
    return '${_days[local.weekday % 7]} ${local.hour}:$minute';
  }

  factory BestTimeSlot.fromJson(Map<String, dynamic> json) => BestTimeSlot(
        dayOfWeek: (json['dayOfWeek'] as num).toInt(),
        hour: (json['hour'] as num).toInt(),
        averageEngagement: (json['averageEngagement'] as num?)?.toDouble() ?? 0,
        sampleCount: (json['sampleCount'] as num?)?.toInt() ?? 0,
      );
}
