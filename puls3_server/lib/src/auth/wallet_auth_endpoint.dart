import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';

import '../generated/protocol.dart';
import '../hire/chain_accounts.dart';
import '../ledger/soroban_rpc_client.dart';
import '../ledger/stellar_config.dart';
import 'serverpod_challenge_store.dart';
import 'wallet_auth_config.dart';
import 'wallet_auth_service.dart';

/// SEP-10 wallet sign-in (`client.walletAuth`).
///
/// Both calls are open so a signed-out client can start, and a client that
/// already holds a session can still challenge a different wallet.
class WalletAuthEndpoint extends Endpoint {
  /// Replaces config for tests. `null` reads the process environment.
  static WalletAuthConfig? debugConfig;

  /// Replaces the chain read for tests. `null` uses Soroban RPC.
  static ChainAccounts? debugChain;

  /// Replaces token issuance for tests. `null` uses the JWT manager.
  static TokenManager? debugTokens;

  /// Replaces the clock for tests.
  static DateTime Function()? debugNow;

  /// When set, every auth log line is appended here as well as logged.
  static List<String>? capturedLogs;

  /// Clears the test seams.
  static void resetDebug() {
    debugConfig = null;
    debugChain = null;
    debugTokens = null;
    debugNow = null;
    capturedLogs = null;
  }

  /// A single-use challenge for [wallet].
  @unauthenticatedClientCall
  Future<WalletChallenge> createChallenge(Session session, String wallet) =>
      _service(session).createChallenge(wallet);

  /// A session for the wallet that signed [signedChallengeXdr].
  @unauthenticatedClientCall
  Future<AuthSuccess> verifyChallenge(
    Session session,
    String challengeId,
    String wallet,
    String signedChallengeXdr,
  ) => _service(session).verifyChallenge(
    challengeId,
    wallet,
    signedChallengeXdr,
  );

  WalletAuthService _service(Session session) {
    final now = debugNow;
    return WalletAuthService(
      session: session,
      readConfig: _config,
      store: ServerpodChallengeStore(session, now: now),
      chain: debugChain ?? _chain(),
      tokens:
          debugTokens ??
          JwtConfigFromPasswords().build(authUsers: const AuthUsers()),
      rateLimiter: DatabaseRateLimiter(
        RateLimiterConfig(
          domain: 'puls3_wallet',
          source: 'challenge',
          maxAttempts: 5,
          timeframe: const Duration(minutes: 1),
        ),
      ),
      now: now,
      log: (message, {required bool failure}) {
        session.log(
          message,
          level: failure ? LogLevel.warning : LogLevel.info,
        );
        capturedLogs?.add(message);
      },
    );
  }

  static WalletAuthConfig _config() {
    final override = debugConfig;
    if (override != null) return override;
    return WalletAuthConfig.fromEnvironment(
      Platform.environment,
      signingKey: Serverpod.instance.getPassword('walletAuthSigningKey'),
      runMode: Serverpod.instance.runMode,
    );
  }

  static ChainAccounts? _defaultChain;

  static ChainAccounts _chain() {
    final existing = _defaultChain;
    if (existing != null) return existing;
    final stellar = StellarConfig.fromEnvironment(Platform.environment);
    return _defaultChain = RpcChainAccounts(
      SorobanRpcClient(
        httpClient: http.Client(),
        url: stellar.rpcUrl,
        timeout: const Duration(seconds: 15),
      ),
    );
  }
}
