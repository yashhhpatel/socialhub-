import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MaxLengthEnforcement;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../domain/repositories/caption_repository.dart';
import '../state/caption_controller.dart';

/// Caption editor with AI generation, inside the publish modal (5.3).
///
/// The text field is the source of truth for what gets published — the
/// controller only supplies generated text. That split is what makes
/// "generate, then edit, then publish what you edited" work: a generation
/// overwrites the field, and everything after that is the user's.
///
/// Stateless on purpose. The TextEditingController is owned by the modal,
/// which needs to read the final text at publish time; giving this widget
/// its own would mean two copies to keep in sync.
class CaptionPanel extends ConsumerWidget {
  const CaptionPanel({
    super.key,
    required this.assetId,
    required this.textController,
    required this.maxLength,
    required this.enabled,
  });

  final String assetId;
  final TextEditingController textController;

  /// The selected platform's ceiling, for the counter. Advisory — the
  /// backend and the platform both enforce independently.
  final int maxLength;

  /// False while a publish is in flight, so the caption cannot change out
  /// from under a request already carrying it.
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caption = ref.watch(captionControllerProvider);
    final theme = Theme.of(context);
    final busy = caption.inFlight || !enabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Caption', style: theme.textTheme.titleSmall),
            ),
            _ToneMenu(
              enabled: !busy,
              onSelected: (tone) => ref
                  .read(captionControllerProvider.notifier)
                  .generate(assetId: assetId, tone: tone),
            ),
            const SizedBox(width: SpacingTokens.xs),
            TextButton.icon(
              onPressed: busy
                  ? null
                  : () => ref
                      .read(captionControllerProvider.notifier)
                      .generate(assetId: assetId),
              icon: caption.inFlight
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome, size: 16),
              // "Regenerate" once there's something to replace — the same
              // request either way, but the label should say what the user
              // is about to lose.
              label: Text(
                caption.inFlight
                    ? 'Generating…'
                    : (caption.caption == null ? 'Generate' : 'Regenerate'),
              ),
            ),
          ],
        ),
        const SizedBox(height: SpacingTokens.xs),
        TextField(
          controller: textController,
          enabled: !busy,
          maxLines: 4,
          minLines: 2,
          // Counter only, no hard cap: truncating someone's text mid-word
          // as they paste is worse than letting them see they're over and
          // decide what to cut.
          maxLength: maxLength,
          maxLengthEnforcement: MaxLengthEnforcement.none,
          decoration: const InputDecoration(
            hintText: 'Write a caption, or generate one.',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        if (caption.phase == CaptionPhase.quotaExceeded)
          _CaptionNotice(
            icon: Icons.hourglass_empty,
            color: theme.colorScheme.error,
            // Quota is the one failure retrying cannot fix, so this says
            // when rather than offering a button that would fail again.
            message: caption.resetAt == null
                ? caption.error ?? 'AI quota exhausted.'
                : '${caption.error ?? 'AI quota exhausted.'} '
                    'Resets ${_formatResetAt(caption.resetAt!)}.',
          )
        else if (caption.phase == CaptionPhase.failed)
          _CaptionNotice(
            icon: Icons.error_outline,
            color: theme.colorScheme.error,
            message: caption.error ?? 'Could not generate a caption.',
          ),
      ],
    );
  }
}

/// Generate with an explicit tone. Separate from the main button because
/// tone is the exception, not the default — the backend prompt takes its
/// cue from the design itself when none is given, which is usually right.
class _ToneMenu extends StatelessWidget {
  const _ToneMenu({required this.enabled, required this.onSelected});

  final bool enabled;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      enabled: enabled,
      tooltip: 'Generate with a tone',
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final tone in captionTones)
          PopupMenuItem<String>(
            value: tone,
            child: Text('${tone[0].toUpperCase()}${tone.substring(1)}'),
          ),
      ],
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: SpacingTokens.xs, vertical: 4),
        child: Icon(Icons.tune, size: 18),
      ),
    );
  }
}

class _CaptionNotice extends StatelessWidget {
  const _CaptionNotice({
    required this.icon,
    required this.color,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: SpacingTokens.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: SpacingTokens.xs),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

const _monthNames = <String>[
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Formats a reset instant for display. Hand-rolled rather than pulling in
/// `intl` for one string — shown in local time, since "when can I use this
/// again" is a question about the user's clock, not the server's.
String _formatResetAt(DateTime resetAt) {
  final local = resetAt.toLocal();
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.day} ${_monthNames[local.month - 1]} '
      'at ${local.hour}:$minute';
}
