import 'package:flutter_test/flutter_test.dart';
import 'package:socialhub/core/layout/nav_menu_data.dart';

void main() {
  group('navMenu', () {
    test('leads with Home (/) then Dashboard as distinct destinations', () {
      expect(navMenu.first.label, 'Home');
      expect(navMenu.first.path, '/');
      expect(navMenu[1].label, 'Dashboard');
      expect(navMenu[1].path, '/dashboard');
    });

    test('order is Home | Dashboard | Create | Calendar | Analytics | Workspace',
        () {
      expect(
        navMenu.map((c) => c.label).toList(),
        ['Home', 'Dashboard', 'Create', 'Calendar', 'Analytics', 'Workspace'],
      );
    });

    test('Home and Dashboard are direct links, not dropdowns', () {
      expect(navMenu.first.isDropdown, isFalse);
      expect(navMenu[1].isDropdown, isFalse);
    });
  });
}
