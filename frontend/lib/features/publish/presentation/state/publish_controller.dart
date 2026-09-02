import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_error_message.dart';
import '../../data/repositories/api_publish_repository.dart';
import '../../domain/entities/publish_models.dart';

/// What the publish modal needs before it can offer anything: the
/// asset's renditions, and the accounts they could go to.
class PublishOptions {
  const PublishOptions({required this.variants, required this.targets});

  final List<PublishableVariant> variants;
  final List<PublishTarget> targets;

  /// A variant is only publishable if it is ready AND there is a
  /// connected account on its platform. Surfacing that pairing here
  /// keeps the modal from offering a combination the backend will refuse.
  List<({PublishableVariant variant, PublishTarget target})> get publishablePairs => [
        for (final variant in variants)
          if (variant.isReady)
            for (final target in targets)
              if (target.isConnected && target.platform == variant.platform)
                (variant: variant, target: target),
      ];
}

final publishOptionsProvider =
    FutureProvider.autoDispose.family<PublishOptions, String>((ref, assetId) async {
  final repository = ref.watch(publishRepositoryProvider);
  // Both requests are independent; a modal needs both before it can
  // render anything useful.
  final results = await Future.wait([
    repository.variantsForAsset(assetId),
    repository.targets(),
  ]);
  return PublishOptions(
    variants: results[0] as List<PublishableVariant>,
    targets: results[1] as List<PublishTarget>,
  );
});

enum PublishPhase { idle, publishing, succeeded, failed }

class PublishState {
  const PublishState({
    this.phase = PublishPhase.idle,
    this.job,
    this.error,
    this.successCount = 1,
  });

  final PublishPhase phase;
  final PublishJob? job;
  final String? error;

  /// How many accounts a successful publish reached — 1 for the single
  /// publish path, or the number of selected accounts for [publishMany].
  final int successCount;

  bool get inFlight => phase == PublishPhase.publishing;
}

/// One account to publish the same design to, in a multi-select publish.
typedef PublishItem = ({
  String variantId,
  String socialAccountId,
  String? caption,
  String label,
});

/// Drives one publish attempt.
///
/// Deliberately has no retry: the backend has none either, for the same
/// reason — a retry after an ambiguous failure can double-post to a real
/// public account. A failed publish surfaces the platform's own message
/// and waits for the user to decide, which also matches the "mutating
/// requests do not auto-retry" rule in docs/architecture §10.
class PublishController extends StateNotifier<PublishState> {
  PublishController(this._ref) : super(const PublishState());

  final Ref _ref;

  Future<void> publish({
    required String variantId,
    required String socialAccountId,
    String? caption,
  }) async {
    state = const PublishState(phase: PublishPhase.publishing);
    try {
      final job = await _ref.read(publishRepositoryProvider).publishNow(
            variantId: variantId,
            socialAccountId: socialAccountId,
            caption: caption,
          );
      if (!mounted) return;
      switch (job.status) {
        case PublishJobStatus.published:
          state = PublishState(phase: PublishPhase.succeeded, job: job);
        case PublishJobStatus.failed:
        case PublishJobStatus.cancelled:
          // Surface the platform's own message (e.g. an X media/permission
          // error) rather than a generic one, so the cause is clear.
          state = PublishState(
            phase: PublishPhase.failed,
            job: job,
            error: job.lastError ?? 'Publish did not complete.',
          );
        case PublishJobStatus.queued:
        case PublishJobStatus.scheduled:
        case PublishJobStatus.processing:
          // Still running after the poll budget — not a failure. It will
          // finish in the background; point the user to where the result lands.
          state = PublishState(
            phase: PublishPhase.failed,
            job: job,
            error: 'Still publishing — this is taking longer than usual. '
                'It will finish in the background; check your Calendar for the '
                'result.',
          );
      }
    } catch (error) {
      if (!mounted) return;
      state = PublishState(phase: PublishPhase.failed, error: describeApiError(error));
    }
  }

  /// Publishes the same design to several accounts at once (Milestone: the
  /// publish modal's multi-select). Each account is its own publishNow call so
  /// one platform failing doesn't cancel the others; the outcome is "succeeded"
  /// only if every account did, otherwise "failed" with a per-account
  /// breakdown. Deliberately no retry, for the same double-post reason as
  /// [publish].
  Future<void> publishMany(List<PublishItem> items) async {
    if (items.isEmpty) return;
    state = const PublishState(phase: PublishPhase.publishing);
    final repository = _ref.read(publishRepositoryProvider);
    final failures = <String>[];
    PublishJob? lastJob;

    for (final item in items) {
      try {
        final job = await repository.publishNow(
          variantId: item.variantId,
          socialAccountId: item.socialAccountId,
          caption: item.caption,
        );
        lastJob = job;
        switch (job.status) {
          case PublishJobStatus.published:
            break; // this account succeeded
          case PublishJobStatus.failed:
          case PublishJobStatus.cancelled:
            failures.add(
              '${item.label}: ${job.lastError ?? 'did not complete'}',
            );
          case PublishJobStatus.queued:
          case PublishJobStatus.scheduled:
          case PublishJobStatus.processing:
            failures.add(
              '${item.label}: still publishing — check your Calendar',
            );
        }
      } catch (error) {
        failures.add('${item.label}: ${describeApiError(error)}');
      }
    }

    if (!mounted) return;
    if (failures.isEmpty) {
      state = PublishState(
        phase: PublishPhase.succeeded,
        job: lastJob,
        successCount: items.length,
      );
    } else {
      state = PublishState(
        phase: PublishPhase.failed,
        error: 'Some publishes failed:\n${failures.join('\n')}',
      );
    }
  }

  void reset() => state = const PublishState();
}

final publishControllerProvider =
    StateNotifierProvider.autoDispose<PublishController, PublishState>(
  (ref) => PublishController(ref),
);
