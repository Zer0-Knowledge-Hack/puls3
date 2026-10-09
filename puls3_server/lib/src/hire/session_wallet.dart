import 'package:puls3_domain/puls3_domain.dart';
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';

/// The wallet bound to the caller's session (api.md, "Auth").
///
/// Every `Auth: Yes` endpoint method resolves its caller here before doing
/// any work, compares any wallet address parameter with the result
/// (`WalletMismatch`) and checks resource ownership against it. Real wallet
/// sessions arrive with #25, which supplies the production implementation.
abstract interface class SessionWallet {
  /// The wallet of [session], or throws when the caller is not logged in.
  Future<StellarAddress> requireLogin(Session session);
}

/// The production binding until #25 lands. It fails closed: no caller can be
/// identified, so every method that requires a session raises
/// `AuthenticationUnavailable` instead of trusting a client-supplied wallet.
final class FailClosedSessionWallet implements SessionWallet {
  const FailClosedSessionWallet();

  @override
  Future<StellarAddress> requireLogin(Session session) async =>
      throw Puls3ApiException(code: 'AuthenticationUnavailable');
}
