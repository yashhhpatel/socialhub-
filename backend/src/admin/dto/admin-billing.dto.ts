export class CountByKeyDto {
  key: string;
  count: number;
}

export class AdminPastDueOrgDto {
  orgId: string;
  orgName: string;
  planTier: string;
  status: string;
  currentPeriodEnd: Date | null;
}

export class AdminInvoiceRowDto {
  id: string;
  orgId: string;
  orgName: string;
  amountDue: number; // minor units (cents)
  amountPaid: number;
  currency: string;
  status: string;
  hostedInvoiceUrl: string | null;
  createdAt: Date;
}

/// Cross-tenant billing overview for the admin panel (Phase 21.6). Amounts are
/// in minor units; no Stripe keys or card data — invoices link out via
/// hostedInvoiceUrl.
export class AdminBillingDto {
  /// Active subscriptions grouped by plan tier.
  activeByTier: CountByKeyDto[];
  /// All subscriptions grouped by status (active/pastDue/canceled/…).
  subscriptionsByStatus: CountByKeyDto[];
  /// Collected revenue (sum of invoice.amountPaid), all-time and trailing 30d.
  revenuePaidAllTime: number;
  revenuePaid30d: number;
  currency: string;
  /// Orgs whose subscription is past due (dunning queue).
  pastDue: AdminPastDueOrgDto[];
  /// Most recent invoices across all tenants.
  recentInvoices: AdminInvoiceRowDto[];
}
