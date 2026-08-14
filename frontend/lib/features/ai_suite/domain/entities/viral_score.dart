/// AI viral-potential estimate (POST /ai/viral-score).
class ViralScore {
  const ViralScore({required this.score, required this.rationale});

  /// 0–100.
  final int score;
  final String rationale;

  factory ViralScore.fromJson(Map<String, dynamic> json) => ViralScore(
        score: (json['score'] as num?)?.toInt() ?? 0,
        rationale: json['rationale'] as String? ?? '',
      );
}
