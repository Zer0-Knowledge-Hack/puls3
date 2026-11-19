import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart' show HireReceiptLineRecord;
import 'hire_receipt_store.dart';

/// PostgreSQL-backed [HireReceiptStore] on the `hire_receipt_line` table.
final class ServerpodHireReceiptStore implements HireReceiptStore {
  ServerpodHireReceiptStore(this._session, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final Session _session;
  final DateTime Function() _now;

  @override
  Future<T> inTransaction<T>(
    Future<T> Function(Transaction? transaction) body,
  ) => _session.db.transaction<T>(body);

  @override
  Future<ReceiptLine> insert(
    NewReceiptLine line, {
    Transaction? transaction,
  }) async {
    final row = await HireReceiptLineRecord.db.insertRow(
      _session,
      HireReceiptLineRecord(
        parentHireId: line.parentHireId,
        childHireId: line.childHireId,
        providerAgentId: line.providerAgentId,
        providerWallet: line.providerWallet,
        budget: line.budget,
        state: line.state,
        createTransaction: line.createTransaction,
        relatedParty: line.relatedParty,
        justification: line.justification,
        createdAt: _now().toUtc(),
      ),
      transaction: transaction,
    );
    return _line(row);
  }

  @override
  Future<ReceiptLine?> findByChildHire(int childHireId) async {
    final row = await HireReceiptLineRecord.db.findFirstRow(
      _session,
      where: (t) => t.childHireId.equals(childHireId),
      orderBy: (t) => t.id,
    );
    return row == null ? null : _line(row);
  }

  @override
  Future<List<ReceiptLine>> listByParent(int parentHireId) async {
    final rows = await HireReceiptLineRecord.db.find(
      _session,
      where: (t) => t.parentHireId.equals(parentHireId),
      orderBy: (t) => t.id,
    );
    return [for (final row in rows) _line(row)];
  }

  @override
  Future<bool> markNotOpened(int childHireId) async {
    final updated = await HireReceiptLineRecord.db.updateWhere(
      _session,
      columnValues: (t) => [t.state(ReceiptLineState.notOpened)],
      where: (t) =>
          t.childHireId.equals(childHireId) &
          t.state.equals(ReceiptLineState.pending),
    );
    return updated.isNotEmpty;
  }

  static ReceiptLine _line(HireReceiptLineRecord row) => ReceiptLine(
    id: row.id!,
    parentHireId: row.parentHireId,
    childHireId: row.childHireId,
    childJobId: row.childJobId,
    providerAgentId: row.providerAgentId,
    providerWallet: row.providerWallet,
    budget: row.budget,
    state: row.state,
    createTransaction: row.createTransaction,
    relatedParty: row.relatedParty,
    justification: row.justification,
    createdAt: row.createdAt.toUtc(),
  );
}
