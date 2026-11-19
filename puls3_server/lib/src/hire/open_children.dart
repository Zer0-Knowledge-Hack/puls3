import 'package:puls3_domain/puls3_domain.dart' show HireStatus;

import 'hire_lifecycle_store.dart';
import 'hire_receipt_store.dart';

/// Child hire statuses after which the child no longer counts toward the
/// parent's `open_children` (ADR-0011 D3).
const _settled = {
  HireStatus.completed,
  HireStatus.rejected,
  HireStatus.expired,
};

/// Whether a parent hire still has an open child job, so its `submit` would
/// be refused with `ChildrenOpen` (ADR-0011 D4).
///
/// A child is closed when its line is [ReceiptLineState.notOpened] or its
/// hire is completed, rejected or expired (from the confirmed submissions of
/// the child hire, so a `release` or `claim_refund` by the deadline relay
/// counts too). Every other child is open: a `pending` or `unverified` line
/// may hide a landed `create_child_job`.
final class OpenChildren {
  const OpenChildren({
    required HireReceiptStore receipts,
    required HireLifecycleStore hires,
  }) : _receipts = receipts,
       _hires = hires;

  final HireReceiptStore _receipts;
  final HireLifecycleStore _hires;

  /// Whether hire [parentHireId] has a child that is not closed.
  Future<bool> anyOpen(int parentHireId) async {
    for (final line in await _receipts.listByParent(parentHireId)) {
      if (line.state == ReceiptLineState.notOpened) continue;
      final childHireId = line.childHireId;
      if (childHireId == null) return true;
      final status = (await _hires.findHire(childHireId))?.status;
      if (!_settled.contains(status)) return true;
    }
    return false;
  }
}
