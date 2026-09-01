import '../domain/entities/dashboard_summary.dart';

/// Sample dashboard shown to signed-out visitors so the Overview looks like a
/// real, active workspace. Never shown once a session exists.
const demoDashboardSummary = DashboardSummary(
  scheduledPosts: 8,
  publishedPosts: 42,
  drafts: 5,
  connectedAccounts: 4,
  aiCreditsUsed: 120,
  aiCreditsTotal: 500,
  recentActivity: [
    ActivityItem(
      description: 'Published “Summer Sale” to Instagram and Facebook',
      timeAgo: '2h ago',
      icon: 'published',
    ),
    ActivityItem(
      description: 'Scheduled “Product Launch” for X',
      timeAgo: '5h ago',
      icon: 'scheduled',
    ),
    ActivityItem(
      description: 'AI generated 10 hashtags for “Behind the Scenes”',
      timeAgo: 'Yesterday',
      icon: 'ai',
    ),
    ActivityItem(
      description: 'Connected a new LinkedIn account',
      timeAgo: '2d ago',
      icon: 'account',
    ),
    ActivityItem(
      description: 'Saved draft “Weekend Giveaway”',
      timeAgo: '3d ago',
      icon: 'draft',
    ),
  ],
);
