import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'chain_submission_store.dart';
import 'submission_values.dart';

/// SQLSTATE `unique_violation`.
const _uniqueViolation = '23505';

/// Index names from `chain_submission.spy.yaml`; PostgreSQL reports them as
/// `DatabaseQueryException.constraintName`.
const _conflictIndexes = {
  'chain_submission_preparation_idx': ChainSubmissionIndex.preparationId,
  'chain_submission_transaction_idx': ChainSubmissionIndex.transaction,
};

/// PostgreSQL-backed [ChainSubmissionStore] on the `chain_submission`
/// table. Purpose and state are stored as their wire names.
final class ServerpodChainSubmissionStore implements ChainSubmissionStore {
  ServerpodChainSubmissionStore(this._session, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final Session _session;
  final DateTime Function() _now;

  @override
  Future<StoredSubmission> insertSubmitted({
    required SubmissionPurpose purpose,
    required String transactionHash,
    required String signedEnvelopeXdr,
    required DateTime validUntil,
    String? preparationId,
    int? hireId,
    String? explorerUrl,
  }) async {
    final now = _now().toUtc();
    try {
      final row = await ChainSubmission.db.insertRow(
        _session,
        ChainSubmission(
          preparationId: preparationId,
          purpose: purpose.wireName,
          transaction: transactionHash,
          state: SubmissionState.submitted.wireName,
          explorerUrl: explorerUrl,
          updatedAt: now,
          hireId: hireId,
          signedEnvelopeXdr: signedEnvelopeXdr,
          validUntil: validUntil.toUtc(),
          sendAttempts: 0,
          createdAt: now,
        ),
      );
      return _stored(row);
    } on DatabaseQueryException catch (e) {
      final index = _conflictIndexes[e.constraintName];
      if (e.code == _uniqueViolation && index != null) {
        throw ChainSubmissionConflict(index);
      }
      rethrow;
    }
  }

  @override
  Future<StoredSubmission?> findByPreparation(String preparationId) async {
    final row = await ChainSubmission.db.findFirstRow(
      _session,
      where: (t) => t.preparationId.equals(preparationId),
    );
    return row == null ? null : _stored(row);
  }

  @override
  Future<List<StoredSubmission>> listSubmitted({int limit = 100}) async {
    checkListLimit(limit);
    final rows = await ChainSubmission.db.find(
      _session,
      where: (t) => t.state.equals(SubmissionState.submitted.wireName),
      orderByList: (t) => [Order(column: t.updatedAt), Order(column: t.id)],
      limit: limit,
    );
    return rows.map(_stored).toList();
  }

  @override
  Future<bool> markConfirmed(int id) =>
      _transition(id, SubmissionState.confirmed, null);

  @override
  Future<bool> markFailed(int id, String code) =>
      _transition(id, SubmissionState.failed, code);

  @override
  Future<bool> recordSend(int id, DateTime at) =>
      _session.db.transaction((transaction) async {
        final row = await ChainSubmission.db.findById(
          _session,
          id,
          transaction: transaction,
          lockMode: LockMode.forUpdate,
        );
        if (row == null || row.state != SubmissionState.submitted.wireName) {
          return false;
        }
        await ChainSubmission.db.updateById(
          _session,
          id,
          columnValues: (t) => [
            t.sendAttempts((row.sendAttempts ?? 0) + 1),
            t.lastSentAt(at.toUtc()),
          ],
          transaction: transaction,
        );
        return true;
      });

  /// One conditional `UPDATE … WHERE state = 'submitted'`, so a final state
  /// is never overwritten.
  Future<bool> _transition(
    int id,
    SubmissionState state,
    String? errorCode,
  ) async {
    final updated = await ChainSubmission.db.updateWhere(
      _session,
      columnValues: (t) => [
        t.state(state.wireName),
        t.errorCode(errorCode),
        t.updatedAt(_now().toUtc()),
      ],
      where: (t) =>
          t.id.equals(id) & t.state.equals(SubmissionState.submitted.wireName),
    );
    return updated.isNotEmpty;
  }

  /// Maps a row to its typed form. A row with an unknown purpose or state,
  /// or without a server-only column this store always writes, is
  /// corrupt and throws [StateError].
  StoredSubmission _stored(ChainSubmission row) {
    final purpose = SubmissionPurpose.tryParse(row.purpose);
    final state = SubmissionState.tryParse(row.state);
    final envelope = row.signedEnvelopeXdr;
    final validUntil = row.validUntil;
    final createdAt = row.createdAt;
    if (purpose == null ||
        state == null ||
        envelope == null ||
        validUntil == null ||
        createdAt == null) {
      throw StateError('chain_submission ${row.id} is incomplete');
    }
    return StoredSubmission(
      id: row.id!,
      preparationId: row.preparationId,
      purpose: purpose,
      transactionHash: row.transaction,
      state: state,
      errorCode: row.errorCode,
      explorerUrl: row.explorerUrl,
      hireId: row.hireId,
      signedEnvelopeXdr: envelope,
      validUntil: validUntil,
      lastSentAt: row.lastSentAt,
      sendAttempts: row.sendAttempts ?? 0,
      createdAt: createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
