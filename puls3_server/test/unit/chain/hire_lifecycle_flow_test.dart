// End-to-end hire lifecycle over fakes (#208, deliverable 6): the agent's
// server-signed `submit`, the tracker confirming it on a fake ledger, and
// the status `getHire` derives from the confirmed records
// (`fundedHireSettlement`). No database and no network.
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/chain/agent_submit_sender.dart';
import 'package:puls3_server/src/chain/chain_log.dart';
import 'package:puls3_server/src/chain/chain_submission_store.dart';
import 'package:puls3_server/src/chain/chain_submission_tracker.dart';
import 'package:puls3_server/src/chain/escrow_deadline.dart';
import 'package:puls3_server/src/chain/submission_ledger.dart';
import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:puls3_server/src/hire/chain_accounts.dart';
import 'package:puls3_server/src/hire/hire_settlement.dart';
import 'package:puls3_server/src/ledger/envelope_codec.dart';
import 'package:puls3_server/src/ledger/soroban_rpc_client.dart';
import 'package:puls3_server/src/ledger/xdr_invoke_encoder.dart';
import 'package:test/test.dart';

import '../../support/fake_envelope_codec.dart';
import '../../support/fake_escrow_effects.dart';
import '../../support/fake_submission_ledger.dart';
import '../../support/in_memory_chain_submission_store.dart';

final _provider = StellarAddress.parse(
  'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H',
);
final _otherProvider = StellarAddress.parse(
  'GCHX6NRPMSB4CIZM3ZLHPOC2VD6DJVAN6IY3NE5QSAMOWJ7N4TAWK6HN',
);
final _escrow = StellarAddress.parse(
  'CBRD7A7MXINM7LREKCL3RMKRQ5UMLGKNHAEYY4JT7MVBBB7R5QV4TPE2',
);
final _start = DateTime.utc(2026, 11, 8, 12);

/// The run output, with non-ASCII text so the hash covers the UTF-8 bytes.
const _result = 'Resumen: categoría «facturación» ✓';

const _hireId = 4;
const _jobId = 12;

DueSubmit _due({int hireId = _hireId, int jobId = _jobId}) => DueSubmit(
  hireId: hireId,
  jobId: jobId,
  provider: _provider,
  result: _result,
);

final class _Accounts implements ChainAccounts {
  var sequence = 8;

  @override
  Future<int> sequenceOf(StellarAddress account) async => sequence;

  @override
  Future<SimulationData> simulate(EnvelopeSpec spec) async =>
      const SimulationData(transactionData: 'AAAA', minResourceFee: 50);

  @override
  Future<AccountAuthority?> authorityOf(StellarAddress account) async => null;
}

void main() {
  late DateTime now;
  late InMemoryChainSubmissionStore store;
  late FakeSubmissionLedger ledger;
  late _Accounts accounts;
  late FakeEnvelopeCodec codec;
  late List<StellarAddress> signers;
  var preparations = 0;

  AgentSubmitSender sender() => AgentSubmitSender(
    submissions: store,
    accounts: accounts,
    codec: codec,
    sign: (prepared, provider) {
      signers.add(provider);
      return Future.value(FakeEnvelopeCodec.sign(prepared.envelopeXdr));
    },
    // The node accepts every envelope; the fake ledger decides its outcome.
    send: (envelope, hash) => Future.value(
      SendTransactionResult(status: SendTransactionStatus.pending, hash: hash),
    ),
    escrow: _escrow,
    inclusionFee: 100,
    validitySeconds: 300,
    now: () => now,
    log: ignoreChainLog,
  );

  ChainSubmissionTracker tracker() => ChainSubmissionTracker(
    ledger: ledger,
    effects: FakeEscrowEffects(),
    now: () => now,
    log: ignoreChainLog,
  );

  /// The status for a funded hire given its confirmed records: the same
  /// `fundedHireSettlement` call `ServerpodHireRepository` makes, over the
  /// confirmed purposes read here from the in-memory store. It does not run
  /// the repository itself.
  Future<HireStatus> status({int hireId = _hireId}) async {
    final confirmed = {
      for (final row in await store.listByHire(hireId))
        if (row.state == SubmissionState.confirmed) row.purpose,
    };
    return fundedHireSettlement(confirmed) ?? HireStatus.funded;
  }

  Future<List<StoredSubmission>> rows(SubmissionPurpose purpose) async => [
    for (final row in await store.listByHire(_hireId))
      if (row.purpose == purpose) row,
  ];

  /// A client-signed call the relay stored after verifying it (`complete`,
  /// `reject`), as `EscrowRelayService.submitEscrowCall` leaves it.
  Future<StoredSubmission> relayClientCall(SubmissionPurpose purpose) =>
      store.insertSubmitted(
        purpose: purpose,
        transactionHash: sha256
            .convert(utf8.encode('${purpose.wireName}-${++preparations}'))
            .toString(),
        signedEnvelopeXdr: 'signed-${purpose.wireName}-$preparations',
        validUntil: now.add(const Duration(minutes: 5)),
        preparationId: 'prep-$preparations',
        hireId: _hireId,
      );

  void lands(StoredSubmission row, TransactionStatus outcome) =>
      ledger.lookups[row.transactionHash] = TransactionLookup(
        status: outcome,
        latestLedgerCloseTime: now,
      );

  setUp(() {
    now = _start;
    store = InMemoryChainSubmissionStore(now: () => now);
    ledger = FakeSubmissionLedger(closeTime: _start);
    accounts = _Accounts();
    codec = FakeEnvelopeCodec();
    signers = [];
    preparations = 0;
  });

  test(
    'funded → submitted → completed: the hire moves only on confirmations',
    () async {
      await sender().send(_due());

      final [submit] = await rows(SubmissionPurpose.submit);
      expect(submit.state, SubmissionState.submitted);
      // Signed by the job's provider, the custodied agent wallet.
      expect(signers, [_provider]);
      expect(codec.built.single.spec.source, _provider);
      // Hire.submit() waits for the chain.
      expect(await status(), HireStatus.funded);

      lands(submit, TransactionStatus.success);
      await tracker().pass(store);
      expect(await status(), HireStatus.submitted);

      final complete = await relayClientCall(SubmissionPurpose.complete);
      expect(await status(), HireStatus.submitted);
      lands(complete, TransactionStatus.success);
      await tracker().pass(store);

      expect(await status(), HireStatus.completed);
    },
  );

  test('funded → submitted → rejected', () async {
    await sender().send(_due());
    lands(
      (await rows(SubmissionPurpose.submit)).single,
      TransactionStatus.success,
    );
    await tracker().pass(store);
    expect(await status(), HireStatus.submitted);

    final reject = await relayClientCall(SubmissionPurpose.reject);
    lands(reject, TransactionStatus.success);
    await tracker().pass(store);

    expect(await status(), HireStatus.rejected);
    // Both calls are confirmed. `rejectedFrom` itself is derived by
    // `ServerpodHireRepository._replaySettlement` and is covered by the
    // integration test "a confirmed reject after submit records rejectedFrom
    // submitted".
    expect(
      {
        for (final row in await store.listByHire(_hireId))
          if (row.state == SubmissionState.confirmed) row.purpose,
      },
      containsAll({SubmissionPurpose.submit, SubmissionPurpose.reject}),
    );
  });

  // Which runs become a `DueSubmit` is `ServerpodDueSubmitSource`, which needs
  // Postgres. Here the hire simply never gets a submit, as after a failed run.
  group('a funded hire with no submit stays funded and then settles', () {
    test('on reject, as rejected', () async {
      expect(await status(), HireStatus.funded);

      final reject = await relayClientCall(SubmissionPurpose.reject);
      expect(await status(), HireStatus.funded);
      lands(reject, TransactionStatus.success);
      await tracker().pass(store);

      expect(await status(), HireStatus.rejected);
    });

    test('on claim_refund after expiry, as expired', () async {
      final refund = await store.insertSubmitted(
        purpose: SubmissionPurpose.claimRefund,
        transactionHash: 'cc' * 32,
        signedEnvelopeXdr: 'signed-claim-refund',
        validUntil: now.add(const Duration(minutes: 5)),
        hireId: _hireId,
      );
      expect(await status(), HireStatus.funded);
      lands(refund, TransactionStatus.success);
      await tracker().pass(store);

      expect(await status(), HireStatus.expired);
    });
  });

  test('the deliverable is SHA-256 of the exact UTF-8 output', () async {
    await sender().send(_due());

    final spec = codec.built.single.spec;
    expect(spec.function, 'submit');
    final expected = encodeInvokeHostFunction(
      contract: _escrow,
      function: 'submit',
      args: [
        ScArg.address(_provider),
        const ScArg.u64(_jobId),
        ScArg.bytes32(
          Uint8List.fromList(sha256.convert(utf8.encode(_result)).bytes),
        ),
      ],
    );
    expect(
      encodeInvokeHostFunction(
        contract: spec.contract,
        function: spec.function,
        args: spec.args,
      ),
      expected,
    );
  });

  test(
    'a submit that fails on chain does not move the hire; the third failure '
    'is EscrowCallFailed and no fourth is built',
    () async {
      for (var attempt = 1; attempt <= maxEscrowCallAttempts; attempt++) {
        accounts.sequence++;
        await sender().send(_due());
        final latest = (await rows(SubmissionPurpose.submit)).last;
        lands(latest, TransactionStatus.failed);
        await tracker().pass(store);
        expect(await status(), HireStatus.funded, reason: 'attempt $attempt');
      }

      final failed = await rows(SubmissionPurpose.submit);
      expect(failed.map((r) => r.state), everyElement(SubmissionState.failed));
      // Only the attempt that uses up the budget is EscrowCallFailed.
      expect(failed.map((r) => r.errorCode), [
        SubmissionOutcomeCode.transactionFailed,
        SubmissionOutcomeCode.transactionFailed,
        SubmissionOutcomeCode.escrowCallFailed,
      ]);
      expect(codec.built, hasLength(3));
      expect(signers, hasLength(3));

      accounts.sequence++;
      await sender().send(_due());
      expect(await rows(SubmissionPurpose.submit), hasLength(3));
      // Nothing is built or signed for a 4th attempt, stored or not.
      expect(codec.built, hasLength(3));
      expect(signers, hasLength(3));
    },
  );

  test(
    'no second submit for a hire: none while one is pending, none after one '
    'is confirmed',
    () async {
      await sender().send(_due());
      // Not on chain yet: the tracker keeps it submitted.
      await tracker().pass(store);
      expect(
        (await rows(SubmissionPurpose.submit)).single.state,
        SubmissionState.submitted,
      );

      // Every send reads the persisted records, so a pending submit blocks
      // another one (the same check protects a restarted server).
      accounts.sequence++;
      await sender().send(_due());
      expect(await rows(SubmissionPurpose.submit), hasLength(1));

      // Once it confirms, a later pass never submits that hire again.
      lands(
        (await rows(SubmissionPurpose.submit)).single,
        TransactionStatus.success,
      );
      await tracker().pass(store);
      accounts.sequence++;
      await sender().send(_due());
      expect(await rows(SubmissionPurpose.submit), hasLength(1));
      expect(await status(), HireStatus.submitted);
    },
  );

  test('a late confirmation is applied when it arrives', () async {
    await sender().send(_due());
    final submit = (await rows(SubmissionPurpose.submit)).single;

    // Several passes while the node does not know the transaction yet.
    for (var i = 0; i < 3; i++) {
      now = now.add(const Duration(seconds: 5));
      await tracker().pass(store);
      expect(await status(), HireStatus.funded);
    }

    now = now.add(const Duration(seconds: 5));
    lands(submit, TransactionStatus.success);
    await tracker().pass(store);
    expect(await status(), HireStatus.submitted);
  });

  test('a repeated confirmation changes nothing', () async {
    await sender().send(_due());
    final submit = (await rows(SubmissionPurpose.submit)).single;
    lands(submit, TransactionStatus.success);

    final first = await tracker().pass(store);
    final second = await tracker().pass(store);

    expect(first.confirmed, 1);
    expect(second.confirmed, 0);
    expect(await status(), HireStatus.submitted);
  });

  test('only one submit is in flight across hires', () async {
    await sender().send(_due());
    accounts.sequence++;
    await sender().send(_due(hireId: 5, jobId: 13));

    expect(await store.listByHire(5), isEmpty);
    expect(signers, [_provider]);
  });

  test('the submit is signed for the due provider only', () async {
    final due = DueSubmit(
      hireId: _hireId,
      jobId: _jobId,
      provider: _otherProvider,
      result: _result,
    );
    await sender().send(due);

    expect(signers, [_otherProvider]);
    expect(codec.built.single.spec.source, _otherProvider);
  });
}
