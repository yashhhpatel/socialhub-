import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/network/api_error_message.dart';
import '../../../../core/layout/widgets/page_header.dart';
import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../../content/domain/entities/content_asset_summary.dart';
import '../../../content/presentation/state/content_library_controller.dart';
import '../../data/repositories/api_ai_suite_repository.dart';
import '../../domain/entities/viral_score.dart';

/// The AI Assistant hub. The generative tools (caption/hashtags/tone/viral)
/// also live inline in the publish flow; this page is the standalone place to
/// analyse a design without starting a publish — pick a design, get hashtag
/// ideas and a viral-score estimate — and to see the best times to post,
/// all through the existing AI endpoints.
class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  String? _assetId;
  List<String>? _hashtags;
  ViralScore? _score;
  bool _busyHashtags = false;
  bool _busyScore = false;

  void _report(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(describeApiError(error))),
    );
  }

  Future<void> _hashtags4() async {
    final id = _assetId;
    if (id == null) return;
    setState(() => _busyHashtags = true);
    try {
      final tags = await ref.read(aiSuiteRepositoryProvider).hashtags(id);
      if (mounted) setState(() => _hashtags = tags);
    } catch (e) {
      if (mounted) _report(e);
    } finally {
      if (mounted) setState(() => _busyHashtags = false);
    }
  }

  Future<void> _scoreIt() async {
    final id = _assetId;
    if (id == null) return;
    setState(() => _busyScore = true);
    try {
      final score = await ref.read(aiSuiteRepositoryProvider).viralScore(id);
      if (mounted) setState(() => _score = score);
    } catch (e) {
      if (mounted) _report(e);
    } finally {
      if (mounted) setState(() => _busyScore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(contentLibraryProvider);

    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'AI Assistant',
            subtitle:
                'Analyse a design for hashtags and viral potential, and see when to post. '
                'Captions and tone rewriting live in the publish dialog.',
          ),
          const SizedBox(height: SpacingTokens.lg),
          const _Section(
            title: 'Best times to post',
            child: _BestTimes(),
          ),
          const SizedBox(height: SpacingTokens.lg),
          _Section(
            title: 'Analyse a design',
            child: library.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(SpacingTokens.md),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Could not load your designs: ${describeApiError(e)}'),
              data: (assets) => assets.isEmpty
                  ? const Text('Create a design first — then analyse it here.')
                  : _Analyser(
                      assets: assets,
                      selectedId: _assetId,
                      onSelect: (id) => setState(() {
                        _assetId = id;
                        _hashtags = null;
                        _score = null;
                      }),
                      onHashtags: _busyHashtags ? null : _hashtags4,
                      onScore: _busyScore ? null : _scoreIt,
                      busyHashtags: _busyHashtags,
                      busyScore: _busyScore,
                      hashtags: _hashtags,
                      score: _score,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Analyser extends StatelessWidget {
  const _Analyser({
    required this.assets,
    required this.selectedId,
    required this.onSelect,
    required this.onHashtags,
    required this.onScore,
    required this.busyHashtags,
    required this.busyScore,
    required this.hashtags,
    required this.score,
  });

  final List<ContentAssetSummary> assets;
  final String? selectedId;
  final ValueChanged<String?> onSelect;
  final VoidCallback? onHashtags;
  final VoidCallback? onScore;
  final bool busyHashtags;
  final bool busyScore;
  final List<String>? hashtags;
  final ViralScore? score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: selectedId,
          decoration: const InputDecoration(
            labelText: 'Design',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: [
            for (final a in assets)
              DropdownMenuItem(
                value: a.id,
                child: Text('Design ${a.id.substring(0, 8)}'),
              ),
          ],
          onChanged: onSelect,
        ),
        const SizedBox(height: SpacingTokens.md),
        Wrap(
          spacing: SpacingTokens.sm,
          runSpacing: SpacingTokens.sm,
          children: [
            OutlinedButton.icon(
              onPressed: selectedId == null ? null : onHashtags,
              icon: busyHashtags
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.tag, size: 16),
              label: const Text('Suggest hashtags'),
            ),
            OutlinedButton.icon(
              onPressed: selectedId == null ? null : onScore,
              icon: busyScore
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.local_fire_department_outlined, size: 16),
              label: const Text('Viral score'),
            ),
          ],
        ),
        if (hashtags != null) ...[
          const SizedBox(height: SpacingTokens.md),
          if (hashtags!.isEmpty)
            Text('No hashtag suggestions.', style: theme.textTheme.bodySmall)
          else
            Wrap(
              spacing: SpacingTokens.xs,
              runSpacing: SpacingTokens.xs,
              children: [for (final t in hashtags!) Chip(label: Text(t))],
            ),
        ],
        if (score != null) ...[
          const SizedBox(height: SpacingTokens.md),
          Row(
            children: [
              Text(
                '${score!.score}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: score!.score >= 70
                      ? AppColors.success
                      : score!.score >= 40
                          ? AppColors.warning
                          : theme.colorScheme.error,
                ),
              ),
              const SizedBox(width: SpacingTokens.xs),
              Text('/ 100', style: theme.textTheme.bodySmall),
              const SizedBox(width: SpacingTokens.md),
              if (score!.rationale.isNotEmpty)
                Expanded(child: Text(score!.rationale, style: theme.textTheme.bodySmall)),
            ],
          ),
        ],
      ],
    );
  }
}

class _BestTimes extends ConsumerWidget {
  const _BestTimes();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final slots = ref.watch(bestTimesProvider);
    return slots.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: SpacingTokens.sm),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Text('Could not load best times: ${describeApiError(e)}'),
      data: (list) => list.isEmpty
          ? Text(
              'Not enough published history yet — best times appear once your posts have metrics.',
              style: theme.textTheme.bodySmall,
            )
          : Wrap(
              spacing: SpacingTokens.sm,
              runSpacing: SpacingTokens.xs,
              children: [for (final s in list) Chip(label: Text(s.localLabel))],
            ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SpacingTokens.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: SpacingTokens.md),
          child,
        ],
      ),
    );
  }
}
