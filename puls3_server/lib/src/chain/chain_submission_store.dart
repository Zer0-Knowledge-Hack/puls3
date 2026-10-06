import '../generated/protocol.dart';
import 'submission_values.dart';

/// A persisted `chain_submission` row with typed purpose and state.
///
/// Every field is set: the store writes the server-only columns on
/// insert even though the generated model declares them nullable.
final class StoredSubmission {
  const StoredSubmission({
    required this.id,
    required this.preparationId,
    required this.purpose,
    required this.transactionHash,
    required this.state,
    required this.errorCode,
    required this.explorerUrl,
    required this.hireId,
    required this.signedEnvelopeXdr,
    required this.validUntil,
    required this.lastSentAt,
    required this.sendAttempts,
    required this.createdAt,
    required this.updatedAt,
    required this.lastCheckedAt,
  });

  final int id;

  /// Null for server-signed purposes.
  final String? preparationId;
  final SubmissionPurpose purpose;

  /// 64-character hex hash of [signedEnvelopeXdr].
  final String transactionHash;
  final SubmissionState state;

  /// Set only when [state] is [SubmissionState.failed].
  final String? errorCode;
  final String? explorerUrl;
  final int? hireId;

  /// Base64 XDR; the only envelope this record ever sends.
  final String signedEnvelopeXdr;

  /// End of the envelope time bounds.
  final DateTime validUntil;

  /// Last send of the envelope; paces resends, never the list order.
  final DateTime? lastSentAt;
  final int sendAttempts;
  final DateTime createdAt;

  /// Last state change. Recording a send or a check does not change it.
  final DateTime updatedAt;

  /// Last time the tracker looked at this record; [createdAt] until then.
  /// Orders [ChainSubmissionStore.listSubmitted].
  final DateTime lastCheckedAt;

  /// The client-visible model, with wire-name strings and no server-only
  /// fields.
  ChainSubmission toProtocol() => ChainSubmission(
    id: id,
    preparationId: preparationId,
    purpose: purpose.wireName,
    transaction: transactionHash,
    state: state.wireName,
    errorCode: errorCode,
    explorerUrl: explorerUrl,
    updatedAt: updatedAt,
  );
}

/// The unique index a rejected insert collided with.
enum ChainSubmissionIndex { preparationId, transaction }

/// An insert collided with an existing record: each preparation and each
/// transaction has at most one submission.
final class ChainSubmissionConflict implements Exception {
  const ChainSubmissionConflict(this.index);

  final ChainSubmissionIndex index;

  @override
  String toString() => 'ChainSubmissionConflict: ${index.name}';
}

/// Durable store of chain submissions (api.md relay steps 4 and 5).
///
/// Named "store" because Serverpod already generates a
/// `ChainSubmissionRepository` (the `ChainSubmission.db` accessor).
///
/// State only moves from `submitted` to `confirmed` or `failed`; both
/// transitions are conditional, so concurrent trackers cannot overwrite a
/// final state.
abstract interface class ChainSubmissionStore {
  /// Persists a `submitted` record before its envelope is sent.
  ///
  /// Throws [ChainSubmissionConflict] when [preparationId] or
  /// [transactionHash] already has a record, and [ArgumentError] when
  /// [preparationId] does not fit [purpose]: wallet-signed purposes need
  /// one, server-signed purposes never have one.
  Future<StoredSubmission> insertSubmitted({
    required SubmissionPurpose purpose,
    required String transactionHash,
    required String signedEnvelopeXdr,
    required DateTime validUntil,
    String? preparationId,
    int? hireId,
    String? explorerUrl,
  });

  /// The record of [preparationId], or `null`.
  Future<StoredSubmission?> findByPreparation(String preparationId);

  /// Up to [limit] `submitted` records, least recently checked first
  /// (`lastCheckedAt`, then id), read in one query. A record goes to the
  /// back once [recordCheck] records a check, so more than [limit] records
  /// that stay `submitted` cannot starve the others. Sends do not change
  /// the order.
  ///
  /// A row that cannot be read (unknown purpose, or a server-only column
  /// missing) is not returned: it is logged and set to `failed` with
  /// [SubmissionOutcomeCode.escrowCallFailed], so it never blocks the batch
  /// again. The result may therefore hold fewer than [limit] records while
  /// more remain.
  ///
  /// Throws [ArgumentError] when [limit] is below 1.
  Future<List<StoredSubmission>> listSubmitted({int limit = 100});

  /// Sets `confirmed` if the record is still `submitted`. Returns whether
  /// it changed.
  Future<bool> markConfirmed(int id);

  /// Sets `failed` with [code] if the record is still `submitted`. Returns
  /// whether it changed.
  ///
  /// Throws [ArgumentError] unless [SubmissionOutcomeCode.isKnown] accepts
  /// [code].
  Future<bool> markFailed(int id, String code);

  /// Counts one more send of the envelope at [at] if the record is still
  /// `submitted`. Returns whether it changed: `false` for an unknown [id] or
  /// a final record. It does not change the state, `updatedAt` or the
  /// [listSubmitted] order.
  Future<bool> recordSend(int id, DateTime at);

  /// Sets `lastCheckedAt` to [at] if the record is still `submitted`, which
  /// moves it to the back of [listSubmitted]. Returns whether it changed:
  /// `false` for an unknown [id] or a final record. It does not change the
  /// state, `updatedAt` or the send fields.
  Future<bool> recordCheck(int id, DateTime at);
}

/// Shared argument check of [ChainSubmissionStore.insertSubmitted].
void checkPreparation(SubmissionPurpose purpose, String? preparationId) {
  if (purpose.isServerSigned && preparationId != null) {
    throw ArgumentError.value(
      preparationId,
      'preparationId',
      'must be null for the server-signed purpose ${purpose.wireName}',
    );
  }
  if (!purpose.isServerSigned && preparationId == null) {
    throw ArgumentError.notNull('preparationId');
  }
}

/// Shared argument check of [ChainSubmissionStore.markFailed].
void checkOutcomeCode(String code) {
  if (!SubmissionOutcomeCode.isKnown(code)) {
    throw ArgumentError.value(code, 'code', 'is not a known outcome code');
  }
}

/// Shared argument check of [ChainSubmissionStore.listSubmitted].
void checkListLimit(int limit) {
  if (limit < 1) {
    throw ArgumentError.value(limit, 'limit', 'must be at least 1');
  }
}
