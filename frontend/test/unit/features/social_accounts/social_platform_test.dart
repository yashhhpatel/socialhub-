import 'package:flutter_test/flutter_test.dart';
import 'package:socialhub/features/social_accounts/domain/entities/social_platform.dart';

void main() {
  group('SocialPlatform', () {
    test('apiValue matches the backend Platform enum exactly for every value', () {
      expect(SocialPlatform.instagram.apiValue, 'instagram');
      expect(SocialPlatform.facebook.apiValue, 'facebook');
      expect(SocialPlatform.threads.apiValue, 'threads');
      expect(SocialPlatform.x.apiValue, 'x');
      expect(SocialPlatform.linkedin.apiValue, 'linkedin');
    });

    test('all five platforms are connectable (Phase 8 complete)', () {
      for (final platform in SocialPlatform.values) {
        expect(platform.isConnectable, isTrue, reason: '${platform.label} should be connectable');
      }
    });

    test('fromApiValue round-trips correctly for every platform', () {
      for (final platform in SocialPlatform.values) {
        expect(SocialPlatformX.fromApiValue(platform.apiValue), platform);
      }
    });

    test('fromApiValue throws on an unrecognized value', () {
      expect(() => SocialPlatformX.fromApiValue('myspace'), throwsArgumentError);
    });
  });
}
