import 'package:puls3_server/src/hire/hire_receipt_store.dart';
import 'package:serverpod/serverpod.dart' show Transaction;

/// In-memory [HireReceiptStore]. [inTransaction] snapshots the lines and
/// restores them when the body throws, and passes a `null` transaction.
class InMemoryHireReceiptStore implements HireReceiptStore {
  InMemoryHireReceiptStore({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  var _lines = <ReceiptLine>[];
  var _nextId = 1;

  /// Every stored line, in insertion order.
  List<ReceiptLine> get all => List.unmodifiable(_lines);

  @override
  Future<T> inTransaction<T>(
    Future<T> Function(Transaction? transaction) body,
  ) async {
    final snapshot = List.of(_lines);
    try {
      return await body(null);
    } catch (_) {
      _lines = snapshot;
      rethrow;
    }
  }

  @override
  Future<ReceiptLine> insert(
    NewReceiptLine line, {
    Transaction? transaction,
  }) async {
    final stored = ReceiptLine(
      id: _nextId++,
      parentHireId: line.parentHireId,
      childHireId: line.childHireId,
      childJobId: null,
      providerAgentId: line.providerAgentId,
      providerWallet: line.providerWallet,
      budget: line.budget,
      state: line.state,
      createTransaction: line.createTransaction,
      relatedParty: line.relatedParty,
      justification: line.justification,
      createdAt: _now().toUtc(),
    );
    _lines.add(stored);
    return stored;
  }

  @override
  Future<ReceiptLine?> findByChildHire(int childHireId) async {
    for (final line in _lines) {
      if (line.childHireId == childHireId) return line;
    }
    return null;
  }

  @override
  Future<List<ReceiptLine>> listByParent(int parentHireId) async => [
    for (final line in _lines)
      if (line.parentHireId == parentHireId) line,
  ];

  @override
  Future<List<ReceiptLine>> listUnsettled() async => [
    for (final line in _lines)
      if (ReceiptLineState.unsettled.contains(line.state)) line,
  ];

  @override
  Future<List<ReceiptLine>> listUnopened() async => [
    for (final line in _lines)
      if (line.state == ReceiptLineState.pending ||
          line.state == ReceiptLineState.unverified)
        line,
  ];

  @override
  Future<bool> reopenUnverified(int childHireId) async {
    final index = _lines.indexWhere(
      (l) =>
          l.childHireId == childHireId &&
          l.state == ReceiptLineState.unverified,
    );
    if (index < 0) return false;
    _lines[index] = _copy(_lines[index], state: ReceiptLineState.pending);
    return true;
  }

  @override
  Future<bool> markNotOpened(int childHireId) async =>
      _settlePending(childHireId, state: ReceiptLineState.notOpened);

  @override
  Future<bool> markUnverified(int childHireId) async =>
      _settlePending(childHireId, state: ReceiptLineState.unverified);

  @override
  Future<bool> markOpened(
    int childHireId, {
    required int childJobId,
    required String createTransaction,
    required String state,
    Transaction? transaction,
  }) async => _settlePending(
    childHireId,
    state: state,
    childJobId: childJobId,
    createTransaction: createTransaction,
  );

  @override
  Future<bool> recordDeliverable(
    int childHireId,
    String deliverableHash, {
    Transaction? transaction,
  }) async {
    final index = _lines.indexWhere(
      (l) => l.childHireId == childHireId && l.deliverableHash == null,
    );
    if (index < 0) return false;
    _lines[index] = _copy(_lines[index], deliverableHash: deliverableHash);
    return true;
  }

  @override
  Future<bool> markSettled(
    int childHireId, {
    required String state,
    required int? fee,
    required int? payout,
    required String settleTransaction,
  }) async {
    final index = _lines.indexWhere(
      (l) =>
          l.childHireId == childHireId &&
          ReceiptLineState.unsettled.contains(l.state),
    );
    if (index < 0) return false;
    _lines[index] = _copy(
      _lines[index],
      state: state,
      fee: fee,
      payout: payout,
      settleTransaction: settleTransaction,
    );
    return true;
  }

  bool _settlePending(
    int childHireId, {
    required String state,
    int? childJobId,
    String? createTransaction,
  }) {
    final index = _lines.indexWhere(
      (l) =>
          l.childHireId == childHireId && l.state == ReceiptLineState.pending,
    );
    if (index < 0) return false;
    _lines[index] = _copy(
      _lines[index],
      state: state,
      childJobId: childJobId,
      createTransaction: createTransaction,
    );
    return true;
  }

  static ReceiptLine _copy(
    ReceiptLine line, {
    String? state,
    int? childJobId,
    String? createTransaction,
    int? fee,
    int? payout,
    String? deliverableHash,
    String? settleTransaction,
  }) => ReceiptLine(
    id: line.id,
    parentHireId: line.parentHireId,
    childHireId: line.childHireId,
    childJobId: childJobId ?? line.childJobId,
    providerAgentId: line.providerAgentId,
    providerWallet: line.providerWallet,
    budget: line.budget,
    state: state ?? line.state,
    createTransaction: createTransaction ?? line.createTransaction,
    relatedParty: line.relatedParty,
    justification: line.justification,
    createdAt: line.createdAt,
    fee: fee ?? line.fee,
    payout: payout ?? line.payout,
    deliverableHash: deliverableHash ?? line.deliverableHash,
    settleTransaction: settleTransaction ?? line.settleTransaction,
  );
}
