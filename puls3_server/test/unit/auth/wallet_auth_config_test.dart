import 'package:puls3_server/src/auth/wallet_auth_config.dart';
import 'package:puls3_server/src/generated/protocol.dart';
import 'package:puls3_server/src/ledger/stellar_config.dart';
import 'package:stellar_dart/stellar_dart.dart' as stellar;
import 'package:test/test.dart';

void main() {
  final signingKey = stellar.StellarPrivateKey.fromBytes(
    List<int>.filled(32, 7),
  ).toBase32();
  final serverAccount = stellar.StellarPrivateKey.fromBase32(
    signingKey,
  ).toPublicKey().toAddress().address;

  const domains = {
    'PULS3_AUTH_HOME_DOMAIN': 'puls3.app',
    'PULS3_AUTH_WEB_AUTH_DOMAIN': 'auth.puls3.app',
  };

  test('a configured key, domains and network build a config', () {
    final config = WalletAuthConfig.fromEnvironment(
      {
        ...domains,
        'PULS3_STELLAR_NETWORK_PASSPHRASE':
            'Public Global Stellar Network ; September 2015',
      },
      signingKey: '$signingKey\n',
    );

    expect(config.serverAccount, serverAccount);
    expect(config.homeDomain, 'puls3.app');
    expect(config.webAuthDomain, 'auth.puls3.app');
    expect(
      config.networkPassphrase,
      StellarConfig.fromEnvironment({
        'PULS3_STELLAR_NETWORK_PASSPHRASE':
            'Public Global Stellar Network ; September 2015',
      }).networkPassphrase,
    );
    expect(config.toString(), isNot(contains(signingKey)));
  });

  test('a missing or blank key is unavailable outside production', () {
    for (final key in [null, '', '   ']) {
      expect(
        () => WalletAuthConfig.fromEnvironment(domains, signingKey: key),
        throwsA(
          isA<Puls3ApiException>().having(
            (error) => error.code,
            'code',
            'AuthenticationUnavailable',
          ),
        ),
        reason: '$key',
      );
    }
  });

  test('a blank home or web-auth domain is unavailable', () {
    for (final env in [
      {'PULS3_AUTH_WEB_AUTH_DOMAIN': 'auth.puls3.app'},
      {
        'PULS3_AUTH_HOME_DOMAIN': 'puls3.app',
        'PULS3_AUTH_WEB_AUTH_DOMAIN': ' ',
      },
    ]) {
      expect(
        () => WalletAuthConfig.fromEnvironment(env, signingKey: signingKey),
        throwsA(
          isA<Puls3ApiException>().having(
            (error) => error.code,
            'code',
            'AuthenticationUnavailable',
          ),
        ),
      );
    }
  });

  test('the secret is never read from the environment', () {
    expect(
      () => WalletAuthConfig.fromEnvironment({
        ...domains,
        'walletAuthSigningKey': signingKey,
        'PULS3_AUTH_SIGNING_KEY': signingKey,
      }, signingKey: null),
      throwsA(isA<Puls3ApiException>()),
    );
  });

  test(
    'a value that is not a Stellar secret is rejected without echoing it',
    () {
      const raw = 'not-a-stellar-secret';

      try {
        WalletAuthConfig.fromEnvironment(domains, signingKey: raw);
        fail('expected an ArgumentError');
      } on ArgumentError catch (error) {
        expect(error.toString(), isNot(contains(raw)));
      }
    },
  );

  test('production refuses to start when wallet auth is not configured', () {
    expect(
      () => WalletAuthConfig.ensureProduction(
        domains,
        signingKey: null,
        runMode: 'production',
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('walletAuthSigningKey'),
        ),
      ),
    );
    expect(
      () => WalletAuthConfig.ensureProduction(
        {'PULS3_AUTH_WEB_AUTH_DOMAIN': 'auth.puls3.app'},
        signingKey: signingKey,
        runMode: 'production',
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('PULS3_AUTH_HOME_DOMAIN'),
        ),
      ),
    );
  });

  test('other run modes do not fail at startup', () {
    for (final runMode in ['development', 'staging', 'test']) {
      expect(
        () => WalletAuthConfig.ensureProduction(
          const {},
          signingKey: null,
          runMode: runMode,
        ),
        returnsNormally,
        reason: runMode,
      );
    }
  });

  test('production startup accepts a configured key', () {
    expect(
      () => WalletAuthConfig.ensureProduction(
        domains,
        signingKey: signingKey,
        runMode: 'production',
      ),
      returnsNormally,
    );
  });
}
