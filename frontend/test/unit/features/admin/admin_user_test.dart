import 'package:flutter_test/flutter_test.dart';
import 'package:socialhub/features/admin/domain/admin_user.dart';

void main() {
  test('AdminUserList parses + derives sign-in method', () {
    final list = AdminUserList.fromJson({
      'total': 3,
      'page': 1,
      'limit': 20,
      'data': [
        {
          'id': 'u1',
          'email': 'a@b.com',
          'role': 'owner',
          'orgId': 'o1',
          'orgName': 'Acme',
          'emailVerified': true,
          'mfaEnabled': false,
          'isPlatformAdmin': true,
          'hasPassword': false,
          'hasGoogle': true,
          'createdAt': '2026-08-01T00:00:00.000Z',
        },
      ],
    });
    final u = list.data.single;
    expect(u.signInMethod, 'Google');
    expect(u.isPlatformAdmin, isTrue);
    expect(list.totalPages, 1);
  });

  test('sign-in method covers password / both / none', () {
    AdminUserListItem make({required bool pw, required bool g}) =>
        AdminUserListItem.fromJson({
          'id': 'x',
          'email': 'e',
          'role': 'r',
          'orgId': 'o',
          'orgName': 'n',
          'emailVerified': false,
          'mfaEnabled': false,
          'isPlatformAdmin': false,
          'hasPassword': pw,
          'hasGoogle': g,
          'createdAt': '',
        });
    expect(make(pw: true, g: false).signInMethod, 'Password');
    expect(make(pw: true, g: true).signInMethod, 'Google + password');
    expect(make(pw: false, g: false).signInMethod, '—');
  });
}
