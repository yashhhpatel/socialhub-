/// Represents an authenticated user session.
///
/// Field names mirror the backend's AuthResponseDto (see
/// docs/api/SocialHub_REST_API_Design.md, §2) so swapping the mock
/// repository for the real one in Milestone 1.4 requires no shape changes
/// here.
class AuthSession {
  const AuthSession({
    required this.userId,
    required this.email,
    required this.role,
    required this.orgId,
    required this.accessToken,
    required this.refreshToken,
  });

  final String userId;
  final String email;
  final String role;
  final String orgId;
  final String accessToken;
  final String refreshToken;
}
