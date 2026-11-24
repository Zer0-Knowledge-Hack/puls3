import 'dart:convert';
import 'dart:math';

import 'package:puls3_server/src/agent/aes_gcm_secret_cipher.dart';
import 'package:puls3_server/src/agent/serverpod_agent_wallet_store.dart';
import 'package:serverpod/serverpod.dart' show Session;

import 'local_sandbox.dart';

/// Stores [agent]'s key in server custody: one encrypted `agent_wallet` row,
/// as a Studio deploy leaves it.
///
/// `createHire` refuses an agent whose payee wallet has no custody row
/// (#276), so a suite agent registered from a Stellar CLI key must be stored
/// before it can be hired. The cipher key is random per run: nothing in an
/// E2E run decrypts the row, and no real custody key is involved.
///
/// [cipher] seals the row; a suite that signs as the agent through the
/// server's custody signer passes the one it hands the signer. Without it the
/// key is random and nothing can decrypt the row.
Future<void> custodyAgentKey(
  Session session,
  E2eAccount agent, {
  AesGcmSecretCipher? cipher,
}) async {
  cipher ??= randomCustodyCipher();
  final secret = await cipher.encrypt(
    utf8.encode(agent.secretSeed),
    aad: utf8.encode(agent.address.value),
  );
  await ServerpodAgentWalletStore(session).save(
    owner: agent.address,
    address: agent.address,
    idempotencyKey: 'e2e-${agent.address.value}',
    secret: secret,
    createdAt: DateTime.now().toUtc(),
  );
}

/// A custody cipher with a random key, for one run.
AesGcmSecretCipher randomCustodyCipher() {
  final random = Random.secure();
  return AesGcmSecretCipher(
    keys: {1: List<int>.generate(32, (_) => random.nextInt(256))},
    writeKeyVersion: 1,
  );
}
