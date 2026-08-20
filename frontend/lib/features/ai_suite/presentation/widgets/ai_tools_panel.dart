import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/network/api_error_message.dart';
import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../data/repositories/api_ai_suite_repository.dart';
import '../../domain/entities/viral_score.dart';

const _tones = ['casual', 'professional', 'playful', 'inspirational', 'bold'];

/// The Phase 12 AI tools attached to the caption in the publish flow
/// (Milestone 12.3): suggest hashtags, rewrite the caption in a tone, and
/// score its viral potential. Operates on the shared caption
/// TextEditingController the modal owns, so results flow into what actually
/// gets published.
class AiToolsPanel extends ConsumerStatefulWidget {
  const AiToolsPanel({
    super.key,
    required this.assetId,
    required this.captionController,
    required this.enabled,
  });

  final String assetId;
  final TextEditingController captionController;
  final bool enabled;

  @override
  ConsumerState<AiToolsPanel> createState() => _AiToolsPanelState();
}

enum _Busy { none, hashtags, tone, score }

class _AiToolsPanelState extends ConsumerState<AiToolsPanel> {
  _Busy _busy = _Busy.none;
  List<String>? _hashtags;
  ViralScore? _score;

  bool get _idle => _busy == _Busy.none && widget.enabled;

  void _report(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(describeApiError(error))),
    );
  }

  Future<void> _suggestHashtags() async {
    setState(() => _busy = _Busy.hashtags);
    try {
      final tags = await ref.read(aiSuiteRepositoryProvider).hashtags(widget.assetId);
      if (mounted) setState(() => _hashtags = tags);
    } catch (e) {
      if (mounted) _report(e);
    } finally {
      if (mounted) setState(() => _busy = _Busy.none);
    }
  }

  Future<void> _rewriteTone(String tone) async {
    final text = widget.captionController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write or generate a caption first, then rewrite its tone.')),
      );
      return;
    }
    setState(() => _busy = _Busy.tone);
    try {
      final rewritten = await ref.read(aiSuiteRepositoryProvider).rewriteTone(text, tone);
      if (mounted) widget.captionController.text = rewritten;
    } catch (e) {
      if (mounted) _report(e);
    } finally {
      if (mounted) setState(() => _busy = _Busy.none);
    }
  }

  Future<void> _scoreIt() async {
    setState(() => _busy = _Busy.score);
    try {
      final score = await ref.read(aiSuiteRepositoryProvider).viralScore(
            widget.assetId,
            caption: widget.captionController.text,
          );
      if (mounted) setState(() => _score = score);
    } catch (e) {
      if (mounted) _report(e);
    } finally {
      if (mounted) setState(() => _busy = _Busy.none);
    }
  }

  void _appendHashtag(String tag) {
    final current = widget.captionController.text;
    final needsSpace = current.isNotEmpty && !current.endsWith(' ') && !current.endsWith('\n');
    widget.captionController.text = '$current${needsSpace ? ' ' : ''}$tag ';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: SpacingTokens.xs,
          runSpacing: SpacingTokens.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _ToolButton(
              icon: Icons.tag,
              label: 'Hashtags',
              busy: _busy == _Busy.hashtags,
              onPressed: _idle ? _suggestHashtags : null,
            ),
            _ToneButton(
              enabled: _idle,
              busy: _busy == _Busy.tone,
              onSelected: _rewriteTone,
            ),
            _ToolButton(
              icon: Icons.local_fire_department_outlined,
              label: 'Viral score',
              busy: _busy == _Busy.score,
              onPressed: _idle ? _scoreIt : null,
            ),
          ],
        ),
        if (_hashtags != null) ...[
          const SizedBox(height: SpacingTokens.xs),
          if (_hashtags!.isEmpty)
            Text('No hashtag suggestions.', style: theme.textTheme.bodySmall)
          else
            Wrap(
              spacing: SpacingTokens.xs,
              runSpacing: SpacingTokens.xs,
              children: [
                for (final tag in _hashtags!)
                  ActionChip(
                    label: Text(tag),
                    onPressed: () => _appendHashtag(tag),
                  ),
              ],
            ),
        ],
        if (_score != null) ...[
          const SizedBox(height: SpacingTokens.sm),
          _ViralScoreGauge(score: _score!),
        ],
      ],
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: busy
          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(icon, size: 16),
      label: Text(label),
    );
  }
}

class _ToneButton extends StatelessWidget {
  const _ToneButton({required this.enabled, required this.busy, required this.onSelected});

  final bool enabled;
  final bool busy;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      enabled: enabled,
      tooltip: 'Rewrite the caption in a tone',
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final tone in _tones)
          PopupMenuItem<String>(
            value: tone,
            child: Text('${tone[0].toUpperCase()}${tone.substring(1)}'),
          ),
      ],
      child: OutlinedButton.icon(
        // The child button is decorative — taps are handled by the menu — so
        // it's disabled to avoid a doubled press target.
        onPressed: null,
        icon: busy
            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.auto_fix_high, size: 16),
        label: const Text('Rewrite tone'),
      ),
    );
  }
}

/// A compact 0–100 gauge + the model's one-line rationale.
class _ViralScoreGauge extends StatelessWidget {
  const _ViralScoreGauge({required this.score});

  final ViralScore score;

  Color _color(ColorScheme scheme) {
    if (score.score >= 70) return AppColors.success;
    if (score.score >= 40) return AppColors.warning;
    return scheme.error;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _color(theme.colorScheme);

    return Container(
      padding: const EdgeInsets.all(SpacingTokens.sm),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              '${score.score}',
              style: theme.textTheme.headlineSmall?.copyWith(color: color),
            ),
          ),
          const SizedBox(width: SpacingTokens.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: score.score / 100,
                    minHeight: 6,
                    color: color,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
                if (score.rationale.isNotEmpty) ...[
                  const SizedBox(height: SpacingTokens.xs),
                  Text(score.rationale, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
