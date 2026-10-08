import 'package:serverpod/serverpod.dart' show Transaction;

import '../chain/submission_values.dart';

/// An unsigned escrow envelope to persist as a preparation.
final class NewPreparation {
  const NewPreparation({
    required this.preparationId,
    required this.hireId,
    required this.purpose,
    required this.signer,
    required this.unsignedEnvelopeXdr,
    required this.transactionHash,
    required this.sequence,
    required this.validUntil,
    this.jobExpiredAt,
    this.rejectReason,
  });

  /// Opaque id the client echoes back on submit.
  final String preparationId;
  final int hireId;
  final SubmissionPurpose purpose;

  /// StrKey of the session wallet that must sign.
  final String signer;

  /// Base64 unsigned envelope XDR, exactly as returned to the client.
  final String unsignedEnvelopeXdr;

  /// Lowercase hex network hash of the prepared transaction.
  final String transactionHash;

  /// Source account sequence number the envelope uses.
  final int sequence;

  /// End of the envelope time bounds.
  final DateTime validUntil;

  /// `expired_at` a `createJob` was prepared with.
  final int? jobExpiredAt;

  /// Reject reason baked into a `reject` envelope.
  final String? rejectReason;
}

/// A persisted `escrow_preparation` row with a typed purpose.
final class StoredPreparation {
  const StoredPreparation({
    required this.id,
    required this.preparationId,
    required this.hireId,
    required this.purpose,
    required this.signer,
    required this.unsignedEnvelopeXdr,
    required this.transactionHash,
    required this.sequence,
    required this.validUntil,
    required this.jobExpiredAt,
    required this.rejectReason,
    required this.createdAt,
    required this.supersededAt,
    required this.submittedAt,
  });

  final int id;
  final String preparationId;
  final int hireId;
  final SubmissionPurpose purpose;
  final String signer;
  final String unsignedEnvelopeXdr;
  final String transactionHash;
  final int sequence;
  final DateTime validUntil;
  final int? jobExpiredAt;
  final String? rejectReason;
  final DateTime createdAt;

  /// Set when a newer preparation replaced this one.
  final DateTime? supersededAt;

  /// Set when a submit claimed this preparation.
  final DateTime? submittedAt;
}

/// An insert reused an existing preparation id.
final class EscrowPreparationConflict implements Exception {
  const EscrowPreparationConflict(this.preparationId);

  final String preparationId;

  @override
  String toString() => 'EscrowPreparationConflict: $preparationId';
}

/// Durable store of the unsigned envelopes prepared for session wallets
/// (design D1 to D3).
///
/// Supersession and claiming are single conditional `UPDATE`s, so a prepare
/// and a submit racing on one preparation are ordered by PostgreSQL row
/// locks: exactly one of [supersedeCurrent] and [claim] wins.
///
/// Every write takes an optional [Transaction] from [inTransaction], so the
/// service can claim a preparation and call
/// `ChainSubmissionStore.insertSubmitted` atomically.
abstract interface class EscrowPreparationStore {
  /// Runs [body] in one database transaction and commits it when [body]
  /// returns. Any exception rolls every write made with the given
  /// transaction back and is rethrown.
  ///
  /// An implementation without a database may pass `null`.
  Future<T> inTransaction<T>(Future<T> Function(Transaction? transaction) body);

  /// Persists an open preparation.
  ///
  /// Throws [EscrowPreparationConflict] when the preparation id is taken.
  Future<StoredPreparation> insert(
    NewPreparation preparation, {
    Transaction? transaction,
  });

  /// The preparation of [preparationId], or `null`.
  Future<StoredPreparation?> findByPreparationId(String preparationId);

  /// The newest preparation of [hireId] that is not superseded, or `null`.
  Future<StoredPreparation?> findCurrent(int hireId);

  /// Supersedes every preparation of [hireId] that is neither superseded
  /// nor claimed. Returns how many changed.
  Future<int> supersedeCurrent(int hireId, {Transaction? transaction});

  /// Sets `submittedAt` unless the preparation is unknown or superseded.
  /// Returns whether a row matched; `false` means the submit lost the race
  /// (the service answers `PreparationExpired`, reason superseded).
  ///
  /// A preparation that is already claimed matches again: a concurrent
  /// identical submit then loses on the `ChainSubmissionStore` preparation
  /// index and re-reads the winner's record.
  Future<bool> claim(String preparationId, {Transaction? transaction});
}
