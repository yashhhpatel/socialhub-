import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialhub/features/templates/data/repositories/api_templates_repository.dart';
import 'package:socialhub/features/templates/domain/entities/template.dart';
import 'package:socialhub/features/templates/presentation/widgets/template_detail_dialog.dart';

/// Detail fetch fails here, so the dialog takes its metadata-only path (the
/// canvas preview degrades to a placeholder) — no network needed in the test.
class _FakeTemplatesRepo extends ApiTemplatesRepository {
  _FakeTemplatesRepo() : super(Dio());

  @override
  Future<TemplateDetail> get(String id) async => throw Exception('offline');
}

void main() {
  testWidgets('detail dialog shows metadata and runs an action after closing',
      (tester) async {
    var used = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          templatesRepositoryProvider.overrideWithValue(_FakeTemplatesRepo()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showTemplateDetail(
                  context,
                  summary: const TemplateSummary(
                    id: 't1',
                    name: 'Promo',
                    category: 'Promotions',
                  ),
                  actions: [
                    TemplateDetailAction(
                      icon: Icons.brush_outlined,
                      label: 'Use template',
                      primary: true,
                      onPressed: () => used = true,
                    ),
                  ],
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // The detail view shows the item's metadata.
    expect(find.text('Promo'), findsOneWidget);
    expect(find.text('Promotions'), findsOneWidget);
    expect(find.text('Community'), findsOneWidget); // not owned
    expect(find.byTooltip('Close'), findsOneWidget);
    expect(find.text('Use template'), findsOneWidget);

    // Tapping an action closes the dialog, then runs it.
    await tester.tap(find.text('Use template'));
    await tester.pumpAndSettle();
    expect(used, isTrue);
    expect(find.text('Promo'), findsNothing); // dialog dismissed
  });
}
