@Tags(['integration'])
library;

import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;
import 'package:puls3_server/src/chain/chain_submission_store.dart';
import 'package:puls3_server/src/chain/chain_submission_tracker.dart';
import 'package:puls3_server/src/chain/escrow_effects.dart';
import 'package:puls3_server/src/chain/serverpod_chain_submission_store.dart';
import 'package:puls3_server/src/chain/submission_ledger.dart';
import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:puls3_server/src/generated/protocol.dart'
    show HirePaymentRecord, HireRunRecord;
import 'package:puls3_server/src/hire/child_job_effects.dart';
import 'package:puls3_server/src/hire/hire_escrow_effects.dart';
import 'package:puls3_server/src/hire/hire_lifecycle_store.dart';
import 'package:puls3_server/src/hire/hire_receipt_store.dart';
import 'package:puls3_server/src/hire/serverpod_child_job_store.dart';
import 'package:puls3_server/src/hire/serverpod_escrow_preparation_store.dart';
import 'package:puls3_server/src/hire/serverpod_hire_receipt_store.dart';
import 'package:puls3_server/src/hire/serverpod_hire_repository.dart';
import 'package:puls3_server/src/ledger/escrow_events.dart';
import 'package:puls3_server/src/ledger/stellar_config.dart';
import 'package:serverpod/serverpod.dart' show Session, Transaction;
import 'package:test/test.dart';

import '../support/fake_submission_ledger.dart';
import '../unit/hire/hire_test_fakes.dart';
import 'test_tools/serverpod_test_tools.dart';

const _alice = 'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H';
const _agentA = 'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY';
const _agentB = 'GBRPYHIL2CI3FNQ4BXLFMNDLFJUNPU2HY3ZMFSHONUCEOASW7QC7OX2H';
const _budget = 500000;
const _childExpiry = 1791747914;
final _at = DateTime.utc(2026, 11, 19, 12);
final _escrow = StellarConfig.testnet.escrow;

/// A parent hire with a bound job, its child hire and pending receipt line,
/// and the child's submitted `create_child_job`, as T6.1 stores them.
typedef _Child = ({
  int parentJobId,
  int childHireId,
  int childJobId,
  StoredSubmission submission,
});

/// [ChainSubmissionStore] whose [listSubmitted] only lists the records of
/// [hireIds], so rows other suites left `submitted` stay out of the pass.
final class _OwnRecords implements ChainSubmissionStore {
  _OwnRecords(this._inner, this.hireIds);

  final ChainSubmissionStore _inner;
  final Set<int> hireIds;

  @override
  Future<List<StoredSubmission>> listSubmitted({int limit = 100}) async => [
    for (final hireId in hireIds)
      for (final row in await _inner.listByHire(hireId))
        if (row.state == SubmissionState.submitted) row,
  ].take(limit).toList();

  @override
  Future<StoredSubmission> insertSubmitted({
    required SubmissionPurpose purpose,
    required String transactionHash,
    required String signedEnvelopeXdr,
    required DateTime validUntil,
    String? preparationId,
    int? hireId,
    String? explorerUrl,
    Transaction? transaction,
  }) => _inner.insertSubmitted(
    purpose: purpose,
    transactionHash: transactionHash,
    signedEnvelopeXdr: signedEnvelopeXdr,
    validUntil: validUntil,
    preparationId: preparationId,
    hireId: hireId,
    explorerUrl: explorerUrl,
    transaction: transaction,
  );

  @override
  Future<StoredSubmission> insertFailed({
    required SubmissionPurpose purpose,
    String? transactionHash,
    required String errorCode,
    int? hireId,
    String? explorerUrl,
    Transaction? transaction,
  }) => _inner.insertFailed(
    purpose: purpose,
    transactionHash: transactionHash,
    errorCode: errorCode,
    hireId: hireId,
    explorerUrl: explorerUrl,
    transaction: transaction,
  );

  @override
  Future<StoredSubmission?> findByPreparation(String preparationId) =>
      _inner.findByPreparation(preparationId);

  @override
  Future<List<StoredSubmission>> listByHire(int hireId) =>
      _inner.listByHire(hireId);

  @override
  Future<bool> hasSubmitted(Set<SubmissionPurpose> purposes) =>
      _inner.hasSubmitted(purposes);

  @override
  Future<bool> markConfirmed(int id) => _inner.markConfirmed(id);

  @override
  Future<bool> markFailed(int id, String code) => _inner.markFailed(id, code);

  @override
  Future<bool> recordSend(int id, DateTime at) => _inner.recordSend(id, at);

  @override
  Future<bool> recordCheck(int id, DateTime at) => _inner.recordCheck(id, at);
}

void main() {
  // Real PostgreSQL transactions: the opening must commit or roll back as one.
  withServerpod(
    'Given a tracked create_child_job on PostgreSQL',
    (sessionBuilder, _) {
      late Session session;
      late ServerpodHireRepository hires;
      late ServerpodHireReceiptStore receipts;
      late ServerpodChainSubmissionStore submissions;
      late FakeSubmissionLedger ledger;
      late HireEscrowEffects effects;
      late ChainSubmissionTracker tracker;

      setUp(() {
        session = sessionBuilder.build();
        hires = ServerpodHireRepository(session, now: () => _at);
        receipts = ServerpodHireReceiptStore(session, now: () => _at);
        submissions = ServerpodChainSubmissionStore(session, now: () => _at);
        ledger = FakeSubmissionLedger(closeTime: _at);
        effects = HireEscrowEffects(
          repositories: <T>(action) => action(hires),
          lifecycle: <T>(action) =>
              action(hires, ServerpodEscrowPreparationStore(session)),
          ledger: FakeLedger(),
          jobs: FakeLedger(),
          usdc: StellarConfig.testnet.usdcSac,
          escrow: _escrow,
          children: ChildJobEffects(
            scope: <T>(action) => action(
              hires,
              receipts,
              ServerpodChildJobStore(session, now: () => _at),
            ),
            escrow: _escrow,
          ),
        );
        tracker = ChainSubmissionTracker(
          ledger: ledger,
          effects: effects,
          log: (level, message) {},
          now: () => _at,
        );
      });

      Future<_Child> storedChild() async {
        final unique = DateTime.now().microsecondsSinceEpoch;
        final parent = await hires.insertHire(
          NewHire(
            consumer: _alice,
            agentId: 7,
            price: 5000000,
            manifestVersion: 1,
            expiredAt: _childExpiry + 200000,
            requestId: 'parent-$unique',
            input: 'summarise',
            subcontractReserve: 2000000,
          ),
        );
        final parentJobId = 800000000 + parent.id;
        await hires.bindJob(
          parent.id,
          parentJobId,
          expiredAt: _childExpiry + 200000,
        );
        final child = await hires.insertHire(
          NewHire(
            consumer: _agentA,
            agentId: 9,
            price: _budget,
            manifestVersion: 3,
            expiredAt: _childExpiry,
            requestId: 'child:${parent.id}:call-$unique',
            input: 'research',
            parentHireId: parent.id,
          ),
        );
        final hash = child.id.toRadixString(16).padLeft(64, 'c');
        await receipts.insert(
          NewReceiptLine(
            parentHireId: parent.id,
            childHireId: child.id,
            providerAgentId: 9,
            providerWallet: _agentB,
            budget: _budget,
            relatedParty: false,
            justification: 'cheapest research agent',
            createTransaction: hash,
          ),
        );
        final submission = await submissions.insertSubmitted(
          purpose: SubmissionPurpose.createChildJob,
          transactionHash: hash,
          signedEnvelopeXdr: 'envelope-${child.id}',
          validUntil: _at.add(const Duration(minutes: 5)),
          hireId: child.id,
        );
        return (
          parentJobId: parentJobId,
          childHireId: child.id,
          childJobId: 800000000 + child.id,
          submission: submission,
        );
      }

      TransactionLookup landed(_Child c, {String provider = _agentB}) =>
          TransactionLookup(
            status: TransactionStatus.success,
            latestLedgerCloseTime: _at,
            childJobCreated: [
              ChildJobCreatedEvent(
                parentJobId: c.parentJobId,
                childJobId: c.childJobId,
                provider: StellarAddress.parse(provider),
                agentId: AgentId(9),
                budget: BigInt.from(_budget),
                reserve: BigInt.zero,
                depth: 1,
                parentReserveLeft: BigInt.from(1500000),
              ),
            ],
            jobCreated: [
              JobCreatedEvent(
                jobId: c.childJobId,
                client: StellarAddress.parse(_agentA),
                provider: StellarAddress.parse(provider),
                evaluator: StellarAddress.parse(_agentA),
                agentId: AgentId(9),
                token: StellarConfig.testnet.usdcSac,
                budget: BigInt.from(_budget),
                expiredAt: _childExpiry,
              ),
            ],
            jobFunded: [
              JobFundedEvent(
                jobId: c.childJobId,
                client: StellarAddress.parse(_agentA),
                amount: BigInt.from(_budget),
                feeBps: 0,
              ),
            ],
          );

      Future<SubmissionState> stateOf(StoredSubmission s) async =>
          (await submissions.listByHire(
            s.hireId!,
          )).singleWhere((row) => row.id == s.id).state;

      Future<List<HirePaymentRecord>> payments(int hireId) =>
          HirePaymentRecord.db.find(
            session,
            where: (t) => t.hireId.equals(hireId),
          );

      Future<List<HireRunRecord>> runs(int hireId) => HireRunRecord.db.find(
        session,
        where: (t) => t.hireId.equals(hireId),
      );

      test('a confirmed create_child_job binds, funds and queues the child '
          'and opens its receipt line', () async {
        final c = await storedChild();
        ledger.lookups[c.submission.transactionHash] = landed(c);

        await tracker.pass(_OwnRecords(submissions, {c.childHireId}));

        expect(await stateOf(c.submission), SubmissionState.confirmed);
        final child = (await hires.findHire(c.childHireId))!;
        expect(child.jobId, c.childJobId);
        expect(child.expiredAt, _childExpiry);
        expect(child.escrow, _escrow.value);
        expect(child.status, HireStatus.funded);
        expect(child.paymentTransaction, c.submission.transactionHash);
        final payment = (await payments(c.childHireId)).single;
        expect(payment.payer, _agentA);
        expect(payment.payee, _agentB);
        expect(payment.amount, _budget);
        expect(payment.jobId, c.childJobId);
        expect((await runs(c.childHireId)).single.state, 'queued');
        final line = (await receipts.findByChildHire(c.childHireId))!;
        expect(line.childJobId, c.childJobId);
        expect(line.createTransaction, c.submission.transactionHash);
        expect(line.state, HireStatus.funded.name);
      });

      test('applying the confirmed transaction again pays and queues '
          'once', () async {
        final c = await storedChild();
        final lookup = landed(c);
        Future<EffectResult> apply() => effects.onChildJobCreated(
          c.submission,
          lookup.childJobCreated,
          created: lookup.jobCreated,
          funded: lookup.jobFunded,
        );

        expect(await apply(), isA<EffectOk>());
        expect(await apply(), isA<EffectOk>());

        expect(await payments(c.childHireId), hasLength(1));
        expect(await runs(c.childHireId), hasLength(1));
      });

      test('a mismatching event does not fund the child and leaves its line '
          'unverified', () async {
        final c = await storedChild();
        ledger.lookups[c.submission.transactionHash] = landed(
          c,
          provider: _alice,
        );

        await tracker.pass(_OwnRecords(submissions, {c.childHireId}));

        expect(await stateOf(c.submission), SubmissionState.failed);
        final failed = (await submissions.listByHire(c.childHireId)).single;
        expect(failed.errorCode, SubmissionOutcomeCode.jobMismatch);
        expect((await hires.findHire(c.childHireId))!.jobId, isNull);
        expect(await payments(c.childHireId), isEmpty);
        expect(await runs(c.childHireId), isEmpty);
        expect(
          (await receipts.findByChildHire(c.childHireId))!.state,
          ReceiptLineState.unverified,
        );
      });

      test('a failed create_child_job marks the line not_opened', () async {
        final c = await storedChild();
        ledger.lookups[c.submission.transactionHash] = const TransactionLookup(
          status: TransactionStatus.failed,
        );

        await tracker.pass(_OwnRecords(submissions, {c.childHireId}));

        expect(await stateOf(c.submission), SubmissionState.failed);
        expect(
          (await receipts.findByChildHire(c.childHireId))!.state,
          ReceiptLineState.notOpened,
        );
        expect(await payments(c.childHireId), isEmpty);
        expect(await runs(c.childHireId), isEmpty);
      });

      test('a line that left pending rolls the whole opening back', () async {
        final c = await storedChild();
        await receipts.markNotOpened(c.childHireId);
        final lookup = landed(c);

        final result = await effects.onChildJobCreated(
          c.submission,
          lookup.childJobCreated,
          created: lookup.jobCreated,
          funded: lookup.jobFunded,
        );

        expect(result, isA<EffectFailed>());
        expect((await hires.findHire(c.childHireId))!.jobId, isNull);
        expect(await payments(c.childHireId), isEmpty);
        expect(await runs(c.childHireId), isEmpty);
      });
    },
    rollbackDatabase: RollbackDatabase.disabled,
  );
}
