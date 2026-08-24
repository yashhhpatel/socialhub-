import 'package:flutter_test/flutter_test.dart';
import 'package:socialhub/features/admin/domain/admin_social_account.dart';

void main() {
  test('parses list and flags needsReconnect for non-connected', () {
    final list = AdminSocialAccountList.fromJson({
      'total': 2,
      'page': 1,
      'limit': 50,
      'data': [
        {
          'id': 's1',
          'orgId': 'o1',
          'orgName': 'Acme',
          'platform': 'x',
          'externalAccountId': 'ext1',
          'status': 'expired',
          'expiresAt': '2026-08-01T00:00:00.000Z',
        },
        {
          'id': 's2',
          'orgId': 'o1',
          'orgName': 'Acme',
          'platform': 'threads',
          'externalAccountId': 'ext2',
          'status': 'connected',
          'expiresAt': null,
        },
      ],
    });
    expect(list.data[0].needsReconnect, isTrue);
    expect(list.data[1].needsReconnect, isFalse);
    expect(list.totalPages, 1);
  });
}
