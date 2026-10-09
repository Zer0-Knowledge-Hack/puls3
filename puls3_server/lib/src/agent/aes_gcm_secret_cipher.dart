import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'secret_cipher.dart';

/// [SecretCipher] over AES-256-GCM with a random 96-bit nonce per secret.
///
/// A keyring maps each key version to its 32-byte key; [writeKeyVersion] is the
/// one new secrets use. Decryption selects the key by `secret.keyVersion`, so a
/// rotation can keep old versions and reject an unknown one. Decryption
/// authenticates the wallet address as additional data, binding each secret to
/// its row.
final class AesGcmSecretCipher implements SecretCipher {
  AesGcmSecretCipher({
    required Map<int, List<int>> keys,
    required int writeKeyVersion,
  }) : _keys = {
         for (final entry in keys.entries) entry.key: SecretKey(entry.value),
       },
       _writeKeyVersion = writeKeyVersion {
    if (!_keys.containsKey(writeKeyVersion)) {
      throw ArgumentError(
        'writeKeyVersion $writeKeyVersion is not one of the configured keys',
      );
    }
  }

  final Map<int, SecretKey> _keys;
  final int _writeKeyVersion;
  final AesGcm _algorithm = AesGcm.with256bits();

  @override
  int get writeKeyVersion => _writeKeyVersion;

  @override
  Future<EncryptedSecret> encrypt(
    List<int> plaintext, {
    required List<int> aad,
  }) async {
    final nonce = _algorithm.newNonce();
    final box = await _algorithm.encrypt(
      plaintext,
      secretKey: _keys[_writeKeyVersion]!,
      nonce: nonce,
      aad: aad,
    );
    return EncryptedSecret(
      ciphertext: base64.encode(box.cipherText),
      nonce: base64.encode(box.nonce),
      mac: base64.encode(box.mac.bytes),
      keyVersion: _writeKeyVersion,
    );
  }

  @override
  Future<List<int>> decrypt(
    EncryptedSecret secret, {
    required List<int> aad,
  }) async {
    final key = _keys[secret.keyVersion];
    if (key == null) {
      throw SecretDecryptionFailed('unknown key version ${secret.keyVersion}');
    }
    final SecretBox box;
    try {
      box = SecretBox(
        base64.decode(secret.ciphertext),
        nonce: base64.decode(secret.nonce),
        mac: Mac(base64.decode(secret.mac)),
      );
    } on FormatException {
      throw const SecretDecryptionFailed('the secret is not valid base64');
    } on ArgumentError {
      throw const SecretDecryptionFailed('the secret has a malformed nonce');
    }
    try {
      return await _algorithm.decrypt(box, secretKey: key, aad: aad);
    } on SecretBoxAuthenticationError {
      throw const SecretDecryptionFailed('authentication failed');
    }
  }
}
