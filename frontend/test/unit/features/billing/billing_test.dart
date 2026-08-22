import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialhub/core/auth/app_role.dart';
import 'package:socialhub/features/auth/domain/entities/current_user.dart';
import 'package:socialhub/features/auth/presentation/state/current_user_provider.dart';
import 'package:socialhub/features/billing/data/api_billing_repository.dart';
import 'package:socialhub/features/billing/domain/billing_overview.dart';
import 'package:socialhub/features/billing/presentation/screens/billing_screen.dart';

Map<String, dynamic> _overviewJson({
  String tier = 'free',
  String status = 'none',
  bool configured = true,
}) =>
    {
      'planTier': tier,
      'status': status,
      'currentPeriodEnd': null,
      'cancelAtPeriodEnd': false,
      'hasBillingAccount': false,
      'billingConfigured': configured,
      'limits': {
        'maxSocialAccounts': 2,
        'maxTeamMembers': 2,
        'aiCreditsPerMonth': 50,
        'maxScheduledPosts': 10,
      },
      'usage': {'socialAccounts': 1, 'teamMembers': 1, 'aiCreditsUsed': 10},
      'invoices': <dynamic>[],
    };

CurrentUser _user(AppRole role) => CurrentUser(
      id: 'u1',
      email: 'me@ex.com',
      role: role,
      orgId: 'org_1',
      emailVerified: true,
      mfaEnabled: false,
    );

Widget _host({required List<Override> overrides}) => ProviderScope(
      overrides: overrides,
      // Mirror AppShell, which hosts every screen inside a scroll view — the
      // billing page is taller than a bare test viewport.
      child: const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: BillingScreen())),
      ),
    );

void main() {
  group('BillingOverview.fromJson', () {
    test('parses plan, limits, usage, and past-due status', () {
      final o = BillingOverview.fromJson(
        _overviewJson(tier: 'pro', status: 'pastDue'),
      );
      expect(o.planTier, 'pro');
      expect(o.isPastDue, isTrue);
      expect(o.limits.maxSocialAccounts, 2);
      expect(o.usage.socialAccounts, 1);
    });

    test('treats -1 limits as unlimited (enterprise)', () {
      final json = _overviewJson(tier: 'enterprise');
      (json['limits'] as Map)['maxSocialAccounts'] = -1;
      final o = BillingOverview.fromJson(json);
      expect(o.limits.maxSocialAccounts, -1);
    });
  });

  group('BillingScreen', () {
    testWidgets('renders current plan, usage, and plans', (tester) async {
      final overrides = <Override>[
        billingOverviewProvider.overrideWith(
          (ref) async => BillingOverview.fromJson(_overviewJson(tier: 'free')),
        ),
        currentUserProvider.overrideWith((ref) async => _user(AppRole.admin)),
      ];
      await tester.pumpWidget(_host(overrides: overrides));
      await tester.pumpAndSettle();

      expect(find.text('Billing'), findsOneWidget);
      expect(find.text('Current plan'), findsOneWidget);
      expect(find.text('Usage'), findsOneWidget);
      expect(find.text('Connected accounts'), findsOneWidget);
      // Plan cards present.
      expect(find.text('Starter'), findsOneWidget);
      expect(find.text('Pro'), findsOneWidget);
      // Admin on a configured server sees enabled Upgrade actions.
      expect(find.widgetWithText(FilledButton, 'Upgrade'), findsWidgets);
    });

    testWidgets('non-admins do not get enabled upgrade buttons',
        (tester) async {
      final overrides = <Override>[
        billingOverviewProvider.overrideWith(
          (ref) async => BillingOverview.fromJson(_overviewJson(tier: 'free')),
        ),
        currentUserProvider.overrideWith((ref) async => _user(AppRole.editor)),
      ];
      await tester.pumpWidget(_host(overrides: overrides));
      await tester.pumpAndSettle();

      // Upgrade buttons render but are disabled (onPressed == null) for editors.
      final upgrades = tester.widgetList<FilledButton>(
        find.widgetWithText(FilledButton, 'Upgrade'),
      );
      expect(upgrades, isNotEmpty);
      expect(upgrades.every((b) => b.onPressed == null), isTrue);
    });

    testWidgets('shows the past-due dunning banner', (tester) async {
      final overrides = <Override>[
        billingOverviewProvider.overrideWith(
          (ref) async =>
              BillingOverview.fromJson(_overviewJson(tier: 'pro', status: 'pastDue')),
        ),
        currentUserProvider.overrideWith((ref) async => _user(AppRole.admin)),
      ];
      await tester.pumpWidget(_host(overrides: overrides));
      await tester.pumpAndSettle();

      expect(find.textContaining('last payment failed'), findsOneWidget);
    });

    testWidgets('logged out (401): plans stay visible, actions gated',
        (tester) async {
      final overrides = <Override>[
        billingOverviewProvider.overrideWith(
          (ref) async => throw DioException(
            requestOptions: RequestOptions(path: '/billing'),
            response: Response(
              requestOptions: RequestOptions(path: '/billing'),
              statusCode: 401,
            ),
          ),
        ),
        // Value is irrelevant here — the 401 branch renders the logged-out
        // billing view regardless of role.
        currentUserProvider.overrideWith((ref) async => _user(AppRole.viewer)),
      ];
      await tester.pumpWidget(_host(overrides: overrides));
      await tester.pumpAndSettle();

      // Page + plans remain visible when logged out.
      expect(find.text('Billing'), findsOneWidget);
      expect(find.textContaining('Log in to manage your plan'), findsOneWidget);
      expect(find.text('Starter'), findsOneWidget);
      expect(find.text('Pro'), findsOneWidget);
      expect(find.text('Enterprise'), findsOneWidget);
      // Upgrade buttons are present and enabled (a tap routes to login).
      final upgrades = tester.widgetList<FilledButton>(
        find.widgetWithText(FilledButton, 'Upgrade'),
      );
      expect(upgrades, isNotEmpty);
      expect(upgrades.every((b) => b.onPressed != null), isTrue);
    });
  });
}
