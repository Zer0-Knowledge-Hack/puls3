import 'package:puls3_domain/puls3_domain.dart';
import 'package:test/test.dart';

final _alice = StellarAddress.parse(
  'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H',
);
final _bob = StellarAddress.parse(
  'GCHX6NRPMSB4CIZM3ZLHPOC2VD6DJVAN6IY3NE5QSAMOWJ7N4TAWK6HN',
);

/// The escrow the reader trusts.
final _escrow = StellarAddress.parse(
  'CBRD7A7MXINM7LREKCL3RMKRQ5UMLGKNHAEYY4JT7MVBBB7R5QV4TPE2',
);

/// Another contract, which could answer anything to `get_job`.
final _otherEscrow = StellarAddress.parse(
  'CD5QZOKGRBV35C5SDT6PG7S72XGG4BHQAC2L56YLNBJDUL4LDMTXFIJJ',
);

String _ref(int jobId, {StellarAddress? escrow}) =>
    PaidJobReference(escrow: escrow ?? _escrow, jobId: jobId).text;

/// A record of agent 7. By default it points to job [index] of Alice, a job
/// [_jobs] holds as completed, so it counts unless a test changes something.
FeedbackRecord _record(
  int value, {
  int index = 1,
  int decimals = 0,
  bool revoked = false,
  StellarAddress? client,
  String? tag2,
}) => FeedbackRecord(
  agentId: AgentId(7),
  client: client ?? _alice,
  index: index,
  value: BigInt.from(value),
  valueDecimals: decimals,
  isRevoked: revoked,
  tag2: tag2 ?? _ref(client == _bob ? 100 + index : index),
);

ReferencedJob _job({
  StellarAddress? client,
  int agent = 7,
  JobState state = JobState.completed,
}) => ReferencedJob(
  client: client ?? _alice,
  agentId: AgentId(agent),
  state: state,
);

/// Completed jobs: 1 to 20 for Alice, 101 to 120 for Bob, all for agent 7.
final _jobs = {
  for (var id = 1; id <= 20; id++) id: _job(),
  for (var id = 101; id <= 120; id++) id: _job(client: _bob),
};

final _provenance = FeedbackProvenance(escrow: _escrow, jobs: _jobs);

FeedbackProvenance _with(Map<int, ReferencedJob> jobs) =>
    FeedbackProvenance(escrow: _escrow, jobs: {..._jobs, ...jobs});

void main() {
  group('exclusionOf: the score (#202)', () {
    test('a whole score from 1 to 5 for a paid job counts', () {
      for (
        var score = lowestFeedbackScore;
        score <= highestFeedbackScore;
        score++
      ) {
        expect(
          exclusionOf(_record(score), _provenance),
          isNull,
          reason: 'score $score',
        );
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
          _provenance,
        ),
        FeedbackExclusion.unreadable,
      );
      expect(
        exclusionOf(_record(5, revoked: true), _provenance),
        FeedbackExclusion.revoked,
      );
      expect(
        exclusionOf(_record(5, decimals: 2), _provenance),
        FeedbackExclusion.notWholeScore,
      );
      expect(
        exclusionOf(_record(0), _provenance),
        FeedbackExclusion.outOfScale,
      );
      expect(
        exclusionOf(_record(6), _provenance),
        FeedbackExclusion.outOfScale,
      );
      expect(
        exclusionOf(_record(-3), _provenance),
        FeedbackExclusion.outOfScale,
      );
    });

    test('checks revoked before the scale', () {
      expect(
        exclusionOf(_record(9, revoked: true), _provenance),
        FeedbackExclusion.revoked,
      );
    });

    test('a rating from the agent owner does not count (#201)', () {
      final owned = FeedbackProvenance(
        escrow: _escrow,
        jobs: _jobs,
        owner: _alice,
      );

      expect(exclusionOf(_record(5), owned), FeedbackExclusion.fromAgentOwner);
      expect(exclusionOf(_record(5, client: _bob), owned), isNull);
      expect(
        exclusionOf(_record(9), owned),
        FeedbackExclusion.outOfScale,
        reason: 'the score is checked first',
      );
    });

    test('checks the score before the job', () {
      expect(
        exclusionOf(_record(9, tag2: ''), _provenance),
        FeedbackExclusion.outOfScale,
      );
    });
  });

  group('exclusionOf: the paid job (#201)', () {
    test('a record with no reference does not count', () {
      expect(
        exclusionOf(_record(5, tag2: ''), _provenance),
        FeedbackExclusion.noJobReference,
      );
    });

    test('a malformed reference does not count and does not throw', () {
      for (final tag in [
        'quality',
        'puls3:job:v1:',
        'puls3:job:v2:${_escrow.value}:1',
        'puls3:job:v1:${_escrow.value}',
        'puls3:job:v1:${_escrow.value}:0',
        'puls3:job:v1:${_escrow.value}:01',
        'puls3:job:v1:${_escrow.value}:-1',
        'puls3:job:v1:${_escrow.value}:1:2',
        'puls3:job:v1:${_alice.value}:1',
        'puls3:job:v1:CNOTANADDRESS:1',
        'https://example.com/job/1',
      ]) {
        expect(
          exclusionOf(_record(5, tag2: tag), _provenance),
          FeedbackExclusion.noJobReference,
          reason: tag,
        );
      }
    });

    test('a job on an escrow the reader does not trust does not count', () {
      expect(
        exclusionOf(
          _record(5, tag2: _ref(1, escrow: _otherEscrow)),
          _provenance,
        ),
        FeedbackExclusion.otherEscrow,
      );
    });

    test('a job the escrow could not answer for does not count', () {
      expect(
        exclusionOf(_record(5, tag2: _ref(999)), _provenance),
        FeedbackExclusion.jobUnreadable,
      );
    });

    test('a job of another client does not count', () {
      // Job 101 is Bob's: Alice cannot borrow it.
      expect(
        exclusionOf(_record(5, tag2: _ref(101)), _provenance),
        FeedbackExclusion.jobMismatch,
      );
    });

    test('a job of another agent does not count', () {
      expect(
        exclusionOf(_record(5), _with({1: _job(agent: 8)})),
        FeedbackExclusion.jobMismatch,
      );
    });

    test('only a completed job counts: not before, not after a refund', () {
      for (final state in JobState.values) {
        expect(
          exclusionOf(_record(5), _with({1: _job(state: state)})),
          state == JobState.completed
              ? isNull
              : FeedbackExclusion.jobNotCompleted,
          reason: state.name,
        );
      }
    });
  });

  group('exclusionsOf: one rating per job', () {
    test('a second record for the same job does not count', () {
      final records = [
        _record(5, index: 1, tag2: _ref(3)),
        _record(1, index: 2, tag2: _ref(3)),
        _record(4, index: 3, tag2: _ref(4)),
      ];

      expect(exclusionsOf(records, _provenance), [
        null,
        FeedbackExclusion.jobAlreadyRated,
        null,
      ]);
    });

    test('a revoked rating frees its job for a new one', () {
      final records = [
        _record(1, index: 1, revoked: true, tag2: _ref(3)),
        _record(5, index: 2, tag2: _ref(3)),
      ];

      expect(exclusionsOf(records, _provenance), [
        FeedbackExclusion.revoked,
        null,
      ]);
    });

    test('an excluded record takes no job', () {
      final records = [
        _record(9, index: 1, tag2: _ref(3)),
        _record(4, index: 2, tag2: _ref(3)),
      ];

      expect(exclusionsOf(records, _provenance), [
        FeedbackExclusion.outOfScale,
        null,
      ]);
    });
  });

  group('referencedJobIds', () {
    test('lists each trusted job once, only for records that could count', () {
      final records = [
        _record(5, index: 1, tag2: _ref(3)),
        _record(4, index: 2, tag2: _ref(3)),
        _record(4, index: 3, tag2: _ref(5)),
        _record(4, index: 4, tag2: _ref(6, escrow: _otherEscrow)),
        _record(9, index: 5, tag2: _ref(7)), // out of scale: no read needed
        _record(4, index: 6, revoked: true, tag2: _ref(8)),
        _record(4, index: 7, tag2: ''),
        FeedbackRecord.unreadable(agentId: AgentId(7), client: _bob, index: 1),
      ];

      expect(referencedJobIds(records, _escrow), [3, 5]);
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

      final counted = countedFeedback(records, _provenance);

      expect(counted.map((f) => f.score), [5, 4, 2, 1]);
      expect(counted.map((f) => f.client), [_alice, _alice, _bob, _bob]);
      expect(counted.every((f) => f.agentId == AgentId(7)), isTrue);
      expect(counted.every((f) => f.hireId == null), isTrue);
    });

    test('a rating written without a paid job does not count', () {
      final records = [
        _record(5, index: 1),
        _record(5, index: 2, tag2: ''), // straight to the contract
        _record(5, index: 3, tag2: _ref(999)), // no such job
      ];

      expect(countedFeedback(records, _provenance), hasLength(1));
    });

    test('nothing is dropped without one of the public reasons', () {
      // Every combination the registry can hold for one value.
      var index = 0;
      final records = [
        for (final value in [-1, 0, 1, 3, 5, 6])
          for (final decimals in [0, 1])
            for (final revoked in [false, true])
              for (final tag in [null, '', _ref(1), _ref(999), _ref(101)])
                _record(
                  value,
                  index: ++index,
                  decimals: decimals,
                  revoked: revoked,
                  tag2: tag ?? _ref(index > 20 ? 20 : index),
                ),
        FeedbackRecord.unreadable(agentId: AgentId(7), client: _bob, index: 9),
      ];

      final counted = countedFeedback(records, _provenance);
      final exclusions = exclusionsOf(records, _provenance);

      expect(exclusions, hasLength(records.length));
      expect(
        counted.length,
        exclusions.where((exclusion) => exclusion == null).length,
      );
      // A whole score, not revoked, whose paid job no earlier record took:
      // value 1 takes job 20 and job 1, so every later valid record (values
      // 3 and 5) points to a job that already counts.
      expect(counted.map((f) => f.score), [1, 1]);
      expect(
        exclusions.where((e) => e == FeedbackExclusion.jobAlreadyRated),
        isNotEmpty,
      );
    });

    test('the rating is reputationOf over exactly the counted records', () {
      final records = [
        _record(5),
        _record(5, index: 2),
        _record(1, index: 3, revoked: true),
        _record(4, index: 4),
        _record(1, index: 5, tag2: ''),
      ];

      expect(
        reputationOf(countedFeedback(records, _provenance)),
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
      expect(countedFeedback(const [], _provenance), isEmpty);
      expect(
        reputationOf(countedFeedback(const [], _provenance)),
        reputationPriorMean,
      );
    });
  });
}
