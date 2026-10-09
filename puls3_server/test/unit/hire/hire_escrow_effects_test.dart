import 'dart:convert';
import 'dart:io';

import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/chain/chain_submission_store.dart';
import 'package:puls3_server/src/chain/escrow_effects.dart';
import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:puls3_server/src/hire/escrow_preparation_store.dart';
import 'package:puls3_server/src/hire/hire_escrow_effects.dart';
import 'package:puls3_server/src/hire/hire_lifecycle_store.dart';
import 'package:puls3_server/src/ledger/escrow_events.dart';
import 'package:puls3_server/src/ledger/escrow_job.dart';
import 'package:puls3_server/src/ledger/ledger_errors.dart';
import 'package:puls3_server/src/ledger/stellar_config.dart';
import 'package:test/test.dart';

import '../../support/in_memory_escrow_preparation_store.dart';
import '../../support/in_memory_hire_lifecycle_store.dart';
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
  Future<Hire> recordPayment(Hire funded, Payment payment, int jobId) async =>
      throw HirePaymentConflict(index);
}

void main() {
  late FakeHireRepository repo;
  late FakeLedger ledger;
  late Hire hire;

  late InMemoryHireLifecycleStore lifecycle;
  late InMemoryEscrowPreparationStore preparations;

  HireEscrowEffects effects(FakeHireRepository used) => HireEscrowEffects(
    repositories: <T>(action) => action(used),
    lifecycle: <T>(action) => action(lifecycle, preparations),
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
    expect((await repo.findById(hire.id))!.status, HireStatus.open);
    expect(repo.recordPaymentCalls, 0);
  }

  setUp(() async {
    lifecycle = InMemoryHireLifecycleStore();
    preparations = InMemoryEscrowPreparationStore();
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
      expect(stored.status, HireStatus.funded);
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
      expect((await repo.findById(hire.id))!.status, HireStatus.funded);
      expect(repo.jobIds[hire.id.value], 3);
    });

    test(
      'is idempotent: the same submission applied twice pays once',
      () async {
        expect(await fund(), isA<EffectOk>());
        expect(await fund(), isA<EffectOk>());

        expect(repo.recordPaymentCalls, 1);
        expect((await repo.findById(hire.id))!.status, HireStatus.funded);
      },
    );

    test('a retry of a funded hire does not read the chain again', () async {
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
      expect((await repo.findById(hire.id))!.status, HireStatus.open);
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

    test('job_id: the hire was funded by another transaction', () async {
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

    test('no field: the hire is no longer open', () async {
      repo.hires[hire.id.value] = hire.reject();

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
    // The job the create_job opened lasts until this instant, which differs
    // from the hire's own expired_at so the effect must copy it.
    const preparedExpiry = 1800000500;

    Future<({HireRow row, StoredSubmission submission})> pending({
      String requestId = 'request-1',
      int? jobExpiredAt = preparedExpiry,
    }) async {
      final row = await lifecycle.insertHire(
        NewHire(
          consumer: _alice.value,
          agentId: 7,
          price: _price,
          manifestVersion: 1,
          expiredAt: _expiredAt,
          requestId: requestId,
          input: 'input',
        ),
      );
      final prepared = await preparations.insert(
        NewPreparation(
          preparationId: 'prep-$requestId',
          hireId: row.id,
          purpose: SubmissionPurpose.createJob,
          signer: _alice.value,
          unsignedEnvelopeXdr: 'AAAA',
          transactionHash: requestId.padLeft(64, '0'),
          sequence: 1,
          validUntil: _at,
          jobExpiredAt: jobExpiredAt,
        ),
      );
      return (
        row: row,
        submission: _submission(
          hireId: row.id,
          purpose: SubmissionPurpose.createJob,
        ).with_(preparationId: prepared.preparationId),
      );
    }

    JobCreatedEvent created(int jobId) => JobCreatedEvent(
      jobId: jobId,
      client: _alice,
      provider: _agentWallet,
      evaluator: _alice,
      agentId: AgentId(7),
      token: _usdc,
      budget: BigInt.from(_price),
      expiredAt: preparedExpiry,
    );

    test(
      'binds the job id, opens the hire and takes the prepared expiry',
      () async {
        final p = await pending();

        final result = await effects(
          repo,
        ).onJobCreated(p.submission, created(3));

        expect(result, isA<EffectOk>());
        final stored = (await lifecycle.findHire(p.row.id))!;
        expect(stored.jobId, 3);
        expect(stored.status, HireStatus.open);
        expect(stored.expiredAt, preparedExpiry);
        expect(repo.recordPaymentCalls, 0);
      },
    );

    test('applied twice it succeeds and the job id is stored once', () async {
      final p = await pending();
      await effects(repo).onJobCreated(p.submission, created(3));

      final again = await effects(repo).onJobCreated(p.submission, created(3));

      expect(again, isA<EffectOk>());
      expect(lifecycle.all.where((h) => h.jobId == 3), hasLength(1));
      expect((await lifecycle.findHire(p.row.id))!.expiredAt, preparedExpiry);
    });

    test(
      'a job id another hire holds is a mismatch and the hire keeps no status',
      () async {
        final first = await pending();
        final second = await pending(requestId: 'request-2');
        await effects(repo).onJobCreated(first.submission, created(3));

        final result = await effects(repo).onJobCreated(
          second.submission,
          created(3),
        );

        expect(result, mismatch('job_id'));
        final stored = (await lifecycle.findHire(second.row.id))!;
        expect(stored.jobId, isNull);
        expect(stored.status, isNull);
      },
    );

    test('a hire that already holds another job is a mismatch', () async {
      final p = await pending();
      await effects(repo).onJobCreated(p.submission, created(3));

      final result = await effects(repo).onJobCreated(p.submission, created(4));

      expect(result, mismatch('job_id'));
      expect((await lifecycle.findHire(p.row.id))!.jobId, 3);
    });

    test('a submission without a hire is a terminal mismatch', () async {
      final result = await effects(repo).onJobCreated(
        _submission(purpose: SubmissionPurpose.createJob, hireId: null),
        created(3),
      );

      expect(result, mismatch(null));
    });

    test(
      'an unknown hire or preparation, or none prepared expiry, is thrown for a retry',
      () async {
        final p = await pending();
        final unprepared = await pending(
          requestId: 'request-3',
          jobExpiredAt: null,
        );

        for (final submission in [
          p.submission.with_(hireId: 999),
          p.submission.with_(preparationId: 'nope'),
          p.submission.with_(preparationId: null),
          unprepared.submission,
        ]) {
          await expectLater(
            effects(repo).onJobCreated(submission, created(3)),
            throwsStateError,
          );
        }
        expect((await lifecycle.findHire(p.row.id))!.jobId, isNull);
        expect((await lifecycle.findHire(unprepared.row.id))!.jobId, isNull);
      },
    );
  });
}

extension on StoredSubmission {
  /// A copy; a `null` [preparationId] argument clears it only when passed.
  StoredSubmission with_({Object? preparationId = _keep, int? hireId}) =>
      StoredSubmission(
        id: id,
        preparationId: identical(preparationId, _keep)
            ? this.preparationId
            : preparationId as String?,
        purpose: purpose,
        transactionHash: transactionHash,
        state: state,
        errorCode: errorCode,
        explorerUrl: explorerUrl,
        hireId: hireId ?? this.hireId,
        signedEnvelopeXdr: signedEnvelopeXdr,
        validUntil: validUntil,
        lastSentAt: lastSentAt,
        sendAttempts: sendAttempts,
        createdAt: createdAt,
        updatedAt: updatedAt,
        lastCheckedAt: lastCheckedAt,
      );
}

const _keep = Object();
