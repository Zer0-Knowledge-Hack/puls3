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
  Future<List<ReceiptLine>> listUnsettled() async {
    final rows = await HireReceiptLineRecord.db.find(
      _session,
      where: (t) => t.state.inSet(ReceiptLineState.unsettled),
      orderBy: (t) => t.id,
    );
    return [for (final row in rows) _line(row)];
  }

  @override
  Future<List<ReceiptLine>> listUnopened() async {
    final rows = await HireReceiptLineRecord.db.find(
      _session,
      where: (t) => t.state.inSet({
        ReceiptLineState.pending,
        ReceiptLineState.unverified,
      }),
      orderBy: (t) => t.id,
    );
    return [for (final row in rows) _line(row)];
  }

  @override
  Future<bool> reopenUnverified(int childHireId) async {
    final updated = await HireReceiptLineRecord.db.updateWhere(
      _session,
      columnValues: (t) => [t.state(ReceiptLineState.pending)],
      where: (t) =>
          t.childHireId.equals(childHireId) &
          t.state.equals(ReceiptLineState.unverified),
    );
    return updated.isNotEmpty;
  }

  @override
  Future<bool> markNotOpened(int childHireId) =>
      _settlePending(childHireId, ReceiptLineState.notOpened);

  @override
  Future<bool> markUnverified(int childHireId) =>
      _settlePending(childHireId, ReceiptLineState.unverified);

  @override
  Future<bool> markOpened(
    int childHireId, {
    required int childJobId,
    required String createTransaction,
    required String state,
    Transaction? transaction,
  }) async {
    final updated = await HireReceiptLineRecord.db.updateWhere(
      _session,
      columnValues: (t) => [
        t.childJobId(childJobId),
        t.createTransaction(createTransaction),
        t.state(state),
      ],
      where: (t) =>
          t.childHireId.equals(childHireId) &
          t.state.equals(ReceiptLineState.pending),
      transaction: transaction,
    );
    return updated.isNotEmpty;
  }

  @override
  Future<bool> recordDeliverable(
    int childHireId,
    String deliverableHash, {
    Transaction? transaction,
  }) async {
    final updated = await HireReceiptLineRecord.db.updateWhere(
      _session,
      columnValues: (t) => [t.deliverableHash(deliverableHash)],
      where: (t) =>
          t.childHireId.equals(childHireId) & t.deliverableHash.equals(null),
      transaction: transaction,
    );
    return updated.isNotEmpty;
  }

  @override
  Future<bool> markSettled(
    int childHireId, {
    required String state,
    required int? fee,
    required int? payout,
    required String settleTransaction,
  }) async {
    final updated = await HireReceiptLineRecord.db.updateWhere(
      _session,
      columnValues: (t) => [
        t.state(state),
        t.fee(fee),
        t.payout(payout),
        t.settleTransaction(settleTransaction),
      ],
      where: (t) =>
          t.childHireId.equals(childHireId) &
          t.state.inSet(ReceiptLineState.unsettled),
    );
    return updated.isNotEmpty;
  }

  Future<bool> _settlePending(int childHireId, String state) async {
    final updated = await HireReceiptLineRecord.db.updateWhere(
      _session,
      columnValues: (t) => [t.state(state)],
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
    fee: row.fee,
    payout: row.payout,
    deliverableHash: row.deliverableHash,
    settleTransaction: row.settleTransaction,
  );
}
