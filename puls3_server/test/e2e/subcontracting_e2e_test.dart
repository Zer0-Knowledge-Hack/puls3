@Tags(['e2e'])
@Timeout(Duration(minutes: 15))
library;

import 'package:puls3_domain/puls3_domain.dart' show HireStatus;
import 'package:puls3_server/src/chain/serverpod_chain_submission_store.dart';
import 'package:puls3_server/src/chain/chain_submission_store.dart'
    show StoredSubmission;
import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:puls3_server/src/hire/serverpod_hire_receipt_store.dart';
import 'package:puls3_server/src/ledger/escrow_job.dart';
import 'package:puls3_server/src/ledger/sc_val_json.dart';
import 'package:puls3_server/src/runtime/child_verdict.dart';
import 'package:puls3_server/src/runtime/conversation.dart'
    show RuntimeEmptyOutput;
import 'package:puls3_server/src/runtime/hire_run_store.dart';
import 'package:puls3_server/src/runtime/serverpod_hire_run_store.dart';
import 'package:puls3_server/src/runtime/run_manifest.dart'
    show subcontractMaxChildrenCap;
import 'package:puls3_server/src/runtime/subcontract_port.dart';
import 'package:puls3_server/src/runtime/tool_loop_codec.dart';
import 'package:test/test.dart';

import 'support/contract_event_log.dart';
import 'support/e2e_world.dart';
import 'support/local_sandbox.dart';
import 'support/subcontract_world.dart';

/// The subcontracting journey of #334 on the local sandbox (#374): the real
/// hire endpoint, chain tracker, subcontract executor and escrow contract,
/// with a deterministic stand-in for the model.
///
/// Every agent is registered on the sandbox before the first search: the
/// marketplace catalog is cached the first time it is read.
void main() {
  late E2eWorld world;
  late SubcontractRuntime runtime;
  late ScriptedManifests manifests;

  late RegisteredAgent worker; // B: delivers.
  late RegisteredAgent failing; // B: its run fails.
  late RegisteredAgent parentReject; // A of the rejection scenario.
  late RegisteredAgent parentRestart; // A of the restart scenario.
  final tag = DateTime.now().microsecondsSinceEpoch;
  final skill = 'e2e-$tag';
  final workerName = 'E2E Worker $tag';
  final failingName = 'E2E Failing Worker $tag';
  const workerOutput = 'B delivered the part A could not do';

  setUpAll(() async {
    world = await E2eWorld.start(environment: subcontractEnvironment());
    worker = await world.registerCustodiedAgent(
      priceStroops: e2ePriceStroops,
      name: workerName,
      skills: [skill],
    );
    failing = await world.registerCustodiedAgent(
      priceStroops: e2ePriceStroops,
      name: failingName,
      skills: [skill],
    );
    parentReject = await world.registerCustodiedAgent(
      priceStroops: e2ePriceStroops,
    );
    parentRestart = await world.registerCustodiedAgent(
      priceStroops: e2ePriceStroops,
    );
    final relay = E2eAccount.random();
    await world.sandbox.fund(relay.address.value);
    manifests = ScriptedManifests()
      ..opensChildren(
        world.agentId,
        'delegates-to-worker',
        maxChildren: subcontractMaxChildrenCap,
      )
      ..opensChildren(
        parentReject.id,
        'delegates-to-failing',
        maxChildren: subcontractMaxChildrenCap,
      )
      ..opensChildren(
        parentRestart.id,
        'delegates-then-restarts',
        maxChildren: subcontractMaxChildrenCap,
      )
      ..plain(worker.id, 'worker')
      ..plain(failing.id, 'failing-worker');
    runtime =
        SubcontractRuntime(
            world: world,
            model: ScriptedModel({
              'delegates-to-worker': Delegator(
                skill: skill,
                wanted: [workerName],
              ),
              'delegates-to-failing': Delegator(
                skill: skill,
                wanted: [failingName],
              ),
              'delegates-then-restarts': Delegator(
                skill: skill,
                wanted: [workerName],
              ),
              'worker': Worker(output: workerOutput),
              'failing-worker': Worker(failure: const RuntimeEmptyOutput()),
            }),
            manifests: manifests,
            relay: relay,
          )
          ..serve(world.agentAccount)
          ..serve(worker.account)
          ..serve(failing.account)
          ..serve(parentReject.account)
          ..serve(parentRestart.account);
    await runtime.discardStaleRuns();
  });
  tearDownAll(() async => world.stop());

  /// The consumer approves the submitted parent hire, signing the `complete`
  /// the endpoint prepared, and waits for it to confirm.
  Future<void> consumerApproves(int hireId) async {
    final complete = await world.endpoint.prepareComplete(
      world.session,
      hireId,
    );
    await world.endpoint.submitEscrowCall(
      world.session,
      hireId,
      complete.preparationId,
      world.consumer.sign(world.codec, complete.unsignedTransactionXdr!),
    );
    await world.confirmed(complete.preparationId);
    await world.hireIn(hireId, HireStatus.completed);
  }

  test(
    'happy path: A subcontracts B from the reserve, B delivers, A approves '
    'and the reserve reconciles',
    () async {
      // Room for a second child, so part of the reserve is left to refund.
      final reserve = reserveFor(subcontractMaxChildrenCap);
      final hire = await world.fundedHire(
        subcontractReserve: reserve,
        input: 'e2e journey of #374: happy path',
      );
      final parentJobId = hire.jobId;

      // The consumer's one signature funded the price and the reserve.
      final funded = (await world.hires.findHire(hire.hireId))!;
      expect(funded.subcontractReserve, reserve);
      final fundedJob = (await world.wiring.ledger.escrowJob(parentJobId))!;
      expect(fundedJob.state, EscrowJobState.funded);
      expect(fundedJob.reserve, BigInt.from(reserve));
      expect(fundedJob.reserveFunded, BigInt.from(reserve));
      expect(fundedJob.openChildren, 0);
      expect(fundedJob.depth, 0);
      expect(fundedJob.parentJobId, isNull);

      // A subcontracts B, B delivers, A approves, A resumes and submits.
      await runtime.passUntil('the parent hire to be submitted', () async {
        final row = await world.hires.findHire(hire.hireId);
        return row?.status == HireStatus.submitted ? row : null;
      });

      // Persisted rows: the receipt line, the child hire and the runs.
      final receipts = ServerpodHireReceiptStore(world.session);
      final lines = await receipts.listByParent(hire.hireId);
      expect(lines, hasLength(1));
      final line = lines.single;
      expect(line.state, HireStatus.completed.name);
      expect(line.providerAgentId, worker.id);
      expect(line.providerWallet, worker.account.address.value);
      expect(line.budget, e2ePriceStroops);
      expect(line.relatedParty, isFalse);
      expect(line.justification, isNotEmpty);
      expect(line.fee, 0);
      expect(line.payout, e2ePriceStroops);
      final childHireId = line.childHireId!;
      final childJobId = line.childJobId!;

      final child = (await world.hires.findHire(childHireId))!;
      expect(child.parentHireId, hire.hireId);
      expect(child.consumer, world.agentAccount.address.value);
      expect(child.agentId, worker.id);
      expect(child.price, e2ePriceStroops);
      expect(child.jobId, childJobId);
      expect(child.status, HireStatus.completed);

      final runs = ServerpodHireRunStore(world.session);
      final childRun = (await runs.find(childHireId))!;
      expect(childRun.state, HireRunState.succeeded);
      expect(childRun.result, workerOutput);
      final parentRun = (await runs.find(hire.hireId))!;
      expect(parentRun.state, HireRunState.succeeded);
      expect(parentRun.result, contains(workerOutput));

      final submissions = ServerpodChainSubmissionStore(world.session);
      Future<StoredSubmission> only(
        int hireId,
        SubmissionPurpose purpose,
      ) async {
        final rows = [
          for (final row in await submissions.listByHire(hireId))
            if (row.purpose == purpose) row,
        ];
        expect(rows, hasLength(1), reason: '${purpose.wireName} of $hireId');
        expect(rows.single.state, SubmissionState.confirmed);
        return rows.single;
      }

      await only(hire.hireId, SubmissionPurpose.fund);
      final createChild = await only(
        childHireId,
        SubmissionPurpose.createChildJob,
      );
      await only(childHireId, SubmissionPurpose.submit);
      final childComplete = await only(
        childHireId,
        SubmissionPurpose.childComplete,
      );
      await only(hire.hireId, SubmissionPurpose.submit);
      expect(line.createTransaction, createChild.transactionHash);
      expect(line.settleTransaction, childComplete.transactionHash);

      // On chain: the child is a job of A's reserve, now completed, and the
      // parent holds the rest of the reserve with no child open.
      final childJob = (await world.wiring.ledger.escrowJob(childJobId))!;
      expect(childJob.state, EscrowJobState.completed);
      expect(childJob.parentJobId, parentJobId);
      expect(childJob.depth, 1);
      expect(childJob.client, world.agentAccount.address);
      expect(childJob.provider, worker.account.address);
      expect(childJob.evaluator, world.agentAccount.address);
      expect(childJob.budget, BigInt.from(e2ePriceStroops));
      final parentJob = (await world.wiring.ledger.escrowJob(parentJobId))!;
      expect(parentJob.state, EscrowJobState.submitted);
      expect(parentJob.openChildren, 0);
      expect(parentJob.reserve, BigInt.from(reserve - e2ePriceStroops));

      // The consumer approves the parent: the unspent reserve goes back.
      await consumerApproves(hire.hireId);

      // Every escrow event of the journey, for these jobs.
      final events = await until('the escrow to report the refund', () async {
        final all = await runtime.escrowEvents();
        return all.forJob('reserve_refunded', parentJobId).isNotEmpty
            ? all
            : null;
      });
      final consumer = world.consumer.address;
      final agentA = world.agentAccount.address;
      final agentB = worker.account.address;
      final price = BigInt.from(e2ePriceStroops);

      final reserveFunded = events.forJob('reserve_funded', parentJobId).single;
      expect(readAddress(reserveFunded.data['client']), consumer);
      expect(readI128(reserveFunded.data['reserve']), BigInt.from(reserve));
      final parentFunded = events.forJob('job_funded', parentJobId).single;
      expect(readI128(parentFunded.data['amount']), price);
      expect(reserveFunded.transaction, parentFunded.transaction);

      final childCreated = events.forJob('child_job_created', parentJobId);
      expect(childCreated, hasLength(1));
      final created = childCreated.single;
      expect(created.transaction, line.createTransaction);
      expect(readU64(created.data['child_job_id']), childJobId);
      expect(readAddress(created.data['provider']), agentB);
      expect(readU32(created.data['agent_id']), worker.id);
      expect(readI128(created.data['budget']), price);
      expect(readI128(created.data['reserve']), BigInt.zero);
      expect(readU32(created.data['depth']), 1);
      expect(
        readI128(created.data['parent_reserve_left']),
        BigInt.from(reserve) - price,
      );
      final childJobCreated = events.forJob('job_created', childJobId).single;
      expect(readAddress(childJobCreated.data['client']), agentA);
      expect(readAddress(childJobCreated.data['provider']), agentB);
      expect(readAddress(childJobCreated.data['evaluator']), agentA);
      expect(childJobCreated.transaction, created.transaction);
      final childFunded = events.forJob('job_funded', childJobId).single;
      expect(readI128(childFunded.data['amount']), price);

      final childSubmitted = events.forJob('job_submitted', childJobId).single;
      expect(readAddress(childSubmitted.data['provider']), agentB);
      final childCompleted = events.forJob('job_completed', childJobId).single;
      expect(childCompleted.transaction, line.settleTransaction);
      expect(readAddress(childCompleted.data['evaluator']), agentA);
      expect(readI128(childCompleted.data['payout']), price);
      expect(readI128(childCompleted.data['fee']), BigInt.zero);
      expect(readBool(childCompleted.data['auto_released']), isFalse);
      expect(
        childCompleted.data['reason'].toString(),
        contains(bytesHex(childReasonHash(ChildVerdictCode.complete))),
      );
      // B was paid before A could submit: the verdict precedes the submit.
      final parentSubmitted = events.forJob('job_submitted', parentJobId);
      expect(parentSubmitted, hasLength(1));
      expect(parentSubmitted.single.ledger, greaterThan(childCompleted.ledger));

      // The parent closes and the unspent reserve returns to the consumer.
      final refunded = events.forJob('reserve_refunded', parentJobId).single;
      expect(readAddress(refunded.data['client']), consumer);
      expect(readBool(refunded.data['deferred']), isFalse);
      final parentCompleted = events
          .forJob('job_completed', parentJobId)
          .single;
      expect(readI128(parentCompleted.data['payout']), price);
      expect(refunded.transaction, parentCompleted.transaction);

      // Reserve accounting: funded - drawn + returned = refunded, and a
      // completed child is final, so nothing came back to the reserve.
      final drawn = [
        for (final e in childCreated) readI128(e.data['budget']),
      ].fold(BigInt.zero, (a, b) => a + b);
      final returned = [
        for (final e in events)
          if (e.name == 'reserve_returned' &&
              readU64(e.topics.first) == parentJobId)
            readI128(e.data['amount']),
      ].fold(BigInt.zero, (a, b) => a + b);
      expect(returned, BigInt.zero);
      expect(
        readI128(reserveFunded.data['reserve']) - drawn + returned,
        readI128(refunded.data['amount']),
      );
      expect(readI128(refunded.data['amount']), BigInt.from(reserve) - price);
    },
  );

  test(
    'rejection: B fails, A rejects, the funds return to the reserve and '
    'never to A, and the consumer gets the whole reserve back',
    () async {
      // B's run fails, so the child is rejected while still funded
      // (`child_run_failed`). Rejecting an output B did deliver
      // (`child_output_empty`) is not reachable here: the production
      // `AgentRunner` fails a blank output as `RuntimeEmptyOutput` before
      // anything is submitted, so that verdict stays covered by the unit
      // tests of `judgeChildOutput` and `EscrowChildResultSource`.
      final reserve = reserveFor(1);
      final hire = await world.fundedHire(
        subcontractReserve: reserve,
        input: 'e2e journey of #374: rejection',
        agent: parentReject.id,
      );
      final parentJobId = hire.jobId;
      final agentA = parentReject.account.address;

      await runtime.passUntil('the parent hire to be submitted', () async {
        final row = await world.hires.findHire(hire.hireId);
        return row?.status == HireStatus.submitted ? row : null;
      });

      final receipts = ServerpodHireReceiptStore(world.session);
      final line = (await receipts.listByParent(hire.hireId)).single;
      expect(line.state, HireStatus.rejected.name);
      expect(line.providerAgentId, failing.id);
      expect(line.payout, 0);
      final childHireId = line.childHireId!;
      final childJobId = line.childJobId!;
      expect(
        (await world.hires.findHire(childHireId))!.status,
        HireStatus.rejected,
      );
      final runs = ServerpodHireRunStore(world.session);
      expect((await runs.find(childHireId))!.state, HireRunState.failed);
      final parentRun = (await runs.find(hire.hireId))!;
      expect(parentRun.result, contains('child_failed'));
      expect(parentRun.result, contains(ChildVerdictCode.runFailed));
      final submissions = ServerpodChainSubmissionStore(world.session);
      final reject = (await submissions.listByHire(childHireId)).singleWhere(
        (r) => r.purpose == SubmissionPurpose.childReject,
      );
      expect(reject.state, SubmissionState.confirmed);
      expect(line.settleTransaction, reject.transactionHash);

      // The child is rejected and the parent has its whole reserve back.
      final childJob = (await world.wiring.ledger.escrowJob(childJobId))!;
      expect(childJob.state, EscrowJobState.rejected);
      final parentJob = (await world.wiring.ledger.escrowJob(parentJobId))!;
      expect(parentJob.reserve, BigInt.from(reserve));
      expect(parentJob.openChildren, 0);
      expect(parentJob.client, world.consumer.address);

      final events = await runtime.escrowEvents();
      final rejected = events.forJob('job_rejected', childJobId).single;
      expect(rejected.transaction, reject.transactionHash);
      expect(
        rejected.data.toString(),
        contains(bytesHex(childReasonHash(ChildVerdictCode.runFailed))),
      );
      final returns = [
        for (final e in events)
          if (e.name == 'reserve_returned' &&
              readU64(e.topics.first) == parentJobId)
            e,
      ];
      expect(returns, hasLength(1));
      final returned = returns.single;
      expect(readU64(returned.data['child_job_id']), childJobId);
      expect(readI128(returned.data['amount']), BigInt.from(e2ePriceStroops));
      // The nearest funded ancestor is the parent job, whose reserve takes
      // the funds back: not its client (the parent is still open) and not A.
      expect(readBool(returned.data['to_client']), isFalse);
      expect(returned.transaction, reject.transactionHash);
      expect(
        events.forJob('job_completed', childJobId),
        isEmpty,
        reason: 'a rejected child pays nobody',
      );
      expect(
        [
          for (final e in events)
            if (e.name == 'reserve_refunded' &&
                readAddress(e.data['client']) == agentA)
              e,
        ],
        isEmpty,
        reason: 'A is never the client of a refund',
      );

      // The parent closes: the consumer, not A, gets the reserve, whole
      // because the rejected child's funds came back to it.
      await consumerApproves(hire.hireId);
      final closing = await until('the escrow to report the refund', () async {
        final all = await runtime.escrowEvents();
        return all.forJob('reserve_refunded', parentJobId).isNotEmpty
            ? all
            : null;
      });
      final refunded = closing.forJob('reserve_refunded', parentJobId).single;
      expect(readAddress(refunded.data['client']), world.consumer.address);
      expect(readI128(refunded.data['amount']), BigInt.from(reserve));
      expect(readBool(refunded.data['deferred']), isFalse);
      final completed = closing.forJob('job_completed', parentJobId).single;
      expect(
        readI128(completed.data['payout']),
        BigInt.from(e2ePriceStroops),
        reason: 'A is paid its own price and nothing of the reserve',
      );
    },
  );

  test(
    'restart: a run resumed after a restart does not open the same child '
    'twice',
    () async {
      final reserve = reserveFor(subcontractMaxChildrenCap);
      final hire = await world.fundedHire(
        subcontractReserve: reserve,
        input: 'e2e journey of #374: restart',
        agent: parentRestart.id,
      );
      final parentJobId = hire.jobId;
      final receipts = ServerpodHireReceiptStore(world.session);
      final runs = ServerpodHireRunStore(world.session);

      // The run opens its child and pauses.
      final paused = await runtime.passUntil(
        'the parent run to wait for its child',
        () async {
          final run = await runs.find(hire.hireId);
          return run?.state == HireRunState.awaitingChild ? run : null;
        },
      );
      final childHireId = paused.childHireId!;
      final stored = decodeChildRequest(paused.childRequest!);
      expect(stored.parentHireId, hire.hireId);
      expect(paused.pendingToolCallId, isNotNull);
      final linesBefore = await receipts.listByParent(hire.hireId);
      expect(linesBefore, hasLength(1));

      // The server restarts: a new runtime and a new model, with nothing in
      // memory, resume from the database alone.
      final restarted =
          SubcontractRuntime(
              world: world,
              model: ScriptedModel({
                'delegates-then-restarts': Delegator(
                  skill: skill,
                  wanted: [workerName],
                ),
                'worker': Worker(output: workerOutput),
              }),
              manifests: manifests,
              relay: runtime.relay,
            )
            ..serve(parentRestart.account)
            ..serve(worker.account);
      await restarted.passUntil('the parent hire to be submitted', () async {
        final row = await world.hires.findHire(hire.hireId);
        return row?.status == HireStatus.submitted ? row : null;
      });

      // One child, one line, one create_child_job: nothing was opened again.
      final lines = await receipts.listByParent(hire.hireId);
      expect(lines, hasLength(1));
      expect(lines.single.childHireId, childHireId);
      expect(lines.single.childJobId, isNotNull);
      expect(lines.single.state, HireStatus.completed.name);
      final events = await restarted.escrowEvents();
      expect(events.forJob('child_job_created', parentJobId), hasLength(1));
      final submissions = ServerpodChainSubmissionStore(world.session);
      final opens = [
        for (final row in await submissions.listByHire(childHireId))
          if (row.purpose == SubmissionPurpose.createChildJob) row,
      ];
      expect(opens, hasLength(1));
      // The restarted model was asked once: the turn that read B's result.
      // It never searched or subcontracted again.
      expect(
        restarted.model.calls.where((c) => c.startsWith('converse')),
        hasLength(1),
      );
      final parentRun = (await runs.find(hire.hireId))!;
      expect(parentRun.result, contains(workerOutput));

      // The same `subcontract` call, sent again after a crash that lost the
      // pause, returns the stored child instead of opening another.
      final again = await restarted.withPort(
        (port) => port.requestChild(
          ChildRequest(
            parentHireId: hire.hireId,
            toolCallId: paused.pendingToolCallId,
            agentRegistryId: stored.agentRegistryId,
            agentId: stored.agentId,
            priceStroops: stored.priceStroops,
            task: stored.task,
            justification: stored.justification,
            isRelatedParty: stored.isRelatedParty,
            relatedPartyJustification: stored.relatedPartyJustification,
            ranking: stored.ranking,
          ),
        ),
      );
      expect(again, childHireId);
      expect(await receipts.listByParent(hire.hireId), hasLength(1));
      expect(
        (await restarted.escrowEvents()).forJob(
          'child_job_created',
          parentJobId,
        ),
        hasLength(1),
      );
    },
  );
}
