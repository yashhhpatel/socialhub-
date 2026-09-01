import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../../editor/canvas/models/canvas_document.dart';
import '../../../editor/canvas/widgets/canvas_preview.dart';
import '../../data/repositories/api_templates_repository.dart';
import '../../domain/entities/template.dart';

/// One action offered inside the detail dialog (e.g. Use / Clone / Publish /
/// Delete). Tapping it closes the dialog first, then runs [onPressed], so the
/// underlying screen action (which may navigate or open its own dialog) never
/// fights this dialog for the navigator.
class TemplateDetailAction {
  const TemplateDetailAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool primary;
  final bool danger;
}

/// The template's full canvas — fetched from GET /templates/:id. Returns null
/// (rather than throwing) when it can't be loaded, e.g. the signed-out demo's
/// sample templates or a transient error, so the dialog degrades to a
/// metadata-only view instead of an error wall.
final _templateDetailProvider =
    FutureProvider.autoDispose.family<TemplateDetail?, String>((ref, id) async {
  try {
    return await ref.watch(templatesRepositoryProvider).get(id);
  } catch (_) {
    return null;
  }
});

/// Opens a detail view for a template / marketplace item: a full canvas
/// preview plus its metadata and the given [actions]. Shared by both the
/// Templates and Marketplace screens.
Future<void> showTemplateDetail(
  BuildContext context, {
  required TemplateSummary summary,
  required List<TemplateDetailAction> actions,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _TemplateDetailDialog(summary: summary, actions: actions),
  );
}

class _TemplateDetailDialog extends ConsumerWidget {
  const _TemplateDetailDialog({required this.summary, required this.actions});

  final TemplateSummary summary;
  final List<TemplateDetailAction> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final isWide = size.width >= 720;
    final detail = ref.watch(_templateDetailProvider(summary.id));

    return Dialog(
      insetPadding:
          EdgeInsets.all(isWide ? SpacingTokens.xl : SpacingTokens.sm),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 760,
          maxHeight: size.height * (isWide ? 0.9 : 0.96),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            SpacingTokens.xl,
            SpacingTokens.lg,
            SpacingTokens.xl,
            SpacingTokens.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header: name + owner/category + close.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(summary.name, style: theme.textTheme.titleLarge),
                        const SizedBox(height: SpacingTokens.xs),
                        Wrap(
                          spacing: SpacingTokens.sm,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (summary.category != null)
                              Chip(
                                label: Text(summary.category!),
                                visualDensity: VisualDensity.compact,
                              ),
                            Chip(
                              label: Text(
                                summary.isOwn ? 'Your template' : 'Community',
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: SpacingTokens.md),
              // Preview area — the real canvas when it loads, otherwise a
              // thumbnail or a neutral placeholder.
              SizedBox(
                height: 340,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: detail.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, __) => _Placeholder(summary: summary),
                    data: (d) => d == null
                        ? _Placeholder(summary: summary)
                        : Padding(
                            padding: const EdgeInsets.all(SpacingTokens.md),
                            child: CanvasPreview(
                              document: CanvasDocument.fromJson(d.canvasJson),
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: SpacingTokens.lg),
              // Actions supplied by the caller.
              Wrap(
                alignment: WrapAlignment.end,
                spacing: SpacingTokens.sm,
                runSpacing: SpacingTokens.sm,
                children: [
                  for (final action in actions)
                    _actionButton(context, theme, action),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton(
    BuildContext context,
    ThemeData theme,
    TemplateDetailAction action,
  ) {
    void run() {
      Navigator.of(context).pop();
      action.onPressed();
    }

    if (action.primary) {
      return FilledButton.icon(
        onPressed: run,
        icon: Icon(action.icon, size: 18),
        label: Text(action.label),
      );
    }
    return OutlinedButton.icon(
      onPressed: run,
      style: action.danger
          ? OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error)
          : null,
      icon: Icon(action.icon, size: 18),
      label: Text(action.label),
    );
  }
}

/// Shown when the canvas can't be rendered (demo templates, or a load error):
/// the item's icon over the surface, so the dialog still reads as a preview.
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.summary});

  final TemplateSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (summary.thumbnailUrl != null) {
      return Image.network(
        summary.thumbnailUrl!,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _icon(theme),
      );
    }
    return _icon(theme);
  }

  Widget _icon(ThemeData theme) => Center(
        child: Icon(
          Icons.dashboard_customize_outlined,
          size: 48,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
}
