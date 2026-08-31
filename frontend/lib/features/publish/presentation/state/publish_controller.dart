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
  const PublishState({this.phase = PublishPhase.idle, this.job, this.error});

  final PublishPhase phase;
  final PublishJob? job;
  final String? error;

  bool get inFlight => phase == PublishPhase.publishing;
}

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

  void reset() => state = const PublishState();
}

final publishControllerProvider =
    StateNotifierProvider.autoDispose<PublishController, PublishState>(
  (ref) => PublishController(ref),
);
