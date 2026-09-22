import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_flutter/src/data/agent_repository.dart';
import 'package:puls3_flutter/src/domain/agent_filter.dart';
import 'package:puls3_flutter/src/domain/stellar_format.dart';
import 'package:puls3_flutter/src/domain/usdc.dart';

void main() {
  group('USDC', () {
    test('formats stroops with integer math', () {
      expect(formatUsdc(5000000), '0.50');
      expect(formatUsdc(45000000), '4.50');
      expect(formatUsdc(10000000), '1.00');
      expect(formatUsdc(12345678), '1.2345678');
      expect(formatUsdc(0), '0.00');
    });

    test('parses user input into stroops', () {
      expect(parseUsdcToStroops('0.50'), 5000000);
      expect(parseUsdcToStroops('.5'), 5000000);
      expect(parseUsdcToStroops('12'), 120000000);
      expect(parseUsdcToStroops('1.2345678'), 12345678);
      expect(parseUsdcToStroops('1.23456789'), isNull);
      expect(parseUsdcToStroops('abc'), isNull);
      expect(parseUsdcToStroops(''), isNull);
    });
  });

  test('shortenAddress keeps head and tail', () {
    expect(
      shortenAddress(
        'GCDSVE4MGRNDOWEP7HX7HGMECBFAZPDI2J5PDGWDLOLLLIUIXFFSQFXZ',
      ),
      'GCDS…QFXZ',
    );
  });

  test('fake ids have Stellar-like shapes', () {
    final ids = FakeLedgerIds();
    expect(ids.accountAddress(), matches(RegExp(r'^G[A-D][A-Z2-7]{54}$')));
    expect(ids.contractId(), matches(RegExp(r'^C[A-D][A-Z2-7]{54}$')));
    expect(ids.txHash(), matches(RegExp(r'^[0-9a-f]{64}$')));
  });

  test('demo_agents.json has 8 valid agents', () {
    final raw = File('assets/mock/demo_agents.json').readAsStringSync();
    final agents = AssetAgentRepository.parseAgents(raw);

    expect(agents, hasLength(8));
    expect(agents.map((a) => a.id).toSet(), hasLength(8));
    for (final a in agents) {
      expect(a.stellarAddress, matches(RegExp(r'^G[A-D][A-Z2-7]{54}$')));
      expect(a.priceUsdcStroops, isPositive);
      expect(a.skills, isNotEmpty);
    }
    expect(filterAgents(agents, query: 'soroban'), isNotEmpty);
    expect(filterAgents(agents, skills: {'Payments'}), hasLength(2));
  });
}
