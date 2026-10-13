import 'package:puls3_domain/puls3_domain.dart';
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'agent_wallet_store.dart';
import 'secret_cipher.dart';

/// PostgreSQL unique-violation SQLSTATE.
const _uniqueViolation = '23505';
const _idempotencyIndex = 'agent_wallet_idempotency_idx';
const _addressIndex = 'agent_wallet_address_idx';

/// PostgreSQL-backed [AgentWalletStore] using the Serverpod ORM.
///
/// A unique violation on the idempotency key or the address is reported as
/// [AgentWalletConflict], so custody can return the existing wallet.
final class ServerpodAgentWalletStore implements AgentWalletStore {
  ServerpodAgentWalletStore(this.session);

  final Session session;

  @override
  Future<StoredAgentWallet> save({
    required StellarAddress owner,
    required StellarAddress address,
    required String idempotencyKey,
    required EncryptedSecret secret,
    required DateTime createdAt,
  }) async {
    try {
      final row = await AgentWallet.db.insertRow(
        session,
        AgentWallet(
          owner: owner.value,
          address: address.value,
          idempotencyKey: idempotencyKey,
          ciphertext: secret.ciphertext,
          nonce: secret.nonce,
          mac: secret.mac,
          keyVersion: secret.keyVersion,
          createdAt: createdAt,
        ),
      );
      return _stored(row);
    } on DatabaseQueryException catch (e) {
      if (e.code == _uniqueViolation) {
        if (e.constraintName == _idempotencyIndex) {
          throw const AgentWalletConflict('idempotencyKey');
        }
        if (e.constraintName == _addressIndex) {
          throw const AgentWalletConflict('address');
        }
      }
      rethrow;
    }
  }

  @override
  Future<StoredAgentWallet?> findByIdempotencyKey(String idempotencyKey) async {
    final row = await AgentWallet.db.findFirstRow(
      session,
      where: (t) => t.idempotencyKey.equals(idempotencyKey),
    );
    return row == null ? null : _stored(row);
  }

  @override
  Future<StoredAgentWallet?> findByAddress(StellarAddress address) async {
    final row = await AgentWallet.db.findFirstRow(
      session,
      where: (t) => t.address.equals(address.value),
    );
    return row == null ? null : _stored(row);
  }

  StoredAgentWallet _stored(AgentWallet row) => StoredAgentWallet(
    id: row.id!,
    owner: StellarAddress.parse(row.owner),
    address: StellarAddress.parse(row.address),
    idempotencyKey: row.idempotencyKey,
    secret: EncryptedSecret(
      ciphertext: row.ciphertext,
      nonce: row.nonce,
      mac: row.mac,
      keyVersion: row.keyVersion,
    ),
    createdAt: row.createdAt,
    agentId: row.agentId == null ? null : AgentId(row.agentId!),
  );
}
