import 'package:puls3_server/src/hire/escrow_preparation_store.dart';
import 'package:serverpod/serverpod.dart' show Transaction;

/// In-memory [EscrowPreparationStore] with the same conditional updates as
/// the Serverpod one. [inTransaction] snapshots the rows and restores them
/// when the body throws, and passes a `null` transaction.
final class InMemoryEscrowPreparationStore implements EscrowPreparationStore {
  InMemoryEscrowPreparationStore({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  var _rows = <StoredPreparation>[];
  var _nextId = 1;

  /// Every stored preparation, in insertion order.
  List<StoredPreparation> get all => List.unmodifiable(_rows);

  @override
  Future<T> inTransaction<T>(
    Future<T> Function(Transaction? transaction) body,
  ) async {
    final snapshot = List.of(_rows);
    try {
      return await body(null);
    } catch (_) {
      _rows = snapshot;
      rethrow;
    }
  }

  @override
  Future<StoredPreparation> insert(
    NewPreparation preparation, {
    Transaction? transaction,
  }) async {
    if (_rows.any((r) => r.preparationId == preparation.preparationId)) {
      throw EscrowPreparationConflict(preparation.preparationId);
    }
    final stored = StoredPreparation(
      id: _nextId++,
      preparationId: preparation.preparationId,
      hireId: preparation.hireId,
      purpose: preparation.purpose,
      signer: preparation.signer,
      unsignedEnvelopeXdr: preparation.unsignedEnvelopeXdr,
      transactionHash: preparation.transactionHash,
      sequence: preparation.sequence,
      validUntil: preparation.validUntil.toUtc(),
      jobExpiredAt: preparation.jobExpiredAt,
      rejectReason: preparation.rejectReason,
      createdAt: _now().toUtc(),
      supersededAt: null,
      submittedAt: null,
    );
    _rows.add(stored);
    return stored;
  }

  @override
  Future<StoredPreparation?> findByPreparationId(String preparationId) async {
    for (final row in _rows) {
      if (row.preparationId == preparationId) return row;
    }
    return null;
  }

  @override
  Future<StoredPreparation?> findCurrent(int hireId) async {
    StoredPreparation? current;
    for (final row in _rows) {
      if (row.hireId == hireId && row.supersededAt == null) current = row;
    }
    return current;
  }

  @override
  Future<int> supersedeCurrent(int hireId, {Transaction? transaction}) async {
    var changed = 0;
    for (var i = 0; i < _rows.length; i++) {
      final row = _rows[i];
      if (row.hireId == hireId &&
          row.supersededAt == null &&
          row.submittedAt == null) {
        _rows[i] = _copy(row, supersededAt: _now().toUtc());
        changed++;
      }
    }
    return changed;
  }

  @override
  Future<bool> claim(String preparationId, {Transaction? transaction}) async {
    for (var i = 0; i < _rows.length; i++) {
      final row = _rows[i];
      if (row.preparationId == preparationId && row.supersededAt == null) {
        _rows[i] = _copy(row, submittedAt: _now().toUtc());
        return true;
      }
    }
    return false;
  }

  StoredPreparation _copy(
    StoredPreparation row, {
    DateTime? supersededAt,
    DateTime? submittedAt,
  }) => StoredPreparation(
    id: row.id,
    preparationId: row.preparationId,
    hireId: row.hireId,
    purpose: row.purpose,
    signer: row.signer,
    unsignedEnvelopeXdr: row.unsignedEnvelopeXdr,
    transactionHash: row.transactionHash,
    sequence: row.sequence,
    validUntil: row.validUntil,
    jobExpiredAt: row.jobExpiredAt,
    rejectReason: row.rejectReason,
    createdAt: row.createdAt,
    supersededAt: supersededAt ?? row.supersededAt,
    submittedAt: submittedAt ?? row.submittedAt,
  );
}
