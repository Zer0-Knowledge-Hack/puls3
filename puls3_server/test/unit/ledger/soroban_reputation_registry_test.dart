import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;
import 'package:puls3_server/src/ledger/contract_reader.dart';
import 'package:puls3_server/src/ledger/escrow_job.dart';
import 'package:puls3_server/src/ledger/ledger_errors.dart';
import 'package:puls3_server/src/ledger/soroban_reputation_registry.dart';
import 'package:puls3_server/src/ledger/soroban_rpc_client.dart';
import 'package:puls3_server/src/ledger/stellar_config.dart';
import 'package:test/test.dart';

import '../../support/fake_reputation_chain.dart';
import '../../support/reputation_registry_contract.dart';

final _alice = StellarAddress.parse(
  'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H',
);
final _bob = StellarAddress.parse(
  'GCHX6NRPMSB4CIZM3ZLHPOC2VD6DJVAN6IY3NE5QSAMOWJ7N4TAWK6HN',
);

/// A contract that is not the escrow the adapter trusts.
final _otherEscrow = StellarAddress.parse(
  'CD5QZOKGRBV35C5SDT6PG7S72XGG4BHQAC2L56YLNBJDUL4LDMTXFIJJ',
);

StoredFeedback _stored(
  int value, {
  int decimals = 0,
  bool revoked = false,
  String tag1 = '',
  String tag2 = '',
}) => (
  value: value,
  decimals: decimals,
  revoked: revoked,
  tag1: tag1,
  tag2: tag2,
);

/// Answers `get_job` per id: a job, null (no such job) or an error. Counts
/// how many reads run at once.
final class _ScriptedJobs implements EscrowJobReader {
  _ScriptedJobs(this.answers);

  final Map<int, Object?> answers;
  var inFlight = 0;
  var maxInFlight = 0;

  @override
  Future<EscrowJob?> escrowJob(int jobId) async {
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    try {
      await Future<void>.delayed(const Duration(milliseconds: 2));
      final answer = answers[jobId];
      if (answer is Exception) throw answer;
      return answer as EscrowJob?;
    } finally {
      inFlight--;
    }
  }
}

final class _NoOwners implements AgentOwnerReader {
  @override
  Future<StellarAddress?> ownerOf(AgentId agent) async => null;
}

EscrowJob _escrowJob(StellarAddress client) => EscrowJob(
  client: client,
  provider: client,
  evaluator: client,
  agentId: AgentId(7),
  token: client,
  budget: BigInt.from(5000000),
  feeBps: 0,
  expiredAt: 0,
  description: '',
  state: EscrowJobState.completed,
  submittedAt: 0,
  approvalDeadline: 0,
  deliverable: null,
);

/// A registry over [jobs]; the registry reads are not used by provenanceOf.
SorobanReputationRegistry _overJobs(EscrowJobReader jobs) =>
    SorobanReputationRegistry(
      ContractReader(
        SorobanRpcClient(
          httpClient: MockClient((_) async => http.Response('', 503)),
          url: StellarConfig.testnet.rpcUrl,
          timeout: const Duration(seconds: 1),
        ),
        source: StellarConfig.testnet.simulationSource,
      ),
      registry: StellarConfig.testnet.escrow,
      escrow: FakeReputationChain.defaultEscrow,
      jobs: jobs,
      owners: _NoOwners(),
    );

/// A record of agent 7 by Alice for job [id] on the trusted escrow.
FeedbackRecord _paidRecord(int id) => FeedbackRecord(
  agentId: AgentId(7),
  client: _alice,
  index: id,
  value: BigInt.from(5),
  valueDecimals: 0,
  isRevoked: false,
  tag2: PaidJobReference(
    escrow: FakeReputationChain.defaultEscrow,
    jobId: id,
  ).text,
);

void main() {
  group('SorobanReputationRegistry', () {
    group('shared contract', () {
      reputationRegistryContract(ChainReputationRegistryRig.new);
    });

    test(
      'reads the clients, their last index, each feedback and its job',
      () async {
        final chain = FakeReputationChain()..addPaid(7, _alice, _stored(4));

        final feedback = await chain.adapter.feedbacksOf(AgentId(7));

        expect(feedback.single.score, 4);
        expect(feedback.single.client, _alice);
        expect(feedback.single.agentId, AgentId(7));
        // The registry stores no puls3 hire id: the job is in tag2 instead.
        expect(feedback.single.hireId, isNull);
        // A page with the client, the empty page that ends the list, the last
        // index, the one feedback, the owner_of of the agent and the get_job
        // of its job.
        expect(chain.requests, hasLength(6));
        expect(chain.jobReads, 1);
        expect(chain.requests.map((r) => r['method']).toSet(), {
          'simulateTransaction',
        });
      },
    );

    test('reads every page of clients', () async {
      final chain = FakeReputationChain();
      final clients = [
        for (var i = 0; i < reputationPageSize + 1; i++) testAccount(i),
      ];
      for (final client in clients) {
        chain.addPaid(7, client, _stored(5));
      }

      final feedback = await chain.adapter.feedbacksOf(AgentId(7));

      expect(feedback, hasLength(reputationPageSize + 1));
      expect(feedback.map((f) => f.client).toSet(), clients.toSet());
    });

    test('skips an entry that is not a puls3 score', () async {
      final chain = FakeReputationChain()
        ..addPaid(7, _alice, _stored(5, decimals: 2)) // 0.05, not a score
        ..addPaid(7, _alice, _stored(0)) // below the scale
        ..addPaid(7, _alice, _stored(6)) // above the scale
        ..addPaid(7, _alice, _stored(-3))
        ..addPaid(7, _bob, _stored(3, tag1: 'quality')); // tag1 does not filter

      final feedback = await chain.adapter.feedbacksOf(AgentId(7));

      expect(feedback.map((f) => f.score), [3]);
      // Only the record that could count needs its job read.
      expect(chain.jobReads, 1);
    });

    test('skips a feedback the registry no longer finds', () async {
      final chain = FakeReputationChain()
        ..addPaid(7, _alice, _stored(5))
        ..addPaid(7, _alice, _stored(2))
        ..missing.add((7, _alice, 1));

      final feedback = await chain.adapter.feedbacksOf(AgentId(7));

      expect(feedback.map((f) => f.score), [2]);
    });

    group('only ratings of a paid, completed job count (#201)', () {
      test('a score written straight to the contract does not count', () async {
        final chain = FakeReputationChain()
          ..addPaid(7, _alice, _stored(4))
          ..add(7, _bob, _stored(5)); // no job reference

        final read = await chain.adapter.readRecords(AgentId(7));
        final feedback = await chain.adapter.feedbacksOf(AgentId(7));

        expect(read.records, hasLength(2));
        expect(exclusionsOf(read.records, read.provenance), [
          null,
          FeedbackExclusion.noJobReference,
        ]);
        expect(feedback.map((f) => f.score), [4]);
      });

      test('tag2 is read verbatim and parsed as the job reference', () async {
        final chain = FakeReputationChain();
        final job = chain.addPaid(7, _alice, _stored(4));

        final record = (await chain.adapter.recordsOf(AgentId(7))).single;

        expect(record.tag2, chain.reference(job));
        expect(
          record.jobReference,
          PaidJobReference(escrow: chain.escrow, jobId: job),
        );
      });

      test('a job that is not completed does not count', () async {
        final chain = FakeReputationChain();
        for (final state in JobState.values) {
          chain.addPaid(7, _alice, _stored(5), jobState: state);
        }

        final read = await chain.adapter.readRecords(AgentId(7));

        expect(exclusionsOf(read.records, read.provenance), [
          for (final state in JobState.values)
            state == JobState.completed
                ? null
                : FeedbackExclusion.jobNotCompleted,
        ]);
        expect(await chain.adapter.feedbacksOf(AgentId(7)), hasLength(1));
      });

      test('a job of another client or another agent does not count', () async {
        final chain = FakeReputationChain();
        final bobsJob = chain.addPaid(7, _bob, _stored(5));
        final otherAgentsJob = chain.addPaid(8, _alice, _stored(5));
        chain
          ..add(7, _alice, _stored(5, tag2: chain.reference(bobsJob)))
          ..add(7, _alice, _stored(5, tag2: chain.reference(otherAgentsJob)));

        final read = await chain.adapter.readRecords(AgentId(7));

        // Bob (listed first) counts for his own job; Alice cannot borrow his
        // job or a job of agent 8.
        expect(exclusionsOf(read.records, read.provenance), [
          null,
          FeedbackExclusion.jobMismatch,
          FeedbackExclusion.jobMismatch,
        ]);
      });

      test('one job counts once, and is read once', () async {
        final chain = FakeReputationChain();
        final job = chain.addPaid(7, _alice, _stored(5));
        chain.add(7, _alice, _stored(1, tag2: chain.reference(job)));

        final read = await chain.adapter.readRecords(AgentId(7));

        expect(exclusionsOf(read.records, read.provenance), [
          null,
          FeedbackExclusion.jobAlreadyRated,
        ]);
        expect(chain.jobReads, 1);
        expect(
          (await chain.adapter.feedbacksOf(AgentId(7))).map((f) => f.score),
          [5],
        );
      });

      test('a job the escrow does not have is jobUnreadable', () async {
        final chain = FakeReputationChain();
        chain.add(7, _alice, _stored(5, tag2: chain.reference(424242)));

        final read = await chain.adapter.readRecords(AgentId(7));

        expect(exclusionsOf(read.records, read.provenance), [
          FeedbackExclusion.jobUnreadable,
        ]);
      });

      test(
        'a job on another escrow is never read and does not count',
        () async {
          final chain = FakeReputationChain()
            ..add(
              7,
              _alice,
              _stored(
                5,
                tag2: PaidJobReference(escrow: _otherEscrow, jobId: 1).text,
              ),
            );

          final read = await chain.adapter.readRecords(AgentId(7));

          expect(exclusionsOf(read.records, read.provenance), [
            FeedbackExclusion.otherEscrow,
          ]);
          expect(chain.jobReads, 0);
        },
      );

      test('a failing job read throws, never a silent exclusion', () async {
        final chain = FakeReputationChain()..addPaid(7, _alice, _stored(5));
        // The two client pages, the last index, the record and the owner
        // answer; the job read fails.
        chain.failAfterRequests = 5;

        await expectLater(
          chain.adapter.feedbacksOf(AgentId(7)),
          throwsA(isA<LedgerUnavailable>()),
        );
      });

      test('an archived job excludes only its own record', () async {
        // A job past its TTL answers a restorePreamble. That one record is
        // jobUnreadable; the agent's other ratings still count, so nobody
        // can blank a reputation by pointing a record at an archived job.
        final chain = FakeReputationChain();
        chain.addPaid(7, _alice, _stored(5));
        final archived = chain.addPaid(7, _alice, _stored(1));
        chain.addPaid(7, _bob, _stored(4));
        chain.archivedJobs.add(archived);

        final read = await chain.adapter.readRecords(AgentId(7));

        expect(exclusionsOf(read.records, read.provenance), [
          null,
          FeedbackExclusion.jobUnreadable,
          null,
        ]);
        expect(
          (await chain.adapter.feedbacksOf(AgentId(7))).map((f) => f.score),
          [5, 4],
        );
      });

      test('a job in a final state is read once per adapter', () async {
        final chain = FakeReputationChain();
        chain.addPaid(7, _alice, _stored(5));
        chain.addPaid(7, _bob, _stored(4), jobState: JobState.funded);
        final adapter = chain.adapter;

        await adapter.feedbacksOf(AgentId(7));
        expect(chain.jobReads, 2);

        // The completed job is not read again; the funded one can still
        // change, so it is.
        final counted = await adapter.feedbacksOf(AgentId(7));
        expect(chain.jobReads, 3);
        expect(counted.map((f) => f.score), [5]);
      });

      test('a completed job keeps counting after it archives', () async {
        final chain = FakeReputationChain();
        final job = chain.addPaid(7, _alice, _stored(5));
        final adapter = chain.adapter;
        await adapter.feedbacksOf(AgentId(7));

        chain.archivedJobs.add(job);

        expect(
          (await adapter.feedbacksOf(AgentId(7))).map((f) => f.score),
          [5],
        );
      });

      test('a rating from the agent owner does not count', () async {
        // Paid, completed and for the owner's own client address: the
        // contract accepts it, the reader does not count it.
        final chain = FakeReputationChain()..owners[7] = _bob;
        chain.addPaid(7, _alice, _stored(4));
        chain.addPaid(7, _bob, _stored(5));

        final read = await chain.adapter.readRecords(AgentId(7));

        expect(read.provenance.owner, _bob);
        expect(exclusionsOf(read.records, read.provenance), [
          null,
          FeedbackExclusion.fromAgentOwner,
        ]);
      });

      test('an owner that cannot be read fails the read, closed', () async {
        // Archived agent entry or registry instance: the owner rule must not
        // turn itself off. FeedbackService fails closed the same way.
        final chain = FakeReputationChain()
          ..owners[7] = _bob
          ..archivedOwners.add(7)
          ..addPaid(7, _bob, _stored(5));

        await expectLater(
          chain.adapter.feedbacksOf(AgentId(7)),
          throwsA(isA<LedgerUnavailable>()),
        );
      });

      test('an unknown owner excludes nothing', () async {
        final chain = FakeReputationChain()..addPaid(7, _bob, _stored(5));

        final read = await chain.adapter.readRecords(AgentId(7));

        expect(read.provenance.owner, isNull);
        expect(countedFeedback(read.records, read.provenance), hasLength(1));
      });

      test('a network failure in a mixed batch fails the whole read', () async {
        final jobs = _ScriptedJobs({
          1: _escrowJob(_alice),
          2: const LedgerUnavailable('restore', archived: true),
          3: const LedgerUnavailable('node down'),
          4: _escrowJob(_alice),
        });

        await expectLater(
          _overJobs(
            jobs,
          ).provenanceOf([for (var i = 1; i <= 4; i++) _paidRecord(i)]),
          throwsA(
            isA<LedgerUnavailable>().having(
              (e) => e.archived,
              'archived',
              false,
            ),
          ),
        );
      });

      test(
        'archived and missing jobs in a batch only drop their records',
        () async {
          final jobs = _ScriptedJobs({
            1: _escrowJob(_alice),
            2: const LedgerUnavailable('restore', archived: true),
            3: null,
          });

          final provenance = await _overJobs(
            jobs,
          ).provenanceOf([for (var i = 1; i <= 3; i++) _paidRecord(i)]);

          expect(provenance.jobs.keys, [1]);
        },
      );

      test('never more than $jobReadConcurrency job reads at once', () async {
        const count = jobReadConcurrency * 3 + 1;
        final jobs = _ScriptedJobs({
          for (var i = 1; i <= count; i++) i: _escrowJob(_alice),
        });

        final provenance = await _overJobs(
          jobs,
        ).provenanceOf([for (var i = 1; i <= count; i++) _paidRecord(i)]);

        expect(provenance.jobs, hasLength(count));
        expect(jobs.maxInFlight, jobReadConcurrency);
      });

      test('reads more jobs than one batch, each once', () async {
        final chain = FakeReputationChain();
        const count = jobReadConcurrency * 2 + 3;
        for (var i = 0; i < count; i++) {
          chain.addPaid(7, i.isEven ? _alice : _bob, _stored(1 + i % 5));
        }

        final counted = await chain.adapter.feedbacksOf(AgentId(7));

        expect(counted, hasLength(count));
        expect(chain.jobReads, count);
      });
    });

    group('no filtering beyond the public rules (#202, #201)', () {
      FakeReputationChain mixedChain() => FakeReputationChain()
        ..addPaid(7, _alice, _stored(5)) // counts
        ..addPaid(7, _alice, _stored(4, revoked: true)) // revoked
        ..addPaid(7, _alice, _stored(3)) // counts
        ..addPaid(7, _alice, _stored(2)) // unreadable (missing below)
        ..addPaid(7, _bob, _stored(25, decimals: 1)) // 2.5, not a whole score
        ..addPaid(7, _bob, _stored(9)) // outside 1 to 5
        ..addPaid(
          7,
          _bob,
          _stored(1, tag1: 'quality'),
        ) // counts: tag1 is no filter
        ..add(7, _bob, _stored(5)) // no paid job
        ..missing.add((7, _alice, 4));

      test('recordsOf returns every record the registry lists', () async {
        final chain = mixedChain();

        final read = await chain.adapter.readRecords(AgentId(7));

        expect(read.records, hasLength(8));
        expect(
          read.records.map((r) => (r.client, r.index)),
          [
            (_alice, 1),
            (_alice, 2),
            (_alice, 3),
            (_alice, 4),
            (_bob, 1),
            (_bob, 2),
            (_bob, 3),
            (_bob, 4),
          ],
        );
        expect(exclusionsOf(read.records, read.provenance), [
          null,
          FeedbackExclusion.revoked,
          null,
          FeedbackExclusion.unreadable,
          FeedbackExclusion.notWholeScore,
          FeedbackExclusion.outOfScale,
          null,
          FeedbackExclusion.noJobReference,
        ]);
      });

      test(
        'an agent with no feedback reads one empty page and no records',
        () async {
          final chain = FakeReputationChain();

          final read = await chain.adapter.readRecords(AgentId(7));

          expect(read.records, isEmpty);
          expect(read.provenance.jobs, isEmpty);
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
          chain.addPaid(7, client, _stored(4));
        }

        final read = await chain.adapter.readRecords(AgentId(7));

        // A full page, a page of one, and the empty page that ends the list.
        expect(read.clientPages, 3);
        expect(read.records, hasLength(reputationPageSize + 1));
        expect(read.records.map((r) => r.client).toSet(), clients.toSet());
        expect(
          countedFeedback(read.records, read.provenance),
          hasLength(clients.length),
        );
      });

      test(
        'equal scores from one client for two paid jobs are both counted',
        () async {
          // The registry keys a record by (client, index): two 5s from Alice
          // for two hires are two feedbacks, not a duplicate to drop.
          final chain = FakeReputationChain()
            ..addPaid(7, _alice, _stored(5))
            ..addPaid(7, _alice, _stored(5));

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
            ..addPaid(7, _alice, _stored(5))
            ..addPaid(7, _alice, _stored(1))
            ..addPaid(7, _bob, _stored(1));
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

      test('feedbacksOf is exactly countedFeedback of readRecords', () async {
        final read = await mixedChain().adapter.readRecords(AgentId(7));
        final feedback = await mixedChain().adapter.feedbacksOf(AgentId(7));

        final expected = countedFeedback(read.records, read.provenance);
        expect(feedback.map((f) => (f.client, f.score)), [
          for (final f in expected) (f.client, f.score),
        ]);
        expect(feedback.map((f) => f.score), [5, 3, 1]);
        // Every record either reaches the formula or has a public reason.
        final excluded = exclusionsOf(
          read.records,
          read.provenance,
        ).where((e) => e != null).length;
        expect(feedback.length + excluded, read.records.length);
        expect(reputationOf(feedback), reputationOf(expected));
      });
    });

    test('archived registry state is unavailable, not empty', () async {
      final chain = FakeReputationChain()
        ..addPaid(7, _alice, _stored(5))
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
