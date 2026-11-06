import 'package:puls3_domain/puls3_domain.dart';
import 'package:test/test.dart';

final _alice = StellarAddress.parse(
  'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H',
);
final _bob = StellarAddress.parse(
  'GCHX6NRPMSB4CIZM3ZLHPOC2VD6DJVAN6IY3NE5QSAMOWJ7N4TAWK6HN',
);

FeedbackRecord _record(
  int value, {
  int index = 1,
  int decimals = 0,
  bool revoked = false,
  StellarAddress? client,
}) => FeedbackRecord(
  agentId: AgentId(7),
  client: client ?? _alice,
  index: index,
  value: BigInt.from(value),
  valueDecimals: decimals,
  isRevoked: revoked,
);

void main() {
  group('exclusionOf', () {
    test('a whole score from 1 to 5 counts', () {
      for (
        var score = lowestFeedbackScore;
        score <= highestFeedbackScore;
        score++
      ) {
        expect(exclusionOf(_record(score)), isNull, reason: 'score $score');
      }
    });

    test('names the reason a record does not count', () {
      expect(
        exclusionOf(
          FeedbackRecord.unreadable(
            agentId: AgentId(7),
            client: _alice,
            index: 1,
          ),
        ),
        FeedbackExclusion.unreadable,
      );
      expect(
        exclusionOf(_record(5, revoked: true)),
        FeedbackExclusion.revoked,
      );
      expect(
        exclusionOf(_record(5, decimals: 2)),
        FeedbackExclusion.notWholeScore,
      );
      expect(exclusionOf(_record(0)), FeedbackExclusion.outOfScale);
      expect(exclusionOf(_record(6)), FeedbackExclusion.outOfScale);
      expect(exclusionOf(_record(-3)), FeedbackExclusion.outOfScale);
    });

    test('checks revoked before the scale', () {
      expect(
        exclusionOf(_record(9, revoked: true)),
        FeedbackExclusion.revoked,
      );
    });
  });

  group('countedFeedback', () {
    test('every record without an exclusion reaches the formula, in order', () {
      final records = [
        _record(5, index: 1),
        _record(3, index: 2, revoked: true),
        _record(4, index: 3),
        _record(2, index: 1, client: _bob),
        _record(5, index: 2, client: _bob, decimals: 1),
        _record(1, index: 3, client: _bob),
      ];

      final counted = countedFeedback(records);

      expect(counted.map((f) => f.score), [5, 4, 2, 1]);
      expect(counted.map((f) => f.client), [_alice, _alice, _bob, _bob]);
      expect(counted.every((f) => f.agentId == AgentId(7)), isTrue);
      expect(counted.every((f) => f.hireId == null), isTrue);
    });

    test('nothing is dropped without one of the four public reasons', () {
      // Every combination the registry can hold for one value.
      final records = [
        for (final value in [-1, 0, 1, 3, 5, 6])
          for (final decimals in [0, 1])
            for (final revoked in [false, true])
              _record(value, decimals: decimals, revoked: revoked),
        FeedbackRecord.unreadable(agentId: AgentId(7), client: _bob, index: 9),
      ];

      final counted = countedFeedback(records);
      final excluded = records.where((r) => exclusionOf(r) != null);

      expect(counted.length + excluded.length, records.length);
      expect(counted.map((f) => f.score), [1, 3, 5]);
    });

    test('the rating is reputationOf over exactly the counted records', () {
      final records = [
        _record(5),
        _record(5, index: 2),
        _record(1, index: 3, revoked: true),
        _record(4, index: 4),
      ];

      expect(
        reputationOf(countedFeedback(records)),
        reputationOf([
          for (final score in [5, 5, 4])
            Feedback(
              hireId: null,
              agentId: AgentId(7),
              client: _alice,
              score: score,
            ),
        ]),
      );
    });

    test('no records is the prior', () {
      expect(countedFeedback(const []), isEmpty);
      expect(reputationOf(countedFeedback(const [])), reputationPriorMean);
    });
  });
}
