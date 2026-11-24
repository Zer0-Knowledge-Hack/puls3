import 'dart:convert';
import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;
import 'package:puls3_server/src/agent/agent_catalog_service.dart';
import 'package:puls3_server/src/agent/hidden_agents.dart';
import 'package:puls3_server/src/generated/protocol.dart';
import 'package:puls3_server/src/hire/hire_endpoint.dart';
import 'package:puls3_server/src/hire/hire_relay_config.dart';
import 'package:puls3_server/src/hire/hire_service.dart';
import 'package:puls3_server/src/hire/hire_services.dart';
import 'package:puls3_server/src/hire/session_wallet.dart';
import 'package:puls3_server/src/ledger/ledger_errors.dart';
import 'package:puls3_server/src/runtime/run_manifest.dart';
import 'package:serverpod/serverpod.dart' show Session;
import 'package:test/test.dart';

import '../support/relay_rig.dart';

/// The endpoint only hands the session to the seam and the builder.
final class _UnusedSession implements Session {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('The endpoint must not use the session');
}

final class _SessionWallet implements SessionWallet {
  _SessionWallet(this.events, this.wallet, {this.failure});

  final List<String> events;
  final StellarAddress wallet;
  final Object? failure;

  @override
  Future<StellarAddress> requireLogin(Session session) async {
    events.add('requireLogin');
    final failure = this.failure;
    if (failure != null) throw failure;
    return wallet;
  }
}

Uint8List _bytes(String text) => Uint8List.fromList(utf8.encode(text));

RunManifest _manifest({SubcontractOptIn? subcontract}) => RunManifest(
  provider: 'workers-ai',
  modelId: '@cf/meta/llama-3.1-8b-instruct',
  systemPrompt: 'Answer.',
  inputMaxChars: 1000,
  outputMaxChars: 1000,
  subcontract: subcontract,
);

void main() {
  final session = _UnusedSession();
  final endpoint = HireEndpoint();
  late RelayRig rig;
  late List<String> events;
  late List<String> warnings;

  /// Installs a services builder over [environment] (the relay settings plus
  /// [ceiling] when given), the seeded [manifests] and [hidden].
  void install({
    String? ceiling,
    Map<String, Map<int, RunManifest>> manifests = const {},
    HiddenAgents hidden = HiddenAgents.none,
    Object? loginFailure,
  }) {
    HireEndpoint.sessionWallet = _SessionWallet(
      events,
      rig.wallet,
      failure: loginFailure,
    );
    HireEndpoint.servicesBuilder = (_) {
      events.add('services');
      return HireServices(
        hires: HireService(
          hires: rig.hires,
          preparations: rig.preparations,
          relay: rig.service,
          registry: rig.ledger,
          catalog: AgentCatalogService(rig.ledger),
          custody: rig.custodyOf,
          config: HireRelayConfig({
            ...relayEnvironment(),
            HireRelayConfig.subcontractReserveMaxKey: ?ceiling,
          }),
          hidden: hidden,
          manifests: SeededRunManifestSource(
            registry: rig.ledger,
            manifests: manifests,
          ),
          warn: warnings.add,
          now: () => rig.clock,
        ),
        relay: rig.service,
      );
    };
  }

  setUp(() {
    rig = RelayRig();
    events = [];
    warnings = [];
    rig.ledger.metadata[7] = {
      'id': _bytes('agt-001'),
      'name': _bytes('Test Agent'),
      'description': _bytes('A helpful test agent for verification.'),
      'skills': _bytes(jsonEncode(['coding'])),
      'priceUsdcStroops': _bytes('5000000'),
      'puls3.manifestVersion': _bytes('2'),
    };
  });

  tearDown(() {
    HireEndpoint.sessionWallet = null;
    HireEndpoint.servicesBuilder = null;
  });

  final optedIn = {
    'agt-001': {
      1: _manifest(),
      2: _manifest(
        subcontract: SubcontractOptIn(maxChildren: 5, suggestedReserve: 750),
      ),
    },
  };

  test('an opted-in agent gets the ceiling, its capped max children and '
      'its suggested reserve from its current manifest', () async {
    install(ceiling: '20000000', manifests: optedIn);

    final terms = await endpoint.getHireTerms(session, 7);

    expect(terms.reserveMaxStroops, 20000000);
    expect(terms.maxChildren, subcontractMaxChildrenCap);
    expect(terms.suggestedReserveStroops, 750);
    expect(events, ['requireLogin', 'services']);
    expect(warnings, isEmpty);
  });

  test('a max children under the platform cap is kept', () async {
    install(
      ceiling: '20000000',
      manifests: {
        'agt-001': {
          2: _manifest(
            subcontract: SubcontractOptIn(maxChildren: 1, suggestedReserve: 0),
          ),
        },
      },
    );

    final terms = await endpoint.getHireTerms(session, 7);

    expect(terms.maxChildren, 1);
    expect(terms.suggestedReserveStroops, 0);
  });

  test(
    'an agent without the opt-in has 0 children and no suggestion',
    () async {
      install(
        ceiling: '20000000',
        manifests: {
          'agt-001': {2: _manifest()},
        },
      );

      final terms = await endpoint.getHireTerms(session, 7);

      expect(terms.reserveMaxStroops, 20000000);
      expect(terms.maxChildren, 0);
      expect(terms.suggestedReserveStroops, 0);
    },
  );

  test('an agent whose manifest is unknown has 0 children', () async {
    install(ceiling: '20000000');

    final terms = await endpoint.getHireTerms(session, 7);

    expect(terms.maxChildren, 0);
    expect(terms.suggestedReserveStroops, 0);
  });

  test('an agent without a readable manifest version has 0 children', () async {
    rig.ledger.metadata[7]!['puls3.manifestVersion'] = _bytes('nope');
    install(ceiling: '20000000', manifests: optedIn);

    final terms = await endpoint.getHireTerms(session, 7);

    expect(terms.maxChildren, 0);
    expect(terms.suggestedReserveStroops, 0);
  });

  test('an unset ceiling is 0 and logs nothing', () async {
    install(manifests: optedIn);

    final terms = await endpoint.getHireTerms(session, 7);

    expect(terms.reserveMaxStroops, 0);
    expect(terms.maxChildren, subcontractMaxChildrenCap);
    expect(warnings, isEmpty);
  });

  test('an invalid ceiling is 0 and is logged, never an error', () async {
    install(ceiling: 'lots', manifests: optedIn);

    final terms = await endpoint.getHireTerms(session, 7);

    expect(terms.reserveMaxStroops, 0);
    expect(warnings, [contains(HireRelayConfig.subcontractReserveMaxKey)]);
  });

  test('a hidden agent is AgentNotFound, like createHire', () async {
    install(
      ceiling: '20000000',
      manifests: optedIn,
      hidden: HiddenAgents.fromEnvironment({hiddenAgentIdsKey: '7'}),
    );

    await expectLater(
      endpoint.getHireTerms(session, 7),
      throwsA(api('AgentNotFound')),
    );
  });

  test('an agent that is not registered is AgentNotFound', () async {
    install(ceiling: '20000000', manifests: optedIn);

    await expectLater(
      endpoint.getHireTerms(session, 8),
      throwsA(api('AgentNotFound')),
    );
  });

  test('an agent id outside the contract u32 is InvalidAgentId', () async {
    install(ceiling: '20000000');

    await expectLater(
      endpoint.getHireTerms(session, -1),
      throwsA(api('InvalidAgentId')),
    );
  });

  test('a chain that cannot be read is ChainUnavailable', () async {
    rig.ledger.metadataError = const LedgerUnavailable('Stellar RPC timeout');
    install(ceiling: '20000000', manifests: optedIn);

    await expectLater(
      endpoint.getHireTerms(session, 7),
      throwsA(api('ChainUnavailable')),
    );
  });

  test('without a session no service work happens', () async {
    install(
      loginFailure: Puls3ApiException(code: 'AuthenticationUnavailable'),
    );

    await expectLater(
      endpoint.getHireTerms(session, 7),
      throwsA(api('AuthenticationUnavailable')),
    );
    expect(events, ['requireLogin']);
  });
}
