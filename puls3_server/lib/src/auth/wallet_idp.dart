import 'dart:convert';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';

import '../generated/protocol.dart';

/// Binds one Stellar wallet to one Serverpod auth user and issues a session.
///
/// The first sign-in creates the auth user and the `wallet_account` row under
/// a transaction advisory lock, so two concurrent first sign-ins leave one
/// user. A later sign-in reuses that user and issues a new token pair.
/// [mergeAuthUsers] is a no-op: the row belongs to one auth user and is
/// removed with it (`ON DELETE CASCADE`).
final class WalletIdp implements IdentityProvider {
  WalletIdp({
    required TokenManager tokenManager,
    AuthUsers authUsers = const AuthUsers(),
  }) : _tokenManager = tokenManager,
       _authUsers = authUsers;

  /// Method stored on issued tokens.
  static const methodName = 'wallet';

  final TokenManager _tokenManager;
  final AuthUsers _authUsers;

  @override
  String get method => methodName;

  /// Returns a session for [wallet], creating the mapping on first use.
  Future<AuthSuccess> signIn(
    Session session, {
    required String wallet,
    Transaction? transaction,
  }) {
    return DatabaseUtil.runInTransactionOrSavepoint(
      session.db,
      transaction,
      (transaction) async {
        await _lock(session, wallet, transaction);
        final existing = await WalletAccount.db.findFirstRow(
          session,
          where: (t) => t.wallet.equals(wallet),
          transaction: transaction,
        );
        final authUserId =
            existing?.authUserId ??
            (await _authUsers.create(
              session,
              transaction: transaction,
            )).id;
        if (existing == null) {
          await WalletAccount.db.insertRow(
            session,
            WalletAccount(
              wallet: wallet,
              authUserId: authUserId,
              createdAt: DateTime.now().toUtc(),
            ),
            transaction: transaction,
          );
        }
        return _tokenManager.issueToken(
          session,
          authUserId: authUserId,
          method: method,
          transaction: transaction,
        );
      },
    );
  }

  @override
  Future<void> mergeAuthUsers(
    Session session, {
    required UuidValue userToKeepId,
    required UuidValue userToRemoveId,
    required Transaction transaction,
  }) async {}

  Future<void> _lock(
    Session session,
    String wallet,
    Transaction transaction,
  ) async {
    if (session.db.dialect != DatabaseDialect.postgres) return;
    await session.db.unsafeQuery(
      'SELECT pg_advisory_xact_lock(@key)',
      parameters: QueryParameters.named({'key': _lockKey(wallet)}),
      transaction: transaction,
    );
  }
}

/// FNV-1a of [wallet], as a signed 64-bit key. A collision only makes two
/// wallets wait on each other.
int _lockKey(String wallet) {
  const offsetBasis = 0xcbf29ce484222325;
  const prime = 0x100000001b3;
  var hash = offsetBasis;
  for (final unit in utf8.encode(wallet)) {
    hash = (hash ^ unit) * prime;
  }
  return hash.toSigned(64);
}
