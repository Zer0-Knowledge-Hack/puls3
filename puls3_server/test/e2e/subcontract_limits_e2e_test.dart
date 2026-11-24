@Tags(['e2e'])
@Timeout(Duration(minutes: 15))
library;

import 'package:puls3_domain/puls3_domain.dart'
    show HireStatus, RelatedPartyJustification;
import 'package:puls3_server/src/hire/escrow_relay_service.dart'
    show SubcontractRejected;
import 'package:puls3_server/src/hire/serverpod_hire_receipt_store.dart';
import 'package:puls3_server/src/ledger/escrow_job.dart';
import 'package:puls3_server/src/ledger/ledger_errors.dart'
    show EscrowSubcontractError;
import 'package:puls3_server/src/ledger/sc_val_json.dart';
import 'package:puls3_server/src/runtime/escrow_subcontract_port.dart'
    show childExpiryMarginSeconds;
import 'package:puls3_server/src/runtime/run_manifest.dart'
    show subcontractMaxChildrenCap;
import 'package:puls3_server/src/runtime/serverpod_hire_run_store.dart';
import 'package:puls3_server/src/runtime/subcontract_port.dart';
import 'package:test/test.dart';

import 'support/contract_event_log.dart';
import 'support/e2e_world.dart';
import 'support/local_sandbox.dart';
import 'support/subcontract_world.dart';

/// The limits of a subcontract (#374): the reserve, the children cap, the
/// depth and a cycle. The contract owns the reserve, the depth and the cycle,
/// so each is checked with the on-chain error code. The children cap is the
/// tool loop's (`effectiveMaxChildren`): the escrow has no such code.
void main() {
  late E2eWorld world;
  late SubcontractRuntime runtime;
  late ScriptedManifests manifests;

  late RegisteredAgent worker;
  late RegisteredAgent capParent;
  late RegisteredAgent reserveParent;
  late RegisteredAgent depth1; // provider of the first child
  late RegisteredAgent depth2; // provider of the second child
  late RegisteredAgent depth3; // the provider of a child too deep
  final tag = DateTime.now().microsecondsSinceEpoch;
  final skill = 'e2e-$tag';
  final workerName = 'E2E Limits Worker $tag';
  const workerOutput = 'B delivered one part';

  setUpAll(() async {
    world = await E2eWorld.start(environment: subcontractEnvironment());
    worker = await world.registerCustodiedAgent(
      priceStroops: e2ePriceStroops,
      name: workerName,
      skills: [skill],
    );
    capParent = await world.registerCustodiedAgent(
      priceStroops: e2ePriceStroops,
    );
    reserveParent = await world.registerCustodiedAgent(
      priceStroops: e2ePriceStroops,
    );
    depth1 = await world.registerCustodiedAgent(priceStroops: e2ePriceStroops);
    depth2 = await world.registerCustodiedAgent(priceStroops: e2ePriceStroops);
    depth3 = await world.registerCustodiedAgent(priceStroops: e2ePriceStroops);
    final relay = E2eAccount.random();
    await world.sandbox.fund(relay.address.value);
    manifests = ScriptedManifests()
      // One child at most, whatever the platform cap is.
      ..opensChildren(capParent.id, 'caps-children', maxChildren: 1)
      ..opensChildren(
        reserveParent.id,
        'spends-the-reserve',
        maxChildren: subcontractMaxChildrenCap,
      )
      ..plain(worker.id, 'worker');
    runtime =
        SubcontractRuntime(
            world: world,
            model: ScriptedModel({
              // Asks for a second child after the first was settled.
              'caps-children': Delegator(
                skill: skill,
                wanted: [workerName, workerName],
              ),
              'spends-the-reserve': Delegator(
                skill: skill,
                wanted: [workerName, workerName],
              ),
              'worker': Worker(output: workerOutput),
            }),
            manifests: manifests,
            relay: relay,
          )
          ..serve(worker.account)
          ..serve(capParent.account)
          ..serve(reserveParent.account);
    await runtime.discardStaleRuns();
  });
  tearDownAll(() async => world.stop());

  /// The latest expiry the escrow accepts for a child of [parentJobId]
  /// (ADR-0011 D2), from the live approval window.
  Future<int> latestChildExpiry(int parentJobId) async {
    final parent = (await world.wiring.ledger.escrowJob(parentJobId))!;
    return parent.expiredAt -
        await runtime.approvalWindow() -
        childExpiryMarginSeconds;
  }

  test(
    'reserve: a child above the unspent reserve is refused with #124',
    () async {
      final reserve = reserveFor(1);
      final hire = await world.fundedHire(
        subcontractReserve: reserve,
        input: 'e2e journey of #374: reserve limit',
      );
      final expiry = await latestChildExpiry(hire.jobId);

      // The escrow refuses `budget + reserve` above what is left, at
      // simulation, so nothing is signed or stored.
      await runtime.withRelay((relay) async {
        await expectLater(
          relay.draftCreateChildJob(
            parentProvider: world.agentAccount.address,
            parentJobId: hire.jobId,
            provider: worker.account.address,
            evaluator: world.agentAccount.address,
            expiredAt: expiry,
            agentId: worker.id,
            budget: reserve + 1,
          ),
          throwsA(
            isA<SubcontractRejected>()
                .having(
                  (e) => e.error,
                  'error',
                  EscrowSubcontractError.reserveExceeded,
                )
                .having((e) => e.error.code, 'code', 124),
          ),
        );
      });

      // The server refuses the same excess before it reaches the chain, with
      // a code of its own, and stores no child.
      final small = await world.fundedHire(
        subcontractReserve: e2ePriceStroops - 1,
        input: 'e2e journey of #374: reserve below the price',
      );
      final refusal = await runtime.withPort(
        (port) => port
            .requestChild(
              ChildRequest(
                parentHireId: small.hireId,
                toolCallId: 'limit-reserve',
                agentRegistryId: worker.id,
                agentId: 'e2e-limits-worker',
                priceStroops: e2ePriceStroops,
                task: 'the part A cannot do',
                justification: 'e2e',
                isRelatedParty: false,
                relatedPartyJustification:
                    RelatedPartyJustification.independent,
                ranking: const [],
              ),
            )
            .then<Object?>((id) => id, onError: (Object e) => e),
      );
      expect(refusal, isA<SubcontractRefused>());
      expect((refusal! as SubcontractRefused).code, 'reserve_exceeded');
      final receipts = ServerpodHireReceiptStore(world.session);
      expect(await receipts.listByParent(small.hireId), isEmpty);
      expect(await receipts.listByParent(hire.hireId), isEmpty);
      final job = (await world.wiring.ledger.escrowJob(hire.jobId))!;
      expect(job.reserve, BigInt.from(reserve));
      expect(job.openChildren, 0);
      expect(
        (await runtime.escrowEvents()).forJob(
          'child_job_created',
          hire.jobId,
        ),
        isEmpty,
      );
    },
  );

  test(
    'cycle: the parent agent as its own child is refused with #127',
    () async {
      final hire = await world.fundedHire(
        subcontractReserve: reserveFor(1),
        input: 'e2e journey of #374: cycle limit',
      );
      final expiry = await latestChildExpiry(hire.jobId);
      await runtime.withRelay((relay) async {
        await expectLater(
          relay.draftCreateChildJob(
            parentProvider: world.agentAccount.address,
            parentJobId: hire.jobId,
            provider: world.agentAccount.address,
            evaluator: depth1.account.address,
            expiredAt: expiry,
            agentId: world.agentId,
            budget: e2ePriceStroops,
          ),
          throwsA(
            isA<SubcontractRejected>()
                .having(
                  (e) => e.error,
                  'error',
                  EscrowSubcontractError.subcontractCycle,
                )
                .having((e) => e.error.code, 'code', 127),
          ),
        );
      });

      // Through the port: A is hireable at its own price, so every server check
      // passes and only the escrow stops it. The port turns #127 into a refusal
      // and stores nothing.
      final refusal = await runtime.withPort(
        (port) => port
            .requestChild(
              ChildRequest(
                parentHireId: hire.hireId,
                toolCallId: 'limit-cycle',
                agentRegistryId: world.agentId,
                agentId: 'e2e-itself',
                priceStroops: e2ePriceStroops,
                task: 'hire myself',
                justification: 'e2e',
                isRelatedParty: false,
                relatedPartyJustification:
                    RelatedPartyJustification.independent,
                ranking: const [],
              ),
            )
            .then<Object?>((id) => id, onError: (Object e) => e),
      );
      expect(refusal, isA<SubcontractRefused>());
      expect((refusal! as SubcontractRefused).code, 'subcontract_cycle');
      final receipts = ServerpodHireReceiptStore(world.session);
      expect(await receipts.listByParent(hire.hireId), isEmpty);
      expect(
        (await runtime.escrowEvents()).forJob('child_job_created', hire.jobId),
        isEmpty,
      );
    },
  );

  test('depth: a child below the maximum depth is refused with #126', () async {
    // The server only draws children at depth 1 with a sub-reserve of 0, so
    // no run can go deeper. The chain below is built straight on the escrow
    // with the production draft: a child with its own sub-reserve (depth 1),
    // its child (depth 2), and then one more.
    final reserve = reserveFor(2);
    final price = BigInt.from(e2ePriceStroops);
    final hire = await world.fundedHire(
      subcontractReserve: reserve,
      input: 'e2e journey of #374: depth limit',
    );
    final root = hire.jobId;

    Future<int> openChild({
      required E2eAccount parent,
      required int parentJobId,
      required RegisteredAgent child,
      required int reserveForChild,
    }) async {
      final expiry = await latestChildExpiry(parentJobId);
      await runtime.withRelay((relay) async {
        final draft = await relay.draftCreateChildJob(
          parentProvider: parent.address,
          parentJobId: parentJobId,
          provider: child.account.address,
          evaluator: parent.address,
          expiredAt: expiry,
          agentId: child.id,
          budget: e2ePriceStroops,
          reserve: reserveForChild,
        );
        await runtime.sendDirect(parent, draft.envelope);
      });
      final events = await until('the child of job $parentJobId', () async {
        final all = await runtime.escrowEvents();
        final created = all.forJob('child_job_created', parentJobId);
        return created.isEmpty ? null : created;
      });
      return readU64(events.single.data['child_job_id']);
    }

    final first = await openChild(
      parent: world.agentAccount,
      parentJobId: root,
      child: depth1,
      reserveForChild: e2ePriceStroops,
    );
    final firstJob = (await world.wiring.ledger.escrowJob(first))!;
    expect(firstJob.depth, 1);
    expect(firstJob.reserve, price);
    final second = await openChild(
      parent: depth1.account,
      parentJobId: first,
      child: depth2,
      reserveForChild: 0,
    );
    final secondJob = (await world.wiring.ledger.escrowJob(second))!;
    expect(secondJob.depth, 2);
    expect(secondJob.parentJobId, first);
    expect(secondJob.state, EscrowJobState.funded);

    // Depth 3 is over the limit, whatever the amounts.
    final expiry = await latestChildExpiry(second);
    await runtime.withRelay((relay) async {
      await expectLater(
        relay.draftCreateChildJob(
          parentProvider: depth2.account.address,
          parentJobId: second,
          provider: depth3.account.address,
          evaluator: depth2.account.address,
          expiredAt: expiry,
          agentId: depth3.id,
          budget: e2ePriceStroops,
        ),
        throwsA(
          isA<SubcontractRejected>()
              .having(
                (e) => e.error,
                'error',
                EscrowSubcontractError.depthExceeded,
              )
              .having((e) => e.error.code, 'code', 126),
        ),
      );
    });
    final after = (await world.wiring.ledger.escrowJob(second))!;
    expect(after.openChildren, 0);
    final events = await runtime.escrowEvents();
    expect(events.forJob('child_job_created', second), isEmpty);
    final createdSecond = events.forJob('child_job_created', first).single;
    expect(readU32(createdSecond.data['depth']), 2);
  });

  test(
    'children cap: a second subcontract past max_children is refused by '
    'the loop',
    () async {
      final hire = await world.fundedHire(
        subcontractReserve: reserveFor(2),
        input: 'e2e journey of #374: children cap',
        agent: capParent.id,
      );
      await runtime.passUntil('the parent hire to be submitted', () async {
        final row = await world.hires.findHire(hire.hireId);
        return row?.status == HireStatus.submitted ? row : null;
      });
      final receipts = ServerpodHireReceiptStore(world.session);
      final lines = await receipts.listByParent(hire.hireId);
      expect(lines, hasLength(1), reason: 'one child, the second was refused');
      expect(lines.single.state, HireStatus.completed.name);
      final run = (await ServerpodHireRunStore(
        world.session,
      ).find(hire.hireId))!;
      expect(run.result, contains(workerOutput));
      expect(run.result, contains('refused max_children_reached'));
      final events = await runtime.escrowEvents();
      expect(events.forJob('child_job_created', hire.jobId), hasLength(1));
      final job = (await world.wiring.ledger.escrowJob(hire.jobId))!;
      expect(job.openChildren, 0);
      expect(job.reserve, BigInt.from(e2ePriceStroops));
    },
  );

  test(
    'reserve in the loop: a subcontract the reserve no longer covers is '
    'refused before it reaches the chain',
    () async {
      final hire = await world.fundedHire(
        subcontractReserve: reserveFor(1),
        input: 'e2e journey of #374: reserve spent',
        agent: reserveParent.id,
      );
      await runtime.passUntil('the parent hire to be submitted', () async {
        final row = await world.hires.findHire(hire.hireId);
        return row?.status == HireStatus.submitted ? row : null;
      });
      final receipts = ServerpodHireReceiptStore(world.session);
      expect(await receipts.listByParent(hire.hireId), hasLength(1));
      final run = (await ServerpodHireRunStore(
        world.session,
      ).find(hire.hireId))!;
      expect(run.result, contains('refused over_reserve'));
      final events = await runtime.escrowEvents();
      expect(events.forJob('child_job_created', hire.jobId), hasLength(1));
      final job = (await world.wiring.ledger.escrowJob(hire.jobId))!;
      expect(job.reserve, BigInt.zero);
    },
  );
}
