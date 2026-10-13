/// Authenticated encryption of agent wallet secrets at rest (ADR-0003
/// decision 4, #18): the server must never store an agent secret in plain text.
///
/// The port keeps the cryptography out of the custody logic so tests can use a
/// deterministic fake and a key can be rotated via [EncryptedSecret.keyVersion].
library;

/// One encrypted secret. [ciphertext], [nonce] and [mac] are base64;
/// [keyVersion] is the key that produced them.
final class EncryptedSecret {
  const EncryptedSecret({
    required this.ciphertext,
    required this.nonce,
    required this.mac,
    required this.keyVersion,
  });

  /// The ciphertext bytes.
  final String ciphertext;

  /// The nonce/IV.
  final String nonce;

  /// The authentication tag.
  final String mac;

  /// The key version that produced this value.
  final int keyVersion;
}

/// A secret could not be decrypted: the key version is unknown, the value is
/// malformed, or authentication failed (wrong key or tampering).
final class SecretDecryptionFailed implements Exception {
  const SecretDecryptionFailed(this.message);

  final String message;

  @override
  String toString() => 'SecretDecryptionFailed: $message';
}

/// Encrypts and decrypts agent wallet secrets.
abstract interface class SecretCipher {
  /// The key version [encrypt] writes. It is stored with each secret.
  int get writeKeyVersion;

  /// Encrypts [plaintext], authenticated with [aad] (the wallet address, so a
  /// secret copied to another row no longer decrypts).
  Future<EncryptedSecret> encrypt(List<int> plaintext, {required List<int> aad});

  /// Decrypts [secret], authenticated with the same [aad] used to encrypt it.
  ///
  /// Throws [SecretDecryptionFailed] when the key version is unknown, the value
  /// is malformed, or authentication fails.
  Future<List<int>> decrypt(EncryptedSecret secret, {required List<int> aad});
}
