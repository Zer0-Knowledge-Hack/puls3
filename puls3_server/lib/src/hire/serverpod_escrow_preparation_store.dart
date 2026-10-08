import 'package:serverpod/serverpod.dart';

import '../chain/submission_values.dart';
import '../generated/protocol.dart';
import 'escrow_preparation_store.dart';

/// SQLSTATE `unique_violation`.
const _uniqueViolation = '23505';

/// Index name from `escrow_preparation.spy.yaml`.
const _preparationIdIndex = 'escrow_preparation_id_idx';

/// PostgreSQL-backed [EscrowPreparationStore] on the `escrow_preparation`
/// table.
final class ServerpodEscrowPreparationStore implements EscrowPreparationStore {
  ServerpodEscrowPreparationStore(this._session, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final Session _session;
  final DateTime Function() _now;

  @override
  Future<T> inTransaction<T>(
    Future<T> Function(Transaction? transaction) body,
  ) => _session.db.transaction<T>(body);

  @override
  Future<StoredPreparation> insert(
    NewPreparation preparation, {
    Transaction? transaction,
  }) async {
    try {
      final row = await EscrowPreparation.db.insertRow(
        _session,
        EscrowPreparation(
          preparationId: preparation.preparationId,
          hireId: preparation.hireId,
          purpose: preparation.purpose.wireName,
          signer: preparation.signer,
          unsignedEnvelopeXdr: preparation.unsignedEnvelopeXdr,
          transactionHash: preparation.transactionHash,
          sequence: preparation.sequence,
          validUntil: preparation.validUntil.toUtc(),
          jobExpiredAt: preparation.jobExpiredAt,
          rejectReason: preparation.rejectReason,
          createdAt: _now().toUtc(),
        ),
        transaction: transaction,
      );
      return _stored(row);
    } on DatabaseQueryException catch (e) {
      if (e.code == _uniqueViolation &&
          e.constraintName == _preparationIdIndex) {
        throw EscrowPreparationConflict(preparation.preparationId);
      }
      rethrow;
    }
  }

  @override
  Future<StoredPreparation?> findByPreparationId(String preparationId) async {
    final row = await EscrowPreparation.db.findFirstRow(
      _session,
      where: (t) => t.preparationId.equals(preparationId),
    );
    return row == null ? null : _stored(row);
  }

  @override
  Future<StoredPreparation?> findCurrent(int hireId) async {
    final row = await EscrowPreparation.db.findFirstRow(
      _session,
      where: (t) => t.hireId.equals(hireId) & t.supersededAt.equals(null),
      orderByList: (t) => [t.id.desc()],
    );
    return row == null ? null : _stored(row);
  }

  /// One `UPDATE … WHERE supersededAt IS NULL AND submittedAt IS NULL`.
  @override
  Future<int> supersedeCurrent(int hireId, {Transaction? transaction}) async {
    final updated = await EscrowPreparation.db.updateWhere(
      _session,
      columnValues: (t) => [t.supersededAt(_now().toUtc())],
      where: (t) =>
          t.hireId.equals(hireId) &
          t.supersededAt.equals(null) &
          t.submittedAt.equals(null),
      transaction: transaction,
    );
    return updated.length;
  }

  /// One `UPDATE … WHERE preparationId = ? AND supersededAt IS NULL`.
  @override
  Future<bool> claim(String preparationId, {Transaction? transaction}) async {
    final updated = await EscrowPreparation.db.updateWhere(
      _session,
      columnValues: (t) => [t.submittedAt(_now().toUtc())],
      where: (t) =>
          t.preparationId.equals(preparationId) & t.supersededAt.equals(null),
      transaction: transaction,
    );
    return updated.isNotEmpty;
  }

  StoredPreparation _stored(EscrowPreparation row) => StoredPreparation(
    id: row.id!,
    preparationId: row.preparationId,
    hireId: row.hireId,
    purpose: SubmissionPurpose.parse(row.purpose),
    signer: row.signer,
    unsignedEnvelopeXdr: row.unsignedEnvelopeXdr,
    transactionHash: row.transactionHash,
    sequence: row.sequence,
    validUntil: row.validUntil,
    jobExpiredAt: row.jobExpiredAt,
    rejectReason: row.rejectReason,
    createdAt: row.createdAt,
    supersededAt: row.supersededAt,
    submittedAt: row.submittedAt,
  );
}
