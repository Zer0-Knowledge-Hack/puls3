import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'secret_cipher.dart';

/// [SecretCipher] over AES-256-GCM with a random 96-bit nonce per secret.
///
/// The authentication tag is kept (base64 today) so a tampered or truncated
/// ciphertext fails to decrypt instead of yielding a wrong seed.
final class AesGcmSecretCipher implements SecretCipher {
  AesGcmSecretCipher({required List<int> key, this.keyVersion = 1})
    : _secretKey = SecretKey(key);

  final SecretKey _secretKey;
  final AesGcm _algorithm = AesGcm.with256bits();

  @override
  final int keyVersion;

  @override
  Future<EncryptedSecret> encrypt(List<int> plaintext) async {
    final nonce = _algorithm.newNonce();
    final box = await _algorithm.encrypt(
      plaintext,
      secretKey: _secretKey,
      nonce: nonce,
    );
    return EncryptedSecret(
      ciphertext: base64.encode(box.cipherText),
      nonce: base64.encode(box.nonce),
      mac: base64.encode(box.mac.bytes),
      keyVersion: keyVersion,
    );
  }

  @override
  Future<List<int>> decrypt(EncryptedSecret secret) async {
    final box = SecretBox(
      base64.decode(secret.ciphertext),
      nonce: base64.decode(secret.nonce),
      mac: Mac(base64.decode(secret.mac)),
    );
    return _algorithm.decrypt(box, secretKey: _secretKey);
  }
}
