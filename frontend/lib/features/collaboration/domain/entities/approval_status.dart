/// Mirrors the backend ApprovalStatus enum. `apiValue` is the exact wire
/// string (snake_case), so it round-trips through the REST API unchanged.
enum ApprovalStatus { draft, pendingApproval, approved, rejected }

extension ApprovalStatusX on ApprovalStatus {
  String get apiValue => switch (this) {
        ApprovalStatus.draft => 'draft',
        ApprovalStatus.pendingApproval => 'pending_approval',
        ApprovalStatus.approved => 'approved',
        ApprovalStatus.rejected => 'rejected',
      };

  String get label => switch (this) {
        ApprovalStatus.draft => 'Draft',
        ApprovalStatus.pendingApproval => 'Pending approval',
        ApprovalStatus.approved => 'Approved',
        ApprovalStatus.rejected => 'Rejected',
      };

  bool get isApproved => this == ApprovalStatus.approved;

  /// Unknown values fall back to draft — the least-privileged, "nothing has
  /// happened yet" state, so a garbled value never reads as approved.
  static ApprovalStatus fromApi(String value) => switch (value) {
        'draft' => ApprovalStatus.draft,
        'pending_approval' => ApprovalStatus.pendingApproval,
        'approved' => ApprovalStatus.approved,
        'rejected' => ApprovalStatus.rejected,
        _ => ApprovalStatus.draft,
      };
}
