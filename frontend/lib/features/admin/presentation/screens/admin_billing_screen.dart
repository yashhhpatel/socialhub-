import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_error_message.dart';
import '../../../../core/platform/external_redirect.dart';
import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../data/api_admin_repository.dart';
import '../../domain/admin_billing.dart';
import '../widgets/admin_stat_card.dart';

/// Admin → Billing & revenue (Phase 21.6): subscriptions, dunning, collected
/// revenue and recent invoices. Read-only; links out to Stripe, no card data.
class AdminBillingScreen extends ConsumerWidget {
  const AdminBillingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(adminBillingProvider);

    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Billing & revenue', style: theme.textTheme.headlineLarge),
          const SizedBox(height: SpacingTokens.lg),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.only(top: SpacingTokens.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Column(
              children: [
                Text(describeApiError(error), style: theme.textTheme.bodySmall),
                const SizedBox(height: SpacingTokens.sm),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(adminBillingProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
            data: (b) => _Content(billing: b),
          ),
        ],
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.billing});
  final AdminBilling billing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = billing;
    final width = MediaQuery.of(context).size.width;
    final columns = width >= 900 ? 3 : 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: SpacingTokens.md,
          mainAxisSpacing: SpacingTokens.md,
          childAspectRatio: 1.9,
          children: [
            AdminStatCard(
              label: 'Revenue (all time)',
              value: formatMoney(b.revenuePaidAllTime, b.currency),
              icon: Icons.payments_outlined,
            ),
            AdminStatCard(
              label: 'Revenue (30d)',
              value: formatMoney(b.revenuePaid30d, b.currency),
              icon: Icons.trending_up,
            ),
            AdminStatCard(
              label: 'Past due',
              value: '${b.pastDue.length}',
              subtitle: 'orgs in dunning',
              icon: Icons.warning_amber_outlined,
              highlight: b.pastDue.isNotEmpty,
            ),
          ],
        ),
        const SizedBox(height: SpacingTokens.lg),
        Text('Active subscriptions by plan', style: theme.textTheme.titleMedium),
        const SizedBox(height: SpacingTokens.sm),
        Wrap(
          spacing: SpacingTokens.sm,
          children: [
            if (b.activeByTier.isEmpty)
              Text('None', style: theme.textTheme.bodySmall)
            else
              for (final c in b.activeByTier)
                Chip(label: Text('${c.key}: ${c.count}')),
          ],
        ),
        const SizedBox(height: SpacingTokens.md),
        Text('Subscriptions by status', style: theme.textTheme.titleMedium),
        const SizedBox(height: SpacingTokens.sm),
        Wrap(
          spacing: SpacingTokens.sm,
          children: [
            for (final c in b.subscriptionsByStatus)
              Chip(label: Text('${c.key}: ${c.count}')),
          ],
        ),
        const SizedBox(height: SpacingTokens.lg),
        Text('Recent invoices', style: theme.textTheme.titleMedium),
        const SizedBox(height: SpacingTokens.sm),
        if (b.recentInvoices.isEmpty)
          Text('No invoices yet.', style: theme.textTheme.bodyMedium)
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Organization')),
                DataColumn(label: Text('Paid')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('')),
              ],
              rows: [
                for (final i in b.recentInvoices)
                  DataRow(
                    cells: [
                      DataCell(Text(i.orgName)),
                      DataCell(Text(formatMoney(i.amountPaid, i.currency))),
                      DataCell(Text(i.status)),
                      DataCell(
                        i.hostedInvoiceUrl == null
                            ? const SizedBox.shrink()
                            : TextButton(
                                onPressed: () =>
                                    redirectToExternal(i.hostedInvoiceUrl!),
                                child: const Text('View'),
                              ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
