import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialhub/features/publish/data/repositories/api_publish_repository.dart';
import 'package:socialhub/features/publish/domain/entities/publish_models.dart';
import 'package:socialhub/features/publish/domain/repositories/publish_repository.dart';
import 'package:socialhub/features/publish/presentation/state/publish_controller.dart';

/// Fake repository that returns a pre-set terminal (or non-terminal) job from
/// publishNow, standing in for the real poll-until-settled behaviour so the
/// controller's outcome mapping can be asserted in isolation.
class _FakeRepo implements PublishRepository {
  _FakeRepo(this._job);
  final PublishJob _job;

  @override
  Future<PublishJob> publishNow({
    required String variantId,
    required String socialAccountId,
    String? caption,
  }) async =>
      _job;

  @override
  Future<PublishJob> job(String jobId) async => _job;

  @override
  Future<List<PublishableVariant>> variantsForAsset(String assetId) async => [];

  @override
  Future<List<PublishTarget>> targets() async => [];

  @override
  Future<void> publishCarousel({
    required String socialAccountId,
    required List<String> mediaUrls,
    String? caption,
    DateTime? scheduledAt,
  }) async {}
}

PublishJob _job(PublishJobStatus status, {String? lastError}) => PublishJob(
      id: 'job1',
      status: status,
      attemptCount: 1,
      lastError: lastError,
    );

Future<PublishState> _run(PublishJob job) async {
  final container = ProviderContainer(
    overrides: [
      publishRepositoryProvider.overrideWithValue(_FakeRepo(job)),
    ],
  );
  addTearDown(container.dispose);
  final controller = container.read(publishControllerProvider.notifier);
  await controller.publish(variantId: 'v1', socialAccountId: 'a1');
  return container.read(publishControllerProvider);
}

void main() {
  test('published job → succeeded', () async {
    final state = await _run(_job(PublishJobStatus.published));
    expect(state.phase, PublishPhase.succeeded);
  });

  test('failed job surfaces the platform\'s own error message', () async {
    final state = await _run(
      _job(PublishJobStatus.failed, lastError: 'X media upload failed: 403'),
    );
    expect(state.phase, PublishPhase.failed);
    expect(state.error, 'X media upload failed: 403');
  });

  test('a job still processing after the poll is reported as in-progress, '
      'not a hard failure', () async {
    final state = await _run(_job(PublishJobStatus.processing));
    expect(state.phase, PublishPhase.failed);
    expect(state.error, contains('Still publishing'));
    // Must NOT show the misleading generic message that was shown before.
    expect(state.error, isNot('Publish did not complete.'));
  });
}
