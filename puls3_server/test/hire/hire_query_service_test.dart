import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;
import 'package:puls3_server/src/agent/custodied_wallets.dart';
import 'package:puls3_server/src/chain/escrow_deadline.dart'
    show maxEscrowCallAttempts;
import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:puls3_server/src/feedback/reputation_calls.dart';
import 'package:puls3_server/src/generated/protocol.dart';
import 'package:puls3_server/src/hire/hire_lifecycle_store.dart' show HireRow;
import 'package:puls3_server/src/hire/explorer_links.dart';
import 'package:puls3_server/src/hire/hire_query_service.dart';
import 'package:puls3_server/src/hire/hire_receipt_store.dart';
import 'package:puls3_server/src/ledger/escrow_job.dart';
import 'package:puls3_server/src/ledger/ledger_errors.dart';
import 'package:puls3_server/src/ledger/stellar_config.dart';
import 'package:puls3_server/src/runtime/hire_run_store.dart';
import 'package:test/test.dart';

import '../support/fake_envelope_codec.dart';
import '../support/in_memory_hire_receipt_store.dart';
import '../support/in_memory_hire_run_store.dart';
import '../support/relay_rig.dart';

final _agent = AgentSummary(
  id: 'agt-007',
  registryId: 7,
  name: 'Support Relay',
  description: 'Triages one customer message.',
  skills: const ['customer-support'],
  priceUsdcStroops: price,
);

Matcher _apiError(String code) =>
    throwsA(isA<Puls3ApiException>().having((e) => e.code, 'code', code));

void main() {
  late RelayRig rig;
  late InMemoryHireRunStore runs;
  late Future<AgentSummary?> Function(int) agents;

  late InMemoryHireReceiptStore receipts;

  HireQueryService query({EscrowJobReader? jobs, CustodyLookup? custody}) =>
      HireQueryService(
        hires: rig.hires,
        runs: runs,
        submissions: rig.submissions,
        preparations: rig.preparations,
        agents: (id) => agents(id),
        jobs: jobs,
        custody: custody,
        receipts: receipts,
        transactionUrl: stellarExpertTransactionUrls(
          StellarConfig.testnet.networkPassphrase,
        ),
      );

  void queue(int hireId) => runs.enqueue(
    QueuedRun(
      hireId: hireId,
      agentId: 7,
      manifestVersion: 1,
      input: 'summarise this',
      expiredAt: 1800000000,
    ),
    rig.clock,
  );

  setUp(() {
    rig = RelayRig();
    runs = InMemoryHireRunStore();
    receipts = InMemoryHireReceiptStore(now: () => rig.clock);
    agents = (id) async => id == 7 ? _agent : null;
  });

  test('a funded hire shows its queued run, the job and the agent', () async {
    final hire = await rig.hire(status: HireStatus.funded);
    queue(hire.id);

    final detail = await query().getHire(rig.wallet, hire.id);

    expect(detail.hire.id, hire.id);
    expect(detail.hire.status, 'funded');
    expect(detail.hire.runtimeStatus, 'queued');
    expect(detail.hire.failureReason, isNull);
    expect(detail.result, isNull);
    expect(detail.input, 'summarise this');
    expect(detail.agent.name, 'Support Relay');
    expect(detail.jobId, hire.jobId);
    expect(
      detail.expiresAt,
      DateTime.fromMillisecondsSinceEpoch(1800000000 * 1000, isUtc: true),
    );
  });

  test('a succeeded run hides its result until the agent submits it, so '
      'the client cannot read it and reject for a refund (#204)', () async {
    final hire = await rig.hire(status: HireStatus.funded);
    queue(hire.id);
    await runs.markRunning(hire.id, rig.clock);
    await runs.markSucceeded(hire.id, 'Category: billing.', rig.clock);

    final detail = await query().getHire(rig.wallet, hire.id);

    expect(detail.hire.status, 'funded');
    expect(detail.hire.runtimeStatus, 'running');
    expect(detail.result, isNull);
    expect(detail.runFinished, isTrue);
  });

  group('submitErrorCode (#277)', () {
    var serial = 0;

    Future<void> submitFailure(int hireId, String code) =>
        rig.submissions.insertFailed(
          purpose: SubmissionPurpose.submit,
          errorCode: code,
          hireId: hireId,
        );

    Future<void> submitInFlight(int hireId) => rig.submissions.insertSubmitted(
      purpose: SubmissionPurpose.submit,
      transactionHash: (++serial).toRadixString(16).padLeft(64, '0'),
      signedEnvelopeXdr: 'AAAA',
      validUntil: rig.clock.add(const Duration(minutes: 5)),
      hireId: hireId,
    );

    test('is null while the submit can still land', () async {
      final hire = await rig.hire(status: HireStatus.funded);
      rig.hires.payees[hire.id] = agentWallet;

      final detail = await query(
        custody: (addresses) async => addresses,
      ).getHire(rig.wallet, hire.id);

      expect(detail.submitErrorCode, isNull);
    });

    test('is AgentCannotDeliver when the payee is not custodied', () async {
      final hire = await rig.hire(status: HireStatus.funded);
      rig.hires.payees[hire.id] = stranger;

      final detail = await query(
        custody: (_) async => const {},
      ).getHire(rig.wallet, hire.id);

      expect(detail.submitErrorCode, agentCannotDeliverCode);
    });

    test('reports a terminal submission rejection', () async {
      final hire = await rig.hire(status: HireStatus.funded);
      rig.hires.payees[hire.id] = agentWallet;
      await submitFailure(
        hire.id,
        SubmissionOutcomeCode.submitSimulationRejected,
      );

      final detail = await query(
        custody: (addresses) async => addresses,
      ).getHire(rig.wallet, hire.id);

      expect(
        detail.submitErrorCode,
        SubmissionOutcomeCode.submitSimulationRejected,
      );
    });

    test('a retryable simulation failure is not terminal', () async {
      final hire = await rig.hire(status: HireStatus.funded);
      rig.hires.payees[hire.id] = agentWallet;
      await submitFailure(hire.id, SubmissionOutcomeCode.simulationFailed);

      final detail = await query(
        custody: (addresses) async => addresses,
      ).getHire(rig.wallet, hire.id);

      expect(detail.submitErrorCode, isNull);
    });

    test('exhausted attempts report EscrowCallFailed', () async {
      final hire = await rig.hire(status: HireStatus.funded);
      rig.hires.payees[hire.id] = agentWallet;
      for (var i = 0; i < maxEscrowCallAttempts; i++) {
        await submitFailure(hire.id, SubmissionOutcomeCode.simulationFailed);
      }

      final detail = await query(
        custody: (addresses) async => addresses,
      ).getHire(rig.wallet, hire.id);

      expect(detail.submitErrorCode, SubmissionOutcomeCode.escrowCallFailed);
    });

    test(
      'an unknown outcome is reported, and a submit in flight clears it',
      () async {
        final hire = await rig.hire(status: HireStatus.funded);
        rig.hires.payees[hire.id] = agentWallet;
        await submitFailure(hire.id, SubmissionOutcomeCode.outcomeUnknown);

        final unknown = await query(
          custody: (addresses) async => addresses,
        ).getHire(rig.wallet, hire.id);
        expect(unknown.submitErrorCode, SubmissionOutcomeCode.outcomeUnknown);

        await submitInFlight(hire.id);
        final inFlight = await query(
          custody: (addresses) async => addresses,
        ).getHire(rig.wallet, hire.id);
        expect(inFlight.submitErrorCode, isNull);
      },
    );
    test(
      'an unknown outcome on another escrow call wins over the custody rule',
      () async {
        final hire = await rig.hire(status: HireStatus.funded);
        rig.hires.payees[hire.id] = stranger;
        await rig.record(
          hire.id,
          SubmissionPurpose.reject,
          failedWith: SubmissionOutcomeCode.outcomeUnknown,
        );

        final detail = await query(
          custody: (_) async => const {},
        ).getHire(rig.wallet, hire.id);

        expect(detail.submitErrorCode, SubmissionOutcomeCode.outcomeUnknown);
      },
    );
  });

  group('the result is shown only once the agent submitted it (#204)', () {
    const output = 'Category: billing.';
    final shown = {HireStatus.submitted, HireStatus.completed};

    for (final status in HireStatus.values) {
      final visible = shown.contains(status);
      test('${status.name}: ${visible ? 'shown' : 'hidden'}', () async {
        final hire = await rig.hire(status: status);
        queue(hire.id);
        await runs.markRunning(hire.id, rig.clock);
        await runs.markSucceeded(hire.id, output, rig.clock);

        final detail = await query().getHire(rig.wallet, hire.id);

        expect(detail.hire.status, status.name);
        expect(detail.result, visible ? output : isNull);
      });
    }
  });

  test('a run waiting for a child shows running on a funded hire, with no '
      'result and no action for the client (ADR-0011 D7)', () async {
    final hire = await rig.hire(status: HireStatus.funded);
    queue(hire.id);
    await runs.markRunning(hire.id, rig.clock);
    await runs.markAwaitingChild(
      hire.id,
      loopState: '{}',
      pendingToolCallId: 'toolu_1',
      childHireId: 99,
      childRequest: '{}',
      at: rig.clock,
    );

    final detail = await query().getHire(rig.wallet, hire.id);
    final summaries = await query().listMyHires(rig.wallet);

    expect(detail.hire.status, 'funded');
    expect(detail.hire.runtimeStatus, 'running');
    expect(detail.hire.failureReason, isNull);
    expect(detail.result, isNull);
    expect(summaries.single.needsAction, isFalse);
  });

  test('a failed run shows failed with its safe reason', () async {
    final hire = await rig.hire(status: HireStatus.funded);
    queue(hire.id);
    await runs.markRunning(hire.id, rig.clock);
    await runs.markFailed(hire.id, 'timeout', rig.clock);

    final detail = await query().getHire(rig.wallet, hire.id);

    expect(detail.hire.runtimeStatus, 'failed');
    expect(detail.hire.failureReason, 'timeout');
    expect(detail.result, isNull);
  });

  test('no run progress before the hire is funded', () async {
    final hire = await rig.hire(status: HireStatus.open);

    final detail = await query().getHire(rig.wallet, hire.id);

    expect(detail.hire.status, 'open');
    expect(detail.hire.runtimeStatus, isNull);
  });

  test('after funded the escrow state wins: no run progress shown', () async {
    final hire = await rig.hire(status: HireStatus.rejected);
    queue(hire.id);
    await runs.markFailed(hire.id, 'timeout', rig.clock);

    final detail = await query().getHire(rig.wallet, hire.id);

    expect(detail.hire.status, 'rejected');
    expect(detail.hire.runtimeStatus, isNull);
    expect(detail.hire.failureReason, isNull);
  });

  test('a submitted hire shows the approval deadline from the job', () async {
    final hire = await rig.hire(status: HireStatus.submitted);
    const deadline = 1800000100;

    final detail = await query(
      jobs: _Jobs(deadline),
    ).getHire(rig.wallet, hire.id);

    expect(detail.hire.status, 'submitted');
    expect(
      detail.approvalDeadline,
      DateTime.fromMillisecondsSinceEpoch(deadline * 1000, isUtc: true),
    );
  });

  test('a funded hire has no approval deadline yet', () async {
    final hire = await rig.hire(status: HireStatus.funded);

    final detail = await query(jobs: _Jobs(1800000100)).getHire(
      rig.wallet,
      hire.id,
    );

    expect(detail.approvalDeadline, isNull);
  });

  test('a completed hire still shows the approval deadline', () async {
    final hire = await rig.hire(status: HireStatus.completed);
    const deadline = 1800000100;

    final detail = await query(
      jobs: _Jobs(deadline),
    ).getHire(rig.wallet, hire.id);

    expect(
      detail.approvalDeadline,
      DateTime.fromMillisecondsSinceEpoch(deadline * 1000, isUtc: true),
    );
  });

  test('a chain read failure leaves the approval deadline unset', () async {
    final hire = await rig.hire(status: HireStatus.submitted);

    final detail = await query(
      jobs: _UnavailableJobs(),
    ).getHire(rig.wallet, hire.id);

    expect(detail.hire.status, 'submitted');
    expect(detail.approvalDeadline, isNull);
  });

  test('a hire without a job has no expiry yet', () async {
    final hire = await rig.hire();

    final detail = await query().getHire(rig.wallet, hire.id);

    expect(detail.hire.status, isNull);
    expect(detail.jobId, isNull);
    expect(detail.expiresAt, isNull);
  });

  test('shows the latest escrow submission of the hire', () async {
    final hire = await rig.hire(status: HireStatus.open);
    await rig.record(hire.id, SubmissionPurpose.createJob);
    final fund = await rig.record(hire.id, SubmissionPurpose.fund);

    final detail = await query().getHire(rig.wallet, hire.id);

    expect(detail.escrowSubmission?.transaction, fund.transactionHash);
    expect(detail.escrowSubmission?.purpose, 'fund');
  });

  group('feedback of a completed hire', () {
    Future<HireRow> completed() => rig.hire(status: HireStatus.completed);

    test('has no feedback before one is given', () async {
      final hire = await completed();

      final detail = await query().getHire(rig.wallet, hire.id);

      expect(detail.feedbackSubmission, isNull);
      expect(detail.hire.feedbackReference, isNull);
    });

    test('a confirmed give_feedback is the reference after a reload', () async {
      final hire = await completed();
      final rated = await rig.record(hire.id, SubmissionPurpose.giveFeedback);
      await rig.submissions.markConfirmed(rated.id);

      final detail = await query().getHire(rig.wallet, hire.id);

      expect(detail.hire.feedbackReference, rated.transactionHash);
      expect(detail.hire.status, 'completed');
      expect(detail.feedbackSubmission?.transaction, rated.transactionHash);
      expect(detail.feedbackSubmission?.purpose, 'giveFeedback');
      expect(detail.feedbackSubmission?.state, 'confirmed');
    });

    test('a give_feedback still pending is already the reference', () async {
      final hire = await completed();
      final rated = await rig.record(hire.id, SubmissionPurpose.giveFeedback);

      final detail = await query().getHire(rig.wallet, hire.id);

      expect(detail.hire.feedbackReference, rated.transactionHash);
      expect(detail.feedbackSubmission?.state, 'submitted');
    });

    test('a failed give_feedback is shown but is no reference', () async {
      final hire = await completed();
      final failed = await rig.record(
        hire.id,
        SubmissionPurpose.giveFeedback,
        failedWith: SubmissionOutcomeCode.transactionFailed,
      );

      final detail = await query().getHire(rig.wallet, hire.id);

      expect(detail.hire.feedbackReference, isNull);
      expect(detail.feedbackSubmission?.transaction, failed.transactionHash);
      expect(detail.feedbackSubmission?.state, 'failed');
    });

    test('a retry after a failure replaces the failed one', () async {
      final hire = await completed();
      await rig.record(
        hire.id,
        SubmissionPurpose.giveFeedback,
        failedWith: SubmissionOutcomeCode.transactionFailed,
      );
      final retry = await rig.record(hire.id, SubmissionPurpose.giveFeedback);

      final detail = await query().getHire(rig.wallet, hire.id);

      expect(detail.hire.feedbackReference, retry.transactionHash);
      expect(detail.feedbackSubmission?.transaction, retry.transactionHash);
    });

    test('the escrow submission stays the latest escrow call', () async {
      final hire = await completed();
      final fund = await rig.record(hire.id, SubmissionPurpose.fund);
      await rig.record(hire.id, SubmissionPurpose.giveFeedback);

      final detail = await query().getHire(rig.wallet, hire.id);

      expect(detail.escrowSubmission?.transaction, fund.transactionHash);
      expect(detail.escrowSubmission?.purpose, 'fund');
    });

    Future<void> rate(int hireId, int score) async {
      final prepared = await rig.service.prepareFeedback(
        rig.wallet,
        hireId,
        ContractCall(
          contract: StellarAddress.parse(
            'CD5QZOKGRBV35C5SDT6PG7S72XGG4BHQAC2L56YLNBJDUL4LDMTXFIJJ',
          ),
          function: 'give_feedback',
          args: const [],
        ),
        feedbackScore: score,
      );
      await rig.service.submitEscrowCall(
        rig.wallet,
        hireId,
        prepared.preparationId,
        FakeEnvelopeCodec.sign(prepared.unsignedTransactionXdr!),
      );
    }

    test('a confirmed rating keeps its score after a reload', () async {
      final hire = await completed();
      await rate(hire.id, 4);
      final submission = (await rig.submissions.listByHire(hire.id)).single;
      await rig.submissions.markConfirmed(submission.id);

      final detail = await query().getHire(rig.wallet, hire.id);

      expect(detail.feedbackScore, 4);
      expect(detail.feedbackSubmission?.state, 'confirmed');
    });

    test('a failed rating returns no score', () async {
      final hire = await completed();
      await rate(hire.id, 2);
      final submission = (await rig.submissions.listByHire(hire.id)).single;
      await rig.submissions.markFailed(
        submission.id,
        SubmissionOutcomeCode.transactionFailed,
      );

      final detail = await query().getHire(rig.wallet, hire.id);

      expect(detail.feedbackScore, isNull);
      expect(detail.feedbackSubmission?.state, 'failed');
    });
  });

  group('receipt (#334, ADR-0011 D6)', () {
    final createHash = 'a' * 64;
    final settleHash = 'b' * 64;
    final deliverable = 'c' * 64;

    Future<ReceiptLine> line(
      int parentHireId, {
      required int childHireId,
      bool relatedParty = false,
    }) => receipts.insert(
      NewReceiptLine(
        parentHireId: parentHireId,
        childHireId: childHireId,
        providerAgentId: 9,
        providerWallet: stranger,
        budget: 1500000,
        relatedParty: relatedParty,
        justification: 'Best ranked translator.',
      ),
    );

    test('lists the parent hire lines oldest first, with every field and '
        'the explorer links of both transactions', () async {
      final parent = await rig.hire(
        status: HireStatus.funded,
        subcontractReserve: 3000000,
      );
      final settled = await line(parent.id, childHireId: 41);
      await receipts.markOpened(
        41,
        childJobId: 12,
        createTransaction: createHash,
        state: 'funded',
      );
      await receipts.recordDeliverable(41, deliverable);
      await receipts.markSettled(
        41,
        state: 'completed',
        fee: 37500,
        payout: 1462500,
        settleTransaction: settleHash,
      );
      final pending = await line(
        parent.id,
        childHireId: 42,
        relatedParty: true,
      );
      final other = await rig.hire(status: HireStatus.funded);
      await line(other.id, childHireId: 43);

      final detail = await query().getHire(rig.wallet, parent.id);

      final receipt = detail.receipt!;
      expect(receipt.map((l) => l.id), [settled.id, pending.id]);
      final first = receipt.first;
      expect(first.childHireId, 41);
      expect(first.childJobId, 12);
      expect(first.providerAgentId, 9);
      expect(first.providerWallet, stranger);
      expect(first.budget, 1500000);
      expect(first.fee, 37500);
      expect(first.payout, 1462500);
      expect(first.state, 'completed');
      expect(first.createTransaction, createHash);
      expect(first.settleTransaction, settleHash);
      expect(first.deliverableHash, deliverable);
      expect(first.relatedParty, isFalse);
      expect(first.justification, 'Best ranked translator.');
      expect(first.createdAt, settled.createdAt);
      expect(
        first.createExplorerUrl,
        'https://stellar.expert/explorer/testnet/tx/$createHash',
      );
      expect(
        first.settleExplorerUrl,
        'https://stellar.expert/explorer/testnet/tx/$settleHash',
      );
      final second = receipt.last;
      expect(second.childHireId, 42);
      expect(second.childJobId, isNull);
      expect(second.state, ReceiptLineState.pending);
      expect(second.relatedParty, isTrue);
      expect(second.fee, isNull);
      expect(second.payout, isNull);
      expect(second.createTransaction, isNull);
      expect(second.createExplorerUrl, isNull);
      expect(second.settleExplorerUrl, isNull);
    });

    test('is an empty list when the hire has no lines', () async {
      final hire = await rig.hire(status: HireStatus.funded);

      final detail = await query().getHire(rig.wallet, hire.id);

      expect(detail.receipt, isEmpty);
    });

    test('another consumer cannot read the lines: HireNotOwned', () async {
      final theirs = await rig.hire(
        status: HireStatus.funded,
        consumer: stranger,
      );
      await line(theirs.id, childHireId: 44);

      await expectLater(
        query().getHire(rig.wallet, theirs.id),
        _apiError('HireNotOwned'),
      );
    });

    test('leaves every other field of getHire unchanged', () async {
      final hire = await rig.hire(status: HireStatus.funded);
      queue(hire.id);
      final withoutReceipts = HireQueryService(
        hires: rig.hires,
        runs: runs,
        submissions: rig.submissions,
        preparations: rig.preparations,
        agents: (id) => agents(id),
      );

      final before = await withoutReceipts.getHire(rig.wallet, hire.id);
      final after = await query().getHire(rig.wallet, hire.id);

      expect(before.receipt, isNull);
      expect(after.receipt, isEmpty);
      expect(after.toJson()..remove('receipt'), before.toJson());
    });
  });

  test(
    'the explorer links follow the network, and other networks get none',
    () {
      expect(
        stellarExpertTransactionUrls(
          'Public Global Stellar Network ; September 2015',
        )!('ab'),
        'https://stellar.expert/explorer/public/tx/ab',
      );
      expect(
        stellarExpertTransactionUrls('Standalone Network ; February 2017'),
        isNull,
      );
    },
  );

  test(
    'an invalid id, a missing hire or another consumer is refused',
    () async {
      final mine = await rig.hire(status: HireStatus.funded);
      final theirs = await rig.hire(
        status: HireStatus.funded,
        consumer: stranger,
      );

      expect(() => query().getHire(rig.wallet, 0), _apiError('InvalidHireId'));
      expect(() => query().getHire(rig.wallet, 999), _apiError('HireNotFound'));
      expect(
        () => query().getHire(rig.wallet, theirs.id),
        _apiError('HireNotOwned'),
      );
      expect((await query().getHire(rig.wallet, mine.id)).hire.id, mine.id);
    },
  );

  test('an unreadable catalog is ChainDataUnavailable', () async {
    final hire = await rig.hire(status: HireStatus.funded);
    agents = (_) async => throw const LedgerUnavailable('rpc down');

    expect(
      () => query().getHire(rig.wallet, hire.id),
      _apiError('ChainDataUnavailable'),
    );
  });

  test('reading a hire never changes its run', () async {
    final hire = await rig.hire(status: HireStatus.funded);
    queue(hire.id);

    await query().getHire(rig.wallet, hire.id);
    await query().getHire(rig.wallet, hire.id);

    expect((await runs.find(hire.id))!.state, HireRunState.queued);
  });

  test(
    'reading a hire past its deadline records no server submission',
    () async {
      final hire = await rig.hire(status: HireStatus.funded);
      final before = await rig.submissions.listByHire(hire.id);

      await query().getHire(rig.wallet, hire.id);

      expect(await rig.submissions.listByHire(hire.id), before);
    },
  );

  group('listMyHires', () {
    // 1800000100 is after the rig clock (2026-10-07), so the window is open.
    const openDeadline = 1800000100;

    HireQueryService listing({int deadline = openDeadline}) => HireQueryService(
      hires: rig.hires,
      runs: runs,
      submissions: rig.submissions,
      preparations: rig.preparations,
      agents: (id) => agents(id),
      jobs: _Jobs(deadline),
      now: () => rig.clock,
    );

    test('returns only the session wallet hires, newest first', () async {
      final first = await rig.hire(status: HireStatus.completed);
      await rig.hire(status: HireStatus.funded, consumer: stranger);
      final second = await rig.hire(status: HireStatus.open);

      final hires = await listing().listMyHires(rig.wallet);

      expect(hires.map((h) => h.id), [second.id, first.id]);
      expect(hires.first.agentName, 'Support Relay');
      expect(hires.first.priceUsdcStroops, price);
      expect(hires.first.inputPreview, 'summarise this');
      expect(hires.first.status, 'open');
    });

    test('a submitted hire within its approval window needs action', () async {
      final hire = await rig.hire(status: HireStatus.submitted);

      final [summary] = await listing().listMyHires(rig.wallet);

      expect(summary.id, hire.id);
      expect(summary.needsAction, isTrue);
      expect(
        summary.approvalDeadline,
        DateTime.fromMillisecondsSinceEpoch(openDeadline * 1000, isUtc: true),
      );
    });

    test('a submitted hire past its approval window needs none', () async {
      await rig.hire(status: HireStatus.submitted);
      final past = rig.clock.millisecondsSinceEpoch ~/ 1000 - 60;

      final [summary] = await listing(deadline: past).listMyHires(rig.wallet);

      expect(summary.needsAction, isFalse);
    });

    test(
      'a funded hire whose run failed needs action (reject to refund)',
      () async {
        final hire = await rig.hire(status: HireStatus.funded);
        queue(hire.id);
        await runs.markRunning(hire.id, rig.clock);
        await runs.markFailed(hire.id, 'timeout', rig.clock);
        final healthy = await rig.hire(status: HireStatus.funded);
        queue(healthy.id);

        final hires = await listing().listMyHires(rig.wallet);

        expect(
          {for (final h in hires) h.id: h.needsAction},
          {
            hire.id: true,
            healthy.id: false,
          },
        );
      },
    );

    test('an agent the catalog cannot name keeps the list readable', () async {
      await rig.hire(status: HireStatus.completed);
      agents = (_) async => null;

      final [summary] = await listing().listMyHires(rig.wallet);

      expect(summary.agentName, 'Agent #7');
      expect(summary.needsAction, isFalse);
    });
  });
}

final class _UnavailableJobs implements EscrowJobReader {
  @override
  Future<EscrowJob?> escrowJob(int jobId) async =>
      throw const LedgerUnavailable('rpc down');
}

final class _Jobs implements EscrowJobReader {
  _Jobs(this.deadline);

  final int deadline;

  @override
  Future<EscrowJob?> escrowJob(int jobId) async => EscrowJob(
    client: StellarAddress.parse(alice),
    provider: StellarAddress.parse(agentWallet),
    evaluator: StellarAddress.parse(alice),
    agentId: AgentId(7),
    token: StellarAddress.parse(alice),
    budget: BigInt.from(price),
    feeBps: 0,
    expiredAt: 1800000000,
    description: 'triage',
    state: EscrowJobState.submitted,
    submittedAt: deadline - 60,
    approvalDeadline: deadline,
    deliverable: null,
  );
}
