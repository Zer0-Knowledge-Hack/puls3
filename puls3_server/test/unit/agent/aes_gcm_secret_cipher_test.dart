import 'dart:convert';

import 'package:puls3_server/src/agent/aes_gcm_secret_cipher.dart';
import 'package:puls3_server/src/agent/secret_cipher.dart';
import 'package:test/test.dart';

void main() {
  final key1 = List<int>.generate(32, (i) => i);
  final key2 = List<int>.generate(32, (i) => 255 - i);
  final aad = utf8.encode('GABCWALLET');

  AesGcmSecretCipher cipher({int write = 2}) =>
      AesGcmSecretCipher(keys: {1: key1, 2: key2}, writeKeyVersion: write);

  Future<void> failsToDecrypt(EncryptedSecret secret, {List<int>? withAad}) =>
      expectLater(
        cipher().decrypt(secret, aad: withAad ?? aad),
        throwsA(isA<SecretDecryptionFailed>()),
      );

  test('round-trips a secret and never stores the plaintext', () async {
    final secret = await cipher().encrypt(utf8.encode('SABCSEED'), aad: aad);

    expect(secret.keyVersion, 2);
    expect(base64.decode(secret.ciphertext), isNot(utf8.encode('SABCSEED')));
    expect(utf8.decode(await cipher().decrypt(secret, aad: aad)), 'SABCSEED');
  });

  test('uses a fresh nonce per call', () async {
    final first = await cipher().encrypt([1, 2, 3], aad: aad);
    final second = await cipher().encrypt([1, 2, 3], aad: aad);

    expect(first.nonce, isNot(second.nonce));
    expect(first.ciphertext, isNot(second.ciphertext));
  });

  test('rejects a tampered ciphertext, nonce and tag', () async {
    final secret = await cipher().encrypt([1, 2, 3], aad: aad);

    await failsToDecrypt(
      EncryptedSecret(
        ciphertext: base64.encode([9, 9, 9]),
        nonce: secret.nonce,
        mac: secret.mac,
        keyVersion: secret.keyVersion,
      ),
    );
    await failsToDecrypt(
      EncryptedSecret(
        ciphertext: secret.ciphertext,
        nonce: base64.encode(List<int>.filled(12, 0)),
        mac: secret.mac,
        keyVersion: secret.keyVersion,
      ),
    );
    await failsToDecrypt(
      EncryptedSecret(
        ciphertext: secret.ciphertext,
        nonce: secret.nonce,
        mac: base64.encode(List<int>.filled(16, 0)),
        keyVersion: secret.keyVersion,
      ),
    );
  });

  test('rejects malformed base64, a malformed nonce and truncation', () async {
    await failsToDecrypt(
      const EncryptedSecret(
        ciphertext: 'not base64!!',
        nonce: 'x',
        mac: 'y',
        keyVersion: 2,
      ),
    );

    final secret = await cipher().encrypt([1, 2, 3], aad: aad);
    await failsToDecrypt(
      EncryptedSecret(
        ciphertext: secret.ciphertext,
        nonce: base64.encode([1, 2, 3, 4]),
        mac: secret.mac,
        keyVersion: secret.keyVersion,
      ),
    );
    await failsToDecrypt(
      EncryptedSecret(
        ciphertext: base64.encode(
          base64.decode(secret.ciphertext).sublist(0, 1),
        ),
        nonce: secret.nonce,
        mac: secret.mac,
        keyVersion: secret.keyVersion,
      ),
    );
  });

  test('rejects a different aad (secret copied to another row)', () async {
    final secret = await cipher().encrypt([1, 2, 3], aad: aad);

    await failsToDecrypt(secret, withAad: utf8.encode('GOTHERWALLET'));
  });

  test('rejects an unknown key version', () async {
    final secret = await cipher().encrypt([1, 2, 3], aad: aad);

    await failsToDecrypt(
      EncryptedSecret(
        ciphertext: secret.ciphertext,
        nonce: secret.nonce,
        mac: secret.mac,
        keyVersion: 99,
      ),
    );
  });

  test('a different key cannot decrypt', () async {
    final secret = await cipher().encrypt([1, 2, 3], aad: aad);
    final other = AesGcmSecretCipher(
      keys: {2: List<int>.filled(32, 9)},
      writeKeyVersion: 2,
    );

    await expectLater(
      other.decrypt(secret, aad: aad),
      throwsA(isA<SecretDecryptionFailed>()),
    );
  });

  test('the write key version must be configured', () {
    expect(
      () => AesGcmSecretCipher(keys: {1: key1}, writeKeyVersion: 2),
      throwsArgumentError,
    );
  });
}
