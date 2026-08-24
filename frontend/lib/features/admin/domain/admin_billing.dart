class CountByKey {
  const CountByKey({required this.key, required this.count});
  final String key;
  final int count;
  factory CountByKey.fromJson(Map<String, dynamic> j) =>
      CountByKey(key: j['key'] as String? ?? '', count: (j['count'] as num?)?.toInt() ?? 0);
}

class AdminPastDueOrg {
  const AdminPastDueOrg({
    required this.orgId,
    required this.orgName,
    required this.planTier,
    required this.status,
  });
  final String orgId;
  final String orgName;
  final String planTier;
  final String status;
  factory AdminPastDueOrg.fromJson(Map<String, dynamic> j) => AdminPastDueOrg(
        orgId: j['orgId'] as String? ?? '',
        orgName: j['orgName'] as String? ?? '',
        planTier: j['planTier'] as String? ?? '',
        status: j['status'] as String? ?? '',
      );
}

class AdminInvoiceRow {
  const AdminInvoiceRow({
    required this.id,
    required this.orgName,
    required this.amountPaid,
    required this.amountDue,
    required this.currency,
    required this.status,
    required this.hostedInvoiceUrl,
  });
  final String id;
  final String orgName;
  final int amountPaid; // cents
  final int amountDue;
  final String currency;
  final String status;
  final String? hostedInvoiceUrl;
  factory AdminInvoiceRow.fromJson(Map<String, dynamic> j) => AdminInvoiceRow(
        id: j['id'] as String? ?? '',
        orgName: j['orgName'] as String? ?? '',
        amountPaid: (j['amountPaid'] as num?)?.toInt() ?? 0,
        amountDue: (j['amountDue'] as num?)?.toInt() ?? 0,
        currency: j['currency'] as String? ?? 'usd',
        status: j['status'] as String? ?? '',
        hostedInvoiceUrl: j['hostedInvoiceUrl'] as String?,
      );
}

class AdminBilling {
  const AdminBilling({
    required this.activeByTier,
    required this.subscriptionsByStatus,
    required this.revenuePaidAllTime,
    required this.revenuePaid30d,
    required this.currency,
    required this.pastDue,
    required this.recentInvoices,
  });

  final List<CountByKey> activeByTier;
  final List<CountByKey> subscriptionsByStatus;
  final int revenuePaidAllTime; // cents
  final int revenuePaid30d;
  final String currency;
  final List<AdminPastDueOrg> pastDue;
  final List<AdminInvoiceRow> recentInvoices;

  factory AdminBilling.fromJson(Map<String, dynamic> j) {
    List<T> list<T>(String k, T Function(Map<String, dynamic>) f) =>
        (j[k] as List<dynamic>? ?? [])
            .map((e) => f(e as Map<String, dynamic>))
            .toList();
    return AdminBilling(
      activeByTier: list('activeByTier', CountByKey.fromJson),
      subscriptionsByStatus: list('subscriptionsByStatus', CountByKey.fromJson),
      revenuePaidAllTime: (j['revenuePaidAllTime'] as num?)?.toInt() ?? 0,
      revenuePaid30d: (j['revenuePaid30d'] as num?)?.toInt() ?? 0,
      currency: j['currency'] as String? ?? 'usd',
      pastDue: list('pastDue', AdminPastDueOrg.fromJson),
      recentInvoices: list('recentInvoices', AdminInvoiceRow.fromJson),
    );
  }
}

/// Formats a minor-unit (cents) amount as e.g. "$12.34 USD".
String formatMoney(int cents, String currency) {
  final amount = (cents / 100).toStringAsFixed(2);
  return '$amount ${currency.toUpperCase()}';
}
