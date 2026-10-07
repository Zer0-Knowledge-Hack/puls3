import 'dart:convert';
import 'dart:io';

import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/chain/chain_submission_store.dart';
import 'package:puls3_server/src/chain/escrow_effects.dart';
import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:puls3_server/src/hire/hire_escrow_effects.dart';
import 'package:puls3_server/src/ledger/escrow_events.dart';
import 'package:puls3_server/src/ledger/escrow_job.dart';
import 'package:puls3_server/src/ledger/ledger_errors.dart';
import 'package:puls3_server/src/ledger/stellar_config.dart';
import 'package:test/test.dart';

import 'hire_test_fakes.dart';

final _alice = StellarAddress.parse(
  'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H',
);
final _agentWallet = StellarAddress.parse(
  'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY',
);
final _stranger = StellarAddress.parse(
  'GBRPYHIL2CI3FNQ4BXLFMNDLFJUNPU2HY3ZMFSHONUCEOASW7QC7OX2H',
);
final _usdc = StellarConfig.testnet.usdcSac;

/// The testnet `fund` of escrow job 3.
const _fundTx =
    '43cd3e8455cafdc08d62a644b8f9dd9174994644b2bdd3e57eaa6893aa5c2437';
const _otherTx =
    '652a575b5d85814c19a4fed0f7d21f40acb35a399c4008d450877ee83e8b31ab';

/// `expired_at` of job 3, which the hire was prepared with.
const _expiredAt = 1791747914;
const _price = 5000000;
final _at = DateTime.utc(2026, 10, 5, 12);

StoredSubmission _submission({
  int? hireId = 1,
  SubmissionPurpose purpose = SubmissionPurpose.fund,
  String transactionHash = _fundTx,
}) => StoredSubmission(
  id: 11,
  preparationId: 'prep-1',
  purpose: purpose,
  transactionHash: transactionHash,
  state: SubmissionState.submitted,
  errorCode: null,
  explorerUrl: null,
  hireId: hireId,
  signedEnvelopeXdr: 'AAAA',
  validUntil: _at,
  lastSentAt: null,
  sendAttempts: 0,
  createdAt: _at,
  updatedAt: _at,
  lastCheckedAt: _at,
);

JobFundedEvent _event({int jobId = 3}) => JobFundedEvent(
  jobId: jobId,
  client: _alice,
  amount: BigInt.from(_price),
  feeBps: 0,
);

EscrowJob _job({
  StellarAddress? client,
  StellarAddress? evaluator,
  StellarAddress? provider,
  StellarAddress? token,
  int agentId = 7,
  int budget = _price,
  int expiredAt = _expiredAt,
  EscrowJobState state = EscrowJobState.funded,
}) => EscrowJob(
  client: client ?? _alice,
  provider: provider ?? _agentWallet,
  evaluator: evaluator ?? _alice,
  agentId: AgentId(agentId),
  token: token ?? _usdc,
  budget: BigInt.from(budget),
  feeBps: 0,
  expiredAt: expiredAt,
  description: 'puls3 testnet evidence job',
  state: state,
  submittedAt: 0,
  approvalDeadline: 0,
  deliverable: null,
);

Map<String, Object?> _fixture(String name) =>
    (jsonDecode(File('test/unit/ledger/fixtures/$name').readAsStringSync())
            as Map<String, Object?>)['result']!
        as Map<String, Object?>;

/// A repository whose `recordPayment` always hits [index].
final class _ConflictingRepository extends FakeHireRepository {
  _ConflictingRepository(this.index);

  final HirePaymentIndex index;

  @override
  Future<Hire> recordPayment(Hire paid, Payment payment, int jobId) async =>
      throw HirePaymentConflict(index);
}

void main() {
  late FakeHireRepository repo;
  late FakeLedger ledger;
  late Hire hire;

  HireEscrowEffects effects(FakeHireRepository used) => HireEscrowEffects(
    repositories: <T>(action) => action(used),
    ledger: ledger,
    jobs: ledger,
    usdc: _usdc,
  );

  Future<EffectResult> fund({
    StoredSubmission? submission,
    JobFundedEvent? event,
    FakeHireRepository? withRepo,
  }) => effects(
    withRepo ?? repo,
  ).onFunded(submission ?? _submission(), event ?? _event());

  Matcher mismatch(String? field) => isA<EffectFailed>()
      .having((r) => r.code, 'code', SubmissionOutcomeCode.jobMismatch)
      .having((r) => r.field, 'field', field);

  Future<void> expectNotPaid() async {
    expect((await repo.findById(hire.id))!.status, HireStatus.requested);
    expect(repo.recordPaymentCalls, 0);
  }

  setUp(() async {
    repo = FakeHireRepository();
    ledger = FakeLedger()
      ..wallets[7] = _agentWallet
      ..jobs[3] = _job();
    hire = await repo.create(
      agentId: AgentId(7),
      consumer: _alice,
      price: UsdcAmount.stroops(_price),
      manifestVersion: 1,
      expiredAt: _expiredAt,
    );
  });

  group('onFunded accepts the funding', () {
    test('pays the hire and stores the payment with the job id', () async {
      final result = await fund();

      expect(result, isA<EffectOk>());
      final stored = (await repo.findById(hire.id))!;
      expect(stored.status, HireStatus.paid);
      expect(stored.paymentTransaction?.value, _fundTx);
      expect(repo.jobIds[hire.id.value], 3);
      final payment = repo.payments[hire.id.value]!;
      expect(payment.payer, _alice);
      expect(payment.payee, _agentWallet);
      expect(payment.amount, UsdcAmount.stroops(_price));
    });

    test('accepts the recorded testnet fund of job 3', () async {
      final event = firstJobFunded(
        _fixture('get_transaction_fund_job_3.json'),
        escrow: StellarConfig.testnet.escrow,
      )!;
      final recorded = decodeEscrowJob(
        (_fixture('simulate_escrow_job_3.json')['results']! as List)
            .cast<Map<String, Object?>>()
            .single['returnValueJson'],
      );
      // The recorded get_job(3) was read after the job completed. At the
      // time of the fund transaction it was Funded.
      expect(recorded.state, EscrowJobState.completed);
      ledger.jobs[3] = EscrowJob(
        client: recorded.client,
        provider: recorded.provider,
        evaluator: recorded.evaluator,
        agentId: recorded.agentId,
        token: recorded.token,
        budget: recorded.budget,
        feeBps: recorded.feeBps,
        expiredAt: recorded.expiredAt,
        description: recorded.description,
        state: EscrowJobState.funded,
        submittedAt: 0,
        approvalDeadline: 0,
        deliverable: null,
      );

      final result = await fund(event: event);

      expect(event.jobId, 3);
      expect(result, isA<EffectOk>());
      expect((await repo.findById(hire.id))!.status, HireStatus.paid);
      expect(repo.jobIds[hire.id.value], 3);
    });

    test('is idempotent: the same submission applied twice pays once', () async {
      expect(await fund(), isA<EffectOk>());
      expect(await fund(), isA<EffectOk>());

      expect(repo.recordPaymentCalls, 1);
      expect((await repo.findById(hire.id))!.status, HireStatus.paid);
    });

    test('a retry of a paid hire does not read the chain again', () async {
      expect(await fund(), isA<EffectOk>());
      ledger.jobError = const LedgerUnavailable('RPC down');

      expect(await fund(), isA<EffectOk>());
    });
  });

  group('onFunded rejects with JobMismatch and the mismatching field', () {
    final cases = <String, (EscrowJob Function(), String)>{
      'state Open': (() => _job(state: EscrowJobState.open), 'state'),
      'state Submitted': (
        () => _job(state: EscrowJobState.submitted),
        'state',
      ),
      'state Completed': (
        () => _job(state: EscrowJobState.completed),
        'state',
      ),
      'state Rejected': (() => _job(state: EscrowJobState.rejected), 'state'),
      'state Expired': (() => _job(state: EscrowJobState.expired), 'state'),
      'client': (() => _job(client: _stranger), 'client'),
      'evaluator': (() => _job(evaluator: _stranger), 'evaluator'),
      'provider': (() => _job(provider: _stranger), 'provider'),
      'agent': (() => _job(agentId: 8), 'agent_id'),
      'token': (() => _job(token: _stranger), 'token'),
      'budget': (() => _job(budget: _price + 1), 'budget'),
      'expired_at': (() => _job(expiredAt: _expiredAt + 1), 'expired_at'),
    };
    for (final entry in cases.entries) {
      test(entry.key, () async {
        ledger.jobs[3] = entry.value.$1();

        final result = await fund();

        expect(result, mismatch(entry.value.$2));
        await expectNotPaid();
      });
    }

    test('provider: the agent has no wallet', () async {
      ledger.wallets.remove(7);

      expect(await fund(), mismatch('provider'));
      await expectNotPaid();
    });

    test('job_id: another hire is already bound to the job', () async {
      final other = await repo.create(
        agentId: AgentId(7),
        consumer: _alice,
        price: UsdcAmount.stroops(_price),
        manifestVersion: 1,
        expiredAt: _expiredAt,
      );
      repo.jobIds[other.id.value] = 3;

      expect(await fund(), mismatch('job_id'));
      expect((await repo.findById(hire.id))!.status, HireStatus.requested);
    });

    for (final index in HirePaymentIndex.values) {
      test('job_id: a ${index.name} conflict from the store', () async {
        final conflicting = _ConflictingRepository(index);
        await conflicting.create(
          agentId: AgentId(7),
          consumer: _alice,
          price: UsdcAmount.stroops(_price),
          manifestVersion: 1,
          expiredAt: _expiredAt,
        );

        expect(await fund(withRepo: conflicting), mismatch('job_id'));
      });
    }

    test('job_id: the hire was paid by another transaction', () async {
      expect(await fund(), isA<EffectOk>());

      final result = await fund(
        submission: _submission(transactionHash: _otherTx),
        event: _event(jobId: 4),
      );

      expect(result, mismatch('job_id'));
      expect(repo.recordPaymentCalls, 1);
      expect(
        (await repo.findById(hire.id))!.paymentTransaction?.value,
        _fundTx,
      );
    });

    test('no field: the hire is no longer payable', () async {
      repo.hires[hire.id.value] = hire.cancel();

      expect(await fund(), mismatch(null));
      expect(repo.recordPaymentCalls, 0);
    });
  });

  group('onFunded without evidence', () {
    test('JobEvidenceUnavailable when the escrow has no such job', () async {
      ledger.jobs.clear();

      final result = await fund();

      expect(
        result,
        isA<EffectFailed>()
            .having(
              (r) => r.code,
              'code',
              SubmissionOutcomeCode.jobEvidenceUnavailable,
            )
            .having((r) => r.field, 'field', isNull),
      );
      await expectNotPaid();
    });

    test('a ledger failure propagates so the tracker retries', () async {
      ledger.jobError = const LedgerUnavailable('RPC down');

      await expectLater(fund(), throwsA(isA<LedgerUnavailable>()));
      await expectNotPaid();
    });

    test('a wallet read failure propagates so the tracker retries', () async {
      ledger.walletError = const LedgerUnavailable('RPC down');

      await expectLater(fund(), throwsA(isA<LedgerUnavailable>()));
      await expectNotPaid();
    });

    test('a submission without a hire is a terminal JobMismatch', () async {
      final result = await fund(submission: _submission(hireId: null));

      expect(
        result,
        isA<EffectFailed>()
            .having((r) => r.code, 'code', SubmissionOutcomeCode.jobMismatch)
            .having((r) => r.field, 'field', isNull),
      );
    });

    test('an unknown hire is a terminal JobMismatch', () async {
      final result = await fund(submission: _submission(hireId: 99));

      expect(
        result,
        isA<EffectFailed>()
            .having((r) => r.code, 'code', SubmissionOutcomeCode.jobMismatch)
            .having((r) => r.field, 'field', isNull),
      );
    });
  });

  group('onJobCreated', () {
    test('has no effect until the hire lifecycle (#96)', () async {
      final result = await effects(repo).onJobCreated(
        _submission(purpose: SubmissionPurpose.createJob),
        JobCreatedEvent(
          jobId: 3,
          client: _alice,
          provider: _agentWallet,
          evaluator: _alice,
          agentId: AgentId(7),
          token: _usdc,
          budget: BigInt.from(_price),
          expiredAt: _expiredAt,
        ),
      );

      expect(result, isA<EffectOk>());
      expect(repo.recordPaymentCalls, 0);
    });
  });
}
