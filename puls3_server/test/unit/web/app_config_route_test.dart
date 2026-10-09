import 'dart:convert';

import 'package:puls3_server/src/auth/wallet_auth_config.dart';
import 'package:puls3_server/src/web/routes/app_config_route.dart';
import 'package:serverpod/serverpod.dart';
import 'package:stellar_dart/stellar_dart.dart' as stellar;
import 'package:test/test.dart';

void main() {
  final secretKey = stellar.StellarPrivateKey.fromBytes(
    List<int>.filled(32, 7),
  );
  final secret = secretKey.toBase32();
  final address = secretKey.toPublicKey().toAddress().address;
  const network = 'Test SDF Network ; September 2015';

  ServerConfig apiConfig() => ServerConfig(
    port: 8080,
    publicScheme: 'http',
    publicHost: 'localhost',
    publicPort: 8080,
  );

  test('the route output publishes the public auth config', () {
    final config = WalletAuthConfig(
      signingKey: secret,
      serverAccount: address,
      homeDomain: 'puls3.app',
      webAuthDomain: 'auth.puls3.app',
      networkPassphrase: network,
    );
    final route = AppConfigRoute(
      apiConfig: apiConfig(),
      auth: AppAuthPublication.fromConfig(config),
    );

    final body = route.widget.render();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final auth = json['auth'] as Map<String, dynamic>;

    expect(json['apiUrl'], 'http://localhost:8080');
    expect(auth['serverSigningKey'], address);
    expect(auth['serverSigningKey'], startsWith('G'));
    expect(auth['homeDomain'], 'puls3.app');
    expect(auth['webAuthDomain'], 'auth.puls3.app');
    expect(auth['networkPassphrase'], network);
    expect(body.contains(secret), isFalse);
  });

  test('a secret signing key is refused and the error omits it', () {
    expect(
      () => AppAuthPublication(
        serverSigningKey: secret,
        homeDomain: 'puls3.app',
        webAuthDomain: 'auth.puls3.app',
        networkPassphrase: network,
      ),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.message.toString(),
          'message',
          isNot(contains(secret)),
        ),
      ),
    );
  });
}
