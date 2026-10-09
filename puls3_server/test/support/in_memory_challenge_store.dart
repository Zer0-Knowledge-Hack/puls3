import 'package:puls3_server/src/auth/challenge_store.dart';
import 'package:serverpod/serverpod.dart' show Transaction;

/// In-memory [ChallengeStore] with the same conditional consume as the
/// Serverpod one. [inTransaction] snapshots the rows and restores them when
/// the body throws, and passes a `null` transaction.
final class InMemoryChallengeStore implements ChallengeStore {
  InMemoryChallengeStore({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  var _rows = <StoredChallenge>[];

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
  Future<void> insert(
    NewChallenge challenge, {
    Transaction? transaction,
  }) async {
    _rows = [
      ..._rows,
      StoredChallenge(
        challengeId: challenge.challengeId,
        wallet: challenge.wallet,
        challengeXdr: challenge.challengeXdr,
        transactionHash: challenge.transactionHash,
        expiresAt: challenge.expiresAt,
        createdAt: _now().toUtc(),
        consumedAt: null,
      ),
    ];
  }

  @override
  Future<StoredChallenge?> find(String challengeId) async {
    for (final row in _rows) {
      if (row.challengeId == challengeId) return row;
    }
    return null;
  }

  @override
  Future<ConsumeOutcome> consume(
    String challengeId, {
    Transaction? transaction,
  }) async {
    final now = _now().toUtc();
    final index = _rows.indexWhere((row) => row.challengeId == challengeId);
    if (index < 0) return ConsumeOutcome.notFound;
    final row = _rows[index];
    if (row.consumedAt != null) return ConsumeOutcome.alreadyConsumed;
    if (!row.expiresAt.isAfter(now)) return ConsumeOutcome.expired;
    _rows = [
      for (var i = 0; i < _rows.length; i++)
        if (i == index)
          StoredChallenge(
            challengeId: row.challengeId,
            wallet: row.wallet,
            challengeXdr: row.challengeXdr,
            transactionHash: row.transactionHash,
            expiresAt: row.expiresAt,
            createdAt: row.createdAt,
            consumedAt: now,
          )
        else
          _rows[i],
    ];
    return ConsumeOutcome.consumed;
  }
}
