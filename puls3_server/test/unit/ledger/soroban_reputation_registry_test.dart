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
      // The registry stores no hire: feedback_index is not a puls3 hire id.
      expect(feedback.single.hireId, isNull);
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

    group('no filtering beyond the public rules (#202)', () {
      FakeReputationChain mixedChain() => FakeReputationChain()
        ..add(7, _alice, _stored(5)) // counts
        ..add(7, _alice, _stored(4, revoked: true)) // revoked
        ..add(7, _alice, _stored(3)) // counts
        ..add(7, _alice, _stored(2)) // unreadable (missing below)
        ..add(7, _bob, _stored(25, decimals: 1)) // 2.5, not a whole score
        ..add(7, _bob, _stored(9)) // outside 1 to 5
        ..add(
          7,
          _bob,
          _stored(1, tag1: 'quality'),
        ) // counts: tags are no filter
        ..missing.add((7, _alice, 4));

      test('recordsOf returns every record the registry lists', () async {
        final chain = mixedChain();

        final records = await chain.adapter.recordsOf(AgentId(7));

        expect(records, hasLength(7));
        expect(
          records.map((r) => (r.client, r.index)),
          [
            (_alice, 1),
            (_alice, 2),
            (_alice, 3),
            (_alice, 4),
            (_bob, 1),
            (_bob, 2),
            (_bob, 3),
          ],
        );
        expect(records.map(exclusionOf), [
          null,
          FeedbackExclusion.revoked,
          null,
          FeedbackExclusion.unreadable,
          FeedbackExclusion.notWholeScore,
          FeedbackExclusion.outOfScale,
          null,
        ]);
      });

      test(
        'an agent with no feedback reads one empty page and no records',
        () async {
          final chain = FakeReputationChain();

          final read = await chain.adapter.readRecords(AgentId(7));

          expect(read.records, isEmpty);
          expect(read.clientPages, 1);
          expect(await chain.adapter.feedbacksOf(AgentId(7)), isEmpty);
        },
      );

      test('pagination reads every client page and drops no record', () async {
        final chain = FakeReputationChain();
        final clients = [
          for (var i = 0; i < reputationPageSize + 1; i++) testAccount(i),
        ];
        for (final client in clients) {
          chain.add(7, client, _stored(4));
        }

        final read = await chain.adapter.readRecords(AgentId(7));

        // A full page, a page of one, and the empty page that ends the list.
        expect(read.clientPages, 3);
        expect(read.records, hasLength(reputationPageSize + 1));
        expect(read.records.map((r) => r.client).toSet(), clients.toSet());
        expect(countedFeedback(read.records), hasLength(clients.length));
      });

      test(
        'equal scores from one client are separate records, all counted',
        () async {
          // The registry keys a record by (client, index): two 5s from Alice
          // are two feedbacks, not a duplicate to drop.
          final chain = FakeReputationChain()
            ..add(7, _alice, _stored(5))
            ..add(7, _alice, _stored(5));

          final records = await chain.adapter.recordsOf(AgentId(7));
          final feedback = await chain.adapter.feedbacksOf(AgentId(7));

          expect(records.map((r) => r.index), [1, 2]);
          expect(feedback.map((f) => f.score), [5, 5]);
        },
      );

      test(
        'a failure in the middle of a read throws, never a partial list',
        () async {
          final chain = FakeReputationChain()
            ..add(7, _alice, _stored(5))
            ..add(7, _alice, _stored(1))
            ..add(7, _bob, _stored(1));
          // The clients pages and Alice's last index answer; the next read fails.
          chain.failAfterRequests = 3;

          await expectLater(
            chain.adapter.recordsOf(AgentId(7)),
            throwsA(isA<LedgerUnavailable>()),
          );
          chain
            ..requests.clear()
            ..failAfterRequests = 3;
          await expectLater(
            chain.adapter.feedbacksOf(AgentId(7)),
            throwsA(isA<LedgerUnavailable>()),
          );
        },
      );

      test('feedbacksOf is exactly countedFeedback of recordsOf', () async {
        final records = await mixedChain().adapter.recordsOf(AgentId(7));
        final feedback = await mixedChain().adapter.feedbacksOf(AgentId(7));

        final expected = countedFeedback(records);
        expect(feedback.map((f) => (f.client, f.score)), [
          for (final f in expected) (f.client, f.score),
        ]);
        expect(feedback.map((f) => f.score), [5, 3, 1]);
        // Every record either reaches the formula or has a public reason.
        final excluded = records.where((r) => exclusionOf(r) != null).length;
        expect(feedback.length + excluded, records.length);
        expect(reputationOf(feedback), reputationOf(expected));
      });
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
