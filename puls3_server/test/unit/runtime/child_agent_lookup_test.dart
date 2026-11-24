import 'dart:convert';
import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;
import 'package:puls3_server/src/agent/hidden_agents.dart';
import 'package:puls3_server/src/generated/protocol.dart'
    show AgentCatalogUnavailable, AgentSummary;
import 'package:puls3_server/src/ledger/ledger_errors.dart';
import 'package:puls3_server/src/runtime/child_agent_lookup.dart';
import 'package:puls3_server/src/runtime/escrow_subcontract_port.dart'
    show ChildAgentLookup;
import 'package:test/test.dart';

import '../../support/relay_rig.dart';

void main() {
  late RelayRig rig;
  var unpublished = <int>{};
  var hidden = HiddenAgents.none;
  var found = <int, Object?>{7: agentSummary};

  Uint8List utf8Bytes(String text) => Uint8List.fromList(utf8.encode(text));

  ChildAgentLookup lookup() => childAgentLookup(
    agentOf: (id) async {
      final entry = found[id];
      if (entry is Exception) throw entry;
      return entry as AgentSummary?;
    },
    registry: rig.ledger,
    custody: rig.custodyOf,
    unpublished: (ids) async => unpublished.intersection(ids),
    hidden: hidden,
  );

  setUp(() {
    rig = RelayRig();
    rig.ledger.metadata[7] = {'puls3.manifestVersion': utf8Bytes('3')};
    unpublished = {};
    hidden = HiddenAgents.none;
    found = {7: agentSummary};
  });

  test(
    'a hireable agent resolves to its live wallet, version and price',
    () async {
      final agent = await lookup()(7);

      expect(agent, isNotNull);
      expect(agent!.wallet.value, agentWallet);
      expect(agent.manifestVersion, 3);
      expect(agent.priceStroops, price);
    },
  );

  test('the wallet is read live, never taken from the catalog', () async {
    rig.ledger.wallets[7] = StellarAddress.parse(stranger);
    rig.custodied.add(stranger);

    expect((await lookup()(7))!.wallet.value, stranger);
  });

  test(
    'an unknown agent, a missing wallet or a hidden agent is null',
    () async {
      expect(await lookup()(8), isNull);

      rig.ledger.wallets.remove(7);
      expect(await lookup()(7), isNull);

      rig.ledger.wallets[7] = StellarAddress.parse(agentWallet);
      hidden = HiddenAgents.fromEnvironment({
        hiddenAgentIdsKey: '7',
      });
      expect(await lookup()(7), isNull);
    },
  );

  test('an agent the server cannot deliver is null', () async {
    rig.custodied.clear();
    expect(await lookup()(7), isNull, reason: 'wallet not custodied');

    rig.custodied.add(agentWallet);
    unpublished = {7};
    expect(await lookup()(7), isNull, reason: 'unpublished Studio agent');
  });

  test('a missing or malformed manifest version is null', () async {
    for (final raw in [null, '', 'x', '0', '-1']) {
      rig.ledger.metadata[7] = {
        if (raw != null) 'puls3.manifestVersion': utf8Bytes(raw),
      };
      expect(await lookup()(7), isNull, reason: '$raw');
    }
  });

  test('a chain read failure stays a LedgerException', () async {
    rig.ledger.walletError = const LedgerUnavailable('node down');
    await expectLater(lookup()(7), throwsA(isA<LedgerUnavailable>()));
  });

  test(
    'an unreadable catalog is a LedgerUnavailable, not a raw error',
    () async {
      found = {7: AgentCatalogUnavailable(message: 'no catalog')};
      await expectLater(lookup()(7), throwsA(isA<LedgerUnavailable>()));
    },
  );
}
