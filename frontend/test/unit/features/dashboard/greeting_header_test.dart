import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:socialhub/core/auth/app_role.dart';
import 'package:socialhub/core/motion/skeleton.dart';
import 'package:socialhub/features/auth/domain/entities/current_user.dart';
import 'package:socialhub/features/auth/presentation/state/current_user_provider.dart';
import 'package:socialhub/features/dashboard/presentation/widgets/greeting_header.dart';

CurrentUser _user(String email) => CurrentUser(
      id: 'u1',
      email: email,
      role: AppRole.editor,
      orgId: 'o1',
      emailVerified: true,
      mfaEnabled: false,
    );

Widget _host(List<Override> overrides) => ProviderScope(
      overrides: overrides,
      child: const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 500, child: GreetingHeader()),
        ),
      ),
    );

const _greetings = ['Good Morning', 'Good Afternoon', 'Good Evening'];

void main() {
  testWidgets('shows a time-aware greeting, derived name, and today\'s date',
      (tester) async {
    await tester.pumpWidget(_host(<Override>[
      currentUserProvider.overrideWith((ref) async => _user('jane.doe@x.com')),
    ],),);
    await tester.pumpAndSettle();

    // One of the three greetings renders (time-of-day from local clock).
    expect(
      _greetings.any((g) => find.textContaining(g).evaluate().isNotEmpty),
      isTrue,
    );
    // Name derived from the email's first token, capitalized.
    expect(find.text('Jane'), findsOneWidget);
    // Today's date via intl, matching the widget's format.
    expect(
      find.text(DateFormat('EEE, MMM d y').format(DateTime.now())),
      findsOneWidget,
    );
    // A leading accent icon tile is present.
    expect(find.byType(Icon), findsWidgets);
  });

  testWidgets('shows a shimmer (not "null") while the name loads',
      (tester) async {
    final never = Completer<CurrentUser>(); // never completes
    await tester.pumpWidget(_host(<Override>[
      currentUserProvider.overrideWith((ref) => never.future),
    ],),);
    await tester.pump(); // let the loading branch build

    expect(find.byType(Skeleton), findsOneWidget);
    expect(find.textContaining('null'), findsNothing);
    // The greeting word still renders immediately (doesn't wait on the user).
    expect(
      _greetings.any((g) => find.textContaining(g).evaluate().isNotEmpty),
      isTrue,
    );
  });

  testWidgets('falls back to a neutral name on error', (tester) async {
    await tester.pumpWidget(_host(<Override>[
      currentUserProvider.overrideWith((ref) async => throw Exception('boom')),
    ],),);
    await tester.pumpAndSettle();

    expect(find.text('there'), findsOneWidget);
    expect(find.textContaining('null'), findsNothing);
  });
}
