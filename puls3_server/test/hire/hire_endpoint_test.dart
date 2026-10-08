import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;
import 'package:puls3_server/src/agent/agent_catalog_service.dart';
import 'package:puls3_server/src/generated/protocol.dart';
import 'package:puls3_server/src/hire/hire_endpoint.dart';
import 'package:puls3_server/src/hire/hire_relay_config.dart';
import 'package:puls3_server/src/hire/hire_service.dart';
import 'package:puls3_server/src/hire/hire_services.dart';
import 'package:puls3_server/src/hire/session_wallet.dart';
import 'package:puls3_server/src/ledger/ledger_errors.dart';
import 'package:serverpod/serverpod.dart' show Session;
import 'package:test/test.dart';

import '../support/fake_envelope_codec.dart';
import '../support/relay_rig.dart';

/// The endpoint never uses the session itself; it only hands it to the seam
/// and to the services builder.
final class _UnusedSession implements Session {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('The endpoint must not use the session');
}

/// A seam that records every call into [events] and answers with [wallet],
/// or fails with [failure].
final class _FakeSessionWallet implements SessionWallet {
  _FakeSessionWallet(this.events, {this.wallet, this.failure});

  final List<String> events;
  final StellarAddress? wallet;
  final Object? failure;

  @override
  Future<StellarAddress> requireLogin(Session session) async {
    events.add('requireLogin');
    final failure = this.failure;
    if (failure != null) throw failure;
    return wallet!;
  }
}

Uint8List _bytes(String text) => Uint8List.fromList(utf8.encode(text));

void main() {
  final session = _UnusedSession();
  final endpoint = HireEndpoint();
  late RelayRig rig;
  late List<String> events;

  void seedAgent() {
    rig.ledger.metadata[7] = {
      'id': _bytes('agt-001'),
      'name': _bytes('Test Agent'),
      'description': _bytes('A helpful test agent for verification.'),
      'skills': _bytes(jsonEncode(['coding', 'testing'])),
      'priceUsdcStroops': _bytes('5000000'),
      'puls3.manifestVersion': _bytes('1'),
    };
  }

  /// Installs the seam and a services builder that records when it runs.
  void install({Object? loginFailure, StellarAddress? wallet}) {
    HireEndpoint.sessionWallet = _FakeSessionWallet(
      events,
      wallet: wallet ?? rig.wallet,
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
          config: HireRelayConfig(relayEnvironment()),
          now: () => rig.clock,
        ),
        relay: rig.service,
      );
    };
  }

  setUp(() {
    rig = RelayRig();
    events = [];
    seedAgent();
    install();
  });

  tearDown(() {
    HireEndpoint.sessionWallet = null;
    HireEndpoint.servicesBuilder = null;
  });

  /// One call per endpoint method, each against a state its service accepts.
  final calls = <String, Future<Object?> Function()>{
    'createHire': () => endpoint.createHire(session, 7, alice, 'hi', 'req-1'),
    'prepareCreateJob': () async =>
        endpoint.prepareCreateJob(session, (await rig.hire()).id),
    'prepareFund': () async => endpoint.prepareFund(
      session,
      (await rig.hire(status: HireStatus.open)).id,
    ),
    'prepareComplete': () async => endpoint.prepareComplete(
      session,
      (await rig.hire(status: HireStatus.submitted)).id,
    ),
    'prepareReject': () async => endpoint.prepareReject(
      session,
      (await rig.hire(status: HireStatus.open)).id,
      'not what I asked for',
    ),
    'submitEscrowCall': () async {
      final hire = await rig.hire(status: HireStatus.open);
      final prepared = await rig.service.prepareFund(rig.wallet, hire.id);
      events.clear();
      return endpoint.submitEscrowCall(
        session,
        hire.id,
        prepared.preparationId,
        FakeEnvelopeCodec.sign(prepared.unsignedTransactionXdr!),
      );
    },
  };

  group('every method resolves the session wallet exactly once, first', () {
    for (final entry in calls.entries) {
      test(entry.key, () async {
        final result = await entry.value();

        expect(result, isNotNull);
        expect(events, ['requireLogin', 'services']);
      });
    }
  });

  group('without a session no service work happens', () {
    final unauthenticated = Puls3ApiException(
      code: 'AuthenticationUnavailable',
    );

    for (final entry in calls.entries) {
      test(entry.key, () async {
        install(loginFailure: unauthenticated);

        await expectLater(
          entry.value(),
          throwsA(api('AuthenticationUnavailable')),
        );
        expect(events.where((e) => e == 'requireLogin'), hasLength(1));
        expect(events, isNot(contains('services')));
      });
    }

    test('createHire stores nothing', () async {
      install(loginFailure: unauthenticated);

      await expectLater(
        endpoint.createHire(session, 7, alice, 'hi', 'req-1'),
        throwsA(api('AuthenticationUnavailable')),
      );
      expect(rig.hires.all, isEmpty);
    });
  });

  group('the production seam fails closed until sessions exist (#25)', () {
    test('the default wallet raises AuthenticationUnavailable', () async {
      HireEndpoint.sessionWallet = null;
      HireEndpoint.servicesBuilder = (_) {
        events.add('services');
        throw StateError('no service may be built without a session');
      };

      await expectLater(
        endpoint.createHire(session, 7, alice, 'hi', 'req-1'),
        throwsA(api('AuthenticationUnavailable')),
      );
      await expectLater(
        endpoint.prepareFund(session, 1),
        throwsA(api('AuthenticationUnavailable')),
      );
      expect(events, isEmpty);
    });

    test('FailClosedSessionWallet never returns a wallet', () {
      expect(
        const FailClosedSessionWallet().requireLogin(session),
        throwsA(api('AuthenticationUnavailable')),
      );
    });
  });

  group('the default wiring', () {
    test('builds with no relay setting and reads each one on use', () {
      final wiring = HireWiring.fromEnvironment(
        environment: {},
        httpClient: MockClient((_) async => http.Response('down', 503)),
      );

      final services = wiring.servicesOn(session);

      expect(services.hires.relay, same(services.relay));
      expect(
        () => wiring.config.preparationValiditySeconds,
        throwsA(
          isA<HireConfigurationMissing>().having(
            (e) => e.setting,
            'setting',
            'PULS3_ESCROW_PREPARATION_VALIDITY_SECONDS',
          ),
        ),
      );
    });

    test('takes the relay settings from the environment it is given', () {
      final wiring = HireWiring.fromEnvironment(
        environment: relayEnvironment(),
        httpClient: MockClient((_) async => http.Response('down', 503)),
      );

      expect(wiring.config.preparationValiditySeconds, validitySeconds);
      expect(wiring.config.inclusionFeeStroops, inclusionFee);
      expect(wiring.config.platformFeeBps, platformFeeBps);
      expect(wiring.config.jobDurationSeconds, jobDurationSeconds);
    });
  });

  group('createHire', () {
    test('returns the hire and its prepared create_job', () async {
      final result = await endpoint.createHire(
        session,
        7,
        alice,
        'summarise',
        'req-1',
      );

      expect(result.hire.consumer, alice);
      expect(result.hire.agentId, 7);
      expect(result.preparedCreateJob?.purpose, 'createJob');
      expect(rig.hires.all.single.input, 'summarise');
    });

    test(
      'a consumer other than the session wallet is WalletMismatch',
      () async {
        await expectLater(
          endpoint.createHire(session, 7, stranger, 'hi', 'req-1'),
          throwsA(api('WalletMismatch')),
        );
        expect(events, ['requireLogin']);
        expect(rig.hires.all, isEmpty);
      },
    );

    test('an invalid consumer address is InvalidStellarAddress', () async {
      await expectLater(
        endpoint.createHire(session, 7, 'not-an-address', 'hi', 'req-1'),
        throwsA(api('InvalidStellarAddress')),
      );
      expect(events, ['requireLogin']);
      expect(rig.hires.all, isEmpty);
    });

    test('a non-positive agent id is InvalidAgentId', () async {
      await expectLater(
        endpoint.createHire(session, 0, alice, 'hi', 'req-1'),
        throwsA(api('InvalidAgentId')),
      );
      await expectLater(
        endpoint.createHire(session, -3, alice, 'hi', 'req-1'),
        throwsA(api('InvalidAgentId')),
      );
      expect(events, ['requireLogin', 'requireLogin']);
    });

    test('an agent that is not registered is AgentNotFound', () async {
      await expectLater(
        endpoint.createHire(session, 8, alice, 'hi', 'req-1'),
        throwsA(api('AgentNotFound')),
      );
      expect(rig.hires.all, isEmpty);
    });

    test(
      'prepareCreateJob for an agent without a wallet is AgentNotFound',
      () async {
        final hire = (await rig.hire()).id;
        rig.ledger.wallets.clear();

        await expectLater(
          endpoint.prepareCreateJob(session, hire),
          throwsA(api('AgentNotFound')),
        );
        expect(rig.preparations.all, isEmpty);
      },
    );

    test('a blank request id is InvalidHire', () async {
      await expectLater(
        endpoint.createHire(session, 7, alice, 'hi', '  '),
        throwsA(api('InvalidHire')),
      );
    });

    test('a chain that cannot be read is ChainUnavailable', () async {
      rig.ledger.walletError = const LedgerUnavailable('Stellar RPC timeout');

      await expectLater(
        endpoint.createHire(session, 7, alice, 'hi', 'req-1'),
        throwsA(api('ChainUnavailable')),
      );
    });

    test(
      'reusing a request id for other input is IdempotencyKeyReused',
      () async {
        await endpoint.createHire(session, 7, alice, 'one', 'req-1');

        await expectLater(
          endpoint.createHire(session, 7, alice, 'two', 'req-1'),
          throwsA(api('IdempotencyKeyReused')),
        );
      },
    );

    test(
      'a missing relay setting stays the typed configuration error',
      () async {
        HireEndpoint.servicesBuilder = (_) => HireServices(
          hires: HireService(
            hires: rig.hires,
            preparations: rig.preparations,
            relay: rig.service,
            registry: rig.ledger,
            catalog: AgentCatalogService(rig.ledger),
            config: const HireRelayConfig({}),
            now: () => rig.clock,
          ),
          relay: rig.service,
        );

        await expectLater(
          endpoint.createHire(session, 7, alice, 'hi', 'req-1'),
          throwsA(isA<HireConfigurationMissing>()),
        );
      },
    );
  });

  group('a hire of another wallet is HireNotOwned', () {
    late int foreign;

    setUp(() async {
      foreign = (await rig.hire(
        status: HireStatus.open,
        consumer: stranger,
      )).id;
    });

    test('prepareCreateJob', () async {
      final hire = (await rig.hire(consumer: stranger)).id;
      await expectLater(
        endpoint.prepareCreateJob(session, hire),
        throwsA(api('HireNotOwned')),
      );
    });

    test(
      'prepareFund',
      () => _notOwned(() => endpoint.prepareFund(session, foreign)),
    );

    test(
      'prepareComplete',
      () => _notOwned(() => endpoint.prepareComplete(session, foreign)),
    );

    test(
      'prepareReject',
      () => _notOwned(() => endpoint.prepareReject(session, foreign, 'no')),
    );

    test(
      'submitEscrowCall',
      () => _notOwned(
        () => endpoint.submitEscrowCall(session, foreign, 'prep-1', 'AAAA'),
      ),
    );

    test(
      'ownership follows the session wallet, not the caller input',
      () async {
        install(wallet: rig.other);
        final mine = (await rig.hire(
          status: HireStatus.open,
          consumer: stranger,
        )).id;

        final prepared = await endpoint.prepareFund(session, mine);

        expect(prepared.signer, stranger);
      },
    );
  });

  group('delegation', () {
    test('prepareFund returns the unsigned fund envelope', () async {
      final hire = await rig.hire(status: HireStatus.open);

      final prepared = await endpoint.prepareFund(session, hire.id);

      expect(prepared.purpose, 'fund');
      expect(prepared.signer, alice);
    });

    test('a hire that does not exist is HireNotFound', () async {
      await expectLater(
        endpoint.prepareComplete(session, 99),
        throwsA(api('HireNotFound')),
      );
    });

    test('submitEscrowCall relays a signed envelope', () async {
      final hire = await rig.hire(status: HireStatus.open);
      final prepared = await endpoint.prepareFund(session, hire.id);

      final detail = await endpoint.submitEscrowCall(
        session,
        hire.id,
        prepared.preparationId,
        FakeEnvelopeCodec.sign(prepared.unsignedTransactionXdr!),
      );

      expect(detail.escrowSubmission?.preparationId, prepared.preparationId);
      expect(detail.escrowSubmission?.state, 'submitted');
    });
  });
}

Future<void> _notOwned(Future<Object?> Function() call) =>
    expectLater(call(), throwsA(api('HireNotOwned')));
