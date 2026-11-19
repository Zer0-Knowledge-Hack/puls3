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
/// settle transaction) are written by the tracker and the verdict (T6.2,
/// T6.3); this view carries what the subcontract executor reads.
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

  /// Sets the line of [childHireId] to [ReceiptLineState.notOpened] while it
  /// is still [ReceiptLineState.pending]. One conditional write; returns
  /// whether it changed the line.
  Future<bool> markNotOpened(int childHireId);
}
