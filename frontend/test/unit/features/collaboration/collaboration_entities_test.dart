import 'package:flutter_test/flutter_test.dart';
import 'package:socialhub/features/collaboration/domain/entities/approval_status.dart';
import 'package:socialhub/features/collaboration/domain/entities/comment.dart';

void main() {
  group('Comment.fromJson', () {
    test('parses body, author and timestamp', () {
      final c = Comment.fromJson({
        'id': 'c1',
        'body': 'Looks great',
        'authorEmail': 'a@ex.com',
        'createdAt': '2026-08-14T09:00:00.000Z',
      });
      expect(c.body, 'Looks great');
      expect(c.authorEmail, 'a@ex.com');
      expect(c.createdAt, DateTime.parse('2026-08-14T09:00:00.000Z'));
    });
  });

  group('ApprovalStatus mapping', () {
    test('round-trips every status through apiValue', () {
      for (final s in ApprovalStatus.values) {
        expect(ApprovalStatusX.fromApi(s.apiValue), s);
      }
    });

    test('pending_approval maps to the enum and a friendly label', () {
      expect(ApprovalStatusX.fromApi('pending_approval'), ApprovalStatus.pendingApproval);
      expect(ApprovalStatus.pendingApproval.label, 'Pending approval');
    });

    test('fails closed to draft on an unknown value', () {
      expect(ApprovalStatusX.fromApi('nonsense'), ApprovalStatus.draft);
    });

    test('isApproved is only true for approved', () {
      expect(ApprovalStatus.approved.isApproved, isTrue);
      expect(ApprovalStatus.pendingApproval.isApproved, isFalse);
    });
  });
}
