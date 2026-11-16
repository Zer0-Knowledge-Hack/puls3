import 'dart:convert';

import 'package:puls3_server/src/agent/agent_wallet_custody.dart';
import 'package:puls3_server/src/agent/wallet_custody_config.dart';
import 'package:test/test.dart';

void main() {
  test('an unset or blank key makes custody unavailable', () {
    expect(
      () => WalletCustodyConfig.fromEnvironment(const {}),
      throwsA(isA<AgentWalletCustodyUnavailable>()),
    );
    expect(
      () => WalletCustodyConfig.fromEnvironment(const {
        'PULS3_AGENT_WALLET_SECRET_KEY': '   ',
      }),
      throwsA(isA<AgentWalletCustodyUnavailable>()),
    );
  });

  test('a wrong-length key is rejected without echoing the value', () {
    const secret = 'AAAABBBBCCCCDDDD'; // valid base64, 12 bytes

    try {
      WalletCustodyConfig.fromEnvironment(const {
        'PULS3_AGENT_WALLET_SECRET_KEY': secret,
      });
      fail('expected an ArgumentError');
    } on ArgumentError catch (e) {
      expect(e.toString(), isNot(contains(secret)));
    }
  });

  test('a non-base64 key is rejected without echoing the value', () {
    const secret = 'not base64!!';

    try {
      WalletCustodyConfig.fromEnvironment(const {
        'PULS3_AGENT_WALLET_SECRET_KEY': secret,
      });
      fail('expected an ArgumentError');
    } on ArgumentError catch (e) {
      expect(e.toString(), isNot(contains(secret)));
    }
  });

  group('the Serverpod password', () {
    final passwordKey = List<int>.generate(32, (i) => 100 + i);
    final envKey = List<int>.generate(32, (i) => i);

    test('wins over the environment variable', () {
      final config = WalletCustodyConfig.fromEnvironment({
        'PULS3_AGENT_WALLET_SECRET_KEY': base64.encode(envKey),
      }, password: base64.encode(passwordKey));

      expect(config.secretKey, passwordKey);
    });

    test('is used alone, with no environment variable', () {
      final config = WalletCustodyConfig.fromEnvironment(
        const {},
        password: '${base64.encode(passwordKey)}\n',
      );

      expect(config.secretKey, passwordKey);
    });

    test('falls back to the environment variable when blank or unset', () {
      for (final password in [null, '', '  ']) {
        final config = WalletCustodyConfig.fromEnvironment({
          'PULS3_AGENT_WALLET_SECRET_KEY': base64.encode(envKey),
        }, password: password);

        expect(config.secretKey, envKey, reason: 'password: $password');
      }
    });

    test('is validated like the variable, without echoing the value', () {
      const secret = 'AAAABBBBCCCCDDDD'; // valid base64, 12 bytes

      try {
        WalletCustodyConfig.fromEnvironment(const {}, password: secret);
        fail('expected an ArgumentError');
      } on ArgumentError catch (e) {
        expect(e.toString(), isNot(contains(secret)));
        expect(e.toString(), contains(agentWalletSecretKeyPassword));
      }
    });

    test('names both sources when neither is set', () {
      expect(
        () => WalletCustodyConfig.fromEnvironment(const {}, password: null),
        throwsA(
          isA<AgentWalletCustodyUnavailable>().having(
            (e) => e.toString(),
            'message',
            allOf(
              contains(agentWalletSecretKeyPassword),
              contains('PULS3_AGENT_WALLET_SECRET_KEY'),
            ),
          ),
        ),
      );
    });
  });

  test('a 32-byte key is accepted, and a trailing newline is trimmed', () {
    final key = List<int>.generate(32, (i) => i);
    final config = WalletCustodyConfig.fromEnvironment({
      'PULS3_AGENT_WALLET_SECRET_KEY': '${base64.encode(key)}\n',
    });

    expect(config.secretKey, key);
    expect(config.keyVersion, 1);
  });
}
