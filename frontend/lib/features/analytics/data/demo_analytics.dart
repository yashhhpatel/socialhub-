import '../domain/entities/analytics_overview.dart';

/// Sample analytics shown to signed-out visitors so the charts, totals and
/// top-posts table look populated. Built fresh so `lastUpdated` reads as "just
/// now". Never shown once a session exists.
AnalyticsOverview demoAnalyticsOverview() {
  const instagram = PlatformBreakdown(
    platform: 'instagram',
    postCount: 18,
    metrics: Metrics(
      impressions: 48200,
      reach: 31400,
      likes: 3120,
      comments: 412,
      shares: 286,
      clicks: 1740,
    ),
  );
  const facebook = PlatformBreakdown(
    platform: 'facebook',
    postCount: 12,
    metrics: Metrics(
      impressions: 26800,
      reach: 19900,
      likes: 1450,
      comments: 190,
      shares: 205,
      clicks: 980,
    ),
  );
  const x = PlatformBreakdown(
    platform: 'x',
    postCount: 21,
    metrics: Metrics(
      impressions: 61200,
      reach: 40100,
      likes: 2870,
      comments: 330,
      shares: 610,
      clicks: 2210,
    ),
  );
  const linkedin = PlatformBreakdown(
    platform: 'linkedin',
    postCount: 7,
    metrics: Metrics(
      impressions: 14300,
      reach: 11200,
      likes: 690,
      comments: 88,
      shares: 74,
      clicks: 540,
    ),
  );

  return AnalyticsOverview(
    totals: const Metrics(
      impressions: 150500,
      reach: 102600,
      likes: 8130,
      comments: 1020,
      shares: 1175,
      clicks: 5470,
    ),
    byPlatform: const [instagram, x, facebook, linkedin],
    postCount: 58,
    topPosts: const [
      TopPost(
        publishJobId: 'demo-job-1',
        variantId: 'demo-var-1',
        platform: 'x',
        metrics: Metrics(
          impressions: 21400,
          reach: 15200,
          likes: 1210,
          comments: 142,
          shares: 320,
          clicks: 940,
        ),
        engagementScore: 92,
      ),
      TopPost(
        publishJobId: 'demo-job-2',
        variantId: 'demo-var-2',
        platform: 'instagram',
        metrics: Metrics(
          impressions: 18800,
          reach: 12600,
          likes: 1580,
          comments: 205,
          shares: 130,
          clicks: 610,
        ),
        engagementScore: 88,
      ),
      TopPost(
        publishJobId: 'demo-job-3',
        variantId: 'demo-var-3',
        platform: 'facebook',
        metrics: Metrics(
          impressions: 9600,
          reach: 7300,
          likes: 540,
          comments: 96,
          shares: 88,
          clicks: 410,
        ),
        engagementScore: 74,
      ),
    ],
    lastUpdated: DateTime.now(),
  );
}
