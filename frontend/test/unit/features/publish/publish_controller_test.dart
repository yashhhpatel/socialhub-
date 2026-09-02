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

/// Returns queued jobs in order, one per publishNow call — lets a multi-account
/// publish be given a different outcome for each account.
class _SeqRepo implements PublishRepository {
  _SeqRepo(this._jobs);
  final List<PublishJob> _jobs;
  int _i = 0;
  int publishCalls = 0;

  @override
  Future<PublishJob> publishNow({
    required String variantId,
    required String socialAccountId,
    String? caption,
  }) async {
    publishCalls++;
    return _jobs[_i++];
  }

  @override
  Future<PublishJob> job(String jobId) async => _jobs.last;
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

  test('publishMany: every account published → succeeded, count = N', () async {
    final container = ProviderContainer(
      overrides: [
        publishRepositoryProvider.overrideWithValue(
          _SeqRepo([
            _job(PublishJobStatus.published),
            _job(PublishJobStatus.published),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(publishControllerProvider.notifier).publishMany([
      (variantId: 'v1', socialAccountId: 'a1', caption: null, label: 'instagram'),
      (variantId: 'v2', socialAccountId: 'a2', caption: null, label: 'threads'),
    ]);

    final state = container.read(publishControllerProvider);
    expect(state.phase, PublishPhase.succeeded);
    expect(state.successCount, 2);
  });

  test('publishMany: one account failing → failed, names that account',
      () async {
    final container = ProviderContainer(
      overrides: [
        publishRepositoryProvider.overrideWithValue(
          _SeqRepo([
            _job(PublishJobStatus.published),
            _job(PublishJobStatus.failed, lastError: 'caption too long'),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(publishControllerProvider.notifier).publishMany([
      (variantId: 'v1', socialAccountId: 'a1', caption: null, label: 'instagram'),
      (variantId: 'v2', socialAccountId: 'a2', caption: null, label: 'threads'),
    ]);

    final state = container.read(publishControllerProvider);
    expect(state.phase, PublishPhase.failed);
    expect(state.error, contains('threads'));
    expect(state.error, contains('caption too long'));
    // The instagram account (which succeeded) is not listed as a failure.
    expect(state.error, isNot(contains('instagram')));
  });
}
