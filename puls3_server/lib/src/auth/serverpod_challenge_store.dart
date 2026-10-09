import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'challenge_store.dart';

/// PostgreSQL-backed [ChallengeStore] on `wallet_challenge`.
final class ServerpodChallengeStore implements ChallengeStore {
  ServerpodChallengeStore(this._session, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final Session _session;
  final DateTime Function() _now;

  @override
  Future<T> inTransaction<T>(
    Future<T> Function(Transaction? transaction) body,
  ) => _session.db.transaction<T>(body);

  @override
  Future<void> insert(
    NewChallenge challenge, {
    Transaction? transaction,
  }) async {
    await WalletChallengeRecord.db.insertRow(
      _session,
      WalletChallengeRecord(
        challengeId: challenge.challengeId,
        wallet: challenge.wallet,
        challengeXdr: challenge.challengeXdr,
        transactionHash: challenge.transactionHash,
        expiresAt: challenge.expiresAt.toUtc(),
        createdAt: _now().toUtc(),
      ),
      transaction: transaction,
    );
  }

  @override
  Future<StoredChallenge?> find(String challengeId) async {
    final row = await WalletChallengeRecord.db.findFirstRow(
      _session,
      where: (t) => t.challengeId.equals(challengeId),
    );
    return row == null ? null : _stored(row);
  }

  /// One `UPDATE … WHERE challengeId = ? AND consumedAt IS NULL AND
  /// expiresAt > now`. Zero rows are re-read to tell consumed, expired and
  /// missing apart.
  @override
  Future<ConsumeOutcome> consume(
    String challengeId, {
    Transaction? transaction,
  }) async {
    final now = _now().toUtc();
    final updated = await WalletChallengeRecord.db.updateWhere(
      _session,
      columnValues: (t) => [t.consumedAt(now)],
      where: (t) =>
          t.challengeId.equals(challengeId) &
          t.consumedAt.equals(null) &
          (t.expiresAt > now),
      transaction: transaction,
    );
    if (updated.isNotEmpty) return ConsumeOutcome.consumed;
    final row = await WalletChallengeRecord.db.findFirstRow(
      _session,
      where: (t) => t.challengeId.equals(challengeId),
      transaction: transaction,
    );
    if (row == null) return ConsumeOutcome.notFound;
    if (row.consumedAt != null) return ConsumeOutcome.alreadyConsumed;
    return ConsumeOutcome.expired;
  }

  StoredChallenge _stored(WalletChallengeRecord row) => StoredChallenge(
    challengeId: row.challengeId,
    wallet: row.wallet,
    challengeXdr: row.challengeXdr,
    transactionHash: row.transactionHash,
    expiresAt: row.expiresAt,
    createdAt: row.createdAt,
    consumedAt: row.consumedAt,
  );
}
