import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:socialhub/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:socialhub/features/templates/presentation/screens/templates_screen.dart';

/// These render with NO auth token override, so the app is in demo mode: the
/// real providers serve their sample data, and protected actions route to
/// login.

void main() {
  testWidgets('signed out: dashboard shows the demo overview data',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: DashboardScreen())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The demo overview numbers, not an empty "log in" state.
    expect(find.text('42'), findsWidgets); // published posts
    expect(find.text('Scheduled Posts'), findsOneWidget);
  });

  testWidgets('signed out: templates show demo data and Use routes to login',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const TemplatesScreen()),
        GoRoute(
          path: '/login',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('LOGIN'))),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    // Demo templates are shown.
    expect(find.text('Product Launch'), findsOneWidget);
    expect(find.text('Weekend Sale'), findsOneWidget);

    // A protected action routes to login instead of running.
    await tester.tap(find.widgetWithText(FilledButton, 'Use template').first);
    await tester.pumpAndSettle();
    expect(find.text('LOGIN'), findsOneWidget);
  });
}
