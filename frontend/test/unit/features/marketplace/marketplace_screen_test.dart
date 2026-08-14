import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialhub/features/marketplace/data/repositories/api_marketplace_repository.dart';
import 'package:socialhub/features/marketplace/presentation/screens/marketplace_screen.dart';
import 'package:socialhub/features/templates/domain/entities/template.dart';

/// Fake repository (subclassed so the provider override supplies canned
/// results). Records the last query it was asked for, so the test can assert
/// the search/filter reached the backend call.
class _FakeMarketplaceRepo extends ApiMarketplaceRepository {
  _FakeMarketplaceRepo() : super(Dio());

  String? lastSearch;
  String? lastCategory;

  @override
  Future<List<TemplateSummary>> search({String? search, String? category}) async {
    lastSearch = search;
    lastCategory = category;
    // "filter" by returning a name that echoes the query, so filtering is
    // observable in the widget tree.
    final label = search == null || search.isEmpty ? 'Everything' : 'Match:$search';
    return [
      TemplateSummary(id: 't1', name: label, category: category),
    ];
  }
}

Future<void> _pump(WidgetTester tester, _FakeMarketplaceRepo repo) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [marketplaceRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: Scaffold(body: MarketplaceScreen())),
    ),
  );
}

void main() {
  testWidgets('lists public templates on load', (tester) async {
    await _pump(tester, _FakeMarketplaceRepo());
    await tester.pumpAndSettle();

    expect(find.text('Marketplace'), findsOneWidget);
    expect(find.text('Everything'), findsOneWidget);
    expect(find.text('Clone'), findsOneWidget);
  });

  testWidgets('search + category re-queries and shows the filtered results', (tester) async {
    final repo = _FakeMarketplaceRepo();
    await _pump(tester, repo);
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Search templates'), 'promo');
    await tester.enterText(find.widgetWithText(TextField, 'Category'), 'Promotions');
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    // The query reached the repository...
    expect(repo.lastSearch, 'promo');
    expect(repo.lastCategory, 'Promotions');
    // ...and the filtered result is rendered.
    expect(find.text('Match:promo'), findsOneWidget);
  });
}
