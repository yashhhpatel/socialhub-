import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../templates/domain/entities/template.dart';

/// Talks to the template-marketplace endpoints (Milestone 14.2): browse
/// public templates, publish one of your own, clone one into your workspace.
/// Reuses the templates feature's TemplateSummary — a marketplace card and a
/// library card carry the same fields.
class ApiMarketplaceRepository {
  ApiMarketplaceRepository(this._dio);

  final Dio _dio;

  Future<List<TemplateSummary>> search({String? search, String? category}) async {
    final response = await _dio.get<List<dynamic>>(
      '/templates/marketplace',
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (category != null && category.isNotEmpty) 'category': category,
      },
    );
    return (response.data ?? [])
        .map((t) => TemplateSummary.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  /// Publishes one of the caller's own templates to the marketplace.
  Future<void> publish(String templateId) async {
    await _dio.post<void>('/templates/$templateId/publish');
  }

  /// Clones a public template into the caller's org, returning the new copy.
  Future<TemplateSummary> clone(String templateId) async {
    final response = await _dio.post<Map<String, dynamic>>('/templates/$templateId/clone');
    return TemplateSummary.fromJson(response.data!);
  }
}

final marketplaceRepositoryProvider = Provider<ApiMarketplaceRepository>((ref) {
  return ApiMarketplaceRepository(ref.watch(apiClientProvider));
});

/// A marketplace query — search text + optional category.
class MarketplaceQuery {
  const MarketplaceQuery({this.search, this.category});

  final String? search;
  final String? category;

  @override
  bool operator ==(Object other) =>
      other is MarketplaceQuery && other.search == search && other.category == category;

  @override
  int get hashCode => Object.hash(search, category);
}

/// Marketplace results for a given query (Milestone 14.2).
final marketplaceResultsProvider = FutureProvider.autoDispose
    .family<List<TemplateSummary>, MarketplaceQuery>((ref, query) async {
  return ref.watch(marketplaceRepositoryProvider).search(
        search: query.search,
        category: query.category,
      );
});
