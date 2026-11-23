import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/agent/agent_wallet_custody.dart';
import 'package:puls3_server/src/chain/agent_submit_sender.dart';
import 'package:puls3_server/src/chain/chain_submission_store.dart';
import 'package:puls3_server/src/chain/escrow_deadline.dart';
import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:puls3_server/src/hire/chain_accounts.dart';
import 'package:puls3_server/src/hire/hire_lifecycle_store.dart';
import 'package:puls3_server/src/hire/hire_receipt_store.dart';
import 'package:puls3_server/src/ledger/envelope_codec.dart';
import 'package:puls3_server/src/ledger/ledger_errors.dart';
import 'package:puls3_server/src/ledger/soroban_rpc_client.dart';
import 'package:puls3_server/src/ledger/xdr_invoke_encoder.dart';
import 'package:puls3_server/src/runtime/child_verdict.dart';
import 'package:puls3_server/src/runtime/escrow_child_result_source.dart';
import 'package:puls3_server/src/runtime/hire_run_store.dart';
import 'package:puls3_server/src/runtime/tool_loop.dart';
import 'package:test/test.dart';

import '../../support/fake_envelope_codec.dart';
import '../../support/in_memory_chain_submission_store.dart';
import '../../support/in_memory_hire_lifecycle_store.dart';
import '../../support/in_memory_hire_receipt_store.dart';
import '../../support/in_memory_hire_run_store.dart';

const _alice = 'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H';
const _agentA = 'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY';
const _agentB = 'GBRPYHIL2CI3FNQ4BXLFMNDLFJUNPU2HY3ZMFSHONUCEOASW7QC7OX2H';
const _childJobId = 4;
const _output = 'B found three sources.';
final _otherAgent = StellarAddress.parse(
  'GBRPYHIL2CI3FNQ4BXLFMNDLFJUNPU2HY3ZMFSHONUCEOASW7QC7OX2H',
);
final _escrow = StellarAddress.parse(
  'CBRD7A7MXINM7LREKCL3RMKRQ5UMLGKNHAEYY4JT7MVBBB7R5QV4TPE2',
);
final _at = DateTime.utc(2026, 11, 19, 12);

final class _Accounts implements ChainAccounts {
  Object? simulationFailure;
  var sequence = 8;

  @override
  Future<int> sequenceOf(StellarAddress account) async => sequence;

  @override
  Future<SimulationData> simulate(EnvelopeSpec spec) async {
    final failure = simulationFailure;
    if (failure != null) throw failure;
    return const SimulationData(transactionData: 'AAAA', minResourceFee: 50);
  }

  @override
  Future<SimulationData> simulateRaw(EnvelopeSpec spec) => simulate(spec);

  @override
  Future<AccountAuthority?> authorityOf(StellarAddress account) async => null;
}

void main() {
  late InMemoryHireLifecycleStore hires;
  late InMemoryHireReceiptStore receipts;
  late InMemoryHireRunStore runs;
  late InMemoryChainSubmissionStore submissions;
  late _Accounts accounts;
  late FakeEnvelopeCodec codec;
  late List<StellarAddress> signers;
  late List<String> sent;
  late SendTransactionStatus answer;
  late Object? signFailure;
  late int childHireId;
  var serial = 0;

  EscrowChildResultSource source() => EscrowChildResultSource(
    receipts: receipts,
    hires: hires,
    runs: runs,
    submissions: submissions,
    accounts: accounts,
    codec: codec,
    sign: (prepared, signer) async {
      final failure = signFailure;
      if (failure != null) throw failure;
      signers.add(signer);
      return FakeEnvelopeCodec.sign(prepared.envelopeXdr);
    },
    send: (envelope, hash) async {
      sent.add(envelope);
      return SendTransactionResult(status: answer, hash: hash);
    },
    escrow: _escrow,
    inclusionFee: 100,
    validitySeconds: 300,
    now: () => _at,
  );

  void run(HireRunState state, {String? result}) => runs.overwrite(
    HireRun(hireId: childHireId, state: state, queuedAt: _at, result: result),
  );

  /// A record of [purpose] on the child hire, in [state].
  Future<StoredSubmission> record(
    SubmissionPurpose purpose, {
    SubmissionState state = SubmissionState.confirmed,
    String errorCode = SubmissionOutcomeCode.transactionFailed,
    int? hireId,
    String? envelope,
  }) async {
    serial++;
    final row = await submissions.insertSubmitted(
      purpose: purpose,
      transactionHash: serial.toRadixString(16).padLeft(64, '0'),
      signedEnvelopeXdr: envelope ?? 'envelope-$serial',
      validUntil: _at,
      preparationId: purpose.isServerSigned ? null : 'prep-$serial',
      hireId: hireId ?? childHireId,
    );
    switch (state) {
      case SubmissionState.confirmed:
        await submissions.markConfirmed(row.id);
      case SubmissionState.failed:
        await submissions.markFailed(row.id, errorCode);
      case SubmissionState.submitted:
        break;
    }
    return row;
  }

  List<StoredSubmission> verdicts() => [
    for (final row in submissions.all)
      if (row.purpose == SubmissionPurpose.childComplete ||
          row.purpose == SubmissionPurpose.childReject)
        row,
  ];

  /// The function and arguments of the single verdict envelope built.
  ({String function, List<int> invoke}) builtCall() {
    final spec = codec.built.single.spec;
    return (
      function: spec.function,
      invoke: encodeInvokeHostFunction(
        contract: spec.contract,
        function: spec.function,
        args: spec.args,
      ),
    );
  }

  List<int> expectedCall(String function, String code) =>
      encodeInvokeHostFunction(
        contract: _escrow,
        function: function,
        args: [
          ScArg.address(StellarAddress.parse(_agentA)),
          ScArg.u64(_childJobId),
          ScArg.bytes32(childReasonHash(code)),
        ],
      );

  setUp(() async {
    hires = InMemoryHireLifecycleStore();
    receipts = InMemoryHireReceiptStore(now: () => _at);
    runs = InMemoryHireRunStore();
    submissions = InMemoryChainSubmissionStore(now: () => _at);
    accounts = _Accounts();
    codec = FakeEnvelopeCodec();
    signers = [];
    sent = [];
    answer = SendTransactionStatus.pending;
    signFailure = null;
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
    final child = await hires.insertHire(
      NewHire(
        consumer: _agentA,
        agentId: 9,
        price: 500000,
        manifestVersion: 3,
        expiredAt: 1791747914,
        requestId: 'child:${parent.id}:call-1',
        input: 'research',
        parentHireId: parent.id,
      ),
    );
    childHireId = child.id;
    await hires.bindJob(childHireId, _childJobId, expiredAt: 1791747914);
    await receipts.insert(
      NewReceiptLine(
        parentHireId: parent.id,
        childHireId: childHireId,
        providerAgentId: 9,
        providerWallet: _agentB,
        budget: 500000,
        relatedParty: false,
        justification: 'cheapest research agent',
        createTransaction: 'ab' * 32,
      ),
    );
    await receipts.markOpened(
      childHireId,
      childJobId: _childJobId,
      createTransaction: 'ab' * 32,
      state: 'funded',
    );
    run(HireRunState.running);
  });

  group('before the child job is proven open', () {
    test('a not_opened line fails the child as child_not_opened', () async {
      final fresh = InMemoryHireReceiptStore();
      receipts = fresh;
      await fresh.insert(
        NewReceiptLine(
          parentHireId: 1,
          childHireId: childHireId,
          providerAgentId: 9,
          providerWallet: _agentB,
          budget: 500000,
          relatedParty: false,
          justification: 'j',
        ),
      );
      await fresh.markNotOpened(childHireId);

      final result = await source().resultOf(childHireId);

      expect(
        result,
        isA<ChildFailed>().having((r) => r.code, 'code', 'child_not_opened'),
      );
      expect(codec.built, isEmpty);
    });

    test('a child without a receipt line fails as child_not_opened', () async {
      expect(
        await source().resultOf(childHireId + 100),
        isA<ChildFailed>().having((r) => r.code, 'code', 'child_not_opened'),
      );
    });

    test('a pending or unverified line keeps waiting', () async {
      for (final unverified in [false, true]) {
        final fresh = InMemoryHireReceiptStore();
        receipts = fresh;
        await fresh.insert(
          NewReceiptLine(
            parentHireId: 1,
            childHireId: childHireId,
            providerAgentId: 9,
            providerWallet: _agentB,
            budget: 500000,
            relatedParty: false,
            justification: 'j',
          ),
        );
        if (unverified) await fresh.markUnverified(childHireId);
        run(HireRunState.failed);

        expect(await source().resultOf(childHireId), isNull);
      }
      expect(codec.built, isEmpty);
      expect(verdicts(), isEmpty);
    });
  });

  group('while the child works', () {
    test('a running child waits and signs nothing', () async {
      for (final state in [
        HireRunState.queued,
        HireRunState.running,
        HireRunState.awaitingChild,
        HireRunState.succeeded,
      ]) {
        run(state, result: state == HireRunState.succeeded ? _output : null);
        expect(await source().resultOf(childHireId), isNull, reason: '$state');
      }
      expect(codec.built, isEmpty);
      expect(verdicts(), isEmpty);
    });

    test('a child whose submit is in flight waits', () async {
      run(HireRunState.succeeded, result: _output);
      await record(SubmissionPurpose.submit, state: SubmissionState.submitted);

      expect(await source().resultOf(childHireId), isNull);
      expect(codec.built, isEmpty);
    });
  });

  group('the verdict', () {
    test('a failed run is rejected from Funded, signed by A', () async {
      run(HireRunState.failed);

      expect(await source().resultOf(childHireId), isNull);

      final call = builtCall();
      expect(call.function, 'reject');
      expect(call.invoke, expectedCall('reject', 'child_run_failed'));
      expect(codec.built.single.spec.source.value, _agentA);
      expect(signers.map((s) => s.value), [_agentA]);
      final verdict = verdicts().single;
      expect(verdict.purpose, SubmissionPurpose.childReject);
      expect(verdict.hireId, childHireId);
      expect(verdict.preparationId, isNull);
      expect(verdict.sendAttempts, 1);
      expect(sent, [verdict.signedEnvelopeXdr]);
      expect(
        (await receipts.findByChildHire(childHireId))!.deliverableHash,
        isNull,
      );
    });

    test('a submitted child with a good output is completed and its '
        'deliverable hash recorded', () async {
      run(HireRunState.succeeded, result: _output);
      await record(SubmissionPurpose.submit);

      expect(await source().resultOf(childHireId), isNull);

      expect(builtCall().invoke, expectedCall('complete', 'child_complete'));
      expect(verdicts().single.purpose, SubmissionPurpose.childComplete);
      expect(
        (await receipts.findByChildHire(childHireId))!.deliverableHash,
        deliverableHashHex(_output),
      );
    });

    test('a submitted child with a blank output is rejected', () async {
      run(HireRunState.succeeded, result: '   ');
      await record(SubmissionPurpose.submit);

      await source().resultOf(childHireId);

      expect(builtCall().invoke, expectedCall('reject', 'child_output_empty'));
    });

    test(
      'a submitted child at the platform output ceiling is completed',
      () async {
        // 16000 runes is the most any manifest allows (`outputMaxChars`), so
        // B's longest valid result is paid, never rejected for its length.
        run(HireRunState.succeeded, result: 'x' * 16000);
        await record(SubmissionPurpose.submit);

        await source().resultOf(childHireId);

        expect(builtCall().invoke, expectedCall('complete', 'child_complete'));
      },
    );

    test('a child whose submit can never land is rejected from Funded as '
        'child_not_submitted', () async {
      run(HireRunState.succeeded, result: _output);
      await record(
        SubmissionPurpose.submit,
        state: SubmissionState.failed,
        errorCode: SubmissionOutcomeCode.submitSimulationRejected,
      );

      await source().resultOf(childHireId);

      expect(builtCall().invoke, expectedCall('reject', 'child_not_submitted'));
    });

    test('is signed and sent once: a later pass waits for it', () async {
      run(HireRunState.succeeded, result: _output);
      await record(SubmissionPurpose.submit);

      expect(await source().resultOf(childHireId), isNull);
      expect(await source().resultOf(childHireId), isNull);
      answer = SendTransactionStatus.tryAgainLater;
      expect(await source().resultOf(childHireId), isNull);

      expect(codec.built, hasLength(1));
      expect(signers, hasLength(1));
      expect(sent, hasLength(1));
      expect(verdicts(), hasLength(1));
    });

    test('waits while another call A signed is in flight', () async {
      run(HireRunState.failed);
      await record(
        SubmissionPurpose.submit,
        state: SubmissionState.submitted,
        hireId: childHireId + 50,
        envelope: FakeEnvelopeCodec.signedBy(StellarAddress.parse(_agentA)),
      );

      expect(await source().resultOf(childHireId), isNull);
      expect(codec.built, isEmpty);
    });

    test(
      'an unreadable agent-signed envelope in flight holds the verdict',
      () async {
        run(HireRunState.failed);
        await record(
          SubmissionPurpose.submit,
          state: SubmissionState.submitted,
          hireId: childHireId + 50,
          envelope: 'AAAA',
        );

        expect(await source().resultOf(childHireId), isNull);
        expect(codec.built, isEmpty);
      },
    );

    test("another wallet's call in flight does not hold the verdict", () async {
      run(HireRunState.failed);
      await record(
        SubmissionPurpose.submit,
        state: SubmissionState.submitted,
        hireId: childHireId + 50,
        envelope: FakeEnvelopeCodec.signedBy(_otherAgent),
      );

      expect(await source().resultOf(childHireId), isNull);
      expect(codec.built, hasLength(1));
      expect(signers.map((s) => s.value), [_agentA]);
    });

    test('a node refusal fails the verdict; a later pass signs again until '
        'the attempts are used up', () async {
      run(HireRunState.failed);
      answer = SendTransactionStatus.error;

      for (var i = 0; i < maxEscrowCallAttempts + 1; i++) {
        accounts.sequence++;
        expect(await source().resultOf(childHireId), isNull);
      }

      expect(verdicts(), hasLength(maxEscrowCallAttempts));
      expect(
        verdicts().every((v) => v.state == SubmissionState.failed),
        isTrue,
      );
      expect(
        verdicts().last.errorCode,
        SubmissionOutcomeCode.escrowCallFailed,
      );
    });

    test('a simulation rejection is stored as one failed attempt', () async {
      run(HireRunState.failed);
      accounts.simulationFailure = const LedgerContractError(
        104,
        'Error(Contract, #104)',
      );

      expect(await source().resultOf(childHireId), isNull);

      final failed = verdicts().single;
      expect(failed.state, SubmissionState.failed);
      expect(failed.errorCode, SubmissionOutcomeCode.simulationFailed);
      expect(failed.purpose, SubmissionPurpose.childReject);
      expect(sent, isEmpty);
    });

    test('custody that cannot sign stores nothing', () async {
      run(HireRunState.failed);
      signFailure = const AgentWalletCustodyUnavailable('locked');

      expect(await source().resultOf(childHireId), isNull);
      expect(verdicts(), isEmpty);
      expect(sent, isEmpty);
    });
  });

  group('after the child settles', () {
    test('a confirmed complete delivers the stored output', () async {
      run(HireRunState.succeeded, result: _output);
      await record(SubmissionPurpose.submit);
      await record(SubmissionPurpose.childComplete);

      final result = await source().resultOf(childHireId);

      expect(
        result,
        isA<ChildDelivered>().having((r) => r.output, 'output', _output),
      );
      expect(codec.built, isEmpty);
    });

    test('a confirmed reject fails with its reason code', () async {
      run(HireRunState.failed);
      await record(SubmissionPurpose.childReject);
      expect(
        await source().resultOf(childHireId),
        isA<ChildFailed>().having((r) => r.code, 'code', 'child_run_failed'),
      );

      run(HireRunState.succeeded, result: '');
      await record(SubmissionPurpose.submit);
      expect(
        await source().resultOf(childHireId),
        isA<ChildFailed>().having((r) => r.code, 'code', 'child_output_empty'),
      );
      expect(codec.built, isEmpty);
    });

    test('a release delivers the output; a refund fails as '
        'child_expired', () async {
      run(HireRunState.succeeded, result: _output);
      await record(SubmissionPurpose.submit);
      await record(SubmissionPurpose.release);
      expect(
        await source().resultOf(childHireId),
        isA<ChildDelivered>().having((r) => r.output, 'output', _output),
      );

      final other = InMemoryChainSubmissionStore(now: () => _at);
      submissions = other;
      await record(SubmissionPurpose.claimRefund);
      expect(
        await source().resultOf(childHireId),
        isA<ChildFailed>().having((r) => r.code, 'code', 'child_expired'),
      );
    });
  });
}
