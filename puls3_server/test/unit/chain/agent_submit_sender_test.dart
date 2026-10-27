import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/agent/agent_wallet_custody.dart';
import 'package:puls3_server/src/chain/agent_submit_sender.dart';
import 'package:puls3_server/src/chain/chain_log.dart';
import 'package:puls3_server/src/chain/escrow_deadline.dart';
import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:puls3_server/src/hire/chain_accounts.dart';
import 'package:puls3_server/src/ledger/envelope_codec.dart';
import 'package:puls3_server/src/ledger/soroban_rpc_client.dart';
import 'package:puls3_server/src/ledger/xdr_invoke_encoder.dart';
import 'package:test/test.dart';

import '../../support/fake_envelope_codec.dart';
import '../../support/in_memory_chain_submission_store.dart';

final _provider = StellarAddress.parse(
  'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H',
);
final _escrow = StellarAddress.parse(
  'CBRD7A7MXINM7LREKCL3RMKRQ5UMLGKNHAEYY4JT7MVBBB7R5QV4TPE2',
);
final _now = DateTime.utc(2026, 10, 13, 12);

const _result = 'Category: billing.';

DueSubmit _due({int hireId = 4, int jobId = 12}) => DueSubmit(
  hireId: hireId,
  jobId: jobId,
  provider: _provider,
  result: _result,
);

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

void main() {
  late InMemoryChainSubmissionStore store;
  late _Accounts accounts;
  late FakeEnvelopeCodec codec;
  late List<String> sent;
  late SendTransactionResult answer;
  late Object? sendFailure;
  late Object? signFailure;

  AgentSubmitSender sender() => AgentSubmitSender(
    submissions: store,
    accounts: accounts,
    codec: codec,
    sign: (prepared, provider) {
      final failure = signFailure;
      if (failure != null) throw failure;
      expect(provider, _provider);
      return Future.value(FakeEnvelopeCodec.sign(prepared.envelopeXdr));
    },
    send: (envelope, hash) {
      sent.add(envelope);
      final failure = sendFailure;
      if (failure != null) throw failure;
      return Future.value(answer);
    },
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
    signFailure = null;
    answer = SendTransactionResult(
      status: SendTransactionStatus.pending,
      hash: 'ab' * 32,
    );
  });

  test('submit is stored before it is sent, signed by the provider', () async {
    await sender().send(_due());

    final spec = codec.built.single.spec;
    expect(spec.source, _provider);
    expect(spec.accountSequence, 8);
    expect(
      encodeInvokeHostFunction(
        contract: spec.contract,
        function: spec.function,
        args: spec.args,
      ),
      encodeInvokeHostFunction(
        contract: _escrow,
        function: 'submit',
        args: [
          ScArg.address(_provider),
          ScArg.u64(12),
          ScArg.bytes32(deliverableHash(_result)),
        ],
      ),
    );

    final record = store.all.single;
    expect(record.purpose, SubmissionPurpose.submit);
    expect(record.preparationId, isNull);
    expect(record.hireId, 4);
    expect(record.state, SubmissionState.submitted);
    expect(record.sendAttempts, 1);
    expect(sent, [record.signedEnvelopeXdr]);
  });

  test('the deliverable is SHA-256 of the UTF-8 output', () {
    expect(
      deliverableHash(_result),
      Uint8List.fromList(sha256.convert(utf8.encode(_result)).bytes),
    );
    expect(deliverableHash(_result), hasLength(32));
  });

  test('one submit is in flight at a time, across hires', () async {
    await sender().send(_due(hireId: 4));
    await sender().send(_due(hireId: 5, jobId: 13));

    expect(codec.built, hasLength(1));
    expect(sent, hasLength(1));

    await store.markConfirmed(store.all.single.id);
    await sender().send(_due(hireId: 5, jobId: 13));

    expect(codec.built, hasLength(2));
    expect(store.all.last.hireId, 5);
  });

  test('a hire with a non-final escrow record is not submitted', () async {
    await store.insertSubmitted(
      purpose: SubmissionPurpose.fund,
      transactionHash: 'cd' * 32,
      signedEnvelopeXdr: 'AAAA',
      validUntil: _now.add(const Duration(minutes: 5)),
      preparationId: 'prep-fund',
      hireId: 4,
    );

    await sender().send(_due());

    expect(codec.built, isEmpty);
    expect(sent, isEmpty);
    expect(store.all.single.purpose, SubmissionPurpose.fund);
  });

  test('a hire with a confirmed submit is not submitted again', () async {
    await sender().send(_due());
    await store.markConfirmed(store.all.single.id);

    await sender().send(_due());

    expect(codec.built, hasLength(1));
  });

  test('a missing custodied key does not store a submission', () async {
    signFailure = const AgentWalletCustodyUnavailable(
      'No custodied key for this agent wallet',
    );

    await sender().send(_due());

    expect(store.all, isEmpty);
    expect(sent, isEmpty);
  });

  test('the third refused submit is labelled EscrowCallFailed', () async {
    answer = const SendTransactionResult(
      status: SendTransactionStatus.error,
      hash: 'ab',
      errorResultXdr: 'AAAA',
    );

    for (var i = 0; i < maxEscrowCallAttempts; i++) {
      accounts.sequence = 8 + i;
      await sender().send(_due());
    }

    expect(store.all.map((row) => row.errorCode), [
      SubmissionOutcomeCode.submissionRejected,
      SubmissionOutcomeCode.submissionRejected,
      SubmissionOutcomeCode.escrowCallFailed,
    ]);
    await sender().send(_due());
    expect(store.all, hasLength(maxEscrowCallAttempts));
  });
}
