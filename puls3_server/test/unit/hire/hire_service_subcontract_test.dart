import 'dart:convert';
import 'dart:typed_data';

import 'package:puls3_server/src/agent/agent_catalog_service.dart';
import 'package:puls3_server/src/generated/protocol.dart';
import 'package:puls3_server/src/hire/hire_relay_config.dart';
import 'package:puls3_server/src/hire/hire_service.dart';
import 'package:puls3_server/src/ledger/stellar_config.dart';
import 'package:test/test.dart';

import '../../support/relay_rig.dart';

/// `createHire` with a subcontract cap and a related-party choice
/// (ADR-0011 D1, D10).

const _ceiling = 10000000;

void main() {
  late RelayRig rig;
  late Map<String, String> env;
  late HireService service;

  Uint8List bytes(String text) => Uint8List.fromList(utf8.encode(text));

  HireService serviceOn(RelayRig on, Map<String, String> environment) =>
      HireService(
        hires: on.hires,
        preparations: on.preparations,
        relay: on.service,
        registry: on.ledger,
        catalog: AgentCatalogService(on.ledger),
        custody: on.custodyOf,
        config: HireRelayConfig(environment),
        now: () => on.clock,
      );

  void seedAgent(RelayRig on) {
    on.ledger.metadata[7] = {
      'id': bytes('agt-001'),
      'name': bytes('Test Agent'),
      'description': bytes('A helpful test agent for verification.'),
      'skills': bytes(jsonEncode(['coding'])),
      'priceUsdcStroops': bytes('$price'),
      'puls3.manifestVersion': bytes('1'),
    };
  }

  Future<CreateHireResult> create({
    int? subcontractReserve,
    bool? allowRelatedParty,
    String input = 'summarise this',
    HireService? on,
  }) => (on ?? service).createHire(
    agentId: 7,
    consumer: alice,
    input: input,
    requestId: 'request-1',
    subcontractReserve: subcontractReserve,
    allowRelatedParty: allowRelatedParty,
  );

  setUp(() {
    env = {
      ...relayEnvironment(),
      HireRelayConfig.subcontractReserveMaxKey: '$_ceiling',
    };
    rig = RelayRig(environment: env);
    seedAgent(rig);
    service = serviceOn(rig, env);
  });

  test('without a cap the hire never subcontracts, as before', () async {
    final result = await create();

    expect(result.hire.subcontractReserve, 0);
    expect(result.hire.allowRelatedParty, isTrue);
    expect(result.hire.parentHireId, isNull);
    final row = rig.hires.all.single;
    expect(row.subcontractReserve, 0);
    expect(row.allowRelatedParty, isTrue);
    expect(rig.codec.built.single.spec.function, 'create_job');
  });

  test('a cap needs no ceiling setting when it is 0', () async {
    final bare = RelayRig();
    seedAgent(bare);

    final result = await create(
      subcontractReserve: 0,
      on: serviceOn(bare, relayEnvironment()),
    );

    expect(result.hire.subcontractReserve, 0);
  });

  test('stores the cap and the related-party opt-out', () async {
    final result = await create(
      subcontractReserve: 2000000,
      allowRelatedParty: false,
    );

    expect(result.hire.subcontractReserve, 2000000);
    expect(result.hire.allowRelatedParty, isFalse);
    final row = rig.hires.all.single;
    expect(row.subcontractReserve, 2000000);
    expect(row.allowRelatedParty, isFalse);
    expect(
      rig.codec.built.single.spec.function,
      'create_job',
      reason: 'the reserve is funded at fund, never at create_job',
    );
  });

  test('a cap at the ceiling is accepted', () async {
    final result = await create(subcontractReserve: _ceiling);

    expect(result.hire.subcontractReserve, _ceiling);
  });

  for (final (label, reserve) in [
    ('negative', -1),
    ('above the platform ceiling', _ceiling + 1),
  ]) {
    test('a $label cap is HireRequestInvalid and stores nothing', () async {
      await expectLater(
        create(subcontractReserve: reserve),
        throwsA(isA<HireRequestInvalid>()),
      );
      expect(rig.hires.all, isEmpty);
      expect(rig.preparations.all, isEmpty);
    });
  }

  test('a cap without a ceiling setting is HireConfigurationMissing', () async {
    final bare = RelayRig();
    seedAgent(bare);

    await expectLater(
      create(
        subcontractReserve: 1,
        on: serviceOn(bare, relayEnvironment()),
      ),
      throwsA(
        isA<HireConfigurationMissing>().having(
          (e) => e.setting,
          'setting',
          HireRelayConfig.subcontractReserveMaxKey,
        ),
      ),
    );
    expect(bare.hires.all, isEmpty);
  });

  test('a retry with another cap is IdempotencyKeyReused', () async {
    await create(subcontractReserve: 2000000);

    await expectLater(
      create(subcontractReserve: 3000000),
      throwsA(api('IdempotencyKeyReused')),
    );
    await expectLater(
      create(subcontractReserve: 2000000, allowRelatedParty: false),
      throwsA(api('IdempotencyKeyReused')),
    );
    expect(rig.hires.all, hasLength(1));
  });

  test('a retry with the same cap returns the same hire', () async {
    final first = await create(subcontractReserve: 2000000);
    final again = await create(subcontractReserve: 2000000);

    expect(again.hire.id, first.hire.id);
  });

  test('the hire is then funded with fund_with_reserve (D1)', () async {
    final created = await create(subcontractReserve: 2000000);
    final id = created.hire.id;
    await rig.hires.bindJob(id, 3, expiredAt: 1800000000);

    await rig.service.prepareFund(rig.wallet, id);

    final spec = rig.codec.built.last.spec;
    expect(spec.contract, StellarConfig.testnet.escrow);
    expect(spec.function, 'fund_with_reserve');
  });
}
