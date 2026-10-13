import 'package:puls3_client/puls3_client.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart'
    show AuthSuccess;

import '../wallet/wallet_port.dart';

/// `client.walletAuth.createChallenge`.
typedef CreateChallengeCall = Future<WalletChallenge> Function(String wallet);

/// `client.walletAuth.verifyChallenge`.
typedef VerifyChallengeCall =
    Future<AuthSuccess> Function(
      String challengeId,
      String wallet,
      String signedChallengeXdr,
    );

/// Signs a SEP-10 challenge with the connected wallet, typically
/// `WalletController.signChallenge`.
typedef ChallengeSigner = Future<String> Function(SignInChallenge challenge);

/// Remembers which wallet the stored Serverpod session belongs to, so a
/// restored session is reused only for that same wallet.
abstract interface class SessionWalletStore {
  Future<String?> read();
  Future<void> write(String? wallet);
}

/// [SessionWalletStore] in memory. A reload forgets it, so the first hire
/// after a reload signs in again.
final class InMemorySessionWalletStore implements SessionWalletStore {
  String? _wallet;

  @override
  Future<String?> read() async => _wallet;

  @override
  Future<void> write(String? wallet) async => _wallet = wallet;
}

/// The wallet-bound Serverpod session (#136, api.md "Wallet session
/// lifecycle", F1-2/F1-3): the server issues a SEP-10 challenge, the wallet
/// signs it, and the server answers with the session credentials, which the
/// client's auth session manager stores and sends on every call.
///
/// The Serverpod calls are injected, so the class is tested without a
/// server; `main.dart` passes `client.walletAuth` and `client.auth`.
class WalletSession {
  WalletSession({
    required this._createChallenge,
    required this._verifyChallenge,
    required this._isAuthenticated,
    required this._storeSession,
    SessionWalletStore? walletStore,
    this.serverSigningKey,
    this.homeDomain,
  }) : _walletStore = walletStore ?? InMemorySessionWalletStore();

  final CreateChallengeCall _createChallenge;
  final VerifyChallengeCall _verifyChallenge;
  final bool Function() _isAuthenticated;
  final Future<void> Function(AuthSuccess? authSuccess) _storeSession;
  final SessionWalletStore _walletStore;

  /// From `config.json` `auth` when the app has it; checked by the wallet.
  final String? serverSigningKey;
  final String? homeDomain;

  /// Makes sure the stored session belongs to [wallet], signing in with
  /// [sign] when it does not. A session of another wallet is dropped first.
  ///
  /// Throws a `WalletException` from the wallet (for example when the user
  /// declines) or a `Puls3ApiException` from the server, unchanged, so the
  /// caller maps them like every other call.
  Future<void> ensureSignedIn(String wallet, ChallengeSigner sign) async {
    if (_isAuthenticated() && await _walletStore.read() == wallet) return;
    await forget();
    final challenge = await _createChallenge(wallet);
    if (challenge.wallet != wallet) {
      throw const WalletInvalidPayload(
        'The sign-in challenge is for another account.',
      );
    }
    final signed = await sign(
      SignInChallenge(
        transactionXdr: challenge.payload,
        networkPassphrase: challenge.networkPassphrase,
        serverSigningKey: serverSigningKey,
        homeDomain: homeDomain,
      ),
    );
    final session = await _verifyChallenge(
      challenge.challengeId,
      wallet,
      signed,
    );
    await _storeSession(session);
    await _walletStore.write(wallet);
  }

  /// Drops the stored session, for example after the server refused it.
  /// The next [ensureSignedIn] signs in again.
  Future<void> forget() async {
    if (_isAuthenticated()) await _storeSession(null);
    await _walletStore.write(null);
  }
}
