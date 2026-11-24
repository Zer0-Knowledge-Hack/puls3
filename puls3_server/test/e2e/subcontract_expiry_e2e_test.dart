@Tags(['e2e'])
@Timeout(Duration(minutes: 20))
library;

import 'dart:io';

import 'package:puls3_domain/puls3_domain.dart' show HireStatus;
import 'package:puls3_server/src/chain/serverpod_chain_submission_store.dart';
import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:puls3_server/src/hire/serverpod_hire_receipt_store.dart';
import 'package:puls3_server/src/ledger/escrow_job.dart';
import 'package:puls3_server/src/ledger/sc_val_json.dart';
import 'package:puls3_server/src/runtime/child_verdict.dart';
import 'package:puls3_server/src/runtime/escrow_subcontract_port.dart'
    show childExpiryMarginSeconds;
import 'package:puls3_server/src/runtime/hire_run_store.dart';
import 'package:puls3_server/src/runtime/hire_runner.dart' show runNotRunnable;
import 'package:puls3_server/src/runtime/run_manifest.dart'
    show subcontractMaxChildrenCap;
import 'package:puls3_server/src/runtime/serverpod_hire_run_store.dart';
import 'package:test/test.dart';

import 'support/contract_event_log.dart';
import 'support/e2e_world.dart';
import 'support/local_sandbox.dart';
import 'support/subcontract_world.dart';

/// Expiry of a child that is never delivered (#374).
///
/// A child outlives its parent's approval window, so with the sandbox's
/// one-day window this scenario would wait more than a day for the ledger
/// clock. The contract owns the window (`set_approval_window`, admin only) and
/// the server reads it live, so the suite shortens it for this run only and
/// restores it afterwards. Nothing else is scaled: the contract's own checks
/// (a child expires `approval_window + CHILD_EXPIRY_MARGIN` before its parent)
/// and the port's own checks hold, except the 30 minutes `childRunHeadroom`
/// the port leaves a child to run, which `EscrowSubcontractPort` takes as a
/// constructor argument and this suite shortens too.
///
/// The timings are derived, not free: with a window `W` and a headroom `h`, a
/// parent lasts `600 + 2W + h + slack` seconds, so its child lasts
/// `W + h + slack`, the least `subcontract` accepts plus `slack`.
void main() {
  // Test timings in seconds, scaled so the scenario ends in about a minute.
  const window = 15;
  const headroomSeconds = 5;
  const headroom = Duration(seconds: headroomSeconds);
  const slack = 20;
  const parentDuration =
      childExpiryMarginSeconds + 2 * window + headroomSeconds + slack;

  late E2eWorld world;
  late SubcontractRuntime runtime;
  late ScriptedManifests manifests;
  late RegisteredAgent worker;
  late int originalWindow;
  final tag = DateTime.now().microsecondsSinceEpoch;
  final skill = 'e2e-$tag';
  final workerName = 'E2E Silent Worker $tag';

  Future<void> setApprovalWindow(int seconds) async {
    final env = world.sandbox.environment;
    final result = await Process.run('stellar', [
      'contract',
      'invoke',
      '--id',
      world.wiring.stellar.escrow.value,
      '--network',
      env['STELLAR_NETWORK']!,
      '--source-account',
      env['STELLAR_ACCOUNT']!,
      '--',
      'set_approval_window',
      '--caller',
      world.sandbox.admin,
      '--approval-window',
      '$seconds',
    ]);
    if (result.exitCode != 0) {
      throw StateError('set_approval_window failed: ${result.stderr}');
    }
  }

  setUpAll(() async {
    world = await E2eWorld.start(
      environment: {
        ...subcontractEnvironment(),
        'PULS3_HIRE_JOB_DURATION_SECONDS': '$parentDuration',
      },
    );
    worker = await world.registerCustodiedAgent(
      priceStroops: e2ePriceStroops,
      name: workerName,
      skills: [skill],
    );
    final relay = E2eAccount.random();
    await world.sandbox.fund(relay.address.value);
    manifests = ScriptedManifests()
      ..opensChildren(
        world.agentId,
        'delegates-to-silent',
        maxChildren: subcontractMaxChildrenCap,
      )
      ..plain(worker.id, 'worker')
      // B's run never starts: its manifest cannot be read, so it stays queued
      // and B never delivers.
      ..unreadable.add(worker.id);
    runtime =
        SubcontractRuntime(
            world: world,
            model: ScriptedModel({
              'delegates-to-silent': Delegator(
                skill: skill,
                wanted: [workerName],
              ),
              'worker': Worker(),
            }),
            manifests: manifests,
            relay: relay,
            runHeadroom: headroom,
          )
          ..serve(world.agentAccount)
          ..serve(worker.account);
    await runtime.discardStaleRuns();
    originalWindow = await runtime.approvalWindow();
    await setApprovalWindow(window);
  });
  tearDownAll(() async {
    try {
      await setApprovalWindow(originalWindow);
    } finally {
      await world.stop();
    }
  });

  test(
    'expiry: a child that is never delivered is refunded to the reserve and '
    'the parent stays consistent',
    () async {
      expect(await runtime.approvalWindow(), window);
      final reserve = reserveFor(1);
      final hire = await world.fundedHire(
        subcontractReserve: reserve,
        input: 'e2e journey of #374: expiry',
      );
      final parentJobId = hire.jobId;
      final receipts = ServerpodHireReceiptStore(world.session);
      final submissions = ServerpodChainSubmissionStore(world.session);
      final runs = ServerpodHireRunStore(world.session);

      // The child opens and funds, and B never starts.
      final opened = await runtime.passUntil(
        'the child to be funded',
        () async {
          final lines = await receipts.listByParent(hire.hireId);
          return lines.length == 1 && lines.single.childJobId != null
              ? lines.single
              : null;
        },
      );
      final childHireId = opened.childHireId!;
      final childJobId = opened.childJobId!;
      final childJob = (await world.wiring.ledger.escrowJob(childJobId))!;
      expect(childJob.state, EscrowJobState.funded);
      final parentJob = (await world.wiring.ledger.escrowJob(parentJobId))!;
      expect(parentJob.openChildren, 1);
      expect(parentJob.reserve, BigInt.zero);
      // The escrow gave the child the least room `subcontract` accepts, plus
      // the slack: it expires a full window and the margin before its parent.
      expect(
        childJob.expiredAt,
        lessThanOrEqualTo(
          parentJob.expiredAt - window - childExpiryMarginSeconds,
        ),
      );
      // The parent cannot submit while the child is open (ADR-0011 D4).
      expect(
        [
          for (final row in await submissions.listByHire(hire.hireId))
            if (row.purpose == SubmissionPurpose.submit) row,
        ],
        isEmpty,
      );

      // The child expires, the deadline relay refunds it to the reserve and
      // the parent run resumes, submits and closes.
      await runtime.passUntil(
        'the parent hire to be submitted after the refund',
        () async {
          final row = await world.hires.findHire(hire.hireId);
          return row?.status == HireStatus.submitted ? row : null;
        },
        timeout: const Duration(minutes: 6),
      );

      // Persisted rows.
      final line = (await receipts.findByChildHire(childHireId))!;
      expect(line.state, HireStatus.expired.name);
      expect(line.payout, 0);
      final child = (await world.hires.findHire(childHireId))!;
      expect(child.status, HireStatus.expired);
      final claim = (await submissions.listByHire(childHireId)).singleWhere(
        (r) => r.purpose == SubmissionPurpose.claimRefund,
      );
      expect(claim.state, SubmissionState.confirmed);
      expect(line.settleTransaction, claim.transactionHash);
      expect(
        [
          for (final row in await submissions.listByHire(childHireId))
            if (row.purpose == SubmissionPurpose.submit) row,
        ],
        isEmpty,
        reason: 'B never delivered',
      );
      // B never ran; once the child expired its queued run left the queue as
      // not runnable instead of calling the model for a refunded job.
      final childRun = (await runs.find(childHireId))!;
      expect(childRun.result, isNull);
      expect(childRun.state, HireRunState.failed);
      expect(childRun.failureReason, runNotRunnable);
      final parentRun = (await runs.find(hire.hireId))!;
      expect(parentRun.state, HireRunState.succeeded);
      expect(parentRun.result, contains('child_failed'));
      expect(parentRun.result, contains(ChildVerdictCode.expired));
      final parentSubmit = (await submissions.listByHire(
        hire.hireId,
      )).singleWhere((r) => r.purpose == SubmissionPurpose.submit);
      expect(parentSubmit.state, SubmissionState.confirmed);

      // On chain: the child expired, the reserve is whole again and the
      // parent is submitted with no child open.
      final expired = (await world.wiring.ledger.escrowJob(childJobId))!;
      expect(expired.state, EscrowJobState.expired);
      final consistent = (await world.wiring.ledger.escrowJob(parentJobId))!;
      expect(consistent.state, EscrowJobState.submitted);
      expect(consistent.openChildren, 0);
      expect(consistent.reserve, BigInt.from(reserve));

      // The consumer approves: the whole reserve goes back.
      final complete = await world.endpoint.prepareComplete(
        world.session,
        hire.hireId,
      );
      await world.endpoint.submitEscrowCall(
        world.session,
        hire.hireId,
        complete.preparationId,
        world.consumer.sign(world.codec, complete.unsignedTransactionXdr!),
      );
      await world.confirmed(complete.preparationId);
      await world.hireIn(hire.hireId, HireStatus.completed);

      final events = await until('the escrow to report the refund', () async {
        final all = await runtime.escrowEvents();
        return all.forJob('reserve_refunded', parentJobId).isNotEmpty
            ? all
            : null;
      });
      final price = BigInt.from(e2ePriceStroops);
      final created = events.forJob('child_job_created', parentJobId).single;
      expect(readU64(created.data['child_job_id']), childJobId);
      expect(readI128(created.data['budget']), price);

      final jobExpired = events.forJob('job_expired', childJobId).single;
      expect(jobExpired.transaction, claim.transactionHash);
      expect(
        readAddress(jobExpired.data['client']),
        world.agentAccount.address,
      );
      expect(readI128(jobExpired.data['refunded']), price);
      final returned = [
        for (final e in events)
          if (e.name == 'reserve_returned' &&
              readU64(e.topics.first) == parentJobId)
            e,
      ].single;
      expect(readU64(returned.data['child_job_id']), childJobId);
      expect(readI128(returned.data['amount']), price);
      expect(readBool(returned.data['to_client']), isFalse);
      expect(returned.transaction, claim.transactionHash);
      expect(
        events.forJob('job_submitted', childJobId),
        isEmpty,
        reason: 'B never delivered',
      );
      expect(
        events.forJob('job_completed', childJobId),
        isEmpty,
        reason: 'an expired child pays nobody',
      );
      // The refund preceded the parent's submit.
      final parentSubmitted = events
          .forJob('job_submitted', parentJobId)
          .single;
      expect(parentSubmitted.ledger, greaterThan(returned.ledger));

      // funded - drawn + returned = refunded: nothing was spent.
      final refunded = events.forJob('reserve_refunded', parentJobId).single;
      expect(readAddress(refunded.data['client']), world.consumer.address);
      expect(
        BigInt.from(reserve) - price + readI128(returned.data['amount']),
        readI128(refunded.data['amount']),
      );
    },
  );
}
