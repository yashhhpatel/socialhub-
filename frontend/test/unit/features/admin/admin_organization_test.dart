import 'package:flutter_test/flutter_test.dart';
import 'package:socialhub/features/admin/domain/admin_organization.dart';

void main() {
  test('AdminOrgList parses rows + pagination and computes totalPages', () {
    final list = AdminOrgList.fromJson({
      'total': 45,
      'page': 2,
      'limit': 20,
      'data': [
        {
          'id': 'o1',
          'name': 'Acme',
          'planTier': 'pro',
          'subscriptionStatus': 'active',
          'memberCount': 3,
          'socialAccountCount': 2,
          'createdAt': '2026-08-01T00:00:00.000Z',
        },
      ],
    });
    expect(list.total, 45);
    expect(list.totalPages, 3); // ceil(45/20)
    expect(list.data.single.name, 'Acme');
    expect(list.data.single.subscriptionStatus, 'active');
  });

  test('AdminOrgDetail parses members, usage, limits, activity', () {
    final d = AdminOrgDetail.fromJson({
      'id': 'o1',
      'name': 'Acme',
      'planTier': 'enterprise',
      'requiresApproval': true,
      'subscriptionStatus': null,
      'createdAt': '2026-08-01T00:00:00.000Z',
      'members': [
        {
          'id': 'u1',
          'email': 'a@b.com',
          'role': 'owner',
          'emailVerified': true,
          'mfaEnabled': false,
          'isPlatformAdmin': true,
        },
      ],
      'usage': {'socialAccounts': 1, 'teamMembers': 2, 'aiCreditsUsed': 3},
      'limits': {
        'maxSocialAccounts': -1,
        'maxTeamMembers': -1,
        'aiCreditsPerMonth': -1,
        'maxScheduledPosts': -1,
      },
      'activity': {
        'connectedAccounts': 2,
        'drafts': 0,
        'scheduledPosts': 1,
        'publishedPosts': 5,
      },
    });
    expect(d.requiresApproval, isTrue);
    expect(d.members.single.isPlatformAdmin, isTrue);
    expect(d.limits['maxSocialAccounts'], -1);
    expect(d.activity['publishedPosts'], 5);
  });
}
