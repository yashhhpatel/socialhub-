import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_error_message.dart';
import '../../../../core/widgets/sign_in_required.dart';
import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../../templates/domain/entities/template.dart';
import '../../../templates/presentation/state/templates_controller.dart';
import '../../data/repositories/api_marketplace_repository.dart';

/// Template marketplace (Milestone 14.2): browse and search public templates
/// published by any org, and clone one into your own workspace.
class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen> {
  final _searchController = TextEditingController();
  final _categoryController = TextEditingController();
  // The submitted query the results are keyed on — updated on Search, not on
  // every keystroke, so browsing doesn't fire a request per character.
  MarketplaceQuery _query = const MarketplaceQuery();
  String? _cloningId;

  @override
  void dispose() {
    _searchController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  void _applySearch() {
    setState(() {
      _query = MarketplaceQuery(
        search: _searchController.text.trim(),
        category: _categoryController.text.trim(),
      );
    });
  }

  Future<void> _clone(TemplateSummary template) async {
    setState(() => _cloningId = template.id);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(marketplaceRepositoryProvider).clone(template.id);
      // Refresh the user's own library so the clone shows up there.
      ref.invalidate(templatesProvider);
      messenger.showSnackBar(
        SnackBar(content: Text('“${template.name}” cloned to your templates.')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not clone: ${describeApiError(error)}')),
      );
    } finally {
      if (mounted) setState(() => _cloningId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resultsAsync = ref.watch(marketplaceResultsProvider(_query));

    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Marketplace', style: theme.textTheme.headlineMedium),
          const SizedBox(height: SpacingTokens.xs),
          Text(
            'Public templates from the community. Clone one into your workspace.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: SpacingTokens.md),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search templates',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _applySearch(),
                ),
              ),
              const SizedBox(width: SpacingTokens.sm),
              Expanded(
                child: TextField(
                  controller: _categoryController,
                  decoration: const InputDecoration(
                    hintText: 'Category',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _applySearch(),
                ),
              ),
              const SizedBox(width: SpacingTokens.sm),
              FilledButton(onPressed: _applySearch, child: const Text('Search')),
            ],
          ),
          const SizedBox(height: SpacingTokens.lg),
          resultsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(SpacingTokens.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => isUnauthorized(error)
                ? const SignInRequired(
                    message: 'Log in to browse the community marketplace.',
                  )
                : Center(
                    child: Text('Could not load the marketplace: ${describeApiError(error)}'),
                  ),
            data: (results) {
              if (results.isEmpty) return const _EmptyMarketplace();
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 260,
                  mainAxisExtent: 230,
                  crossAxisSpacing: SpacingTokens.md,
                  mainAxisSpacing: SpacingTokens.md,
                ),
                itemCount: results.length,
                itemBuilder: (context, i) => _MarketplaceCard(
                  template: results[i],
                  cloning: _cloningId == results[i].id,
                  onClone: () => _clone(results[i]),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MarketplaceCard extends StatelessWidget {
  const _MarketplaceCard({
    required this.template,
    required this.cloning,
    required this.onClone,
  });

  final TemplateSummary template;
  final bool cloning;
  final VoidCallback onClone;

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
                      errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.image_outlined)),
                    )
                  : const Center(child: Icon(Icons.storefront_outlined, size: 32)),
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
                  child: OutlinedButton.icon(
                    onPressed: cloning ? null : onClone,
                    icon: cloning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.copy_all_outlined, size: 16),
                    label: const Text('Clone'),
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

class _EmptyMarketplace extends StatelessWidget {
  const _EmptyMarketplace();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.storefront_outlined, size: 40, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: SpacingTokens.md),
          Text('No public templates found', style: theme.textTheme.titleMedium),
          const SizedBox(height: SpacingTokens.xs),
          Text(
            'Try a different search, or publish one of your own from Templates.',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
