import 'package:puls3_server/src/generated/protocol.dart';
import 'package:puls3_server/src/ledger/stellar_config.dart';
import 'package:stellar_dart/stellar_dart.dart' as stellar;

/// SEP-10 server signing configuration (ADR-0003, #136).
///
/// The signing key is the Serverpod password `walletAuthSigningKey` (an `S…`
/// secret). It is never read from the environment, logged, or included in
/// [toString]. Home and web-auth domains are public (`PULS3_AUTH_HOME_DOMAIN`,
/// `PULS3_AUTH_WEB_AUTH_DOMAIN`). The network passphrase comes from
/// [StellarConfig].
///
/// Production refuses to start while any of those is missing
/// ([ensureProduction]). Other run modes leave the process up and
/// [fromEnvironment] answers [Puls3ApiException] `AuthenticationUnavailable`
/// so the challenge call can fail closed.
final class WalletAuthConfig {
  const WalletAuthConfig({
    required this.signingKey,
    required this.serverAccount,
    required this.homeDomain,
    required this.webAuthDomain,
    required this.networkPassphrase,
  });

  /// Throws in production when the signing key or a public domain is missing
  /// or blank. Other run modes return without reading the values, so local
  /// and test servers still boot.
  static void ensureProduction(
    Map<String, String> env, {
    required String? signingKey,
    required String runMode,
  }) {
    if (runMode != 'production') return;
    WalletAuthConfig.fromEnvironment(
      env,
      signingKey: signingKey,
      runMode: runMode,
    );
  }

  /// Reads public auth settings from [env] and the Serverpod password
  /// [signingKey].
  ///
  /// Throws [Puls3ApiException] `AuthenticationUnavailable` when the key or a
  /// domain is missing, except in production, where it throws [StateError] so
  /// startup fails with a configuration error. A key that is not a Stellar
  /// secret throws [ArgumentError] and the message does not contain the value.
  factory WalletAuthConfig.fromEnvironment(
    Map<String, String> env, {
    required String? signingKey,
    String runMode = 'development',
  }) {
    final key = signingKey?.trim();
    final home = _public(env, 'PULS3_AUTH_HOME_DOMAIN');
    final web = _public(env, 'PULS3_AUTH_WEB_AUTH_DOMAIN');
    final missing = <String>[
      if (key == null || key.isEmpty) 'walletAuthSigningKey',
      if (home == null) 'PULS3_AUTH_HOME_DOMAIN',
      if (web == null) 'PULS3_AUTH_WEB_AUTH_DOMAIN',
    ];
    if (missing.isNotEmpty) {
      if (runMode == 'production') {
        throw StateError(
          'Wallet auth is not configured: ${missing.join(', ')}',
        );
      }
      throw Puls3ApiException(
        code: 'AuthenticationUnavailable',
        message: 'Wallet auth is not configured',
      );
    }

    final account = _accountFor(key!);
    return WalletAuthConfig(
      signingKey: account.secret,
      serverAccount: account.address,
      homeDomain: home!,
      webAuthDomain: web!,
      networkPassphrase: StellarConfig.fromEnvironment(
        env,
      ).networkPassphrase,
    );
  }

  /// Stellar secret seed (`S…`). Never log this.
  final String signingKey;

  /// Public account (`G…`) of [signingKey].
  final String serverAccount;

  final String homeDomain;
  final String webAuthDomain;
  final String networkPassphrase;

  @override
  String toString() =>
      'WalletAuthConfig(server: $serverAccount, home: $homeDomain, '
      'web: $webAuthDomain)';
}

String? _public(Map<String, String> env, String name) {
  final value = env[name]?.trim();
  if (value == null || value.isEmpty) return null;
  return value;
}

({String secret, String address}) _accountFor(String raw) {
  try {
    final key = stellar.StellarPrivateKey.fromBase32(raw);
    return (
      secret: key.toBase32(),
      address: key.toPublicKey().toAddress().address,
    );
  } on Object {
    throw ArgumentError('walletAuthSigningKey must be a Stellar secret key');
  }
}
