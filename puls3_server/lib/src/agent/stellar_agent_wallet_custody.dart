import 'dart:convert';
import 'dart:math';

import 'package:puls3_domain/puls3_domain.dart';
import 'package:stellar_dart/stellar_dart.dart' as stellar;

import 'agent_wallet_custody.dart';
import 'agent_wallet_store.dart';
import 'secret_cipher.dart';

/// Creates a custodied agent wallet with a fresh ed25519 keypair.
///
/// The secret seed is generated from a secure random source, encrypted with
/// [cipher] and stored through [wallets]; the plaintext seed never leaves this
/// method, is never logged and is never returned. Only the public address is.
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
  Future<StellarAddress> create({required StellarAddress owner}) async {
    final seed = List<int>.generate(_seedLength, (_) => _random.nextInt(256));
    final privateKey = stellar.StellarPrivateKey.fromBytes(seed);
    final address = StellarAddress.parse(
      privateKey.toPublicKey().toAddress().baseAddress,
    );
    final secret = await _cipher.encrypt(utf8.encode(privateKey.toBase32()));
    await _wallets.save(
      owner: owner,
      address: address,
      secret: secret,
      createdAt: _now().toUtc(),
    );
    return address;
  }
}

/// ed25519 seed length in bytes.
const _seedLength = 32;
