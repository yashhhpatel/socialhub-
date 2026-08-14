import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialhub/core/auth/app_role.dart';
import 'package:socialhub/features/auth/domain/entities/current_user.dart';
import 'package:socialhub/features/auth/presentation/state/current_user_provider.dart';
import 'package:socialhub/features/collaboration/data/repositories/api_collaboration_repository.dart';
import 'package:socialhub/features/collaboration/domain/entities/approval_status.dart';
import 'package:socialhub/features/collaboration/domain/entities/comment.dart';
import 'package:socialhub/features/collaboration/presentation/widgets/approval_bar.dart';
import 'package:socialhub/features/collaboration/presentation/widgets/comments_drawer.dart';

CurrentUser _user(AppRole role) =>
    CurrentUser(id: 'u1', email: 'me@ex.com', role: role, orgId: 'org_1');

Comment _comment(String body) => Comment(
      id: body,
      body: body,
      authorEmail: 'a@ex.com',
      createdAt: DateTime.utc(2026, 8, 14, 9),
    );

Future<void> _pump(WidgetTester tester, Widget child, List<Override> overrides) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
}

void main() {
  testWidgets('comment thread renders the fetched comments', (tester) async {
    await _pump(
      tester,
      const CommentsDrawer(assetId: 'asset_1'),
      [
        commentsProvider('asset_1').overrideWith(
          (ref) async => [_comment('First pass looks good'), _comment('Fix the CTA')],
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Comments'), findsOneWidget);
    expect(find.text('First pass looks good'), findsOneWidget);
    expect(find.text('Fix the CTA'), findsOneWidget);
  });

  testWidgets('an admin sees Approve/Reject on a pending design', (tester) async {
    await _pump(
      tester,
      const ApprovalBar(assetId: 'asset_1'),
      [
        currentUserProvider.overrideWith((ref) async => _user(AppRole.admin)),
        approvalStatusProvider('asset_1')
            .overrideWith((ref) async => ApprovalStatus.pendingApproval),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Pending approval'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
  });

  testWidgets('an editor does NOT see Approve/Reject on a pending design', (tester) async {
    await _pump(
      tester,
      const ApprovalBar(assetId: 'asset_1'),
      [
        currentUserProvider.overrideWith((ref) async => _user(AppRole.editor)),
        approvalStatusProvider('asset_1')
            .overrideWith((ref) async => ApprovalStatus.pendingApproval),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Approve'), findsNothing);
    expect(find.text('Reject'), findsNothing);
  });

  testWidgets('a draft shows Submit for approval to an editor', (tester) async {
    await _pump(
      tester,
      const ApprovalBar(assetId: 'asset_1'),
      [
        currentUserProvider.overrideWith((ref) async => _user(AppRole.editor)),
        approvalStatusProvider('asset_1').overrideWith((ref) async => ApprovalStatus.draft),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Submit for approval'), findsOneWidget);
  });
}
