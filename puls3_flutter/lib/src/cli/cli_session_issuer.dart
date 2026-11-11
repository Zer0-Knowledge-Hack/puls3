import 'package:puls3_client/puls3_client.dart' as api;

import '../hire/wallet_session.dart';
import '../wallet/wallet_port.dart';

/// `client.cliSession.create`.
typedef CreateCliSessionCall = Future<api.CliSessionGrant> Function();

/// Issues a CLI session for the connected wallet (#259, ADR-0007 A′): a
/// separate session a program seeds with `PULS3_REFRESH_TOKEN`.
abstract interface class CliSessionIssuer {
  /// A new CLI session for [wallet]. It signs in first when the app has no
  /// session for that wallet yet. The app's own session is not touched.
  Future<api.CliSessionGrant> issue(String wallet);
}

/// [CliSessionIssuer] over `CliSessionEndpoint.create`, on the same wallet
/// session hire and Studio use.
final class ServerCliSessionIssuer implements CliSessionIssuer {
  ServerCliSessionIssuer({
    required this._create,
    required this._session,
    required this._wallet,
  });

  final CreateCliSessionCall _create;
  final WalletSession _session;
  final WalletPort _wallet;

  @override
  Future<api.CliSessionGrant> issue(String wallet) async {
    await _session.ensureSignedIn(wallet, _wallet.signChallenge);
    return _create();
  }
}
