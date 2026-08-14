import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialhub/features/ai_suite/data/repositories/api_ai_suite_repository.dart';
import 'package:socialhub/features/ai_suite/domain/entities/viral_score.dart';
import 'package:socialhub/features/ai_suite/presentation/widgets/ai_tools_panel.dart';

/// Fake over the concrete repository — subclassed so the provider can be
/// overridden with canned AI responses (no network).
class _FakeRepo extends ApiAiSuiteRepository {
  _FakeRepo() : super(Dio());

  @override
  Future<List<String>> hashtags(String assetId, {int count = 10}) async =>
      ['#coldbrew', '#coffee'];

  @override
  Future<String> rewriteTone(String text, String tone) async => 'REWRITTEN($tone): $text';

  @override
  Future<ViralScore> viralScore(String assetId, {String? caption}) async =>
      const ViralScore(score: 77, rationale: 'Good hook.');
}

Future<void> _pump(WidgetTester tester, TextEditingController controller) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [aiSuiteRepositoryProvider.overrideWithValue(_FakeRepo())],
      child: MaterialApp(
        home: Scaffold(
          body: AiToolsPanel(
            assetId: 'asset_1',
            captionController: controller,
            enabled: true,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('suggests hashtags and appends a tapped chip to the caption', (tester) async {
    final controller = TextEditingController(text: 'Cold brew season');
    await _pump(tester, controller);

    await tester.tap(find.text('Hashtags'));
    await tester.pumpAndSettle();

    // Chips rendered for each suggestion.
    expect(find.text('#coldbrew'), findsOneWidget);
    expect(find.text('#coffee'), findsOneWidget);

    // Tapping a chip appends it to the caption (with a separating space).
    await tester.tap(find.text('#coldbrew'));
    await tester.pump();
    expect(controller.text, 'Cold brew season #coldbrew ');
  });

  testWidgets('shows a viral score gauge after scoring', (tester) async {
    final controller = TextEditingController(text: 'Launch day');
    await _pump(tester, controller);

    await tester.tap(find.text('Viral score'));
    await tester.pumpAndSettle();

    expect(find.text('77'), findsOneWidget);
    expect(find.text('Good hook.'), findsOneWidget);
  });
}
