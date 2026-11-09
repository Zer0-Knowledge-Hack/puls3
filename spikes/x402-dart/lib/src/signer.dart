import 'dart:typed_data';

import 'package:stellar_dart/stellar_dart.dart' as stellar;

/// Signs Soroban authorization payloads for one Stellar account.
abstract interface class AuthSigner {
  /// The account address (`G…`).
  String get address;

  /// The 32-byte ed25519 public key.
  Uint8List get publicKey;

  /// The 64-byte ed25519 signature of [payload].
  Uint8List sign(Uint8List payload);
}

/// An [AuthSigner] backed by a secret key (`S…`).
///
/// [toString] shows only the address, so the secret cannot reach output by
/// accident.
final class SecretKeySigner implements AuthSigner {
  SecretKeySigner._(this._key, this.address, this.publicKey);

  /// Parses [secret]. Throws [FormatException] without echoing it.
  factory SecretKeySigner.fromSecret(String secret) {
    final stellar.StellarPrivateKey key;
    try {
      key = stellar.StellarPrivateKey.fromBase32(secret.trim());
    } on Object {
      throw const FormatException(
        'the secret key file does not hold an S… key',
      );
    }
    final public = key.toPublicKey();
    return SecretKeySigner._(
      key,
      public.toAddress().baseAddress,
      Uint8List.fromList(public.toBytes()),
    );
  }

  final stellar.StellarPrivateKey _key;

  @override
  final String address;

  @override
  final Uint8List publicKey;

  @override
  Uint8List sign(Uint8List payload) =>
      Uint8List.fromList(_key.sign(payload).signature);

  @override
  String toString() => 'SecretKeySigner($address)';
}
