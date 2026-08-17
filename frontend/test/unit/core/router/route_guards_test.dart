import 'package:flutter_test/flutter_test.dart';
import 'package:socialhub/core/router/route_guards.dart';

void main() {
  group('authRedirect', () {
    test(
      'unauthenticated user can browse a would-be-protected page without being '
      'bounced (access is gated at the point of use, not on navigation)',
      () {
        expect(
          authRedirect(matchedLocation: '/dashboard', isAuthenticated: false),
          isNull,
        );
        expect(
          authRedirect(matchedLocation: '/content', isAuthenticated: false),
          isNull,
        );
        expect(
          authRedirect(matchedLocation: '/team', isAuthenticated: false),
          isNull,
        );
        expect(
          authRedirect(matchedLocation: '/settings', isAuthenticated: false),
          isNull,
        );
      },
    );

    test('authenticated user hitting /login is bounced to /dashboard', () {
      final result = authRedirect(
        matchedLocation: '/login',
        isAuthenticated: true,
      );
      expect(result, '/dashboard');
    });

    test('authenticated user hitting /register is bounced to /dashboard', () {
      final result = authRedirect(
        matchedLocation: '/register',
        isAuthenticated: true,
      );
      expect(result, '/dashboard');
    });

    test('authenticated user hitting a normal page is NOT redirected', () {
      final result = authRedirect(
        matchedLocation: '/dashboard',
        isAuthenticated: true,
      );
      expect(result, isNull);
    });

    test('unauthenticated user hitting /login is NOT redirected', () {
      final result = authRedirect(
        matchedLocation: '/login',
        isAuthenticated: false,
      );
      expect(result, isNull);
    });

    test('unauthenticated user hitting the root is NOT redirected', () {
      final result = authRedirect(
        matchedLocation: '/',
        isAuthenticated: false,
      );
      expect(result, isNull);
    });

    test('authenticated user hitting the root is NOT redirected by the guard', () {
      final result = authRedirect(
        matchedLocation: '/',
        isAuthenticated: true,
      );
      expect(result, isNull);
    });
  });
}
