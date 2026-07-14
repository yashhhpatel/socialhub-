/// Redirect decision logic, extracted from the route table itself, per
/// docs/architecture — Flutter Web Application Architecture, §4
/// (Routing).
///
/// Built ahead of its originally-planned position (the blueprint deferred
/// this until a real protected route existed) at explicit request, once
/// the lack of ANY authenticated destination made the placeholder screen
/// at '/' read as a login-redirect bug rather than what it actually was:
/// nowhere to land after a successful login.
///
/// Intentionally minimal — two rules only:
/// - Not authenticated + hitting a protected route -> bounce to /login.
/// - Authenticated + hitting /login or /register -> bounce to /dashboard
///   (skip showing the login form to someone already signed in).
///
/// A pure function (location + bool in, redirect target or null out) so
/// it's testable without spinning up a GoRouter/widget tree at all.
String? authRedirect({
  required String matchedLocation,
  required bool isAuthenticated,
}) {
  const authRoutes = {'/login', '/register'};
  const protectedRoutes = {'/dashboard'};

  if (!isAuthenticated && protectedRoutes.contains(matchedLocation)) {
    return '/login';
  }

  if (isAuthenticated && authRoutes.contains(matchedLocation)) {
    return '/dashboard';
  }

  return null;
}
