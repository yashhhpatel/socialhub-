import 'package:flutter_test/flutter_test.dart';
import 'package:socialhub/core/auth/app_role.dart';

void main() {
  group('AppRole', () {
    test('ranks owner > admin > editor > viewer', () {
      expect(AppRole.owner.rank, greaterThan(AppRole.admin.rank));
      expect(AppRole.admin.rank, greaterThan(AppRole.editor.rank));
      expect(AppRole.editor.rank, greaterThan(AppRole.viewer.rank));
    });

    test('isAtLeast implements the "X+" threshold', () {
      expect(AppRole.admin.isAtLeast(AppRole.admin), isTrue);
      expect(AppRole.owner.isAtLeast(AppRole.admin), isTrue);
      expect(AppRole.editor.isAtLeast(AppRole.admin), isFalse);
      expect(AppRole.viewer.isAtLeast(AppRole.editor), isFalse);
    });

    test('fromApi round-trips known roles', () {
      for (final r in AppRole.values) {
        expect(AppRoleX.fromApi(r.apiValue), r);
      }
    });

    test('fromApi falls back to the least-privileged role on garbage', () {
      // Fail closed: an unknown role must never grant elevated access.
      expect(AppRoleX.fromApi('superadmin'), AppRole.viewer);
    });
  });
}
