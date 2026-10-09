import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;
import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:puls3_server/src/generated/protocol.dart';
import 'package:puls3_server/src/hire/hire_query_service.dart';
import 'package:puls3_server/src/ledger/ledger_errors.dart';
import 'package:puls3_server/src/runtime/hire_run_store.dart';
import 'package:test/test.dart';

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

  HireQueryService query() => HireQueryService(
    hires: rig.hires,
    runs: runs,
    submissions: rig.submissions,
    agents: (id) => agents(id),
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

  test(
    'a succeeded run shows its result while the hire waits for submit',
    () async {
      final hire = await rig.hire(status: HireStatus.funded);
      queue(hire.id);
      await runs.markRunning(hire.id, rig.clock);
      await runs.markSucceeded(hire.id, 'Category: billing.', rig.clock);

      final detail = await query().getHire(rig.wallet, hire.id);

      expect(detail.hire.runtimeStatus, 'running');
      expect(detail.result, 'Category: billing.');
    },
  );

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
}
