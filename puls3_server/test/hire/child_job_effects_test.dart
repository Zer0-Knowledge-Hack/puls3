import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/chain/chain_submission_store.dart';
import 'package:puls3_server/src/chain/escrow_effects.dart';
import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:puls3_server/src/hire/child_job_effects.dart';
import 'package:puls3_server/src/hire/hire_escrow_effects.dart';
import 'package:puls3_server/src/hire/hire_lifecycle_store.dart';
import 'package:puls3_server/src/hire/hire_receipt_store.dart';
import 'package:puls3_server/src/ledger/escrow_events.dart';
import 'package:puls3_server/src/ledger/stellar_config.dart';
import 'package:test/test.dart';

import '../support/in_memory_child_job_store.dart';
import '../support/in_memory_escrow_preparation_store.dart';
import '../support/in_memory_hire_lifecycle_store.dart';
import '../support/in_memory_hire_receipt_store.dart';
import '../unit/hire/hire_test_fakes.dart';

const _alice = 'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H';
const _agentA = 'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY';
const _agentB = 'GBRPYHIL2CI3FNQ4BXLFMNDLFJUNPU2HY3ZMFSHONUCEOASW7QC7OX2H';
const _budget = 500000;
const _childExpiry = 1791747914;
const _parentJobId = 3;
const _childJobId = 4;
const _createTx =
    '43cd3e8455cafdc08d62a644b8f9dd9174994644b2bdd3e57eaa6893aa5c2437';
final _escrow = StellarConfig.testnet.escrow;
final _usdc = StellarConfig.testnet.usdcSac;
final _at = DateTime.utc(2026, 11, 19, 12);

const _settleTx =
    '9f2c3e8455cafdc08d62a644b8f9dd9174994644b2bdd3e57eaa6893aa5c2401';

StoredSubmission _submission(
  int? childHireId, {
  SubmissionPurpose purpose = SubmissionPurpose.createChildJob,
  String transactionHash = _createTx,
}) => StoredSubmission(
  id: 21,
  preparationId: null,
  purpose: purpose,
  transactionHash: transactionHash,
  state: SubmissionState.submitted,
  errorCode: null,
  explorerUrl: null,
  hireId: childHireId,
  signedEnvelopeXdr: 'AAAA',
  validUntil: _at,
  lastSentAt: null,
  sendAttempts: 0,
  createdAt: _at,
  updatedAt: _at,
  lastCheckedAt: _at,
);

ChildJobCreatedEvent _child({
  int parentJobId = _parentJobId,
  String provider = _agentB,
  int agentId = 9,
  int budget = _budget,
  int reserve = 0,
}) => ChildJobCreatedEvent(
  parentJobId: parentJobId,
  childJobId: _childJobId,
  provider: StellarAddress.parse(provider),
  agentId: AgentId(agentId),
  budget: BigInt.from(budget),
  reserve: BigInt.from(reserve),
  depth: 1,
  parentReserveLeft: BigInt.from(1500000),
);

JobCreatedEvent _created({
  String client = _agentA,
  int expiredAt = _childExpiry,
}) => JobCreatedEvent(
  jobId: _childJobId,
  client: StellarAddress.parse(client),
  provider: StellarAddress.parse(_agentB),
  evaluator: StellarAddress.parse(_agentA),
  agentId: AgentId(9),
  token: _usdc,
  budget: BigInt.from(_budget),
  expiredAt: expiredAt,
);

JobFundedEvent _funded({int amount = _budget}) => JobFundedEvent(
  jobId: _childJobId,
  client: StellarAddress.parse(_agentA),
  amount: BigInt.from(amount),
  feeBps: 0,
);

void main() {
  late InMemoryHireLifecycleStore hires;
  late InMemoryHireReceiptStore receipts;
  late InMemoryChildJobStore openings;
  late ChildJobEffects effects;
  late int childHireId;

  setUp(() async {
    hires = InMemoryHireLifecycleStore();
    receipts = InMemoryHireReceiptStore(now: () => _at);
    openings = InMemoryChildJobStore(hires, receipts);
    effects = ChildJobEffects(
      scope: <T>(action) => action(hires, receipts, openings),
      escrow: _escrow,
    );
    final parent = await hires.insertHire(
      const NewHire(
        consumer: _alice,
        agentId: 7,
        price: 5000000,
        manifestVersion: 1,
        expiredAt: _childExpiry + 200000,
        requestId: 'parent',
        input: 'summarise',
        subcontractReserve: 2000000,
      ),
    );
    await hires.bindJob(
      parent.id,
      _parentJobId,
      expiredAt: _childExpiry + 200000,
    );
    final child = await hires.insertHire(
      NewHire(
        consumer: _agentA,
        agentId: 9,
        price: _budget,
        manifestVersion: 3,
        expiredAt: _childExpiry,
        requestId: 'child:${parent.id}:call-1',
        input: 'research',
        parentHireId: parent.id,
      ),
    );
    childHireId = child.id;
    await receipts.insert(
      NewReceiptLine(
        parentHireId: parent.id,
        childHireId: child.id,
        providerAgentId: 9,
        providerWallet: _agentB,
        budget: _budget,
        relatedParty: false,
        justification: 'cheapest research agent',
        createTransaction: _createTx,
      ),
    );
  });

  Future<EffectResult> apply({
    List<ChildJobCreatedEvent>? children,
    List<JobCreatedEvent>? created,
    List<JobFundedEvent>? funded,
    int? hireId,
  }) => effects.onChildJobCreated(
    _submission(hireId ?? childHireId),
    children ?? [_child()],
    created: created ?? [_created()],
    funded: funded ?? [_funded()],
  );

  Matcher mismatch(String? field) => isA<EffectFailed>()
      .having((r) => r.code, 'code', SubmissionOutcomeCode.jobMismatch)
      .having((r) => r.field, 'field', field);

  Future<ReceiptLine> line() async =>
      (await receipts.findByChildHire(childHireId))!;

  Future<void> expectNotOpened() async {
    expect(openings.payments, isEmpty);
    expect(openings.queued, isEmpty);
    expect((await hires.findHire(childHireId))!.jobId, isNull);
    expect((await line()).state, ReceiptLineState.pending);
  }

  group('onChildJobCreated', () {
    test('binds the child job, pays B and opens the receipt line', () async {
      expect(await apply(), isA<EffectOk>());

      final child = (await hires.findHire(childHireId))!;
      expect(child.jobId, _childJobId);
      expect(child.expiredAt, _childExpiry);
      expect(child.escrow, _escrow.value);
      final payment = openings.payments[childHireId]!;
      expect(payment.payer, _agentA);
      expect(payment.payee, _agentB);
      expect(payment.amount, _budget);
      expect(payment.transactionHash, _createTx);
      expect(openings.queued, [childHireId]);
      final opened = await line();
      expect(opened.childJobId, _childJobId);
      expect(opened.createTransaction, _createTx);
      expect(opened.state, HireStatus.funded.name);
    });

    test('applying it again pays and queues once', () async {
      await apply();

      expect(await apply(), isA<EffectOk>());

      expect(openings.payments, hasLength(1));
      expect(openings.queued, [childHireId]);
    });

    final cases = <String, Future<EffectResult> Function()>{
      'parent_job_id': () => apply(children: [_child(parentJobId: 99)]),
      'provider': () => apply(children: [_child(provider: _alice)]),
      'agent_id': () => apply(children: [_child(agentId: 10)]),
      'budget': () => apply(children: [_child(budget: _budget + 1)]),
      'reserve': () => apply(children: [_child(reserve: 1)]),
      'client': () => apply(created: [_created(client: _alice)]),
      'expired_at': () => apply(created: [_created(expiredAt: 1)]),
      'amount': () => apply(funded: [_funded(amount: _budget - 1)]),
    };
    for (final MapEntry(key: field, value: run) in cases.entries) {
      test('a different $field does not fund the child', () async {
        expect(await run(), mismatch(field));
        await expectNotOpened();
      });
    }

    test('several ChildJobCreated events are not provable', () async {
      expect(await apply(children: [_child(), _child()]), mismatch('job_id'));
      await expectNotOpened();
    });

    test('a child job without its JobCreated or JobFunded is not '
        'provable', () async {
      expect(await apply(created: []), mismatch('job_id'));
      expect(await apply(funded: []), mismatch('job_id'));
      await expectNotOpened();
    });

    test('a job id another hire holds is a mismatch on job_id', () async {
      final other = await hires.insertHire(
        const NewHire(
          consumer: _alice,
          agentId: 7,
          price: 1,
          manifestVersion: 1,
          expiredAt: 1,
          requestId: 'other',
          input: 'x',
        ),
      );
      await hires.bindJob(other.id, _childJobId, expiredAt: 1);

      expect(await apply(), mismatch('job_id'));
      expect(openings.payments, isEmpty);
    });

    test('a submission without a child hire is terminal', () async {
      expect(
        await effects.onChildJobCreated(
          _submission(null),
          [_child()],
          created: [_created()],
          funded: [_funded()],
        ),
        mismatch(null),
      );
      expect(await apply(hireId: 999), mismatch(null));
    });
  });

  group('onChildJobFailed', () {
    Future<String> failWith(String code) async {
      await effects.onChildJobFailed(_submission(childHireId), code);
      return (await line()).state;
    }

    for (final code in [
      SubmissionOutcomeCode.transactionFailed,
      SubmissionOutcomeCode.preparationExpired,
      SubmissionOutcomeCode.submissionRejected,
    ]) {
      test('$code marks the line not_opened', () async {
        expect(await failWith(code), ReceiptLineState.notOpened);
      });
    }

    for (final code in [
      SubmissionOutcomeCode.jobMismatch,
      SubmissionOutcomeCode.jobEvidenceUnavailable,
      SubmissionOutcomeCode.outcomeUnknown,
    ]) {
      test('$code may have landed: the line is unverified', () async {
        expect(await failWith(code), ReceiptLineState.unverified);
      });
    }

    test('a line that left pending is not changed', () async {
      await apply();

      expect(
        await failWith(SubmissionOutcomeCode.transactionFailed),
        HireStatus.funded.name,
      );
    });

    test('a submission without a child hire does nothing', () async {
      await effects.onChildJobFailed(
        _submission(null),
        SubmissionOutcomeCode.transactionFailed,
      );
      expect((await line()).state, ReceiptLineState.pending);
    });
  });

  group('HireEscrowEffects', () {
    HireEscrowEffects hireEffects({ChildJobEffects? children}) =>
        HireEscrowEffects(
          repositories: <T>(action) => action(FakeHireRepository()),
          lifecycle: <T>(action) =>
              action(hires, InMemoryEscrowPreparationStore()),
          ledger: FakeLedger(),
          jobs: FakeLedger(),
          usdc: _usdc,
          escrow: _escrow,
          children: children,
        );

    test('delegates child jobs to its ChildJobEffects', () async {
      final delegating = hireEffects(children: effects);

      expect(
        await delegating.onChildJobCreated(
          _submission(childHireId),
          [_child()],
          created: [_created()],
          funded: [_funded()],
        ),
        isA<EffectOk>(),
      );
      expect(openings.queued, [childHireId]);
    });

    test('delegates relay settlements to its ChildJobEffects', () async {
      await apply();

      await hireEffects(children: effects).onRelaySettled(
        _submission(childHireId, purpose: SubmissionPurpose.claimRefund),
        const [],
      );

      expect((await line()).state, HireStatus.expired.name);
    });

    test('without ChildJobEffects a relay settlement changes nothing and does '
        'not throw, because plain hires are released too', () async {
      await hireEffects().onRelaySettled(
        _submission(childHireId, purpose: SubmissionPurpose.release),
        const [],
      );
    });

    test('without ChildJobEffects throws, so the record is retried', () {
      final bare = hireEffects();

      expect(
        bare.onChildJobCreated(
          _submission(childHireId),
          [_child()],
          created: [_created()],
          funded: [_funded()],
        ),
        throwsStateError,
      );
      expect(
        bare.onChildJobFailed(
          _submission(childHireId),
          SubmissionOutcomeCode.transactionFailed,
        ),
        throwsStateError,
      );
    });
  });
  group('onChildSettled', () {
    JobCompletedEvent completed({int jobId = _childJobId}) => JobCompletedEvent(
      jobId: jobId,
      evaluator: StellarAddress.parse(_agentA),
      payout: BigInt.from(490000),
      fee: BigInt.from(10000),
      autoReleased: false,
    );

    Future<void> settle(
      SubmissionPurpose purpose, [
      List<JobCompletedEvent>? events,
    ]) => effects.onChildSettled(
      _submission(
        childHireId,
        purpose: purpose,
        transactionHash: _settleTx,
      ),
      events ?? [completed()],
    );

    test('a confirmed complete records fee, payout and the settle '
        'transaction', () async {
      await apply();

      await settle(SubmissionPurpose.childComplete);

      final settled = await line();
      expect(settled.state, HireStatus.completed.name);
      expect(settled.fee, 10000);
      expect(settled.payout, 490000);
      expect(settled.settleTransaction, _settleTx);
    });

    test('a confirmed reject pays nothing', () async {
      await apply();

      await settle(SubmissionPurpose.childReject, const []);

      final settled = await line();
      expect(settled.state, HireStatus.rejected.name);
      expect(settled.fee, 0);
      expect(settled.payout, 0);
      expect(settled.settleTransaction, _settleTx);
    });

    test('a complete without the child job event leaves fee and payout '
        'unset', () async {
      await apply();

      await settle(SubmissionPurpose.childComplete, [completed(jobId: 99)]);

      final settled = await line();
      expect(settled.state, HireStatus.completed.name);
      expect(settled.fee, isNull);
      expect(settled.payout, isNull);
    });

    test('is applied once', () async {
      await apply();
      await settle(SubmissionPurpose.childComplete);

      await settle(SubmissionPurpose.childReject, const []);

      expect((await line()).state, HireStatus.completed.name);
    });

    test('does not settle a line that never opened', () async {
      await settle(SubmissionPurpose.childComplete);

      expect((await line()).state, ReceiptLineState.pending);
      expect((await line()).settleTransaction, isNull);
    });
  });
  group('onRelaySettled', () {
    JobCompletedEvent completed({int jobId = _childJobId}) => JobCompletedEvent(
      jobId: jobId,
      evaluator: StellarAddress.parse(_agentA),
      payout: BigInt.from(490000),
      fee: BigInt.from(10000),
      autoReleased: true,
    );

    Future<void> relay(
      SubmissionPurpose purpose, [
      List<JobCompletedEvent>? events,
      int? hireId,
    ]) => effects.onRelaySettled(
      _submission(
        hireId ?? childHireId,
        purpose: purpose,
        transactionHash: _settleTx,
      ),
      events ?? [completed()],
    );

    test('a confirmed release records the child as completed with fee, '
        'payout and the settle transaction', () async {
      await apply();

      await relay(SubmissionPurpose.release);

      final settled = await line();
      expect(settled.state, HireStatus.completed.name);
      expect(settled.fee, 10000);
      expect(settled.payout, 490000);
      expect(settled.settleTransaction, _settleTx);
    });

    test('a confirmed claim_refund records the child as expired and paying '
        'nothing, since the budget went back to the reserve', () async {
      await apply();

      await relay(SubmissionPurpose.claimRefund, const []);

      final settled = await line();
      expect(settled.state, HireStatus.expired.name);
      expect(settled.fee, 0);
      expect(settled.payout, 0);
      expect(settled.settleTransaction, _settleTx);
    });

    test('a release without the child job event leaves fee and payout '
        'unset', () async {
      await apply();

      await relay(SubmissionPurpose.release, [completed(jobId: 99)]);

      final settled = await line();
      expect(settled.state, HireStatus.completed.name);
      expect(settled.fee, isNull);
      expect(settled.payout, isNull);
    });

    test(
      'a verdict already settled the line: the relay writes nothing',
      () async {
        await apply();
        await effects.onChildSettled(
          _submission(
            childHireId,
            purpose: SubmissionPurpose.childReject,
            transactionHash: _createTx,
          ),
          const [],
        );

        await relay(SubmissionPurpose.release);

        expect((await line()).state, HireStatus.rejected.name);
        expect((await line()).settleTransaction, _createTx);
      },
    );

    test('a hire without a receipt line, such as a plain hire, changes '
        'nothing', () async {
      await relay(SubmissionPurpose.release, null, childHireId + 100);

      expect((await line()).state, ReceiptLineState.pending);
    });

    test('a hire without a stored hire id changes nothing', () async {
      await effects.onRelaySettled(
        _submission(null, purpose: SubmissionPurpose.release),
        const [],
      );
    });
  });
}
