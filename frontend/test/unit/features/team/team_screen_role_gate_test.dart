import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialhub/core/auth/app_role.dart';
import 'package:socialhub/features/auth/domain/entities/current_user.dart';
import 'package:socialhub/features/auth/presentation/state/current_user_provider.dart';
import 'package:socialhub/features/team/domain/entities/team_member.dart';
import 'package:socialhub/features/team/presentation/screens/team_screen.dart';
import 'package:socialhub/features/team/presentation/state/team_controller.dart';

CurrentUser _user(AppRole role) =>
    CurrentUser(id: 'u1', email: 'me@ex.com', role: role, orgId: 'org_1', emailVerified: true);

Future<void> _pump(WidgetTester tester, AppRole role) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) async => _user(role)),
        teamMembersProvider.overrideWith(
          (ref) async => const [
            TeamMember(id: 'u1', email: 'me@ex.com', role: AppRole.owner),
            TeamMember(id: 'u2', email: 'ed@ex.com', role: AppRole.editor),
          ],
        ),
        teamInvitesProvider.overrideWith((ref) async => const <TeamInvite>[]),
      ],
      child: const MaterialApp(home: Scaffold(body: TeamScreen())),
    ),
  );
}

void main() {
  testWidgets('an admin sees the roster and the invite action', (tester) async {
    await _pump(tester, AppRole.admin);
    await tester.pumpAndSettle();

    expect(find.text('Invite teammate'), findsOneWidget);
    expect(find.text('MEMBERS'), findsOneWidget); // section header is uppercased
    expect(find.text('ed@ex.com'), findsOneWidget);
    expect(find.text('Admins only'), findsNothing);
  });

  testWidgets('an editor is shown the access-denied state, not the controls',
      (tester) async {
    await _pump(tester, AppRole.editor);
    await tester.pumpAndSettle();

    expect(find.text('Admins only'), findsOneWidget);
    expect(find.text('Invite teammate'), findsNothing);
    // The roster/mutation controls are never built for a non-admin.
    expect(find.text('MEMBERS'), findsNothing);
  });

  testWidgets('a viewer is also denied', (tester) async {
    await _pump(tester, AppRole.viewer);
    await tester.pumpAndSettle();
    expect(find.text('Admins only'), findsOneWidget);
    expect(find.text('Invite teammate'), findsNothing);
  });
}
