import 'package:serverpod/serverpod.dart';

/// A challenge that has not been stored yet.
final class NewChallenge {
  const NewChallenge({
    required this.challengeId,
    required this.wallet,
    required this.challengeXdr,
    required this.transactionHash,
    required this.expiresAt,
  });

  final String challengeId;
  final String wallet;
  final String challengeXdr;
  final String transactionHash;
  final DateTime expiresAt;
}

/// A challenge row. [consumedAt] is set only after a successful consume.
final class StoredChallenge {
  const StoredChallenge({
    required this.challengeId,
    required this.wallet,
    required this.challengeXdr,
    required this.transactionHash,
    required this.expiresAt,
    required this.createdAt,
    required this.consumedAt,
  });

  final String challengeId;
  final String wallet;
  final String challengeXdr;
  final String transactionHash;
  final DateTime expiresAt;
  final DateTime createdAt;
  final DateTime? consumedAt;
}

/// Why [ChallengeStore.consume] did not leave a newly consumed row.
enum ConsumeOutcome { consumed, alreadyConsumed, expired, notFound }

/// Single-use SEP-10 challenges.
///
/// [consume] updates a row only when it is unconsumed and `expiresAt` is
/// still after the store clock. [inTransaction] commits when [body] returns
/// and rolls every write back when [body] throws.
abstract interface class ChallengeStore {
  /// Runs [body] in one transaction. An implementation without a database
  /// may pass `null`.
  Future<T> inTransaction<T>(
    Future<T> Function(Transaction? transaction) body,
  );

  Future<void> insert(NewChallenge challenge, {Transaction? transaction});

  Future<StoredChallenge?> find(String challengeId);

  Future<ConsumeOutcome> consume(
    String challengeId, {
    Transaction? transaction,
  });
}
