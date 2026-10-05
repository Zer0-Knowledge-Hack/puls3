import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/chain/chain_log.dart';
import 'package:puls3_server/src/chain/chain_submission_store.dart';
import 'package:puls3_server/src/chain/chain_submission_tracker.dart';
import 'package:puls3_server/src/chain/escrow_effects.dart';
import 'package:puls3_server/src/chain/submission_ledger.dart';
import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:puls3_server/src/ledger/escrow_events.dart';
import 'package:puls3_server/src/ledger/ledger_errors.dart';
import 'package:puls3_server/src/ledger/soroban_rpc_client.dart';
import 'package:puls3_server/src/ledger/stellar_config.dart';
import 'package:test/test.dart';

import '../../support/fake_escrow_effects.dart';
import '../../support/fake_submission_ledger.dart';
import '../../support/in_memory_chain_submission_store.dart';

const _resendAfter = Duration(seconds: 30);
final _start = DateTime.utc(2026, 10, 5, 12);
final _validUntil = _start.add(const Duration(minutes: 5));
final _address = StellarConfig.testnet.simulationSource;

final _jobCreated = JobCreatedEvent(
  jobId: 3,
  client: _address,
  provider: _address,
  evaluator: _address,
  agentId: AgentId(7),
  token: _address,
  budget: BigInt.from(5000000),
  expiredAt: 1791747914,
);
final _jobFunded = JobFundedEvent(
  jobId: 3,
  client: _address,
  amount: BigInt.from(5000000),
  feeBps: 0,
);

TransactionLookup _success({
  JobCreatedEvent? jobCreated,
  JobFundedEvent? jobFunded,
}) => TransactionLookup(
  status: TransactionStatus.success,
  latestLedgerCloseTime: _start,
  jobCreated: jobCreated,
  jobFunded: jobFunded,
);

/// Delegates to an in-memory store but throws from the transitions while
/// [failTransitions] is set.
final class _FlakyStore implements ChainSubmissionStore {
  _FlakyStore(this._inner);

  final ChainSubmissionStore _inner;
  bool failTransitions = true;

  @override
  Future<StoredSubmission> insertSubmitted({
    required SubmissionPurpose purpose,
    required String transactionHash,
    required String signedEnvelopeXdr,
    required DateTime validUntil,
    String? preparationId,
    int? hireId,
    String? explorerUrl,
  }) => _inner.insertSubmitted(
    purpose: purpose,
    transactionHash: transactionHash,
    signedEnvelopeXdr: signedEnvelopeXdr,
    validUntil: validUntil,
    preparationId: preparationId,
    hireId: hireId,
    explorerUrl: explorerUrl,
  );

  @override
  Future<StoredSubmission?> findByPreparation(String preparationId) =>
      _inner.findByPreparation(preparationId);

  @override
  Future<List<StoredSubmission>> listSubmitted({int limit = 100}) =>
      _inner.listSubmitted(limit: limit);

  @override
  Future<bool> markConfirmed(int id) =>
      failTransitions ? throw StateError('db down') : _inner.markConfirmed(id);

  @override
  Future<bool> markFailed(int id, String code) => failTransitions
      ? throw StateError('db down')
      : _inner.markFailed(id, code);

  @override
  Future<bool> recordSend(int id, DateTime at) => _inner.recordSend(id, at);
}

void main() {
  late DateTime now;
  late InMemoryChainSubmissionStore store;
  late FakeSubmissionLedger ledger;
  late FakeEscrowEffects effects;
  late List<String> logged;
  late ChainSubmissionTracker tracker;
  var serial = 0;

  setUp(() {
    now = _start;
    store = InMemoryChainSubmissionStore(now: () => now);
    ledger = FakeSubmissionLedger(closeTime: _start);
    effects = FakeEscrowEffects();
    logged = [];
    tracker = ChainSubmissionTracker(
      ledger: ledger,
      effects: effects,
      now: () => now,
      resendAfter: _resendAfter,
      batchLimit: 10,
      log: (level, message) => logged.add('${level.name}: $message'),
    );
  });

  Future<StoredSubmission> submit(
    SubmissionPurpose purpose, {
    DateTime? validUntil,
  }) {
    serial++;
    return store.insertSubmitted(
      purpose: purpose,
      transactionHash: serial.toRadixString(16).padLeft(64, '0'),
      signedEnvelopeXdr: 'envelope-$serial',
      validUntil: validUntil ?? _validUntil,
      preparationId: purpose.isServerSigned ? null : 'prep-$serial',
    );
  }

  Future<StoredSubmission> reload(StoredSubmission submission) async =>
      store.all.singleWhere((s) => s.id == submission.id);

  Future<void> expectState(
    StoredSubmission submission,
    SubmissionState state, [
    String? errorCode,
  ]) async {
    final current = await reload(submission);
    expect(current.state, state);
    expect(current.errorCode, errorCode);
  }

  group('NOT_FOUND', () {
    test('after validUntil by chain time fails PreparationExpired without '
        'resending', () async {
      final s = await submit(SubmissionPurpose.fund);
      ledger.closeTime = _validUntil.add(const Duration(seconds: 1));

      await tracker.pass(store);

      await expectState(
        s,
        SubmissionState.failed,
        SubmissionOutcomeCode.preparationExpired,
      );
      expect(ledger.resent, isEmpty);
    });

    test('exactly at validUntil is not expired', () async {
      final s = await submit(SubmissionPurpose.fund);
      ledger.closeTime = _validUntil;

      await tracker.pass(store);

      await expectState(s, SubmissionState.submitted);
    });

    test('chain time wins over a server clock that is ahead', () async {
      final s = await submit(SubmissionPurpose.fund);
      now = _validUntil.add(const Duration(minutes: 1));
      ledger.closeTime = _start;

      await tracker.pass(store);

      await expectState(s, SubmissionState.submitted);
    });

    test('without a chain time the server clock decides expiry', () async {
      final s = await submit(SubmissionPurpose.fund);
      ledger.closeTime = null;
      now = _validUntil.add(const Duration(seconds: 1));

      await tracker.pass(store);

      await expectState(
        s,
        SubmissionState.failed,
        SubmissionOutcomeCode.preparationExpired,
      );
    });

    test('a never-sent envelope is resent and the send recorded', () async {
      final s = await submit(SubmissionPurpose.createJob);

      await tracker.pass(store);

      expect(ledger.resent, [s.signedEnvelopeXdr]);
      final current = await reload(s);
      expect(current.state, SubmissionState.submitted);
      expect(current.sendAttempts, 1);
      expect(current.lastSentAt, now);
    });

    test('an envelope sent less than resendAfter ago is not resent', () async {
      final s = await submit(SubmissionPurpose.fund);
      await store.recordSend(s.id, now);
      now = now.add(_resendAfter - const Duration(seconds: 1));

      await tracker.pass(store);

      expect(ledger.resent, isEmpty);
      expect((await reload(s)).sendAttempts, 1);
    });

    test('an envelope sent resendAfter ago is resent', () async {
      final s = await submit(SubmissionPurpose.fund);
      await store.recordSend(s.id, now);
      now = now.add(_resendAfter);

      await tracker.pass(store);

      expect(ledger.resent, [s.signedEnvelopeXdr]);
      expect((await reload(s)).sendAttempts, 2);
    });

    test('a resend answered ERROR stays submitted, is recorded and '
        'logged', () async {
      final s = await submit(SubmissionPurpose.fund);
      ledger.sends[s.signedEnvelopeXdr] = SendTransactionResult(
        status: SendTransactionStatus.error,
        hash: s.transactionHash,
        errorResultXdr: 'AAAAAAAAAGT////7AAAAAA==',
      );

      await tracker.pass(store);

      await expectState(s, SubmissionState.submitted);
      expect((await reload(s)).sendAttempts, 1);
      expect(
        logged,
        contains(
          allOf(
            startsWith('warning'),
            contains('submission ${s.id}'),
            contains('AAAAAAAAAGT////7AAAAAA=='),
          ),
        ),
      );
    });

    test('a resend the node rejects fails SubmissionRejected', () async {
      final s = await submit(SubmissionPurpose.fund);
      ledger.sends[s.signedEnvelopeXdr] = const RpcRequestRejected(
        -32602,
        'invalid transaction',
        'sendTransaction answered JSON-RPC error -32602',
      );

      await tracker.pass(store);

      await expectState(
        s,
        SubmissionState.failed,
        SubmissionOutcomeCode.submissionRejected,
      );
    });

    test('a resend with an unknown outcome stays submitted and is not '
        'recorded', () async {
      final s = await submit(SubmissionPurpose.fund);
      ledger.sends[s.signedEnvelopeXdr] = const LedgerUnavailable('timeout');

      final summary = await tracker.pass(store);

      await expectState(s, SubmissionState.submitted);
      expect((await reload(s)).sendAttempts, 0);
      expect(summary.unavailable, 1);
    });
  });

  test('FAILED fails TransactionFailed', () async {
    final s = await submit(SubmissionPurpose.fund);
    ledger.lookups[s.transactionHash] = TransactionLookup(
      status: TransactionStatus.failed,
      latestLedgerCloseTime: _start,
    );

    await tracker.pass(store);

    await expectState(
      s,
      SubmissionState.failed,
      SubmissionOutcomeCode.transactionFailed,
    );
  });

  group('SUCCESS of createJob', () {
    test('applies the JobCreated effect and confirms', () async {
      final s = await submit(SubmissionPurpose.createJob);
      ledger.lookups[s.transactionHash] = _success(jobCreated: _jobCreated);

      await tracker.pass(store);

      expect(effects.created, [s.id]);
      await expectState(s, SubmissionState.confirmed);
    });

    test('without a JobCreated event fails JobEvidenceUnavailable', () async {
      final s = await submit(SubmissionPurpose.createJob);
      ledger.lookups[s.transactionHash] = _success(jobFunded: _jobFunded);

      await tracker.pass(store);

      expect(effects.created, isEmpty);
      await expectState(
        s,
        SubmissionState.failed,
        SubmissionOutcomeCode.jobEvidenceUnavailable,
      );
    });

    test('a failed effect fails with its code', () async {
      final s = await submit(SubmissionPurpose.createJob);
      ledger.lookups[s.transactionHash] = _success(jobCreated: _jobCreated);
      effects.result = EffectResult.failed(SubmissionOutcomeCode.jobMismatch);

      await tracker.pass(store);

      await expectState(
        s,
        SubmissionState.failed,
        SubmissionOutcomeCode.jobMismatch,
      );
    });
  });

  group('SUCCESS of fund', () {
    test('applies the JobFunded effect and confirms', () async {
      final s = await submit(SubmissionPurpose.fund);
      ledger.lookups[s.transactionHash] = _success(jobFunded: _jobFunded);

      await tracker.pass(store);

      expect(effects.funded, [s.id]);
      await expectState(s, SubmissionState.confirmed);
    });

    test('without a JobFunded event fails JobEvidenceUnavailable', () async {
      final s = await submit(SubmissionPurpose.fund);
      ledger.lookups[s.transactionHash] = _success(jobCreated: _jobCreated);

      await tracker.pass(store);

      expect(effects.funded, isEmpty);
      await expectState(
        s,
        SubmissionState.failed,
        SubmissionOutcomeCode.jobEvidenceUnavailable,
      );
    });

    test('a failed effect fails with its code', () async {
      final s = await submit(SubmissionPurpose.fund);
      ledger.lookups[s.transactionHash] = _success(jobFunded: _jobFunded);
      effects.result = EffectResult.failed(
        SubmissionOutcomeCode.jobMismatch,
        field: 'budget',
      );

      await tracker.pass(store);

      await expectState(
        s,
        SubmissionState.failed,
        SubmissionOutcomeCode.jobMismatch,
      );
    });
  });

  test('SUCCESS of a purpose without an effect yet stays submitted and is '
      'logged once', () async {
    final s = await submit(SubmissionPurpose.complete);
    ledger.lookups[s.transactionHash] = _success();

    await tracker.pass(store);
    await tracker.pass(store);

    await expectState(s, SubmissionState.submitted);
    expect(
      logged.where((m) => m.contains('submission ${s.id}')),
      hasLength(1),
    );
  });

  test('purposes with their own outcome codes are not tracked yet and are '
      'logged once', () async {
    final wallet = await submit(SubmissionPurpose.setAgentWallet);
    final release = await submit(SubmissionPurpose.release);
    ledger.closeTime = _validUntil.add(const Duration(minutes: 1));

    await tracker.pass(store);
    await tracker.pass(store);

    await expectState(wallet, SubmissionState.submitted);
    await expectState(release, SubmissionState.submitted);
    expect(ledger.resent, isEmpty);
    expect(ledger.lookedUp, isEmpty);
    for (final s in [wallet, release]) {
      expect(
        logged.where((m) => m.contains('submission ${s.id}')),
        hasLength(1),
      );
    }
  });

  test('an unreadable chain for one record skips only that record', () async {
    final down = await submit(SubmissionPurpose.fund);
    final up = await submit(SubmissionPurpose.fund);
    ledger.lookups[down.transactionHash] = const LedgerUnavailable('down');
    ledger.lookups[up.transactionHash] = _success(jobFunded: _jobFunded);

    final summary = await tracker.pass(store);

    await expectState(down, SubmissionState.submitted);
    await expectState(up, SubmissionState.confirmed);
    expect(summary.unavailable, 1);
    expect(summary.confirmed, 1);
  });

  test('an effect that throws leaves the record submitted for the next '
      'pass', () async {
    final s = await submit(SubmissionPurpose.fund);
    final other = await submit(SubmissionPurpose.createJob);
    ledger.lookups[s.transactionHash] = _success(jobFunded: _jobFunded);
    ledger.lookups[other.transactionHash] = _success(jobCreated: _jobCreated);
    effects.error = StateError('hire table locked');

    final first = await tracker.pass(store);
    effects.error = null;
    final second = await tracker.pass(store);

    expect(first.errors, 2);
    expect(second.confirmed, 2);
    await expectState(s, SubmissionState.confirmed);
    expect(
      logged,
      contains(allOf(startsWith('error'), contains('submission ${s.id}'))),
    );
  });

  test('a store transition that throws leaves the record submitted', () async {
    final flaky = _FlakyStore(store);
    final s = await submit(SubmissionPurpose.fund);
    ledger.lookups[s.transactionHash] = _success(jobFunded: _jobFunded);

    final first = await tracker.pass(flaky);
    flaky.failTransitions = false;
    await tracker.pass(flaky);

    expect(first.errors, 1);
    await expectState(s, SubmissionState.confirmed);
  });

  test('a pass handles at most batchLimit records', () async {
    for (var i = 0; i < 12; i++) {
      await submit(SubmissionPurpose.fund);
    }

    final summary = await tracker.pass(store);

    expect(summary.listed, 10);
    expect(ledger.lookedUp, hasLength(10));
  });

  test('the summary counts every outcome', () async {
    final confirmed = await submit(SubmissionPurpose.fund);
    final failed = await submit(SubmissionPurpose.fund);
    await submit(SubmissionPurpose.fund); // resent
    final waiting = await submit(SubmissionPurpose.fund);
    await store.recordSend(waiting.id, now);
    final untracked = await submit(SubmissionPurpose.complete);
    ledger.lookups[confirmed.transactionHash] = _success(jobFunded: _jobFunded);
    ledger.lookups[failed.transactionHash] = TransactionLookup(
      status: TransactionStatus.failed,
    );
    ledger.lookups[untracked.transactionHash] = _success();

    final summary = await tracker.pass(store);

    expect(summary.listed, 5);
    expect(summary.confirmed, 1);
    expect(summary.failed, 1);
    expect(summary.resent, 1);
    expect(summary.waiting, 1);
    expect(summary.untracked, 1);
    expect(summary.unavailable, 0);
    expect(summary.errors, 0);
    expect(summary.toString(), contains('confirmed 1'));
  });

  test('rejects a batch limit below 1', () {
    expect(
      () => ChainSubmissionTracker(
        ledger: ledger,
        effects: effects,
        batchLimit: 0,
        log: ignoreChainLog,
      ),
      throwsArgumentError,
    );
  });
}
