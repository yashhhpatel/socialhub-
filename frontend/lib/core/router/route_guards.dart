/// Redirect decision logic, extracted from the route table itself, per
/// docs/architecture — Flutter Web Application Architecture, §4
/// (Routing).
///
/// The whole app is browsable without an account: an unauthenticated visitor
/// is NEVER bounced away from a page just for navigating to it. Access is
/// instead gated at the point of *use* — a request that needs an account
/// (see AuthInterceptor) routes the user to /login when they try to act.
///
/// So this leaves exactly one rule:
/// - Authenticated + hitting /login or /register -> bounce to /dashboard
///   (an already-signed-in user has no reason to see the auth screens).
///
/// A pure function (location + bool in, redirect target or null out) so
/// it's testable without spinning up a GoRouter/widget tree at all.
String? authRedirect({
  required String matchedLocation,
  required bool isAuthenticated,
}) {
  const authRoutes = {'/login', '/register'};

  if (isAuthenticated && authRoutes.contains(matchedLocation)) {
    return '/dashboard';
  }

  return null;
}
