import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;
import 'package:puls3_server/src/agent/agent_catalog_service.dart';
import 'package:puls3_server/src/feedback/feedback_endpoint.dart';
import 'package:puls3_server/src/feedback/feedback_service.dart';
import 'package:puls3_server/src/hire/hire_endpoint.dart';
import 'package:puls3_server/src/hire/hire_relay_config.dart';
import 'package:puls3_server/src/hire/hire_service.dart';
import 'package:puls3_server/src/hire/hire_services.dart';
import 'package:puls3_server/src/hire/session_wallet.dart';
import 'package:serverpod/serverpod.dart' show Session;
import 'package:test/test.dart';

import '../support/fake_envelope_codec.dart';
import '../support/fake_feedback_ports.dart';
import '../support/relay_rig.dart';

final class _UnusedSession implements Session {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('The endpoint must not use the session');
}

final class _FakeSessionWallet implements SessionWallet {
  _FakeSessionWallet(this.events, this.wallet, {this.failure});

  final List<String> events;
  final StellarAddress wallet;
  final Object? failure;

  @override
  Future<StellarAddress> requireLogin(Session session) async {
    events.add('requireLogin');
    if (failure != null) throw failure!;
    return wallet;
  }
}

void main() {
  final session = _UnusedSession();
  final endpoint = FeedbackEndpoint();
  late RelayRig rig;
  late List<String> events;

  void install({Object? loginFailure}) {
    HireEndpoint.sessionWallet = _FakeSessionWallet(
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
          config: HireRelayConfig(relayEnvironment()),
          now: () => rig.clock,
        ),
        relay: rig.service,
        feedback: FeedbackService(
          hires: rig.hires,
          submissions: rig.submissions,
          preparations: rig.preparations,
          owners: FakeAgentOwners({7: StellarAddress.parse(agentWallet)}),
          calls: FakeReputationCalls(),
          relay: rig.service,
        ),
      );
    };
  }

  setUp(() {
    rig = RelayRig();
    events = [];
    install();
  });

  tearDown(() {
    HireEndpoint.sessionWallet = null;
    HireEndpoint.servicesBuilder = null;
  });

  test('a caller without a session reaches no service', () async {
    install(loginFailure: StateError('not logged in'));
    final hire = await rig.hire(status: HireStatus.completed);

    await expectLater(
      endpoint.getFeedbackEligibility(session, hire.id, alice),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      endpoint.prepareFeedback(session, hire.id, 4, ''),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      endpoint.submitFeedback(session, hire.id, 'prep-1', 'AAAA'),
      throwsA(isA<StateError>()),
    );
    expect(events, isNot(contains('services')));
  });

  test('eligibility rejects a client that is not the session wallet', () async {
    final hire = await rig.hire(status: HireStatus.completed);

    await expectLater(
      endpoint.getFeedbackEligibility(session, hire.id, stranger),
      throwsA(api('WalletMismatch')),
    );
    await expectLater(
      endpoint.getFeedbackEligibility(session, hire.id, 'nope'),
      throwsA(api('InvalidStellarAddress')),
    );
  });

  test('eligibility, prepare and submit run the flow end to end', () async {
    final hire = await rig.hire(status: HireStatus.completed);

    final eligibility = await endpoint.getFeedbackEligibility(
      session,
      hire.id,
      alice,
    );
    final prepared = await endpoint.prepareFeedback(session, hire.id, 5, 'ok');
    final detail = await endpoint.submitFeedback(
      session,
      hire.id,
      prepared.preparationId,
      FakeEnvelopeCodec.sign(prepared.unsignedTransactionXdr!, tag: 'ok'),
    );

    expect(eligibility.eligible, isTrue);
    expect(prepared.purpose, 'giveFeedback');
    expect(
      detail.hire.feedbackReference,
      detail.feedbackSubmission!.transaction,
    );
    expect(detail.hire.status, 'completed');
    expect(events.first, 'requireLogin');
  });
}
