import 'package:puls3_domain/puls3_domain.dart';
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'agent_wallet_store.dart';
import 'secret_cipher.dart';

/// PostgreSQL-backed [AgentWalletStore] using the Serverpod ORM.
final class ServerpodAgentWalletStore implements AgentWalletStore {
  ServerpodAgentWalletStore(this.session);

  final Session session;

  @override
  Future<StoredAgentWallet> save({
    required StellarAddress owner,
    required StellarAddress address,
    required EncryptedSecret secret,
    required DateTime createdAt,
  }) async {
    final row = await AgentWallet.db.insertRow(
      session,
      AgentWallet(
        owner: owner.value,
        address: address.value,
        ciphertext: secret.ciphertext,
        nonce: secret.nonce,
        mac: secret.mac,
        keyVersion: secret.keyVersion,
        createdAt: createdAt,
      ),
    );
    return _stored(row);
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
