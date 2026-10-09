import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/generated/protocol.dart';
import 'package:puls3_server/src/hire/session_wallet.dart';
import 'package:serverpod/serverpod.dart';

/// Test double that refuses every caller. Production uses [WalletSessionWallet].
final class FailClosedSessionWallet implements SessionWallet {
  const FailClosedSessionWallet();

  @override
  Future<StellarAddress> requireLogin(Session session) async =>
      throw Puls3ApiException(code: 'AuthenticationUnavailable');
}
