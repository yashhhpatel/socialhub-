import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_error_message.dart';
import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../../content/data/repositories/api_content_repository.dart';
import '../../../editor/canvas/models/canvas_document.dart';
import '../../data/repositories/api_templates_repository.dart';
import '../../domain/entities/template.dart';
import '../state/templates_controller.dart';

/// Template gallery (Milestone 9.4). Browse the org's templates and start a
/// new design from one — which clones the template's canvas into a fresh
/// ContentAsset (via the existing content-creation endpoint) and opens the
/// editor on it.
class TemplatesScreen extends ConsumerStatefulWidget {
  const TemplatesScreen({super.key});

  @override
  ConsumerState<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends ConsumerState<TemplatesScreen> {
  /// Id of the template currently being turned into a design, so its card
  /// shows a spinner and can't be double-tapped.
  String? _startingId;

  Future<void> _startFrom(TemplateSummary summary) async {
    setState(() => _startingId = summary.id);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final detail = await ref.read(templatesRepositoryProvider).get(summary.id);
      final document = CanvasDocument.fromJson(detail.canvasJson);
      final assetId =
          await ref.read(contentRepositoryProvider).createAsset(document: document);
      if (!mounted) return;
      router.go('/editor/$assetId');
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not start from template: ${describeApiError(error)}')),
      );
      setState(() => _startingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(templatesProvider);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Templates', style: theme.textTheme.headlineMedium),
          const SizedBox(height: SpacingTokens.xs),
          Text(
            'Start a new design from a saved template. Save any design as a template from the editor.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: SpacingTokens.lg),
          Expanded(
            child: templatesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text('Could not load templates: ${describeApiError(error)}'),
              ),
              data: (templates) {
                if (templates.isEmpty) return const _EmptyTemplates();
                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 260,
                    mainAxisExtent: 220,
                    crossAxisSpacing: SpacingTokens.md,
                    mainAxisSpacing: SpacingTokens.md,
                  ),
                  itemCount: templates.length,
                  itemBuilder: (context, i) => _TemplateCard(
                    template: templates[i],
                    starting: _startingId == templates[i].id,
                    onUse: () => _startFrom(templates[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.starting,
    required this.onUse,
  });

  final TemplateSummary template;
  final bool starting;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              color: theme.colorScheme.surfaceContainerHighest,
              child: template.thumbnailUrl != null
                  ? Image.network(
                      template.thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Center(child: Icon(Icons.image_outlined)),
                    )
                  : const Center(child: Icon(Icons.dashboard_customize_outlined, size: 32)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(SpacingTokens.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  template.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                if (template.category != null)
                  Text(template.category!, style: theme.textTheme.bodySmall),
                const SizedBox(height: SpacingTokens.sm),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: starting ? null : onUse,
                    child: starting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Use template'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTemplates extends StatelessWidget {
  const _EmptyTemplates();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.dashboard_customize_outlined,
            size: 40,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: SpacingTokens.md),
          Text('No templates yet', style: theme.textTheme.titleMedium),
          const SizedBox(height: SpacingTokens.xs),
          Text(
            'Open a design in the editor and choose “Save as template”.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
