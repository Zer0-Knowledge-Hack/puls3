import 'dart:convert';
import 'dart:math';

import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/agent/aes_gcm_secret_cipher.dart';
import 'package:puls3_server/src/agent/agent_wallet_store.dart';
import 'package:puls3_server/src/agent/secret_cipher.dart';
import 'package:puls3_server/src/agent/stellar_agent_wallet_custody.dart';
import 'package:stellar_dart/stellar_dart.dart' as stellar;
import 'package:test/test.dart';

const _owner = 'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H';

final class _MemoryWallets implements AgentWalletStore {
  final rows = <StoredAgentWallet>[];
  int _next = 1;

  @override
  Future<StoredAgentWallet> save({
    required StellarAddress owner,
    required StellarAddress address,
    required String idempotencyKey,
    required EncryptedSecret secret,
    required DateTime createdAt,
  }) async {
    if (rows.any((row) => row.idempotencyKey == idempotencyKey)) {
      throw const AgentWalletConflict('idempotencyKey');
    }
    final wallet = StoredAgentWallet(
      id: _next++,
      owner: owner,
      address: address,
      idempotencyKey: idempotencyKey,
      secret: secret,
      createdAt: createdAt,
    );
    rows.add(wallet);
    return wallet;
  }

  @override
  Future<StoredAgentWallet?> findByIdempotencyKey(String idempotencyKey) async {
    for (final row in rows) {
      if (row.idempotencyKey == idempotencyKey) return row;
    }
    return null;
  }

  @override
  Future<StoredAgentWallet?> findByAddress(StellarAddress address) async {
    for (final row in rows) {
      if (row.address == address) return row;
    }
    return null;
  }
}

void main() {
  final cipher = AesGcmSecretCipher(
    keys: {1: List<int>.generate(32, (i) => i)},
    writeKeyVersion: 1,
  );

  StellarAgentWalletCustody custodyOver(
    _MemoryWallets wallets, {
    int seed = 7,
  }) => StellarAgentWalletCustody(
    wallets: wallets,
    cipher: cipher,
    random: Random(seed),
    now: () => DateTime.utc(2026, 10, 9),
  );

  test('creates a valid address tied to the encrypted seed', () async {
    final wallets = _MemoryWallets();

    final address = await custodyOver(wallets).create(
      owner: StellarAddress.parse(_owner),
      idempotencyKey: 'deploy-1',
    );

    expect(address.value, startsWith('G'));
    expect(wallets.rows, hasLength(1));
    final row = wallets.rows.single;
    expect(row.address, address);
    expect(row.owner.value, _owner);
    expect(row.idempotencyKey, 'deploy-1');
    expect(row.createdAt, DateTime.utc(2026, 10, 9));
    expect(row.agentId, isNull);

    // The stored secret decrypts (with the address as aad) to a seed that
    // derives the very same address.
    final seed = utf8.decode(
      await cipher.decrypt(row.secret, aad: utf8.encode(address.value)),
    );
    expect(seed, startsWith('S'));
    final derived = stellar.StellarPrivateKey.fromBase32(
      seed,
    ).toPublicKey().toAddress().baseAddress;
    expect(derived, address.value);
    expect(base64.decode(row.secret.ciphertext), isNot(utf8.encode(seed)));
  });

  test('the same idempotency key returns the same wallet', () async {
    final wallets = _MemoryWallets();
    final custody = custodyOver(wallets);

    final first = await custody.create(
      owner: StellarAddress.parse(_owner),
      idempotencyKey: 'deploy-1',
    );
    final second = await custody.create(
      owner: StellarAddress.parse(_owner),
      idempotencyKey: 'deploy-1',
    );

    expect(second, first);
    expect(wallets.rows, hasLength(1));
  });

  test('different keys create different wallets', () async {
    final wallets = _MemoryWallets();
    final custody = custodyOver(wallets);

    final first = await custody.create(
      owner: StellarAddress.parse(_owner),
      idempotencyKey: 'deploy-1',
    );
    final second = await custody.create(
      owner: StellarAddress.parse(_owner),
      idempotencyKey: 'deploy-2',
    );

    expect(first, isNot(second));
    expect(wallets.rows, hasLength(2));
  });
}
