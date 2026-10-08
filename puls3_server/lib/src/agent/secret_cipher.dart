/// Authenticated encryption of agent wallet secrets at rest (ADR-0003
/// decision 4, #18): the server must never store an agent secret in plain
/// text.
///
/// The port keeps the cryptography out of the custody logic so tests can use a
/// deterministic fake and a key can be rotated via [EncryptedSecret.keyVersion].
library;

/// One encrypted secret. Every field is base64.
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

/// Encrypts and decrypts agent wallet secrets.
abstract interface class SecretCipher {
  /// The key version this cipher writes. It is stored with each secret.
  int get keyVersion;

  /// Encrypts [plaintext]. The result never equals [plaintext].
  Future<EncryptedSecret> encrypt(List<int> plaintext);

  /// Decrypts [secret]. Throws when the key is wrong or the value was
  /// tampered with.
  Future<List<int>> decrypt(EncryptedSecret secret);
}
