import 'package:puls3_client/puls3_client.dart' as api;

import '../hire/wallet_session.dart';
import '../wallet/wallet_port.dart';

/// `client.cliSession.create`.
typedef CreateCliSessionCall = Future<api.CliSessionGrant> Function();

/// `client.cliSession.list`.
typedef ListCliSessionsCall = Future<List<api.CliSession>> Function();

/// `client.cliSession.revoke`.
typedef RevokeCliSessionCall = Future<bool> Function(String id);

/// Issues and manages CLI sessions for the connected wallet (#259, ADR-0007
/// A′): a separate session a program seeds with `PULS3_REFRESH_TOKEN`.
abstract interface class CliSessionIssuer {
  /// A new CLI session for [wallet]. It signs in first when the app has no
  /// session for that wallet yet. The app's own session is not touched.
  Future<api.CliSessionGrant> issue(String wallet);

  /// The caller's live CLI sessions for [wallet], oldest first. Empty when
  /// the app has no session for that wallet yet, or when the stored session
  /// belongs to another wallet.
  Future<List<api.CliSession>> list(String wallet);

  /// Revokes the caller's CLI session [id] for [wallet]. False when it is not
  /// one of that wallet's CLI sessions, including the app's own session, or
  /// when the stored session belongs to another wallet.
  Future<bool> revoke(String wallet, String id);
}

/// [CliSessionIssuer] over `CliSessionEndpoint`, on the same wallet session
/// hire and Studio use.
final class ServerCliSessionIssuer implements CliSessionIssuer {
  ServerCliSessionIssuer({
    required this._create,
    required this._list,
    required this._revoke,
    required this._session,
    required this._wallet,
  });

  final CreateCliSessionCall _create;
  final ListCliSessionsCall _list;
  final RevokeCliSessionCall _revoke;
  final WalletSession _session;
  final WalletPort _wallet;

  @override
  Future<api.CliSessionGrant> issue(String wallet) async {
    await _session.ensureSignedIn(wallet, _wallet.signChallenge);
    return _create();
  }

  @override
  Future<List<api.CliSession>> list(String wallet) async {
    if (!await _session.isSignedInAs(wallet)) return const [];
    return _list();
  }

  @override
  Future<bool> revoke(String wallet, String id) async {
    if (!await _session.isSignedInAs(wallet)) return false;
    return _revoke(id);
  }
}
