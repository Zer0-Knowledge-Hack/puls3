import 'dart:convert';

import 'package:puls3_server/src/agent/agent_wallet_custody.dart';
import 'package:puls3_server/src/agent/wallet_custody_config.dart';
import 'package:test/test.dart';

void main() {
  test('an unset key makes custody unavailable', () {
    expect(
      () => WalletCustodyConfig.fromEnvironment(const {}),
      throwsA(isA<AgentWalletCustodyUnavailable>()),
    );
  });

  test('a key that is not base64 is rejected', () {
    expect(
      () => WalletCustodyConfig.fromEnvironment({
        'PULS3_AGENT_WALLET_SECRET_KEY': 'not base64!!',
      }),
      throwsArgumentError,
    );
  });

  test('a key that is not 32 bytes is rejected', () {
    expect(
      () => WalletCustodyConfig.fromEnvironment({
        'PULS3_AGENT_WALLET_SECRET_KEY': base64.encode(List<int>.filled(16, 1)),
      }),
      throwsArgumentError,
    );
  });

  test('a 32-byte base64 key is accepted', () {
    final key = List<int>.generate(32, (i) => i);
    final config = WalletCustodyConfig.fromEnvironment({
      'PULS3_AGENT_WALLET_SECRET_KEY': base64.encode(key),
    });

    expect(config.secretKey, key);
    expect(config.keyVersion, 1);
  });
}
