import 'package:flutter_test/flutter_test.dart';
import 'package:socialhub/features/social_accounts/domain/entities/social_account.dart';
import 'package:socialhub/features/social_accounts/domain/entities/social_platform.dart';

void main() {
  group('SocialAccount.fromJson', () {
    test('parses a fully-populated account (mirrors the backend DTO shape)', () {
      final account = SocialAccount.fromJson({
        'id': 'sa_1',
        'platform': 'instagram',
        'externalAccountId': 'ig_ext_123',
        'status': 'connected',
        'expiresAt': '2026-08-01T00:00:00.000Z',
        'createdAt': '2026-07-01T00:00:00.000Z',
      });

      expect(account.id, 'sa_1');
      expect(account.platform, SocialPlatform.instagram);
      expect(account.externalAccountId, 'ig_ext_123');
      expect(account.status, 'connected');
      expect(account.expiresAt, DateTime.parse('2026-08-01T00:00:00.000Z'));
      expect(account.createdAt, DateTime.parse('2026-07-01T00:00:00.000Z'));
    });

    test('handles a null expiresAt (some platforms may not always report one)', () {
      final account = SocialAccount.fromJson({
        'id': 'sa_2',
        'platform': 'x',
        'externalAccountId': 'x_ext_456',
        'status': 'connected',
        'expiresAt': null,
        'createdAt': '2026-07-01T00:00:00.000Z',
      });

      expect(account.expiresAt, isNull);
    });
  });
}
