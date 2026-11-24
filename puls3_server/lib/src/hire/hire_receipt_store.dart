import 'package:serverpod/serverpod.dart' show Transaction;

/// The `state` of a receipt line before its child job exists. Once the
/// `create_child_job` is confirmed the line carries the child's `HireStatus`
/// name instead (`open`, `funded`, ...), as `hire_receipt_line.spy.yaml` says.
abstract final class ReceiptLineState {
  /// The child hire is stored and its `create_child_job` is signed and
  /// submitted, not confirmed yet.
  static const pending = 'pending';

  /// The `create_child_job` definitely did not land: the child was never
  /// opened and nothing was drawn from the reserve.
  static const notOpened = 'not_opened';

  /// The `create_child_job` may have landed but could not be proven to be
  /// this child: its events did not match the stored child, the job was
  /// bound elsewhere, its events never showed up, or the node lost the
  /// transaction past its retention. The child hire stays unfunded and never
  /// runs until `UnverifiedChildReconciler` finds its job on the chain or
  /// proves it never landed (T6.4.4).
  static const unverified = 'unverified';

  /// The child `HireStatus` names of an opened line that is not settled
  /// yet; [HireReceiptStore.markSettled] only moves these.
  static const unsettled = {'open', 'funded', 'submitted'};
}

/// A receipt line to persist (ADR-0011 D6): one child job of a parent hire.
final class NewReceiptLine {
  const NewReceiptLine({
    required this.parentHireId,
    required this.childHireId,
    required this.providerAgentId,
    required this.providerWallet,
    required this.budget,
    required this.relatedParty,
    required this.justification,
    this.state = ReceiptLineState.pending,
    this.createTransaction,
  });

  final int parentHireId;
  final int childHireId;

  /// Registry id of the subcontracted agent.
  final int providerAgentId;

  /// StrKey of the subcontracted agent's payment wallet.
  final String providerWallet;

  /// USDC stroops drawn from the parent reserve.
  final int budget;
  final bool relatedParty;

  /// The parent agent's reason for the pick (D10).
  final String justification;
  final String state;

  /// The `create_child_job` transaction hash, lowercase hex.
  final String? createTransaction;
}

/// A stored receipt line. Settlement fields (fee, payout, deliverable and
/// settle transaction) are written by the verdict and the tracker (T6.3).
final class ReceiptLine {
  const ReceiptLine({
    required this.id,
    required this.parentHireId,
    required this.childHireId,
    required this.childJobId,
    required this.providerAgentId,
    required this.providerWallet,
    required this.budget,
    required this.state,
    required this.createTransaction,
    required this.relatedParty,
    required this.justification,
    required this.createdAt,
    this.fee,
    this.payout,
    this.deliverableHash,
    this.settleTransaction,
  });

  final int id;
  final int parentHireId;
  final int? childHireId;
  final int? childJobId;
  final int providerAgentId;
  final String providerWallet;
  final int budget;
  final String state;
  final String? createTransaction;
  final bool relatedParty;
  final String justification;
  final DateTime createdAt;

  /// USDC stroops of platform fee and of provider payout, once settled: the
  /// `JobCompleted` amounts of a complete, 0 for a reject.
  final int? fee;
  final int? payout;

  /// The child's deliverable hash, lowercase hex, once its verdict is sent.
  final String? deliverableHash;

  /// The transaction that settled the child, lowercase hex.
  final String? settleTransaction;
}

/// The itemized receipt of parent hires, on `hire_receipt_line`.
abstract interface class HireReceiptStore {
  /// Runs [body] in one database transaction and commits it when [body]
  /// returns. Any exception rolls back every write made with the given
  /// transaction and is rethrown. An implementation without a database may
  /// pass `null`.
  Future<T> inTransaction<T>(Future<T> Function(Transaction? transaction) body);

  /// Stores [line] and returns it. Joins [transaction] when given.
  Future<ReceiptLine> insert(NewReceiptLine line, {Transaction? transaction});

  /// The line of [childHireId], or `null`.
  Future<ReceiptLine?> findByChildHire(int childHireId);

  /// Every line of [parentHireId], oldest first (by id).
  Future<List<ReceiptLine>> listByParent(int parentHireId);

  /// Every opened line that is not settled yet ([ReceiptLineState.unsettled]),
  /// oldest first (by id), across parents. These are the live child jobs.
  /// The set stays small, because each one settles by its deadline at the
  /// latest.
  Future<List<ReceiptLine>> listUnsettled();

  /// Every line whose child job is not opened yet, [ReceiptLineState.pending]
  /// or [ReceiptLineState.unverified], oldest first (by id), across parents.
  Future<List<ReceiptLine>> listUnopened();

  /// Sets the line of [childHireId] back to [ReceiptLineState.pending] while
  /// it is [ReceiptLineState.unverified], so that reconciliation can open it
  /// or mark it [ReceiptLineState.notOpened] through the usual pending-only
  /// writes (T6.4.4). One conditional write; returns whether it changed the
  /// line.
  Future<bool> reopenUnverified(int childHireId);

  /// Sets the line of [childHireId] to [ReceiptLineState.notOpened] while it
  /// is still [ReceiptLineState.pending]. One conditional write; returns
  /// whether it changed the line.
  Future<bool> markNotOpened(int childHireId);

  /// Sets the line of [childHireId] to [ReceiptLineState.unverified] while
  /// it is still [ReceiptLineState.pending]. One conditional write; returns
  /// whether it changed the line.
  Future<bool> markUnverified(int childHireId);

  /// Records the confirmed child job on the line of [childHireId] while it is
  /// still [ReceiptLineState.pending]: its [childJobId], its
  /// [createTransaction] and the child's status name as [state]. One
  /// conditional write; returns whether it changed the line. Joins
  /// [transaction] when given.
  Future<bool> markOpened(
    int childHireId, {
    required int childJobId,
    required String createTransaction,
    required String state,
    Transaction? transaction,
  });

  /// Sets the deliverable hash of the line of [childHireId] while it has
  /// none. One conditional write; returns whether it changed the line.
  /// Joins [transaction] when given.
  Future<bool> recordDeliverable(
    int childHireId,
    String deliverableHash, {
    Transaction? transaction,
  });

  /// Records the child's settlement on the line of [childHireId] while it is
  /// opened and unsettled ([ReceiptLineState.unsettled]): [state] (the
  /// child's `HireStatus` name), [fee], [payout] and the
  /// [settleTransaction]. One conditional write; returns whether it changed
  /// the line.
  Future<bool> markSettled(
    int childHireId, {
    required String state,
    required int? fee,
    required int? payout,
    required String settleTransaction,
  });
}
