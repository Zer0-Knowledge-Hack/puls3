import 'package:puls3_domain/puls3_domain.dart';
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';

/// The wallet bound to the caller's session (api.md, "Auth").
///
/// Every `Auth: Yes` endpoint method resolves its caller here before doing
/// any work, compares any wallet address parameter with the result
/// (`WalletMismatch`) and checks resource ownership against it.
abstract interface class SessionWallet {
  /// The wallet of [session], or throws when the caller is not logged in.
  Future<StellarAddress> requireLogin(Session session);
}

/// Resolves the wallet from `wallet_account` for the authenticated user.
///
/// No session, or an auth user with no row, is [NotAuthorizedException]
/// (HTTP 401), so the client repeats the challenge. It never trusts an
/// address supplied by the caller.
final class WalletSessionWallet implements SessionWallet {
  const WalletSessionWallet();

  @override
  Future<StellarAddress> requireLogin(Session session) async {
    final userIdentifier = session.authenticated?.userIdentifier;
    if (userIdentifier == null) {
      throw NotAuthorizedException(
        reason: AuthenticationFailureReason.unauthenticated,
      );
    }

    final row = await WalletAccount.db.findFirstRow(
      session,
      where: (t) =>
          t.authUserId.equals(UuidValue.withValidation(userIdentifier)),
    );
    if (row == null) {
      throw NotAuthorizedException(
        reason: AuthenticationFailureReason.unauthenticated,
      );
    }
    return StellarAddress.parse(row.wallet);
  }
}
