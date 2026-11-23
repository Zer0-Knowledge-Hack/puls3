import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/chain/chain_submission_store.dart';
import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:puls3_server/src/hire/hire_lifecycle_store.dart';
import 'package:puls3_server/src/hire/hire_receipt_store.dart';
import 'package:puls3_server/src/hire/unverified_child_reconciler.dart';
import 'package:puls3_server/src/ledger/escrow_job.dart';
import 'package:puls3_server/src/ledger/ledger_errors.dart';
import 'package:puls3_server/src/ledger/stellar_config.dart';
import 'package:test/test.dart';

import '../../support/in_memory_chain_submission_store.dart';
import '../../support/in_memory_child_job_store.dart';
import '../../support/in_memory_hire_lifecycle_store.dart';
import '../../support/in_memory_hire_receipt_store.dart';

const _alice = 'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H';
const _agentA = 'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY';
const _agentB = 'GBRPYHIL2CI3FNQ4BXLFMNDLFJUNPU2HY3ZMFSHONUCEOASW7QC7OX2H';
final _escrow = StellarAddress.parse(
  'CBRD7A7MXINM7LREKCL3RMKRQ5UMLGKNHAEYY4JT7MVBBB7R5QV4TPE2',
);
const _parentJobId = 10;
const _price = 500000;
const _childExpiry = 1791747914;
final _at = DateTime.utc(2026, 11, 23, 12);
final _createHash = 'ab' * 32;

final class _Jobs implements EscrowJobReader {
  final jobs = <int, EscrowJob>{};
  final archived = <int>{};
  final read = <int>[];
  Object? error;

  @override
  Future<EscrowJob?> escrowJob(int jobId) async {
    read.add(jobId);
    if (error case final error?) throw error;
    if (archived.contains(jobId)) {
      throw const LedgerUnavailable('archived', archived: true);
    }
    return jobs[jobId];
  }
}

/// A job the escrow holds; by default the child's own fields.
EscrowJob _job({
  int parentJobId = _parentJobId,
  String provider = _agentB,
  int budget = _price,
}) => EscrowJob(
  client: StellarAddress.parse(_agentA),
  provider: StellarAddress.parse(provider),
  evaluator: StellarAddress.parse(_agentA),
  agentId: AgentId(9),
  token: StellarConfig.testnet.usdcSac,
  budget: BigInt.from(budget),
  feeBps: 100,
  expiredAt: _childExpiry,
  description: '',
  state: EscrowJobState.funded,
  submittedAt: 0,
  approvalDeadline: 0,
  deliverable: null,
  parentJobId: parentJobId,
);

void main() {
  late InMemoryHireLifecycleStore hires;
  late InMemoryHireReceiptStore receipts;
  late InMemoryChildJobStore openings;
  late InMemoryChainSubmissionStore submissions;
  late _Jobs jobs;
  late DateTime now;
  late int childHireId;
  late StoredSubmission create;

  UnverifiedChildReconciler reconciler() => UnverifiedChildReconciler(
    receipts: receipts,
    hires: hires,
    openings: openings,
    submissions: submissions,
    jobs: jobs,
    escrow: _escrow,
    now: () => now,
  );

  Future<ReceiptLine> line() async =>
      (await receipts.findByChildHire(childHireId))!;

  setUp(() async {
    hires = InMemoryHireLifecycleStore();
    receipts = InMemoryHireReceiptStore(now: () => _at);
    openings = InMemoryChildJobStore(hires, receipts);
    submissions = InMemoryChainSubmissionStore(now: () => _at);
    jobs = _Jobs();
    // Past the envelope's validity unless a test says otherwise.
    now = _at.add(const Duration(hours: 1));
    final parent = await hires.insertHire(
      const NewHire(
        consumer: _alice,
        agentId: 7,
        price: 5000000,
        manifestVersion: 1,
        expiredAt: 1791947914,
        requestId: 'parent',
        input: 'summarise',
        subcontractReserve: 2000000,
      ),
    );
    await hires.bindJob(parent.id, _parentJobId, expiredAt: 1791947914);
    final child = await hires.insertHire(
      NewHire(
        consumer: _agentA,
        agentId: 9,
        price: _price,
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
        childHireId: childHireId,
        providerAgentId: 9,
        providerWallet: _agentB,
        budget: _price,
        relatedParty: false,
        justification: 'cheapest research agent',
        createTransaction: _createHash,
      ),
    );
    create = await submissions.insertSubmitted(
      purpose: SubmissionPurpose.createChildJob,
      transactionHash: _createHash,
      signedEnvelopeXdr: 'envelope',
      validUntil: _at.add(const Duration(minutes: 5)),
      hireId: childHireId,
    );
    // The node lost the transaction: it may have landed.
    await submissions.markFailed(create.id, SubmissionOutcomeCode.outcomeUnknown);
    await receipts.markUnverified(childHireId);
  });

  test('one matching job opens the child as a confirmed create would', () async {
    jobs.jobs[11] = _job(parentJobId: 3);
    jobs.jobs[12] = _job();

    await reconciler().reconcile();

    final opened = await line();
    expect(opened.state, HireStatus.funded.name);
    expect(opened.childJobId, 12);
    expect((await hires.findHire(childHireId))!.jobId, 12);
    final payment = openings.payments[childHireId]!;
    expect(payment.transactionHash, _createHash);
    expect(payment.payer, _agentA);
    expect(payment.payee, _agentB);
    expect(payment.amount, _price);
    expect(openings.queued, [childHireId]);
    expect(jobs.read, [11, 12, 13], reason: 'up to the first missing id');
  });

  test('jobs of another provider, budget or parent do not match', () async {
    jobs.jobs[11] = _job(provider: _alice);
    jobs.jobs[12] = _job(budget: _price + 1);
    jobs.jobs[13] = _job(parentJobId: 3);

    await reconciler().reconcile();

    expect((await line()).state, ReceiptLineState.notOpened);
    expect(openings.queued, isEmpty);
  });

  test('no job and an expired envelope close the line as not_opened', () async {
    await reconciler().reconcile();

    expect((await line()).state, ReceiptLineState.notOpened);
    expect((await hires.findHire(childHireId))!.jobId, isNull);
  });

  test('no job while the envelope can still land leaves the line '
      'unverified', () async {
    now = _at.add(const Duration(minutes: 4));

    await reconciler().reconcile();

    expect((await line()).state, ReceiptLineState.unverified);
  });

  test('no job after a confirmed create leaves the line unverified: it '
      'landed somewhere', () async {
    final confirmed = await submissions.insertSubmitted(
      purpose: SubmissionPurpose.createChildJob,
      transactionHash: 'cd' * 32,
      signedEnvelopeXdr: 'envelope-2',
      validUntil: _at,
      hireId: childHireId,
    );
    await submissions.markConfirmed(confirmed.id);

    await reconciler().reconcile();

    expect((await line()).state, ReceiptLineState.unverified);
  });

  test('two matching jobs are ambiguous and write nothing', () async {
    jobs.jobs[11] = _job();
    jobs.jobs[12] = _job();

    await reconciler().reconcile();

    expect((await line()).state, ReceiptLineState.unverified);
    expect(openings.queued, isEmpty);
  });

  test('a create still in flight belongs to the tracker: nothing is '
      'read', () async {
    await submissions.insertSubmitted(
      purpose: SubmissionPurpose.createChildJob,
      transactionHash: 'ef' * 32,
      signedEnvelopeXdr: 'envelope-3',
      validUntil: _at,
      hireId: childHireId,
    );

    await reconciler().reconcile();

    expect(jobs.read, isEmpty);
    expect((await line()).state, ReceiptLineState.unverified);
  });

  test('an archived job is skipped and the scan goes on', () async {
    jobs.archived.add(11);
    jobs.jobs[12] = _job();

    await reconciler().reconcile();

    expect((await line()).childJobId, 12);
  });

  test('a chain error defers the line unchanged', () async {
    jobs.error = const LedgerUnavailable('node down');

    await reconciler().reconcile();

    expect((await line()).state, ReceiptLineState.unverified);
  });

  test('a matching job another hire holds leaves the line unverified', () async {
    jobs.jobs[11] = _job();
    final other = await hires.insertHire(
      const NewHire(
        consumer: _alice,
        agentId: 9,
        price: _price,
        manifestVersion: 1,
        expiredAt: _childExpiry,
        requestId: 'other',
        input: 'other',
      ),
    );
    await hires.bindJob(other.id, 11, expiredAt: _childExpiry);

    await reconciler().reconcile();

    expect((await line()).state, ReceiptLineState.unverified);
    expect(openings.queued, isEmpty);
  });
}
