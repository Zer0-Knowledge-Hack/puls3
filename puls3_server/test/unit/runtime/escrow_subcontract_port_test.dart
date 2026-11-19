import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;
import 'package:puls3_server/src/agent/agent_wallet_custody.dart';
import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:puls3_server/src/hire/hire_lifecycle_store.dart';
import 'package:puls3_server/src/hire/hire_receipt_store.dart';
import 'package:puls3_server/src/hire/hire_relay_config.dart';
import 'package:puls3_server/src/ledger/escrow_job.dart';
import 'package:puls3_server/src/ledger/ledger_errors.dart';
import 'package:puls3_server/src/ledger/soroban_rpc_client.dart';
import 'package:puls3_server/src/ledger/stellar_config.dart';
import 'package:puls3_server/src/runtime/escrow_subcontract_port.dart';
import 'package:puls3_server/src/runtime/subcontract_port.dart';
import 'package:test/test.dart';

import '../../support/fake_envelope_codec.dart';
import '../../support/in_memory_hire_receipt_store.dart';
import '../../support/relay_rig.dart';

const _approvalWindow = 86400;
const _jobDuration = 259200;
const _reserve = 2000000;
const _budget = 500000;
const _childRegistryId = 9;

final _agentA = StellarAddress.parse(agentWallet);
final _agentB = StellarAddress.parse(stranger);

Map<String, String> _environment() => {
  ...relayEnvironment(),
  HireRelayConfig.jobDurationKey: '$_jobDuration',
};

ChildRequest _request(int parentHireId, {String? callId = 'call-1'}) =>
    ChildRequest(
      parentHireId: parentHireId,
      agentRegistryId: _childRegistryId,
      agentId: 'agt-009',
      priceStroops: _budget,
      task: 'Research the topic',
      justification: 'Best rated research agent',
      isRelatedParty: false,
      relatedPartyJustification: RelatedPartyJustification.independent,
      ranking: const [],
      toolCallId: callId,
    );

void main() {
  late RelayRig rig;
  late InMemoryHireReceiptStore receipts;
  late int nowSeconds;
  final signers = <StellarAddress>[];
  final sent = <String>[];
  var answer = SendTransactionStatus.pending;
  Object? sendFailure;
  Object? signFailure;
  Object? approvalFailure;
  var approvalReads = 0;
  ChildAgent? childAgent;

  EscrowSubcontractPort port() => EscrowSubcontractPort(
    hires: rig.hires,
    receipts: receipts,
    submissions: rig.submissions,
    jobs: rig.ledger,
    relay: rig.service,
    config: HireRelayConfig(_environment()),
    childAgent: (registryId) async =>
        registryId == _childRegistryId ? childAgent : null,
    approvalWindow: () async {
      approvalReads++;
      final failure = approvalFailure;
      if (failure != null) throw failure;
      return _approvalWindow;
    },
    sign: (prepared, signer) async {
      final failure = signFailure;
      if (failure != null) throw failure;
      signers.add(signer);
      return FakeEnvelopeCodec.sign(prepared.envelopeXdr);
    },
    send: (envelope, hash) async {
      sent.add(envelope);
      final failure = sendFailure;
      if (failure != null) throw failure;
      return SendTransactionResult(status: answer, hash: hash);
    },
    now: () => rig.clock,
  );

  /// Agent A's parent job on the chain.
  EscrowJob chainJob({
    int expiresIn = _jobDuration,
    EscrowJobState state = EscrowJobState.funded,
    int reserve = _reserve,
  }) => EscrowJob(
    client: rig.wallet,
    provider: _agentA,
    evaluator: rig.wallet,
    agentId: AgentId(7),
    token: StellarConfig.testnet.usdcSac,
    budget: BigInt.from(price),
    feeBps: platformFeeBps,
    expiredAt: nowSeconds + expiresIn,
    description: '',
    state: state,
    submittedAt: 0,
    approvalDeadline: 0,
    deliverable: null,
    reserve: BigInt.from(reserve),
    reserveFunded: BigInt.from(_reserve),
  );

  /// A funded parent hire of agent A whose chain job expires at
  /// [expiresIn] seconds from now and holds [reserve].
  Future<HireRow> parent({
    int expiresIn = _jobDuration,
    EscrowJobState state = EscrowJobState.funded,
    int reserve = _reserve,
    HireStatus status = HireStatus.funded,
  }) async {
    final hire = await rig.hire(status: status, subcontractReserve: _reserve);
    rig.ledger.jobs[hire.jobId!] = chainJob(
      expiresIn: expiresIn,
      state: state,
      reserve: reserve,
    );
    return hire;
  }

  Future<void> expectRefused(Future<int> call, String code) => expectLater(
    call,
    throwsA(isA<SubcontractRefused>().having((e) => e.code, 'code', code)),
  );

  void expectNothingOpened() {
    expect(
      rig.hires.all.where((h) => h.parentHireId != null),
      isEmpty,
      reason: 'no child hire is stored',
    );
    expect(receipts.all, isEmpty, reason: 'no receipt line is stored');
    expect(signers, isEmpty, reason: 'nothing is signed');
    expect(sent, isEmpty, reason: 'nothing is sent');
  }

  setUp(() {
    rig = RelayRig(environment: _environment());
    receipts = InMemoryHireReceiptStore(now: () => rig.clock);
    nowSeconds = rig.clock.millisecondsSinceEpoch ~/ 1000;
    signers.clear();
    sent.clear();
    answer = SendTransactionStatus.pending;
    sendFailure = null;
    signFailure = null;
    approvalFailure = null;
    approvalReads = 0;
    childAgent = ChildAgent(
      wallet: _agentB,
      manifestVersion: 3,
      priceStroops: _budget,
    );
  });

  group('requestChild', () {
    test('opens the child hire, its receipt line and an A-signed '
        'create_child_job', () async {
      final hire = await parent();

      final childId = await port().requestChild(_request(hire.id));

      final child = (await rig.hires.findHire(childId))!;
      expect(child.parentHireId, hire.id);
      expect(child.consumer, agentWallet, reason: 'A pays from the reserve');
      expect(child.agentId, _childRegistryId);
      expect(child.price, _budget);
      expect(child.input, 'Research the topic');
      expect(child.manifestVersion, 3);
      expect(child.subcontractReserve, 0, reason: 'depth 1 (D5)');
      expect(child.requestId, 'child:${hire.id}:call-1');
      // min(now + job duration, parent expiry - window - 600).
      final expiry = nowSeconds + _jobDuration - _approvalWindow - 600;
      expect(child.expiredAt, expiry);

      final line = receipts.all.single;
      expect(line.parentHireId, hire.id);
      expect(line.childHireId, childId);
      expect(line.providerAgentId, _childRegistryId);
      expect(line.providerWallet, stranger);
      expect(line.budget, _budget);
      expect(line.state, ReceiptLineState.pending);
      expect(line.relatedParty, isFalse);
      expect(line.justification, 'Best rated research agent');

      final submission = (await rig.submissions.listByHire(childId)).single;
      expect(submission.purpose, SubmissionPurpose.createChildJob);
      expect(submission.state, SubmissionState.submitted);
      expect(submission.preparationId, isNull, reason: 'server-signed');
      expect(line.createTransaction, submission.transactionHash);
      expect(signers, [_agentA]);
      expect(sent, [submission.signedEnvelopeXdr]);
      expect(submission.sendAttempts, 1);

      final spec = rig.codec.built.single.spec;
      expect(spec.function, 'create_child_job');
      expect(spec.source, _agentA);
    });

    test('caps the child expiry at now plus the job duration', () async {
      final hire = await parent(expiresIn: _jobDuration * 3);

      final childId = await port().requestChild(_request(hire.id));

      expect(
        (await rig.hires.findHire(childId))!.expiredAt,
        nowSeconds + _jobDuration,
      );
    });

    test('a retry of the same call returns the same child and signs and '
        'sends nothing again', () async {
      final hire = await parent();
      final first = await port().requestChild(_request(hire.id));

      final again = await port().requestChild(_request(hire.id));

      expect(again, first);
      expect(signers, hasLength(1));
      expect(sent, hasLength(1));
      expect(receipts.all, hasLength(1));
      expect(await rig.submissions.listByHire(first), hasLength(1));
    });

    test('a retry returns the stored child before any chain read, even when '
        'the chain cannot be read', () async {
      final hire = await parent();
      final first = await port().requestChild(_request(hire.id));
      rig.ledger.jobError = const LedgerUnavailable('down');
      approvalFailure = const LedgerUnavailable('down');

      final again = await port().requestChild(_request(hire.id));

      expect(again, first);
      expect(signers, hasLength(1));
      expect(sent, hasLength(1));
      expect(approvalReads, 1, reason: 'only the first call read the window');
    });

    test('a retry returns the stored child after the parent left '
        'funded', () async {
      final hire = await parent();
      final first = await port().requestChild(_request(hire.id));
      rig.hires.statusOverride[hire.id] = HireStatus.submitted;
      rig.ledger.jobs[hire.jobId!] = chainJob(state: EscrowJobState.submitted);

      expect(await port().requestChild(_request(hire.id)), first);
      expect(signers, hasLength(1));
      expect(sent, hasLength(1));
    });

    test('a retry returns the stored child after the parent expired', () async {
      final hire = await parent();
      final first = await port().requestChild(_request(hire.id));
      rig.clock = rig.clock.add(const Duration(seconds: _jobDuration + 1));

      expect(await port().requestChild(_request(hire.id)), first);
      expect(signers, hasLength(1));
      expect(sent, hasLength(1));
    });

    test('a retry of a child that was not opened is refused before any chain '
        'read', () async {
      final hire = await parent();
      answer = SendTransactionStatus.error;
      await expectRefused(
        port().requestChild(_request(hire.id)),
        'chain_refused',
      );
      rig.ledger.jobError = const LedgerUnavailable('down');

      await expectRefused(
        port().requestChild(_request(hire.id)),
        'child_not_opened',
      );
      expect(sent, hasLength(1));
    });

    test('another call id opens another child', () async {
      final hire = await parent();
      final first = await port().requestChild(_request(hire.id));
      rig.accounts.sequence += 1;

      final second = await port().requestChild(
        _request(hire.id, callId: 'call-2'),
      );

      expect(second, isNot(first));
    });

    test('an identical envelope already stored refuses with chain_busy and '
        'sends nothing', () async {
      final hire = await parent();
      await port().requestChild(_request(hire.id));

      // Same sequence and arguments: the same transaction hash.
      await expectRefused(
        port().requestChild(_request(hire.id, callId: 'call-2')),
        'chain_busy',
      );
      expect(sent, hasLength(1));
      expect(receipts.all, hasLength(1), reason: 'the line rolled back');
    });

    test('refuses a parent that is not funded', () async {
      final hire = await parent(status: HireStatus.open);

      await expectRefused(
        port().requestChild(_request(hire.id)),
        'parent_not_funded',
      );
      expectNothingOpened();
    });

    test('refuses a parent whose chain job is no longer funded', () async {
      final hire = await parent(state: EscrowJobState.submitted);

      await expectRefused(
        port().requestChild(_request(hire.id)),
        'parent_not_funded',
      );
      expectNothingOpened();
    });

    test('refuses an expired parent', () async {
      final hire = await parent(expiresIn: 0);

      await expectRefused(
        port().requestChild(_request(hire.id)),
        'parent_not_funded',
      );
      expectNothingOpened();
    });

    test('refuses an unknown parent', () async {
      await expectRefused(
        port().requestChild(_request(4242)),
        'parent_not_funded',
      );
    });

    test('refuses parent_too_short before any write or chain call', () async {
      // The latest child expiry leaves less than one approval window plus
      // the run headroom for the child to submit.
      final hire = await parent(
        expiresIn: 2 * _approvalWindow + 600 + childRunHeadroom.inSeconds,
      );

      await expectRefused(
        port().requestChild(_request(hire.id)),
        'parent_too_short',
      );
      expectNothingOpened();
      expect(rig.accounts.simulated, isEmpty, reason: 'no simulation');
      expect(rig.accounts.sequenceReads, isEmpty);
    });

    test('accepts a parent just long enough', () async {
      final hire = await parent(
        expiresIn: 2 * _approvalWindow + 600 + childRunHeadroom.inSeconds + 1,
      );

      expect(await port().requestChild(_request(hire.id)), isPositive);
    });

    test('refuses a budget over the unspent chain reserve', () async {
      final hire = await parent(reserve: _budget - 1);

      await expectRefused(
        port().requestChild(_request(hire.id)),
        'reserve_exceeded',
      );
      expectNothingOpened();
    });

    test('counts pending children against the reserve', () async {
      final hire = await parent(reserve: _budget + _budget ~/ 2);
      await port().requestChild(_request(hire.id));

      await expectRefused(
        port().requestChild(_request(hire.id, callId: 'call-2')),
        'reserve_exceeded',
      );
    });

    test('refuses an agent that is gone or changed its price', () async {
      final hire = await parent();
      childAgent = null;
      await expectRefused(
        port().requestChild(_request(hire.id)),
        'agent_unavailable',
      );

      childAgent = ChildAgent(
        wallet: _agentB,
        manifestVersion: 3,
        priceStroops: _budget + 1,
      );
      await expectRefused(
        port().requestChild(_request(hire.id)),
        'price_changed',
      );
      expectNothingOpened();
    });

    test('maps a subcontract contract refusal to its code', () async {
      final hire = await parent();
      rig.accounts.simulationFailure = const LedgerContractError(
        127,
        'create_child_job failed with #127',
      );

      await expectRefused(
        port().requestChild(_request(hire.id)),
        'subcontract_cycle',
      );
      expectNothingOpened();
    });

    test('maps any other contract refusal to chain_refused', () async {
      final hire = await parent();
      rig.accounts.simulationFailure = const LedgerContractError(
        6,
        'create_child_job failed with #6',
      );

      await expectRefused(
        port().requestChild(_request(hire.id)),
        'chain_refused',
      );
      expectNothingOpened();
    });

    test('refuses with chain_unavailable when the chain cannot be '
        'read', () async {
      final hire = await parent();
      approvalFailure = const LedgerUnavailable('down');

      await expectRefused(
        port().requestChild(_request(hire.id)),
        'chain_unavailable',
      );
      expectNothingOpened();
    });

    test('refuses with custody_unavailable when A cannot sign', () async {
      final hire = await parent();
      signFailure = const AgentWalletCustodyUnavailable('no key');

      await expectRefused(
        port().requestChild(_request(hire.id)),
        'custody_unavailable',
      );
      expectNothingOpened();
    });

    test('a node refusal fails the submission, closes the line and refuses '
        'a retry of the call', () async {
      final hire = await parent();
      answer = SendTransactionStatus.error;

      await expectRefused(
        port().requestChild(_request(hire.id)),
        'chain_refused',
      );

      final child = rig.hires.all.singleWhere((h) => h.parentHireId != null);
      final submission = (await rig.submissions.listByHire(child.id)).single;
      expect(submission.state, SubmissionState.failed);
      expect(receipts.all.single.state, ReceiptLineState.notOpened);

      answer = SendTransactionStatus.pending;
      await expectRefused(
        port().requestChild(_request(hire.id)),
        'child_not_opened',
      );
      expect(sent, hasLength(1), reason: 'the retry sends nothing');
    });

    test('an unreachable node leaves the child submitted for the '
        'tracker', () async {
      final hire = await parent();
      sendFailure = const LedgerUnavailable('timeout');

      final childId = await port().requestChild(_request(hire.id));

      final submission = (await rig.submissions.listByHire(childId)).single;
      expect(submission.state, SubmissionState.submitted);
      expect(receipts.all.single.state, ReceiptLineState.pending);
    });

    test('a request without a tool call id is a programming error', () async {
      final hire = await parent();

      await expectLater(
        port().requestChild(_request(hire.id, callId: null)),
        throwsArgumentError,
      );
      expect(approvalReads, 0);
    });
  });
}
