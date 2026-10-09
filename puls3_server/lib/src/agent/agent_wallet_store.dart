import 'package:puls3_domain/puls3_domain.dart';

import 'secret_cipher.dart';

/// A stored agent wallet, reconstructed from its row.
final class StoredAgentWallet {
  const StoredAgentWallet({
    required this.id,
    required this.owner,
    required this.address,
    required this.idempotencyKey,
    required this.secret,
    required this.createdAt,
    this.agentId,
  });

  final int id;
  final StellarAddress owner;
  final StellarAddress address;

  /// The caller's idempotency key; unique, so a retry returns this wallet.
  final String idempotencyKey;

  /// The encrypted secret seed. Nothing outside the custody adapter decrypts
  /// it, and it is never logged or returned by an endpoint.
  final EncryptedSecret secret;
  final DateTime createdAt;

  /// The on-chain registry id, set once `register_full` is confirmed.
  final AgentId? agentId;
}

/// A wallet already exists for the same idempotency key (or address).
final class AgentWalletConflict implements Exception {
  const AgentWalletConflict(this.index);

  /// The unique index that was violated: `idempotencyKey` or `address`.
  final String index;

  @override
  String toString() => 'AgentWalletConflict: $index';
}

/// Stores and loads custodied agent wallets. Implemented by the backend
/// (Serverpod ORM).
///
/// Named "store" because Serverpod already generates an
/// `AgentWalletRepository` for the `AgentWallet.db` accessor.
abstract interface class AgentWalletStore {
  /// Inserts a wallet and returns it with its id.
  ///
  /// Throws [AgentWalletConflict] when [idempotencyKey] or [address] already
  /// has a wallet.
  Future<StoredAgentWallet> save({
    required StellarAddress owner,
    required StellarAddress address,
    required String idempotencyKey,
    required EncryptedSecret secret,
    required DateTime createdAt,
  });

  /// The wallet created for [idempotencyKey], or `null` if there is none.
  Future<StoredAgentWallet?> findByIdempotencyKey(String idempotencyKey);

  /// The wallet with payment [address], or `null` if there is none.
  Future<StoredAgentWallet?> findByAddress(StellarAddress address);
}
