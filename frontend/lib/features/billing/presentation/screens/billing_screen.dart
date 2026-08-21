import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/motion/skeleton.dart';
import '../../../../core/network/api_error_message.dart';
import '../../../../core/platform/external_redirect.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../../auth/presentation/state/current_user_provider.dart';
import '../../data/api_billing_repository.dart';
import '../../domain/billing_overview.dart';

/// Billing & plans (Phase 18). Shows the current plan, usage against limits,
/// upgrade options (Stripe Checkout), a manage-billing link (Stripe Portal),
/// a past-due dunning banner, and invoice history. Mutating actions are
/// admin-only (also enforced by the backend).
class BillingScreen extends ConsumerStatefulWidget {
  const BillingScreen({super.key});

  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen> {
  String? _busyTier; // tier whose checkout is being started
  bool _portalBusy = false;

  Future<void> _upgrade(String tier) async {
    setState(() => _busyTier = tier);
    try {
      final url = await ref.read(billingRepositoryProvider).startCheckout(tier);
      redirectToExternal(url); // leaves this tab for Stripe Checkout
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyTier = null);
      _toast('Could not start checkout: ${describeApiError(e)}');
    }
  }

  Future<void> _manage() async {
    setState(() => _portalBusy = true);
    try {
      final url = await ref.read(billingRepositoryProvider).startPortal();
      redirectToExternal(url);
    } catch (e) {
      if (!mounted) return;
      setState(() => _portalBusy = false);
      _toast('Could not open billing portal: ${describeApiError(e)}');
    }
  }

  void _toast(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overviewAsync = ref.watch(billingOverviewProvider);
    final isAdmin =
        ref.watch(currentUserProvider).valueOrNull?.isAdmin ?? false;

    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Billing', style: theme.textTheme.headlineMedium),
          const SizedBox(height: SpacingTokens.xs),
          Text(
            'Manage your plan, usage, and payment details.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: SpacingTokens.lg),
          overviewAsync.when(
            loading: () => const _BillingSkeleton(),
            error: (error, _) => isUnauthorized(error)
                ? Text(
                    'Log in to view your billing.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                : _ErrorState(
                    message: describeApiError(error),
                    onRetry: () => ref.invalidate(billingOverviewProvider),
                  ),
            data: (o) => _Content(
              overview: o,
              isAdmin: isAdmin,
              busyTier: _busyTier,
              portalBusy: _portalBusy,
              onUpgrade: _upgrade,
              onManage: _manage,
            ),
          ),
        ],
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.overview,
    required this.isAdmin,
    required this.busyTier,
    required this.portalBusy,
    required this.onUpgrade,
    required this.onManage,
  });

  final BillingOverview overview;
  final bool isAdmin;
  final String? busyTier;
  final bool portalBusy;
  final void Function(String tier) onUpgrade;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (overview.isPastDue) const _PastDueBanner(),
        _CurrentPlanCard(
          overview: overview,
          isAdmin: isAdmin,
          portalBusy: portalBusy,
          onManage: onManage,
        ),
        const SizedBox(height: SpacingTokens.lg),
        _UsageSection(overview: overview),
        const SizedBox(height: SpacingTokens.lg),
        Text('Plans', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: SpacingTokens.sm),
        if (!overview.billingConfigured)
          Padding(
            padding: const EdgeInsets.only(bottom: SpacingTokens.md),
            child: Text(
              'Billing isn\'t set up on this server yet — plan changes are '
              'unavailable.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        _PlanGrid(
          overview: overview,
          isAdmin: isAdmin,
          busyTier: busyTier,
          onUpgrade: onUpgrade,
        ),
        if (overview.invoices.isNotEmpty) ...[
          const SizedBox(height: SpacingTokens.lg),
          Text('Invoices', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: SpacingTokens.sm),
          _InvoiceList(invoices: overview.invoices),
        ],
      ],
    );
  }
}

class _PastDueBanner extends StatelessWidget {
  const _PastDueBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: SpacingTokens.md),
      padding: const EdgeInsets.all(SpacingTokens.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border.all(color: AppColors.warning),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.warning, size: 20),
          const SizedBox(width: SpacingTokens.sm),
          Expanded(
            child: Text(
              'Your last payment failed. Update your payment method to keep '
              'your plan active.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentPlanCard extends StatelessWidget {
  const _CurrentPlanCard({
    required this.overview,
    required this.isAdmin,
    required this.portalBusy,
    required this.onManage,
  });

  final BillingOverview overview;
  final bool isAdmin;
  final bool portalBusy;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Current plan', style: theme.textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(
                  _titleCase(overview.planTier),
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: SpacingTokens.xs),
                Text(
                  _subtitle(overview),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (isAdmin && overview.hasBillingAccount)
            OutlinedButton(
              onPressed: portalBusy ? null : onManage,
              child: portalBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Manage billing'),
            ),
        ],
      ),
    );
  }

  String _subtitle(BillingOverview o) {
    if (o.currentPeriodEnd == null) return 'No active subscription.';
    final date = _formatDate(o.currentPeriodEnd!);
    return o.cancelAtPeriodEnd
        ? 'Access until $date (cancels then).'
        : 'Renews on $date.';
  }
}

class _UsageSection extends StatelessWidget {
  const _UsageSection({required this.overview});

  final BillingOverview overview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = overview.limits;
    final u = overview.usage;
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Usage', style: theme.textTheme.titleMedium),
          const SizedBox(height: SpacingTokens.md),
          _UsageBar(label: 'Connected accounts', used: u.socialAccounts, limit: l.maxSocialAccounts),
          const SizedBox(height: SpacingTokens.md),
          _UsageBar(label: 'Team members', used: u.teamMembers, limit: l.maxTeamMembers),
          const SizedBox(height: SpacingTokens.md),
          _UsageBar(label: 'AI credits (this month)', used: u.aiCreditsUsed, limit: l.aiCreditsPerMonth),
        ],
      ),
    );
  }
}

class _UsageBar extends StatelessWidget {
  const _UsageBar({required this.label, required this.used, required this.limit});

  final String label;
  final int used;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unlimited = limit < 0;
    final fraction = unlimited ? 0.0 : (limit == 0 ? 1.0 : (used / limit).clamp(0.0, 1.0));
    final atLimit = !unlimited && used >= limit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
            Text(
              unlimited ? '$used / Unlimited' : '$used / $limit',
              style: theme.textTheme.bodySmall?.copyWith(
                color: atLimit ? AppColors.warning : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: unlimited ? 0 : fraction,
            minHeight: 6,
            backgroundColor: AppColors.surfaceRaised,
            color: atLimit ? AppColors.warning : AppColors.accent,
          ),
        ),
      ],
    );
  }
}

class _PlanGrid extends StatelessWidget {
  const _PlanGrid({
    required this.overview,
    required this.isAdmin,
    required this.busyTier,
    required this.onUpgrade,
  });

  final BillingOverview overview;
  final bool isAdmin;
  final String? busyTier;
  final void Function(String tier) onUpgrade;

  // Purchasable tiers with a short, honest blurb (real price shows on Stripe).
  static const _plans = [
    (tier: 'starter', name: 'Starter', blurb: '5 accounts · 5 members · 500 AI credits'),
    (tier: 'pro', name: 'Pro', blurb: '15 accounts · 20 members · 5,000 AI credits'),
    (tier: 'enterprise', name: 'Enterprise', blurb: 'Unlimited accounts, members & AI'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: SpacingTokens.md,
      runSpacing: SpacingTokens.md,
      children: [
        for (final p in _plans)
          SizedBox(
            width: 260,
            child: _PlanCard(
              tier: p.tier,
              name: p.name,
              blurb: p.blurb,
              isCurrent: overview.planTier == p.tier,
              canPurchase: isAdmin && overview.billingConfigured,
              busy: busyTier == p.tier,
              onUpgrade: () => onUpgrade(p.tier),
            ),
          ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.tier,
    required this.name,
    required this.blurb,
    required this.isCurrent,
    required this.canPurchase,
    required this.busy,
    required this.onUpgrade,
  });

  final String tier;
  final String name;
  final String blurb;
  final bool isCurrent;
  final bool canPurchase;
  final bool busy;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent ? AppColors.accent : theme.dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: theme.textTheme.titleMedium),
          const SizedBox(height: SpacingTokens.xs),
          Text(
            blurb,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: SpacingTokens.md),
          SizedBox(
            width: double.infinity,
            child: isCurrent
                ? const OutlinedButton(
                    onPressed: null,
                    child: Text('Current plan'),
                  )
                : FilledButton(
                    onPressed: (canPurchase && !busy) ? onUpgrade : null,
                    child: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Upgrade'),
                  ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceList extends StatelessWidget {
  const _InvoiceList({required this.invoices});

  final List<InvoiceSummary> invoices;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: [
          for (var i = 0; i < invoices.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            ListTile(
              title: Text(
                invoices[i].createdAt == null
                    ? 'Invoice'
                    : _formatDate(invoices[i].createdAt!),
                style: theme.textTheme.bodyMedium,
              ),
              subtitle: Text(
                '${_money(invoices[i].amountDue, invoices[i].currency)} · '
                '${invoices[i].status}',
                style: theme.textTheme.bodySmall,
              ),
              trailing: invoices[i].hostedInvoiceUrl != null
                  ? TextButton(
                      onPressed: () =>
                          redirectToExternal(invoices[i].hostedInvoiceUrl!),
                      child: const Text('View'),
                    )
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _BillingSkeleton extends StatelessWidget {
  const _BillingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Skeleton(height: 96, borderRadius: BorderRadius.circular(12)),
        const SizedBox(height: SpacingTokens.lg),
        Skeleton(height: 160, borderRadius: BorderRadius.circular(12)),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Could not load billing: $message'),
        const SizedBox(height: SpacingTokens.md),
        OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}

String _titleCase(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

String _formatDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

String _money(int minorUnits, String currency) {
  final amount = (minorUnits / 100).toStringAsFixed(2);
  final symbol = currency.toLowerCase() == 'usd' ? '\$' : '';
  return symbol.isNotEmpty ? '$symbol$amount' : '$amount ${currency.toUpperCase()}';
}
