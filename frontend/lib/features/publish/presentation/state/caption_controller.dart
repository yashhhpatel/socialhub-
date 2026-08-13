import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_error_message.dart';
import '../../data/repositories/api_caption_repository.dart';

enum CaptionPhase {
  idle,
  generating,
  ready,

  /// A plain failure — network, 422 empty design, 503 AI not configured.
  failed,

  /// Specifically 429 from QuotaGuard (Milestone 5.2). Separated from
  /// `failed` because it is the one failure a retry cannot fix, so the UI
  /// must stop offering "try again" and say when the org can generate next.
  quotaExceeded,
}

class CaptionState {
  const CaptionState({
    this.phase = CaptionPhase.idle,
    this.caption,
    this.error,
    this.resetAt,
  });

  final CaptionPhase phase;

  /// The most recent generated text. The user's *edits* live in the
  /// modal's TextEditingController, not here — this is only what the model
  /// last returned, so the panel knows when to overwrite the field.
  final String? caption;

  final String? error;

  /// When the org's AI allowance next frees up. Only set on quotaExceeded.
  final DateTime? resetAt;

  bool get inFlight => phase == CaptionPhase.generating;
}

/// Drives AI caption generation for one asset (Milestone 5.3).
///
/// Regeneration is just generate() again — there is no separate path,
/// because "regenerate" and "generate" are the same request. What differs
/// is only what the panel does with the result, and the panel decides that.
class CaptionController extends StateNotifier<CaptionState> {
  CaptionController(this._ref) : super(const CaptionState());

  final Ref _ref;

  Future<void> generate({required String assetId, String? tone}) async {
    // Keep the previous caption visible while regenerating — blanking the
    // field mid-request would lose text the user may still want if the
    // regeneration turns out worse, or fails outright.
    state = CaptionState(phase: CaptionPhase.generating, caption: state.caption);

    try {
      final caption = await _ref
          .read(captionRepositoryProvider)
          .generate(assetId: assetId, tone: tone);
      if (!mounted) return;
      state = CaptionState(phase: CaptionPhase.ready, caption: caption);
    } catch (error) {
      if (!mounted) return;

      final resetAt = _quotaResetAt(error);
      state = CaptionState(
        phase: resetAt != null ? CaptionPhase.quotaExceeded : CaptionPhase.failed,
        caption: state.caption,
        error: describeApiError(error),
        resetAt: resetAt,
      );
    }
  }

  void reset() => state = const CaptionState();
}

/// Pulls `resetAt` out of QuotaGuard's 429 body, or null if this wasn't one.
///
/// Doubles as the quota-vs-other-failure test: only the quota response
/// carries this field, so a parsed date is proof of which failure occurred.
/// Tolerant by design — a 429 whose body has drifted still surfaces as a
/// normal failure with its message intact, rather than throwing in the
/// error handler.
DateTime? _quotaResetAt(Object error) {
  if (error is! DioException) return null;
  if (error.response?.statusCode != 429) return null;

  final data = error.response?.data;
  if (data is! Map<String, dynamic>) return null;

  final raw = data['resetAt'];
  return raw is String ? DateTime.tryParse(raw) : null;
}

final captionControllerProvider =
    StateNotifierProvider.autoDispose<CaptionController, CaptionState>(
  (ref) => CaptionController(ref),
);
