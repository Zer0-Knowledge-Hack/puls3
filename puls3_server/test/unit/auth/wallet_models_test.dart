import 'dart:io';

import 'package:puls3_server/src/generated/protocol.dart';
import 'package:test/test.dart';

void main() {
  test('WalletChallenge carries the fields the client signs', () {
    final expiresAt = DateTime.utc(2026, 10, 9, 12);

    final challenge = WalletChallenge(
      challengeId: 'ch-1',
      wallet: 'GABC',
      payload: 'xdr',
      networkPassphrase: 'Test SDF Network ; September 2015',
      expiresAt: expiresAt,
    );

    expect(challenge.challengeId, 'ch-1');
    expect(challenge.wallet, 'GABC');
    expect(challenge.payload, 'xdr');
    expect(
      challenge.networkPassphrase,
      'Test SDF Network ; September 2015',
    );
    expect(challenge.expiresAt, expiresAt);

    final json = challenge.toJson();
    expect(json['challengeId'], 'ch-1');
    expect(json['wallet'], 'GABC');
    expect(json['payload'], 'xdr');
    expect(json['networkPassphrase'], 'Test SDF Network ; September 2015');
  });

  test('stored wallet rows stay off the client protocol', () {
    final client = File(
      '../puls3_client/lib/src/protocol/protocol.dart',
    ).readAsStringSync();

    expect(client, isNot(contains('WalletChallengeRecord')));
    expect(client, isNot(contains('WalletAccount')));
    expect(RegExp(r'\bWalletChallenge\b').hasMatch(client), isTrue);
  });
}
