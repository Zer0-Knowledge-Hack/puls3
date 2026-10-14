import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;
import 'package:puls3_server/src/ledger/ledger_errors.dart';
import 'package:puls3_server/src/ledger/soroban_reputation_registry.dart';
import 'package:test/test.dart';

import '../../support/fake_reputation_chain.dart';
import '../../support/reputation_registry_contract.dart';

final _alice = StellarAddress.parse(
  'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H',
);
final _bob = StellarAddress.parse(
  'GCHX6NRPMSB4CIZM3ZLHPOC2VD6DJVAN6IY3NE5QSAMOWJ7N4TAWK6HN',
);

StoredFeedback _stored(
  int value, {
  int decimals = 0,
  bool revoked = false,
  String tag1 = '',
}) => (
  value: value,
  decimals: decimals,
  revoked: revoked,
  tag1: tag1,
  tag2: '',
);

void main() {
  group('SorobanReputationRegistry', () {
    group('shared contract', () {
      reputationRegistryContract(ChainReputationRegistryRig.new);
    });

    test('reads the clients, their last index and each feedback', () async {
      final chain = FakeReputationChain()..add(7, _alice, _stored(4));

      final feedback = await chain.adapter.feedbacksOf(AgentId(7));

      expect(feedback.single.score, 4);
      expect(feedback.single.client, _alice);
      expect(feedback.single.agentId, AgentId(7));
      // A page with the client, the empty page that ends the list, the last
      // index and the one feedback.
      expect(chain.requests, hasLength(4));
      expect(chain.requests.map((r) => r['method']).toSet(), {
        'simulateTransaction',
      });
    });

    test('reads every page of clients', () async {
      final chain = FakeReputationChain();
      final clients = [
        for (var i = 0; i < reputationPageSize + 1; i++) testAccount(i),
      ];
      for (final client in clients) {
        chain.add(7, client, _stored(5));
      }

      final feedback = await chain.adapter.feedbacksOf(AgentId(7));

      expect(feedback, hasLength(reputationPageSize + 1));
      expect(feedback.map((f) => f.client).toSet(), clients.toSet());
    });

    test('skips an entry that is not a puls3 score', () async {
      final chain = FakeReputationChain()
        ..add(7, _alice, _stored(5, decimals: 2)) // 0.05, not a score
        ..add(7, _alice, _stored(0)) // below the scale
        ..add(7, _alice, _stored(6)) // above the scale
        ..add(7, _alice, _stored(-3))
        ..add(7, _bob, _stored(3, tag1: 'quality')); // tags do not filter

      final feedback = await chain.adapter.feedbacksOf(AgentId(7));

      expect(feedback.map((f) => f.score), [3]);
    });

    test('skips a feedback the registry no longer finds', () async {
      final chain = FakeReputationChain()
        ..add(7, _alice, _stored(5))
        ..add(7, _alice, _stored(2))
        ..missing.add((7, _alice, 1));

      final feedback = await chain.adapter.feedbacksOf(AgentId(7));

      expect(feedback.map((f) => f.score), [2]);
    });

    test('archived registry state is unavailable, not empty', () async {
      final chain = FakeReputationChain()
        ..add(7, _alice, _stored(5))
        ..needsRestore = true;

      await expectLater(
        chain.adapter.feedbacksOf(AgentId(7)),
        throwsA(isA<LedgerUnavailable>()),
      );
    });

    test('never records feedback: the wallet signs give_feedback', () {
      final chain = FakeReputationChain();

      expect(
        () => chain.adapter.giveFeedback(
          Feedback(
            hireId: HireId(1),
            agentId: AgentId(7),
            client: _alice,
            score: 5,
          ),
        ),
        throwsA(isA<UnsupportedError>()),
      );
      expect(chain.requests, isEmpty);
    });
  });
}
