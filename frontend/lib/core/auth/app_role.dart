/// The four org roles, mirroring the backend's `UserRole` enum
/// (owner > admin > editor > viewer). The single client-side source of
/// truth for "X+" permission checks, matching backend/common/role-rank.ts.
enum AppRole { viewer, editor, admin, owner }

extension AppRoleX on AppRole {
  /// Higher outranks lower — same ordering as the backend's ROLE_RANK.
  int get rank => switch (this) {
        AppRole.viewer => 0,
        AppRole.editor => 1,
        AppRole.admin => 2,
        AppRole.owner => 3,
      };

  bool isAtLeast(AppRole minimum) => rank >= minimum.rank;

  String get label => switch (this) {
        AppRole.viewer => 'Viewer',
        AppRole.editor => 'Editor',
        AppRole.admin => 'Admin',
        AppRole.owner => 'Owner',
      };

  /// The exact string the backend expects/returns.
  String get apiValue => name;

  /// Unknown/garbled values fall back to the least-privileged role, so a
  /// gate can only ever err toward hiding something, never revealing it.
  static AppRole fromApi(String value) => AppRole.values.firstWhere(
        (r) => r.name == value,
        orElse: () => AppRole.viewer,
      );
}
