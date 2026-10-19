import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/chain/chain_log.dart';
import 'package:puls3_server/src/chain/escrow_deadline.dart';
import 'package:puls3_server/src/chain/escrow_server_submit.dart';
import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:puls3_server/src/hire/chain_accounts.dart';
import 'package:puls3_server/src/hire/hire_lifecycle_store.dart';
import 'package:puls3_server/src/ledger/envelope_codec.dart';
import 'package:puls3_server/src/ledger/escrow_job.dart';
import 'package:puls3_server/src/ledger/ledger_errors.dart';
import 'package:puls3_server/src/ledger/soroban_rpc_client.dart';
import 'package:puls3_server/src/ledger/xdr_invoke_encoder.dart';
import 'package:stellar_dart/stellar_dart.dart' as stellar;
import 'package:test/test.dart';

import '../../support/fake_envelope_codec.dart';
import '../../support/in_memory_chain_submission_store.dart';
import '../../support/in_memory_hire_lifecycle_store.dart';

final _source = StellarAddress.parse(
  'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H',
);
final _escrow = StellarAddress.parse(
  'CBRD7A7MXINM7LREKCL3RMKRQ5UMLGKNHAEYY4JT7MVBBB7R5QV4TPE2',
);
final _provider = StellarAddress.parse(
  'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY',
);

const _deadline = 1_700_000_100;
const _expiredAt = 1_700_000_500;
final _now = DateTime.utc(2026, 10, 13, 12);

final class _Accounts implements ChainAccounts {
  Object? failure;
  var sequence = 8;
  final specs = <EnvelopeSpec>[];

  @override
  Future<int> sequenceOf(StellarAddress account) async {
    final failure = this.failure;
    if (failure != null) throw failure;
    return sequence;
  }

  @override
  Future<SimulationData> simulate(EnvelopeSpec spec) async {
    specs.add(spec);
    final failure = this.failure;
    if (failure != null) throw failure;
    return const SimulationData(transactionData: 'AAAA', minResourceFee: 50);
  }

  @override
  Future<AccountAuthority?> authorityOf(StellarAddress account) async => null;
}

final class _Jobs implements EscrowJobReader, EscrowExpiryReader {
  EscrowJob? job;
  var expired = false;

  @override
  Future<EscrowJob?> escrowJob(int jobId) async => job;

  @override
  Future<bool> isExpired(int jobId) async => expired;
}

/// Records which jobs a pass read; every job is still open.
final class _RecordingJobs implements EscrowJobReader, EscrowExpiryReader {
  _RecordingJobs(this.read);

  final List<int> read;

  @override
  Future<EscrowJob?> escrowJob(int jobId) async {
    read.add(jobId);
    return _job(EscrowJobState.open);
  }

  @override
  Future<bool> isExpired(int jobId) async => false;
}

EscrowJob _job(EscrowJobState state) => EscrowJob(
  client: _source,
  provider: _provider,
  evaluator: _source,
  agentId: AgentId(7),
  token: _provider,
  budget: BigInt.from(5000000),
  feeBps: 0,
  expiredAt: _expiredAt,
  description: 'triage',
  state: state,
  submittedAt: state == EscrowJobState.submitted ? _deadline - 60 : 0,
  approvalDeadline: state == EscrowJobState.submitted ? _deadline : 0,
  deliverable: null,
);

void main() {
  late InMemoryChainSubmissionStore store;
  late _Accounts accounts;
  late FakeEnvelopeCodec codec;
  late List<String> sent;
  late List<String> sentHashes;
  late SendTransactionResult answer;
  late Object? sendFailure;

  RelayEscrowCallSender sender() => RelayEscrowCallSender(
    submissions: store,
    accounts: accounts,
    codec: codec,
    sign: (prepared) => FakeEnvelopeCodec.sign(prepared.envelopeXdr),
    send: (envelope, hash) {
      sent.add(envelope);
      sentHashes.add(hash);
      final failure = sendFailure;
      if (failure != null) throw failure;
      return Future.value(answer);
    },
    source: _source,
    escrow: _escrow,
    inclusionFee: 100,
    validitySeconds: 300,
    now: () => _now,
    log: ignoreChainLog,
  );

  setUp(() {
    store = InMemoryChainSubmissionStore();
    accounts = _Accounts();
    codec = FakeEnvelopeCodec();
    sent = [];
    sentHashes = [];
    sendFailure = null;
    answer = SendTransactionResult(
      status: SendTransactionStatus.pending,
      hash: 'ab' * 32,
    );
  });

  test('release is stored before it is sent, with only the job id', () async {
    await sender().send(hireId: 4, jobId: 3, call: EscrowServerCall.release);

    final spec = codec.built.single.spec;
    final invoke = encodeInvokeHostFunction(
      contract: _escrow,
      function: 'release',
      args: [ScArg.u64(3)],
    );
    expect(spec.source, _source);
    expect(spec.accountSequence, 8);
    expect(spec.contract, _escrow);
    expect(
      spec.validUntil,
      _now.add(const Duration(seconds: 300)).millisecondsSinceEpoch ~/ 1000,
    );
    expect(
      encodeInvokeHostFunction(
        contract: spec.contract,
        function: spec.function,
        args: spec.args,
      ),
      invoke,
    );

    final record = store.all.single;
    expect(record.purpose, SubmissionPurpose.release);
    expect(record.preparationId, isNull);
    expect(record.hireId, 4);
    expect(record.state, SubmissionState.submitted);
    expect(record.sendAttempts, 1);
    expect(record.transactionHash, hasLength(64));
    expect(sent, [record.signedEnvelopeXdr]);
    expect(sentHashes, [record.transactionHash]);
  });

  test('claim_refund invokes claim_refund', () async {
    await sender().send(
      hireId: 4,
      jobId: 3,
      call: EscrowServerCall.claimRefund,
    );

    expect(codec.built.single.spec.function, 'claim_refund');
    expect(store.all.single.purpose, SubmissionPurpose.claimRefund);
  });

  test('a hire with a submission in flight is not sent again', () async {
    await sender().send(hireId: 4, jobId: 3, call: EscrowServerCall.release);

    await sender().send(hireId: 4, jobId: 3, call: EscrowServerCall.release);

    expect(store.all, hasLength(1));
    expect(sent, hasLength(1));
    expect(codec.built, hasLength(1));
  });

  test('one relay call is in flight at a time, across hires', () async {
    // The relay sequence comes from the ledger: a second envelope built
    // before the first is applied would reuse it (txBadSeq).
    await sender().send(hireId: 4, jobId: 3, call: EscrowServerCall.release);
    await sender().send(
      hireId: 5,
      jobId: 9,
      call: EscrowServerCall.claimRefund,
    );

    expect(codec.built, hasLength(1));
    expect(sent, hasLength(1));

    await store.markConfirmed(store.all.single.id);
    await sender().send(
      hireId: 5,
      jobId: 9,
      call: EscrowServerCall.claimRefund,
    );

    expect(codec.built, hasLength(2));
    expect(store.all.last.hireId, 5);
    expect(store.all.last.purpose, SubmissionPurpose.claimRefund);
  });

  test('a refused relay call does not hold back the next hire', () async {
    answer = const SendTransactionResult(
      status: SendTransactionStatus.error,
      hash: 'ab',
      errorResultXdr: 'AAAA',
    );
    await sender().send(hireId: 4, jobId: 3, call: EscrowServerCall.release);
    await sender().send(hireId: 5, jobId: 9, call: EscrowServerCall.release);

    expect(codec.built, hasLength(2));
  });

  test('a node ERROR fails the record as SubmissionRejected', () async {
    answer = const SendTransactionResult(
      status: SendTransactionStatus.error,
      hash: 'ab',
      errorResultXdr: 'AAAA',
    );

    await sender().send(hireId: 4, jobId: 3, call: EscrowServerCall.release);

    final record = store.all.single;
    expect(record.state, SubmissionState.failed);
    expect(record.errorCode, SubmissionOutcomeCode.submissionRejected);
    expect(record.sendAttempts, 0);
  });

  test('the third refused release is labelled EscrowCallFailed', () async {
    answer = const SendTransactionResult(
      status: SendTransactionStatus.error,
      hash: 'ab',
      errorResultXdr: 'AAAA',
    );

    for (var i = 0; i < maxEscrowCallAttempts; i++) {
      accounts.sequence = 8 + i;
      await sender().send(hireId: 4, jobId: 3, call: EscrowServerCall.release);
    }

    expect(store.all.map((row) => row.errorCode), [
      SubmissionOutcomeCode.submissionRejected,
      SubmissionOutcomeCode.submissionRejected,
      SubmissionOutcomeCode.escrowCallFailed,
    ]);
  });

  test('a third rejected claim_refund request is EscrowCallFailed, and '
      'a failed fund of the hire does not count', () async {
    final fund = await store.insertSubmitted(
      purpose: SubmissionPurpose.fund,
      transactionHash: 'f' * 64,
      signedEnvelopeXdr: 'fund',
      validUntil: _now,
      preparationId: 'prep-fund',
      hireId: 4,
    );
    await store.markFailed(fund.id, SubmissionOutcomeCode.transactionFailed);
    sendFailure = const RpcRequestRejected(-32600, 'invalid', 'no');

    for (var i = 0; i < maxEscrowCallAttempts; i++) {
      accounts.sequence = 8 + i;
      await sender().send(
        hireId: 4,
        jobId: 3,
        call: EscrowServerCall.claimRefund,
      );
    }

    final refunds = store.all.where(
      (row) => row.purpose == SubmissionPurpose.claimRefund,
    );
    expect(refunds.map((row) => row.errorCode), [
      SubmissionOutcomeCode.submissionRejected,
      SubmissionOutcomeCode.submissionRejected,
      SubmissionOutcomeCode.escrowCallFailed,
    ]);
    expect(fund.id, store.all.first.id);
    expect(
      store.all.first.errorCode,
      SubmissionOutcomeCode.transactionFailed,
    );
  });

  test('a rejected request fails the record and an unreachable node '
      'leaves it submitted', () async {
    sendFailure = const RpcRequestRejected(-32600, 'invalid', 'no');
    await sender().send(hireId: 4, jobId: 3, call: EscrowServerCall.release);
    expect(store.all.single.state, SubmissionState.failed);

    store = InMemoryChainSubmissionStore();
    sendFailure = const LedgerUnavailable('down');
    await sender().send(hireId: 4, jobId: 3, call: EscrowServerCall.release);
    expect(store.all.single.state, SubmissionState.submitted);
    expect(store.all.single.sendAttempts, 0);
  });

  test('an unreadable chain stores nothing', () async {
    accounts.failure = chainUnavailable();

    await sender().send(hireId: 4, jobId: 3, call: EscrowServerCall.release);

    expect(store.all, isEmpty);
    expect(sent, isEmpty);
  });

  test('three failed attempts stop a fourth envelope', () async {
    for (var i = 0; i < maxEscrowCallAttempts; i++) {
      final row = await store.insertSubmitted(
        purpose: SubmissionPurpose.release,
        transactionHash: i.toRadixString(16).padLeft(64, '0'),
        signedEnvelopeXdr: 'envelope-$i',
        validUntil: _now,
        hireId: 4,
      );
      await store.markFailed(row.id, SubmissionOutcomeCode.submissionRejected);
    }

    await sender().send(hireId: 4, jobId: 3, call: EscrowServerCall.release);

    expect(store.all, hasLength(maxEscrowCallAttempts));
    expect(sent, isEmpty);
  });

  test('the deadline pass sends release only once the ledger is due', () async {
    final hires = InMemoryHireLifecycleStore();
    final hire = await hires.insertHire(
      NewHire(
        consumer: _source.value,
        agentId: 7,
        price: 5000000,
        manifestVersion: 1,
        expiredAt: _expiredAt,
        requestId: 'request-1',
        input: 'triage',
      ),
    );
    await hires.bindJob(hire.id, 3, expiredAt: _expiredAt);
    final jobs = _Jobs()..job = _job(EscrowJobState.submitted);
    var ledgerTime = _deadline - 1;

    Future<void> pass() => EscrowDeadlineRunner(
      jobs: jobs,
      expiry: jobs,
      sender: sender(),
      hires: hires,
      ledgerTime: () async => ledgerTime,
      log: ignoreChainLog,
    ).pass();

    await pass();
    expect(store.all, isEmpty);

    ledgerTime = _deadline;
    await pass();
    expect(store.all.single.purpose, SubmissionPurpose.release);
    expect(sent, hasLength(1));
  });

  test(
    'the deadline pass pages through every hire, then starts over',
    () async {
      final hires = InMemoryHireLifecycleStore();
      final ids = <int>[];
      for (var i = 0; i < 3; i++) {
        final hire = await hires.insertHire(
          NewHire(
            consumer: _source.value,
            agentId: 7,
            price: 5000000,
            manifestVersion: 1,
            expiredAt: _expiredAt,
            requestId: 'request-$i',
            input: 'triage',
          ),
        );
        await hires.bindJob(hire.id, 10 + i, expiredAt: _expiredAt);
        ids.add(hire.id);
      }
      final read = <int>[];
      final jobs = _RecordingJobs(read);

      Future<int> pass(int afterId) => EscrowDeadlineRunner(
        jobs: jobs,
        expiry: jobs,
        sender: sender(),
        hires: hires,
        ledgerTime: () async => _deadline,
        log: ignoreChainLog,
        afterId: afterId,
        limit: 2,
      ).pass();

      final next = await pass(0);
      expect(next, ids[1]);
      expect(await pass(next), 0, reason: 'the last page starts over');
      expect(read, [10, 11, 12]);
    },
  );

  test('a blank relay password stays off and a bad one is not echoed', () {
    expect(relaySigningAccount(null), isNull);
    expect(relaySigningAccount('   '), isNull);

    const raw = 'not-a-stellar-secret';
    expect(
      () => relaySigningAccount(raw),
      throwsA(
        isA<ArgumentError>().having(
          (error) => '$error',
          'message',
          isNot(contains(raw)),
        ),
      ),
    );
  });

  test('relaySigningAccount keeps the public address and hides the secret', () {
    final key = stellar.StellarPrivateKey.fromBytes(Uint8List(32)..[0] = 7);
    final account = relaySigningAccount(key.toBase32())!;

    expect(account.address.value, key.toPublicKey().toAddress().address);
    expect(account.toString(), isNot(contains(account.secret)));
  });
}
