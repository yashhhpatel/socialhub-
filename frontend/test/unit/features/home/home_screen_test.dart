import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:socialhub/features/home/presentation/screens/home_screen.dart';

GoRouter _router() => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(
            body: SingleChildScrollView(child: HomeScreen()),
          ),
        ),
        GoRoute(path: '/register', builder: (_, __) => _marker('REGISTER')),
        GoRoute(path: '/login', builder: (_, __) => _marker('LOGIN')),
        GoRoute(path: '/dashboard', builder: (_, __) => _marker('DASHBOARD')),
        GoRoute(path: '/content', builder: (_, __) => _marker('CONTENT')),
        GoRoute(path: '/calendar', builder: (_, __) => _marker('CALENDAR')),
      ],
    );

Widget _marker(String t) => Scaffold(body: Center(child: Text(t)));

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1400, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp.router(routerConfig: _router()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders the hero, platforms, and features', (tester) async {
    await _pump(tester);

    // Two-colour headline (a RichText of two spans) + primary CTAs.
    expect(
      find.textContaining('Publish everywhere', findRichText: true),
      findsWidgets,
    );
    expect(find.text('Get started free'), findsWidgets);
    expect(find.text('Explore the app'), findsOneWidget);

    // Supported platforms strip (shared PlatformStyle labels). skipOffstage
    // is off because the page is one long non-lazy scroll view.
    expect(find.text('Instagram', skipOffstage: false), findsWidgets);
    expect(find.text('LinkedIn', skipOffstage: false), findsWidgets);

    // Feature cards.
    expect(
      find.text('Composer & carousels', skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.text('Visual scheduling', skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.text('Cross-platform analytics', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('primary CTA routes to Sign up (register)', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Get started free').first);
    await tester.pumpAndSettle();
    expect(find.text('REGISTER'), findsOneWidget);
  });

  testWidgets('"Explore the app" routes into the product (dashboard)',
      (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Explore the app'));
    await tester.pumpAndSettle();
    expect(find.text('DASHBOARD'), findsOneWidget);
  });

  testWidgets('a feature card links into its real page', (tester) async {
    await _pump(tester);
    await tester.ensureVisible(find.text('Composer & carousels'));
    await tester.tap(find.text('Composer & carousels'));
    await tester.pumpAndSettle();
    expect(find.text('CONTENT'), findsOneWidget);
  });
}
