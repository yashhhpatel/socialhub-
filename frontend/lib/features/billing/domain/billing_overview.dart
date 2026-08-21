/// The billing state for an org, as returned by GET /billing (Phase 18).
class BillingOverview {
  const BillingOverview({
    required this.planTier,
    required this.status,
    required this.currentPeriodEnd,
    required this.cancelAtPeriodEnd,
    required this.hasBillingAccount,
    required this.billingConfigured,
    required this.limits,
    required this.usage,
    required this.invoices,
  });

  final String planTier;
  final String status;
  final DateTime? currentPeriodEnd;
  final bool cancelAtPeriodEnd;
  final bool hasBillingAccount;

  /// Whether the server has Stripe keys — when false, checkout/portal are
  /// unavailable and the UI shows a "billing not configured" note instead of
  /// upgrade buttons.
  final bool billingConfigured;

  final PlanLimits limits;
  final PlanUsage usage;
  final List<InvoiceSummary> invoices;

  bool get isPastDue => status == 'pastDue';

  factory BillingOverview.fromJson(Map<String, dynamic> json) => BillingOverview(
        planTier: json['planTier'] as String,
        status: json['status'] as String,
        currentPeriodEnd: json['currentPeriodEnd'] == null
            ? null
            : DateTime.tryParse(json['currentPeriodEnd'] as String),
        cancelAtPeriodEnd: json['cancelAtPeriodEnd'] as bool? ?? false,
        hasBillingAccount: json['hasBillingAccount'] as bool? ?? false,
        billingConfigured: json['billingConfigured'] as bool? ?? false,
        limits: PlanLimits.fromJson(json['limits'] as Map<String, dynamic>),
        usage: PlanUsage.fromJson(json['usage'] as Map<String, dynamic>),
        invoices: (json['invoices'] as List<dynamic>? ?? [])
            .map((e) => InvoiceSummary.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class PlanLimits {
  const PlanLimits({
    required this.maxSocialAccounts,
    required this.maxTeamMembers,
    required this.aiCreditsPerMonth,
    required this.maxScheduledPosts,
  });

  /// `-1` means unlimited.
  final int maxSocialAccounts;
  final int maxTeamMembers;
  final int aiCreditsPerMonth;
  final int maxScheduledPosts;

  factory PlanLimits.fromJson(Map<String, dynamic> json) => PlanLimits(
        maxSocialAccounts: json['maxSocialAccounts'] as int,
        maxTeamMembers: json['maxTeamMembers'] as int,
        aiCreditsPerMonth: json['aiCreditsPerMonth'] as int,
        maxScheduledPosts: json['maxScheduledPosts'] as int,
      );
}

class PlanUsage {
  const PlanUsage({
    required this.socialAccounts,
    required this.teamMembers,
    required this.aiCreditsUsed,
  });

  final int socialAccounts;
  final int teamMembers;
  final int aiCreditsUsed;

  factory PlanUsage.fromJson(Map<String, dynamic> json) => PlanUsage(
        socialAccounts: json['socialAccounts'] as int? ?? 0,
        teamMembers: json['teamMembers'] as int? ?? 0,
        aiCreditsUsed: json['aiCreditsUsed'] as int? ?? 0,
      );
}

class InvoiceSummary {
  const InvoiceSummary({
    required this.id,
    required this.amountDue,
    required this.currency,
    required this.status,
    required this.hostedInvoiceUrl,
    required this.createdAt,
  });

  final String id;
  final int amountDue; // minor units (cents)
  final String currency;
  final String status;
  final String? hostedInvoiceUrl;
  final DateTime? createdAt;

  factory InvoiceSummary.fromJson(Map<String, dynamic> json) => InvoiceSummary(
        id: json['id'] as String,
        amountDue: json['amountDue'] as int? ?? 0,
        currency: json['currency'] as String? ?? 'usd',
        status: json['status'] as String? ?? 'open',
        hostedInvoiceUrl: json['hostedInvoiceUrl'] as String?,
        createdAt: json['createdAt'] == null
            ? null
            : DateTime.tryParse(json['createdAt'] as String),
      );
}
