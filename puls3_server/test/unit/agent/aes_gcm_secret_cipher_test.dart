import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:puls3_server/src/agent/aes_gcm_secret_cipher.dart';
import 'package:puls3_server/src/agent/secret_cipher.dart';
import 'package:test/test.dart';

void main() {
  final key = List<int>.generate(32, (i) => i);
  AesGcmSecretCipher cipher() => AesGcmSecretCipher(key: key, keyVersion: 3);

  test('round-trips a secret and never stores the plaintext', () async {
    final secret = await cipher().encrypt(utf8.encode('SABCSEED'));

    expect(secret.keyVersion, 3);
    expect(base64.decode(secret.ciphertext), isNot(utf8.encode('SABCSEED')));
    expect(utf8.decode(await cipher().decrypt(secret)), 'SABCSEED');
  });

  test('uses a fresh nonce per call', () async {
    final first = await cipher().encrypt([1, 2, 3]);
    final second = await cipher().encrypt([1, 2, 3]);

    expect(first.nonce, isNot(second.nonce));
    expect(first.ciphertext, isNot(second.ciphertext));
  });

  test('rejects a tampered tag', () async {
    final secret = await cipher().encrypt([1, 2, 3]);
    final tampered = EncryptedSecret(
      ciphertext: secret.ciphertext,
      nonce: secret.nonce,
      mac: base64.encode(List<int>.filled(16, 0)),
      keyVersion: secret.keyVersion,
    );

    await expectLater(
      cipher().decrypt(tampered),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });

  test('a different key cannot decrypt', () async {
    final secret = await cipher().encrypt([1, 2, 3]);
    final other = AesGcmSecretCipher(key: List<int>.filled(32, 9));

    await expectLater(
      other.decrypt(secret),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });
}
