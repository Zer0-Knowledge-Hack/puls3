import 'dart:convert';

import 'package:serverpod/serverpod.dart';

import '../agent/secret_cipher.dart';
import '../generated/protocol.dart';
import 'builder_credential.dart';

/// PostgreSQL unique-violation SQLSTATE.
const _uniqueViolation = '23505';

/// PostgreSQL-backed [BuilderCredentialStore] (#235). One row per owner and
/// provider; saving again replaces it.
///
/// The secret is encrypted with [cipher] and authenticated with the owner and
/// provider, so a row copied to another builder no longer decrypts. A row
/// that does not decrypt (an unknown key version, a wrong key, tampering) is
/// treated as no credential: the run fails as a missing credential, and the
/// builder's next save replaces the row. It never falls back to another
/// credential.
final class ServerpodBuilderCredentialStore implements BuilderCredentialStore {
  ServerpodBuilderCredentialStore(
    this.session, {
    required SecretCipher cipher,
    DateTime Function() now = DateTime.now,
  }) : _cipher = cipher,
       _now = now;

  final Session session;
  final SecretCipher _cipher;
  final DateTime Function() _now;

  @override
  Future<BuilderProviderCredential?> find({
    required String owner,
    required String provider,
  }) async {
    final row = await _row(owner, provider);
    if (row == null) return null;
    final List<int> secret;
    try {
      secret = await _cipher.decrypt(
        EncryptedSecret(
          ciphertext: row.ciphertext,
          nonce: row.nonce,
          mac: row.mac,
          keyVersion: row.keyVersion,
        ),
        aad: _aad(owner, provider),
      );
    } on SecretDecryptionFailed {
      session.log(
        'A builder credential could not be decrypted '
        '(provider $provider, key version ${row.keyVersion}); '
        'treated as missing',
        level: LogLevel.warning,
      );
      return null;
    }
    return BuilderProviderCredential(
      provider: row.provider,
      secret: utf8.decode(secret),
      accountId: row.accountId,
    );
  }

  @override
  Future<void> save({
    required String owner,
    required BuilderProviderCredential credential,
  }) async {
    final provider = credential.provider;
    final encrypted = await _cipher.encrypt(
      utf8.encode(credential.secret),
      aad: _aad(owner, provider),
    );
    final row = BuilderCredentialRecord(
      owner: owner,
      provider: provider,
      accountId: credential.accountId,
      ciphertext: encrypted.ciphertext,
      nonce: encrypted.nonce,
      mac: encrypted.mac,
      keyVersion: encrypted.keyVersion,
      updatedAt: _now().toUtc(),
    );
    final existing = await _row(owner, provider);
    if (existing != null) {
      await BuilderCredentialRecord.db.updateRow(
        session,
        row.copyWith(id: existing.id),
      );
      return;
    }
    try {
      await BuilderCredentialRecord.db.insertRow(session, row);
    } on DatabaseQueryException catch (e) {
      // Two saves raced and the other one inserted first: this one wins.
      if (e.code != _uniqueViolation) rethrow;
      final winner = await _row(owner, provider);
      if (winner == null) rethrow;
      await BuilderCredentialRecord.db.updateRow(
        session,
        row.copyWith(id: winner.id),
      );
    }
  }

  Future<BuilderCredentialRecord?> _row(String owner, String provider) =>
      BuilderCredentialRecord.db.findFirstRow(
        session,
        where: (t) => t.owner.equals(owner) & t.provider.equals(provider),
      );
}

/// The GCM additional data that binds a secret to its owner and provider.
List<int> _aad(String owner, String provider) =>
    utf8.encode('builder-credential|$owner|$provider');
