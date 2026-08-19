/// Outcome of an account-lifecycle action (Phase 17.1): email verification,
/// password-reset request, password reset, resend verification.
///
/// Unlike [AuthResult] these actions don't produce a session — they either
/// succeed (optionally with a message to show) or fail with a user-facing
/// message. Kept as a small feature-local type for the same reasons AuthResult
/// is (see auth_result.dart).
class AccountActionResult {
  const AccountActionResult._({required this.ok, this.message});

  factory AccountActionResult.success([String? message]) =>
      AccountActionResult._(ok: true, message: message);

  factory AccountActionResult.failure(String message) =>
      AccountActionResult._(ok: false, message: message);

  final bool ok;
  final String? message;
}
