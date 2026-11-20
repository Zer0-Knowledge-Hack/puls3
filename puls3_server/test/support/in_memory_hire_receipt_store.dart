import 'package:puls3_server/src/hire/hire_receipt_store.dart';
import 'package:serverpod/serverpod.dart' show Transaction;

/// In-memory [HireReceiptStore]. [inTransaction] snapshots the lines and
/// restores them when the body throws, and passes a `null` transaction.
final class InMemoryHireReceiptStore implements HireReceiptStore {
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
  Future<bool> markNotOpened(int childHireId) async {
    final index = _lines.indexWhere(
      (l) =>
          l.childHireId == childHireId && l.state == ReceiptLineState.pending,
    );
    if (index < 0) return false;
    final line = _lines[index];
    _lines[index] = ReceiptLine(
      id: line.id,
      parentHireId: line.parentHireId,
      childHireId: line.childHireId,
      childJobId: line.childJobId,
      providerAgentId: line.providerAgentId,
      providerWallet: line.providerWallet,
      budget: line.budget,
      state: ReceiptLineState.notOpened,
      createTransaction: line.createTransaction,
      relatedParty: line.relatedParty,
      justification: line.justification,
      createdAt: line.createdAt,
    );
    return true;
  }
}
