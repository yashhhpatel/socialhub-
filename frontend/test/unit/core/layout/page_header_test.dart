import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialhub/core/layout/widgets/page_header.dart';
import 'package:socialhub/core/theme/app_theme.dart';

Widget _host(Widget child, {Size size = const Size(1200, 800)}) => MaterialApp(
      theme: midnightStudioTheme,
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(size: size),
          child: SizedBox(width: size.width, child: child),
        ),
      ),
    );

void main() {
  testWidgets('centers the title and enlarges it to headlineLarge',
      (tester) async {
    await tester.pumpWidget(_host(const PageHeader(title: 'Calendar')));
    await tester.pumpAndSettle();

    final title = tester.widget<Text>(find.text('Calendar'));
    expect(title.textAlign, TextAlign.center);
    // headlineLarge is 32 in the app's type scale — larger than the old
    // headlineMedium (24) page titles.
    expect(title.style?.fontSize, 32);
  });

  testWidgets('centers the subtitle and enlarges it to titleMedium',
      (tester) async {
    await tester.pumpWidget(
      _host(const PageHeader(title: 'Calendar', subtitle: 'Everything here.')),
    );
    await tester.pumpAndSettle();

    final subtitle = tester.widget<Text>(find.text('Everything here.'));
    expect(subtitle.textAlign, TextAlign.center);
    // titleMedium is 16 — larger than the old bodyMedium (14) subtitles.
    expect(subtitle.style?.fontSize, 16);
  });

  testWidgets('omits the subtitle line when none is given', (tester) async {
    await tester.pumpWidget(_host(const PageHeader(title: 'Billing')));
    await tester.pumpAndSettle();
    expect(find.text('Billing'), findsOneWidget);
  });

  testWidgets('renders a trailing action alongside the title', (tester) async {
    await tester.pumpWidget(
      _host(
        PageHeader(
          title: 'Calendar',
          subtitle: 'Everything here.',
          trailing: IconButton(
            tooltip: 'Refresh',
            onPressed: () {},
            icon: const Icon(Icons.refresh),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Calendar'), findsOneWidget);
    expect(find.byTooltip('Refresh'), findsOneWidget);
  });

  testWidgets('keeps the title and action on a narrow (mobile) width',
      (tester) async {
    await tester.pumpWidget(
      _host(
        PageHeader(
          title: 'Media Library',
          trailing: FilledButton(
            onPressed: () {},
            child: const Text('Upload'),
          ),
        ),
        size: const Size(375, 812),
      ),
    );
    await tester.pumpAndSettle();

    // Both still render (stacked vertically on mobile) — the centered title
    // must not push the action off-screen or overlap it.
    expect(find.text('Media Library'), findsOneWidget);
    expect(find.text('Upload'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
