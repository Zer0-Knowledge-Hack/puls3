import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;
import 'package:puls3_server/src/hire/hire_receipt_store.dart';
import 'package:puls3_server/src/hire/hire_relay_config.dart';
import 'package:puls3_server/src/ledger/escrow_job.dart';
import 'package:puls3_server/src/ledger/soroban_rpc_client.dart';
import 'package:puls3_server/src/ledger/stellar_config.dart';
import 'package:puls3_server/src/runtime/child_verdict.dart';
import 'package:puls3_server/src/runtime/escrow_subcontract_port.dart';
import 'package:puls3_server/src/runtime/subcontract_port.dart';
import 'package:puls3_server/src/runtime/subcontract_setup.dart';
import 'package:puls3_server/src/runtime/subcontract_wiring.dart';
import 'package:puls3_server/src/runtime/tool_loop.dart';
import 'package:test/test.dart';

import '../../support/fake_envelope_codec.dart';
import '../../support/in_memory_child_job_store.dart';
import '../../support/in_memory_hire_receipt_store.dart';
import '../../support/in_memory_hire_run_store.dart';
import '../../support/relay_rig.dart';

const _window = 86400;

final class _FailingReceipts extends InMemoryHireReceiptStore {
  _FailingReceipts({super.now});

  @override
  Future<List<ReceiptLine>> listUnopened() async =>
      throw StateError('database down');
}

void main() {
  group('runtimeTimings', () {
    test('a run may hold up to maxTurns model calls, so staleAfter covers '
        'them all', () {
      final timings = runtimeTimings(
        timeout: const Duration(seconds: 120),
        batchSize: 10,
        maxTurns: defaultMaxLoopTurns,
      );

      // 8 calls of 120 s plus the one minute margin of a plain run.
      expect(timings.staleAfter, const Duration(seconds: 8 * 120 + 60));
    });

    test('a pass resumes one batch and runs one batch, each run up to '
        'maxTurns calls', () {
      final timings = runtimeTimings(
        timeout: const Duration(seconds: 120),
        batchSize: 10,
        maxTurns: defaultMaxLoopTurns,
      );

      expect(
        timings.passTimeout,
        const Duration(seconds: 2 * 10 * 8 * 120 + 60),
      );
    });

    test('with one turn a run is one call, as without the tool loop', () {
      final timings = runtimeTimings(
        timeout: const Duration(seconds: 120),
        batchSize: 10,
        maxTurns: 1,
      );

      expect(timings.staleAfter, const Duration(seconds: 120 + 60));
      expect(timings.passTimeout, const Duration(seconds: 2 * 10 * 120 + 60));
    });
  });

  group('buildSubcontractServices', () {
    late RelayRig rig;
    late InMemoryHireReceiptStore receipts;
    late InMemoryChildJobStore openings;
    var windowReads = 0;

    SubcontractServices build({int maxTurns = defaultMaxLoopTurns}) =>
        buildSubcontractServices(
          hires: rig.hires,
          receipts: receipts,
          runs: InMemoryHireRunStore(),
          submissions: rig.submissions,
          openings: openings,
          jobs: rig.ledger,
          relay: rig.service,
          accounts: rig.accounts,
          codec: rig.codec,
          config: HireRelayConfig({
            ...relayEnvironment(),
            HireRelayConfig.jobDurationKey: '259200',
          }),
          childAgent: (_) async => ChildAgent(
            wallet: StellarAddress.parse(stranger),
            manifestVersion: 1,
            priceStroops: 500000,
          ),
          approvalWindow: () async {
            windowReads++;
            return _window;
          },
          sign: (prepared, signer) async =>
              FakeEnvelopeCodec.sign(prepared.envelopeXdr),
          send: (envelope, hash) async => SendTransactionResult(
            status: SendTransactionStatus.pending,
            hash: hash,
          ),
          search:
              ({
                required hireId,
                required remainingReserveStroops,
                required query,
                skills = const [],
              }) async => const [],
          escrow: StellarConfig.testnet.escrow,
          inclusionFee: inclusionFee,
          validitySeconds: validitySeconds,
          maxTurns: maxTurns,
          now: () => rig.clock,
        );

    ChildRequest request(int parentHireId) => ChildRequest(
      parentHireId: parentHireId,
      agentRegistryId: 9,
      agentId: 'agt-009',
      priceStroops: 500000,
      task: 'Research the topic',
      justification: 'Best rated research agent',
      isRelatedParty: false,
      relatedPartyJustification: RelatedPartyJustification.independent,
      ranking: const [],
      toolCallId: 'call-1',
    );

    setUp(() {
      rig = RelayRig(
        environment: {
          ...relayEnvironment(),
          HireRelayConfig.jobDurationKey: '259200',
        },
      );
      receipts = InMemoryHireReceiptStore(now: () => rig.clock);
      openings = InMemoryChildJobStore(rig.hires, receipts);
      windowReads = 0;
    });

    test('the setup carries the given turn bound and no lease by '
        'default', () {
      final setup = build(maxTurns: 5).setup;

      expect(setup.maxTurns, 5);
      expect(setup.lease, isNull);
      expect(setup.port, isA<EscrowSubcontractPort>());
      expect(setup.children, isA<ChildResultSource>());
    });

    test('the port reads the approval window live and the parent from the '
        'shared hire store', () async {
      final parent = await rig.hire(
        status: HireStatus.funded,
        subcontractReserve: 2000000,
      );
      final nowSeconds = rig.clock.millisecondsSinceEpoch ~/ 1000;
      rig.ledger.jobs[parent.jobId!] = EscrowJob(
        client: rig.wallet,
        provider: StellarAddress.parse(agentWallet),
        evaluator: rig.wallet,
        agentId: AgentId(7),
        token: StellarConfig.testnet.usdcSac,
        budget: BigInt.from(price),
        feeBps: platformFeeBps,
        // Shorter than two windows: refused only because of the window the
        // contract reported.
        expiredAt: nowSeconds + _window + 3600,
        description: '',
        state: EscrowJobState.funded,
        submittedAt: 0,
        approvalDeadline: 0,
        deliverable: null,
        reserve: BigInt.from(2000000),
        reserveFunded: BigInt.from(2000000),
      );

      await expectLater(
        build().setup.port.requestChild(request(parent.id)),
        throwsA(
          isA<SubcontractRefused>().having(
            (e) => e.code,
            'code',
            'parent_too_short',
          ),
        ),
      );
      expect(windowReads, 1);
    });

    test('the result source reads the same receipt store as the open-child '
        'check', () async {
      final parent = await rig.hire(status: HireStatus.funded);
      final child = await rig.hire();
      await receipts.insert(
        NewReceiptLine(
          parentHireId: parent.id,
          childHireId: child.id,
          providerAgentId: 9,
          providerWallet: stranger,
          budget: 500000,
          relatedParty: false,
          justification: 'j',
        ),
      );
      final services = build();

      expect(await services.childrenOpen(parent.id), isTrue);
      expect(await services.setup.children.resultOf(child.id), isNull);

      await receipts.markNotOpened(child.id);

      expect(await services.childrenOpen(parent.id), isFalse);
      final result = await services.setup.children.resultOf(child.id);
      expect(result, isA<ChildFailed>());
      expect((result! as ChildFailed).code, ChildVerdictCode.notOpened);
    });

    test('a reconciliation that fails is logged and never reaches the '
        'pass', () async {
      receipts = _FailingReceipts(now: () => rig.clock);
      openings = InMemoryChildJobStore(rig.hires, receipts);
      final logs = <String>[];

      await build().reconcileChildren(
        (level, message) => logs.add('${level.name}: $message'),
      );

      expect(logs.single, startsWith('error: Reconciliation of children'));
      expect(logs.single, contains('database down'));
    });

    test('the reconciler reads the same stores and a pass with nothing '
        'unopened does nothing', () async {
      await build().reconciler.reconcile();

      expect(openings.payments, isEmpty);
      expect(await rig.submissions.listByHire(1), isEmpty);
    });
  });
}
