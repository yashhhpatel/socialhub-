/// Coerces a decoded JSON object into `Map<String, dynamic>`, tolerant of a
/// map whose static type isn't already that (an empty `{}` literal, a loosely
/// decoded nested object). Real API payloads from Dio are already
/// `Map<String, dynamic>`; this just keeps parsing robust either way.
Map<String, dynamic> _obj(Object? v) =>
    v is Map ? v.map((k, val) => MapEntry(k.toString(), val)) : const {};

int _int(Object? v) => v is num ? v.toInt() : 0;

/// Canonical, cross-platform metric bundle — mirrors the backend's
/// CanonicalMetrics (Phase 10). Every count defaults to 0 so charts never
/// have to special-case a gap.
class Metrics {
  const Metrics({
    this.impressions = 0,
    this.reach = 0,
    this.likes = 0,
    this.comments = 0,
    this.shares = 0,
    this.clicks = 0,
  });

  final int impressions;
  final int reach;
  final int likes;
  final int comments;
  final int shares;
  final int clicks;

  /// Actions taken on the post — likes + comments + shares + clicks. Excludes
  /// impressions/reach, which are passive.
  int get engagement => likes + comments + shares + clicks;

  factory Metrics.fromJson(Object? json) {
    final j = _obj(json);
    return Metrics(
      impressions: _int(j['impressions']),
      reach: _int(j['reach']),
      likes: _int(j['likes']),
      comments: _int(j['comments']),
      shares: _int(j['shares']),
      clicks: _int(j['clicks']),
    );
  }
}

/// Per-platform slice used by the comparison view.
class PlatformBreakdown {
  const PlatformBreakdown({
    required this.platform,
    required this.postCount,
    required this.metrics,
  });

  final String platform;
  final int postCount;
  final Metrics metrics;

  factory PlatformBreakdown.fromJson(Map<String, dynamic> json) => PlatformBreakdown(
        platform: json['platform'] as String,
        postCount: _int(json['postCount']),
        metrics: Metrics.fromJson(json['metrics']),
      );
}

class TopPost {
  const TopPost({
    required this.publishJobId,
    required this.variantId,
    required this.platform,
    required this.metrics,
    required this.engagementScore,
    this.externalPostId,
  });

  final String publishJobId;
  final String variantId;
  final String platform;
  final String? externalPostId;
  final Metrics metrics;
  final int engagementScore;

  factory TopPost.fromJson(Map<String, dynamic> json) => TopPost(
        publishJobId: json['publishJobId'] as String,
        variantId: json['variantId'] as String,
        platform: json['platform'] as String,
        externalPostId: json['externalPostId'] as String?,
        metrics: Metrics.fromJson(json['metrics']),
        engagementScore: _int(json['engagementScore']),
      );
}

/// The whole dashboard payload (GET /analytics/overview).
class AnalyticsOverview {
  const AnalyticsOverview({
    required this.totals,
    required this.byPlatform,
    required this.postCount,
    required this.topPosts,
    this.lastUpdated,
  });

  final Metrics totals;
  final List<PlatformBreakdown> byPlatform;
  final int postCount;
  final List<TopPost> topPosts;
  final DateTime? lastUpdated;

  bool get isEmpty => postCount == 0;

  factory AnalyticsOverview.fromJson(Map<String, dynamic> json) => AnalyticsOverview(
        totals: Metrics.fromJson(json['totals']),
        byPlatform: [
          for (final p in (json['byPlatform'] as List<dynamic>? ?? []))
            PlatformBreakdown.fromJson(_obj(p)),
        ],
        postCount: _int(json['postCount']),
        topPosts: [
          for (final t in (json['topPosts'] as List<dynamic>? ?? []))
            TopPost.fromJson(_obj(t)),
        ],
        lastUpdated: json['lastUpdated'] == null
            ? null
            : DateTime.tryParse(json['lastUpdated'] as String),
      );
}
