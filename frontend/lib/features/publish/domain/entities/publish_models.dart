/// Caption ceiling per platform, mirroring each adapter's `capabilities()`
/// on the backend (instagram.adapter.ts: 2200, x.adapter.ts: 280).
///
/// Duplicated here rather than fetched because the publish modal needs it
/// to render a live character counter as the user types — a round trip per
/// keystroke is not an option, and the limits change about as often as the
/// platforms themselves do. The backend remains the enforcing authority;
/// this only decides when to warn.
const _maxCaptionLengthByPlatform = <String, int>{
  'instagram': 2200,
  'x': 280,
};

/// Used when a variant's platform has no known limit — a platform added to
/// the backend enum before this map catches up. Generous on purpose: the
/// counter is advisory, and warning about a limit that may not exist is
/// worse than not warning at all.
const _fallbackMaxCaptionLength = 2200;

/// A rendition that can be published — one platform's version of a design.
class PublishableVariant {
  const PublishableVariant({
    required this.id,
    required this.platform,
    required this.status,
    this.renderedMediaUrl,
    this.caption,
  });

  final String id;
  final String platform;
  final String status;
  final String? renderedMediaUrl;
  final String? caption;

  /// The backend refuses anything not `ready` (see PublishingService's
  /// preconditions), so the modal disables these rather than letting the
  /// user click into a guaranteed 422.
  bool get isReady => status == 'ready' && renderedMediaUrl != null;

  /// Longest caption this variant's platform will accept.
  int get maxCaptionLength =>
      _maxCaptionLengthByPlatform[platform] ?? _fallbackMaxCaptionLength;

  factory PublishableVariant.fromJson(Map<String, dynamic> json) => PublishableVariant(
        id: json['id'] as String,
        platform: json['platform'] as String,
        status: json['status'] as String,
        renderedMediaUrl: json['renderedMediaUrl'] as String?,
        caption: json['caption'] as String?,
      );
}

/// A connected account a variant can be published TO.
///
/// Deliberately a publish-owned projection rather than an import of
/// features/social_accounts' SocialAccount: per docs/architecture —
/// Flutter Web Application Architecture §1, a feature never reaches into
/// another feature's internals. This carries only what choosing a publish
/// destination needs, which is a different question from "what is the
/// state of my connections".
class PublishTarget {
  const PublishTarget({
    required this.id,
    required this.platform,
    required this.externalAccountId,
    required this.status,
  });

  final String id;
  final String platform;
  final String externalAccountId;
  final String status;

  bool get isConnected => status == 'connected';

  factory PublishTarget.fromJson(Map<String, dynamic> json) => PublishTarget(
        id: json['id'] as String,
        platform: json['platform'] as String,
        externalAccountId: json['externalAccountId'] as String,
        status: json['status'] as String,
      );
}

enum PublishJobStatus { queued, scheduled, processing, published, failed, cancelled }

class PublishJob {
  const PublishJob({
    required this.id,
    required this.status,
    required this.attemptCount,
    this.lastError,
    this.externalPostId,
  });

  final String id;
  final PublishJobStatus status;
  final int attemptCount;
  final String? lastError;
  final String? externalPostId;

  factory PublishJob.fromJson(Map<String, dynamic> json) => PublishJob(
        id: json['id'] as String,
        status: PublishJobStatus.values.byName(json['status'] as String),
        attemptCount: json['attemptCount'] as int? ?? 0,
        lastError: json['lastError'] as String?,
        externalPostId: json['externalPostId'] as String?,
      );
}
