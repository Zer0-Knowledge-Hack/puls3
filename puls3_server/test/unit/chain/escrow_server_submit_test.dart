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
  final specs = <EnvelopeSpec>[];

  @override
  Future<int> sequenceOf(StellarAddress account) async {
    final failure = this.failure;
    if (failure != null) throw failure;
    return 8;
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
  late SendTransactionResult answer;
  late Object? sendFailure;

  RelayEscrowCallSender sender() => RelayEscrowCallSender(
    submissions: store,
    accounts: accounts,
    codec: codec,
    sign: (prepared) => FakeEnvelopeCodec.sign(prepared.envelopeXdr),
    send: (envelope) {
      sent.add(envelope);
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
