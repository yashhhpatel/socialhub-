import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/billing_overview.dart';

/// Talks to the backend /billing endpoints (Phase 18): the overview, and the
/// checkout / portal session starters (which return a Stripe-hosted URL the
/// screen redirects the tab to).
class ApiBillingRepository {
  ApiBillingRepository(this._dio);

  final Dio _dio;

  Future<BillingOverview> getOverview() async {
    final response = await _dio.get<Map<String, dynamic>>('/billing');
    return BillingOverview.fromJson(response.data!);
  }

  /// Starts Checkout for [tier]; returns the hosted URL to redirect to.
  Future<String> startCheckout(String tier) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/billing/checkout',
      data: {'tier': tier},
    );
    return response.data!['url'] as String;
  }

  /// Opens the Stripe Billing Portal; returns the URL to redirect to.
  Future<String> startPortal() async {
    final response = await _dio.post<Map<String, dynamic>>('/billing/portal');
    return response.data!['url'] as String;
  }
}

final billingRepositoryProvider = Provider<ApiBillingRepository>((ref) {
  return ApiBillingRepository(ref.watch(apiClientProvider));
});

/// The org's billing overview. autoDispose so it re-fetches on revisit (e.g.
/// after returning from Stripe Checkout). Watches token presence so it
/// re-evaluates on login/logout rather than caching a logged-out 401.
final billingOverviewProvider =
    FutureProvider.autoDispose<BillingOverview>((ref) async {
  return ref.watch(billingRepositoryProvider).getOverview();
});
