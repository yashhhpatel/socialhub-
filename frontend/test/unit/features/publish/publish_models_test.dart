import 'package:flutter_test/flutter_test.dart';
import 'package:socialhub/features/publish/domain/entities/publish_models.dart';
import 'package:socialhub/features/publish/presentation/state/publish_controller.dart';

PublishableVariant _variant({
  String id = 'var_1',
  String platform = 'x',
  String status = 'ready',
  String? url = 'https://cdn.test/a.png',
}) =>
    PublishableVariant(id: id, platform: platform, status: status, renderedMediaUrl: url);

PublishTarget _target({
  String id = 'sa_1',
  String platform = 'x',
  String status = 'connected',
}) =>
    PublishTarget(id: id, platform: platform, externalAccountId: 'ext_1', status: status);

void main() {
  group('PublishableVariant.isReady', () {
    test('ready with a rendered image is publishable', () {
      expect(_variant().isReady, isTrue);
    });

    test('a pending variant is not publishable', () {
      expect(_variant(status: 'pending').isReady, isFalse);
    });

    test('ready but with no rendered image is not publishable', () {
      // The backend refuses this (PublishingService: "no rendered image
      // to publish"), so offering it would guarantee a 422.
      expect(_variant(url: null).isReady, isFalse);
    });
  });

  group('PublishOptions.publishablePairs', () {
    test('pairs a ready variant with a connected account on the SAME platform', () {
      const options = PublishOptions(variants: [], targets: []);
      expect(options.publishablePairs, isEmpty);

      final withBoth = PublishOptions(variants: [_variant()], targets: [_target()]);
      expect(withBoth.publishablePairs, hasLength(1));
      expect(withBoth.publishablePairs.single.variant.id, 'var_1');
      expect(withBoth.publishablePairs.single.target.id, 'sa_1');
    });

    test('never pairs across platforms', () {
      // An X rendition is 16:9. Sent to Instagram it would "succeed" and
      // simply look wrong — far harder to notice than a refusal, which
      // is why the backend rejects it and the UI must not offer it.
      final options = PublishOptions(
        variants: [_variant(platform: 'x')],
        targets: [_target(platform: 'instagram')],
      );
      expect(options.publishablePairs, isEmpty);
    });

    test('excludes a disconnected account', () {
      final options = PublishOptions(
        variants: [_variant()],
        targets: [_target(status: 'revoked')],
      );
      expect(options.publishablePairs, isEmpty);
    });

    test('excludes a variant that is not ready', () {
      final options = PublishOptions(
        variants: [_variant(status: 'pending')],
        targets: [_target()],
      );
      expect(options.publishablePairs, isEmpty);
    });

    test('offers every valid combination when several accounts share a platform', () {
      final options = PublishOptions(
        variants: [_variant(platform: 'x'), _variant(id: 'var_2', platform: 'instagram')],
        targets: [
          _target(id: 'sa_x', platform: 'x'),
          _target(id: 'sa_ig', platform: 'instagram'),
          _target(id: 'sa_ig2', platform: 'instagram'),
        ],
      );

      final pairs = options.publishablePairs;
      expect(pairs, hasLength(3));
      // Every pair must be platform-consistent.
      for (final p in pairs) {
        expect(p.variant.platform, p.target.platform);
      }
    });
  });

  group('PublishJob.fromJson', () {
    test('parses a successful job including the platform post id', () {
      final job = PublishJob.fromJson({
        'id': 'job_1',
        'status': 'published',
        'attemptCount': 1,
        'lastError': null,
        'externalPostId': 'tweet_9',
      });

      expect(job.status, PublishJobStatus.published);
      expect(job.externalPostId, 'tweet_9');
      expect(job.lastError, isNull);
    });

    test("parses a failed job and keeps the platform's error text", () {
      final job = PublishJob.fromJson({
        'id': 'job_2',
        'status': 'failed',
        'attemptCount': 1,
        'lastError': 'X publish failed: 403 caption too long',
        'externalPostId': null,
      });

      expect(job.status, PublishJobStatus.failed);
      expect(job.lastError, contains('caption too long'));
    });

    test('parses every status the backend enum can emit', () {
      for (final status in [
        'queued',
        'scheduled',
        'processing',
        'published',
        'failed',
        'cancelled',
      ]) {
        final job = PublishJob.fromJson({
          'id': 'j',
          'status': status,
          'attemptCount': 0,
        });
        expect(job.status.name, status);
      }
    });
  });
}
