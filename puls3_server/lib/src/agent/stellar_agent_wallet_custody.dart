import 'dart:convert';
import 'dart:math';

import 'package:puls3_domain/puls3_domain.dart';
import 'package:stellar_dart/stellar_dart.dart' as stellar;

import '../ledger/envelope_codec.dart';
import '../ledger/stellar_envelope_codec.dart';
import 'agent_wallet_custody.dart';
import 'agent_wallet_store.dart';
import 'secret_cipher.dart';

/// Creates a custodied agent wallet with a fresh ed25519 keypair.
///
/// The secret seed is generated from a secure random source, encrypted with
/// [cipher] and stored through [wallets]; the plaintext seed never leaves this
/// method, is never logged and is never returned. Only the public address is.
///
/// Creation is idempotent per [AgentWalletCustody.create]'s key: the same key
/// returns the same wallet, so a retry cannot orphan a funded account.
final class StellarAgentWalletCustody implements AgentWalletCustody {
  StellarAgentWalletCustody({
    required AgentWalletStore wallets,
    required SecretCipher cipher,
    Random? random,
    DateTime Function()? now,
  }) : _wallets = wallets,
       _cipher = cipher,
       _random = random ?? Random.secure(),
       _now = now ?? DateTime.now;

  final AgentWalletStore _wallets;
  final SecretCipher _cipher;
  final Random _random;
  final DateTime Function() _now;

  @override
  Future<StellarAddress> create({
    required StellarAddress owner,
    required String idempotencyKey,
  }) async {
    final existing = await _wallets.findByIdempotencyKey(idempotencyKey);
    if (existing != null) return existing.address;

    final seed = List<int>.generate(_seedLength, (_) => _random.nextInt(256));
    final privateKey = stellar.StellarPrivateKey.fromBytes(seed);
    final address = StellarAddress.parse(
      privateKey.toPublicKey().toAddress().baseAddress,
    );
    final secret = await _cipher.encrypt(
      utf8.encode(privateKey.toBase32()),
      aad: utf8.encode(address.value),
    );
    try {
      await _wallets.save(
        owner: owner,
        address: address,
        idempotencyKey: idempotencyKey,
        secret: secret,
        createdAt: _now().toUtc(),
      );
      return address;
    } on AgentWalletConflict {
      // A concurrent create won the race; return its wallet.
      final won = await _wallets.findByIdempotencyKey(idempotencyKey);
      if (won != null) return won.address;
      rethrow;
    }
  }
}

/// ed25519 seed length in bytes.
const _seedLength = 32;

/// Signs a prepared envelope with a custodied agent key.
///
/// The plaintext seed is decrypted inside this adapter and never returned.
abstract interface class AgentEnvelopeSigner {
  Future<String> sign(PreparedEnvelope envelope, StellarAddress address);
}

/// [AgentEnvelopeSigner] over the encrypted rows [custody] stored.
final class CustodiedEnvelopeSigner implements AgentEnvelopeSigner {
  CustodiedEnvelopeSigner({
    required AgentWalletStore wallets,
    required SecretCipher cipher,
    required StellarEnvelopeCodec codec,
  }) : _wallets = wallets,
       _cipher = cipher,
       _codec = codec;

  final AgentWalletStore _wallets;
  final SecretCipher _cipher;
  final StellarEnvelopeCodec _codec;

  @override
  Future<String> sign(PreparedEnvelope envelope, StellarAddress address) async {
    final stored = await _wallets.findByAddress(address);
    if (stored == null) {
      throw const AgentWalletCustodyUnavailable(
        'No custodied key for this agent wallet',
      );
    }
    final seed = await _cipher.decrypt(
      stored.secret,
      aad: utf8.encode(address.value),
    );
    final key = stellar.StellarPrivateKey.fromBase32(utf8.decode(seed));
    return _codec.sign(envelope, key);
  }
}
