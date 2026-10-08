import 'dart:convert';
import 'dart:math';

import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/agent/aes_gcm_secret_cipher.dart';
import 'package:puls3_server/src/agent/agent_wallet_store.dart';
import 'package:puls3_server/src/agent/secret_cipher.dart';
import 'package:puls3_server/src/agent/stellar_agent_wallet_custody.dart';
import 'package:test/test.dart';

const _owner = 'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H';

final class _MemoryWallets implements AgentWalletStore {
  final rows = <StoredAgentWallet>[];
  int _next = 1;

  @override
  Future<StoredAgentWallet> save({
    required StellarAddress owner,
    required StellarAddress address,
    required EncryptedSecret secret,
    required DateTime createdAt,
  }) async {
    final wallet = StoredAgentWallet(
      id: _next++,
      owner: owner,
      address: address,
      secret: secret,
      createdAt: createdAt,
    );
    rows.add(wallet);
    return wallet;
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
  final cipher = AesGcmSecretCipher(key: List<int>.generate(32, (i) => i));

  StellarAgentWalletCustody custodyOver(_MemoryWallets wallets, {int seed = 7}) =>
      StellarAgentWalletCustody(
        wallets: wallets,
        cipher: cipher,
        random: Random(seed),
        now: () => DateTime.utc(2026, 10, 8),
      );

  test('creates a valid address and stores only the encrypted secret',
      () async {
    final wallets = _MemoryWallets();

    final address = await custodyOver(
      wallets,
    ).create(owner: StellarAddress.parse(_owner));

    expect(address.value, startsWith('G'));
    expect(wallets.rows, hasLength(1));
    final row = wallets.rows.single;
    expect(row.address, address);
    expect(row.owner.value, _owner);
    expect(row.createdAt, DateTime.utc(2026, 10, 8));
    expect(row.agentId, isNull);

    // The stored secret decrypts to an S… seed, and is not stored in the clear.
    final seed = utf8.decode(await cipher.decrypt(row.secret));
    expect(seed, startsWith('S'));
    expect(base64.decode(row.secret.ciphertext), isNot(utf8.encode(seed)));
  });

  test('two calls create two different wallets', () async {
    final wallets = _MemoryWallets();
    final custody = custodyOver(wallets);

    final first = await custody.create(owner: StellarAddress.parse(_owner));
    final second = await custody.create(owner: StellarAddress.parse(_owner));

    expect(first, isNot(second));
    expect(wallets.rows, hasLength(2));
  });

  test('findByAddress returns the stored wallet', () async {
    final wallets = _MemoryWallets();
    final address = await custodyOver(
      wallets,
    ).create(owner: StellarAddress.parse(_owner));

    expect((await wallets.findByAddress(address))?.address, address);
  });
}
