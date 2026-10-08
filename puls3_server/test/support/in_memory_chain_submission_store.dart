import 'package:puls3_server/src/chain/chain_submission_store.dart';
import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:serverpod/serverpod.dart' show Transaction;

/// In-memory [ChainSubmissionStore] with the same unique indexes and
/// conditional transitions as the Serverpod one.
final class InMemoryChainSubmissionStore implements ChainSubmissionStore {
  InMemoryChainSubmissionStore({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final _rows = <int, StoredSubmission>{};
  var _nextId = 1;

  /// Every stored record, in insertion order.
  List<StoredSubmission> get all => List.unmodifiable(_rows.values);

  @override
  Future<StoredSubmission> insertSubmitted({
    required SubmissionPurpose purpose,
    required String transactionHash,
    required String signedEnvelopeXdr,
    required DateTime validUntil,
    String? preparationId,
    int? hireId,
    String? explorerUrl,
    Transaction? transaction,
  }) async {
    checkPreparation(purpose, preparationId);
    if (preparationId != null &&
        _rows.values.any((r) => r.preparationId == preparationId)) {
      throw const ChainSubmissionConflict(ChainSubmissionIndex.preparationId);
    }
    if (_rows.values.any((r) => r.transactionHash == transactionHash)) {
      throw const ChainSubmissionConflict(ChainSubmissionIndex.transaction);
    }
    final now = _now().toUtc();
    final stored = StoredSubmission(
      id: _nextId++,
      preparationId: preparationId,
      purpose: purpose,
      transactionHash: transactionHash,
      state: SubmissionState.submitted,
      errorCode: null,
      explorerUrl: explorerUrl,
      hireId: hireId,
      signedEnvelopeXdr: signedEnvelopeXdr,
      validUntil: validUntil.toUtc(),
      lastSentAt: null,
      sendAttempts: 0,
      createdAt: now,
      updatedAt: now,
      lastCheckedAt: now,
    );
    _rows[stored.id] = stored;
    return stored;
  }

  @override
  Future<StoredSubmission?> findByPreparation(String preparationId) async {
    for (final row in _rows.values) {
      if (row.preparationId == preparationId) return row;
    }
    return null;
  }

  @override
  Future<List<StoredSubmission>> listByHire(int hireId) async =>
      _rows.values.where((r) => r.hireId == hireId).toList();

  @override
  Future<List<StoredSubmission>> listSubmitted({int limit = 100}) async {
    checkListLimit(limit);
    final submitted =
        _rows.values.where((r) => r.state == SubmissionState.submitted).toList()
          ..sort(_listOrder);
    return submitted.take(limit).toList();
  }

  @override
  Future<bool> markConfirmed(int id) async =>
      _transition(id, SubmissionState.confirmed, null);

  @override
  Future<bool> markFailed(int id, String code) async {
    checkOutcomeCode(code);
    return _transition(id, SubmissionState.failed, code);
  }

  @override
  Future<bool> recordSend(int id, DateTime at) async {
    final row = _rows[id];
    if (row == null || row.state != SubmissionState.submitted) return false;
    _rows[id] = _copy(
      row,
      lastSentAt: at.toUtc(),
      sendAttempts: row.sendAttempts + 1,
    );
    return true;
  }

  @override
  Future<bool> recordCheck(int id, DateTime at) async {
    final row = _rows[id];
    if (row == null || row.state != SubmissionState.submitted) return false;
    _rows[id] = _copy(row, lastCheckedAt: at.toUtc());
    return true;
  }

  bool _transition(int id, SubmissionState state, String? errorCode) {
    final row = _rows[id];
    if (row == null || row.state != SubmissionState.submitted) return false;
    _rows[id] = _copy(
      row,
      state: state,
      errorCode: errorCode,
      updatedAt: _now().toUtc(),
    );
    return true;
  }

  StoredSubmission _copy(
    StoredSubmission row, {
    SubmissionState? state,
    String? errorCode,
    DateTime? updatedAt,
    DateTime? lastSentAt,
    int? sendAttempts,
    DateTime? lastCheckedAt,
  }) => StoredSubmission(
    id: row.id,
    preparationId: row.preparationId,
    purpose: row.purpose,
    transactionHash: row.transactionHash,
    state: state ?? row.state,
    errorCode: errorCode ?? row.errorCode,
    explorerUrl: row.explorerUrl,
    hireId: row.hireId,
    signedEnvelopeXdr: row.signedEnvelopeXdr,
    validUntil: row.validUntil,
    lastSentAt: lastSentAt ?? row.lastSentAt,
    sendAttempts: sendAttempts ?? row.sendAttempts,
    createdAt: row.createdAt,
    updatedAt: updatedAt ?? row.updatedAt,
    lastCheckedAt: lastCheckedAt ?? row.lastCheckedAt,
  );
}

/// The order of [ChainSubmissionStore.listSubmitted]: least recently
/// checked first, then id.
int _listOrder(StoredSubmission a, StoredSubmission b) {
  final byCheck = a.lastCheckedAt.compareTo(b.lastCheckedAt);
  return byCheck != 0 ? byCheck : a.id.compareTo(b.id);
}
