import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialhub/features/auth/presentation/state/current_user_provider.dart';
import 'package:socialhub/features/team/presentation/screens/team_screen.dart';

/// A 401 like the API interceptor surfaces when signed out.
DioException _unauthorized() => DioException(
      requestOptions: RequestOptions(path: '/users/me'),
      response: Response(
        requestOptions: RequestOptions(path: '/users/me'),
        statusCode: 401,
      ),
    );

void main() {
  testWidgets(
    'Team page stays browsable when logged out — content shows, no sign-in wall',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Signed out: the profile fetch 401s.
            currentUserProvider.overrideWith((ref) async => throw _unauthorized()),
          ],
          child: const MaterialApp(home: Scaffold(body: TeamScreen())),
        ),
      );
      await tester.pumpAndSettle();

      // The page renders its real content...
      expect(find.text('Team'), findsOneWidget);
      expect(find.text('Invite teammate'), findsOneWidget);
      // ...and is NOT replaced by a blocking sign-in wall or an access denial.
      expect(find.text('Sign in to continue'), findsNothing);
      expect(find.text('Admins only'), findsNothing);
    },
  );
}
