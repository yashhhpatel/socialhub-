import 'package:flutter_test/flutter_test.dart';
import 'package:socialhub/core/router/route_guards.dart';

void main() {
  group('authRedirect', () {
    test('unauthenticated user hitting /dashboard is bounced to /login', () {
      final result = authRedirect(
        matchedLocation: '/dashboard',
        isAuthenticated: false,
      );
      expect(result, '/login');
    });

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

    test('authenticated user hitting /dashboard is NOT redirected', () {
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

    test('unauthenticated user hitting the neutral root is NOT redirected', () {
      final result = authRedirect(
        matchedLocation: '/',
        isAuthenticated: false,
      );
      expect(result, isNull);
    });

    test('authenticated user hitting the neutral root is NOT redirected', () {
      final result = authRedirect(
        matchedLocation: '/',
        isAuthenticated: true,
      );
      expect(result, isNull);
    });
  });
}
