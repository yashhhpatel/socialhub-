import '../entities/account_action_result.dart';

/// Account-lifecycle actions that sit alongside auth but don't issue a session
/// (Phase 17.1). Kept separate from [AuthRepository] — which owns the
/// login/register/logout session flow — so the screens for these public flows
/// depend only on what they need.
abstract class AccountRepository {
  /// Confirms an emailed verification token. PUBLIC — the user may not be
  /// signed in when they click the link.
  Future<AccountActionResult> verifyEmail(String token);

  /// Requests a password-reset link. Always reports success (the backend never
  /// reveals whether the email is registered), so the message is generic.
  Future<AccountActionResult> requestPasswordReset(String email);

  /// Sets a new password using an emailed reset token.
  Future<AccountActionResult> resetPassword({
    required String token,
    required String newPassword,
  });

  /// Re-sends the verification email to the currently signed-in user.
  Future<AccountActionResult> resendVerification();
}
