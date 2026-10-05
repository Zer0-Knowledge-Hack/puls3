import '../ledger/ledger_errors.dart';
import '../ledger/soroban_rpc_client.dart';
import 'chain_log.dart';
import 'chain_submission_store.dart';
import 'escrow_effects.dart';
import 'submission_ledger.dart';
import 'submission_values.dart';

/// How long to wait after a send before the same envelope is sent again.
const defaultResendAfter = Duration(seconds: 30);

/// How many `submitted` records one pass handles at most.
const defaultTrackerBatchLimit = 100;

/// Purposes whose final outcomes use codes this tracker does not set yet:
/// `setAgentWallet` expires as `AuthorizationExpired`, and server-signed
/// calls fail as `EscrowCallFailed` after bounded retries (api.md). They are
/// left `submitted` until their rules are implemented.
const _untrackedPurposes = {
  SubmissionPurpose.setAgentWallet,
  SubmissionPurpose.submit,
  SubmissionPurpose.release,
  SubmissionPurpose.claimRefund,
};

/// What one [ChainSubmissionTracker.pass] did, for logging.
final class TrackerPassSummary {
  TrackerPassSummary();

  /// Records the pass read.
  int listed = 0;

  /// Records set to `confirmed`.
  int confirmed = 0;

  /// Records set to `failed`.
  int failed = 0;

  /// Envelopes sent again.
  int resent = 0;

  /// Records not yet on chain and sent too recently to resend.
  int waiting = 0;

  /// Records left alone because their purpose is not handled yet.
  int untracked = 0;

  /// Records skipped because the chain could not be read or the outcome
  /// of a resend is unknown.
  int unavailable = 0;

  /// Records skipped because an effect or the store threw.
  int errors = 0;

  @override
  String toString() =>
      'listed $listed, confirmed $confirmed, failed $failed, '
      'resent $resent, waiting $waiting, untracked $untracked, '
      'unavailable $unavailable, errors $errors';
}

/// Drives `submitted` chain submissions to a final state (api.md relay
/// step 5). Each [pass] reads a batch from the store and, per record:
///
/// - `NOT_FOUND`: once the chain time is past `validUntil` the envelope can
///   never be included, so the record fails `PreparationExpired`.
///   Otherwise the persisted envelope is sent again when it was never sent
///   or was last sent at least `resendAfter` ago. A resend the node refuses
///   ([RpcRequestRejected]) fails `SubmissionRejected`; an `ERROR` status
///   is logged and the record waits for its time bounds.
/// - `FAILED`: fails `TransactionFailed`.
/// - `SUCCESS`: `createJob` and `fund` need their escrow event (else
///   `JobEvidenceUnavailable`) and the [EscrowEffects] result decides
///   `confirmed` or the failure code. Other purposes stay `submitted` until
///   their effects exist.
///
/// The chain time is the lookup's latest ledger close time, because the
/// envelope time bounds are checked against it. Only when the node does not
/// report it does the server clock decide expiry. Resend pacing always uses
/// the server clock.
///
/// A record whose chain read or resend fails, or whose effect or store
/// update throws, stays `submitted` and is retried on the next pass; the
/// rest of the batch continues. Final states are only set through the
/// store's conditional transitions, so concurrent trackers are safe.
final class ChainSubmissionTracker {
  ChainSubmissionTracker({
    required SubmissionLedger ledger,
    required EscrowEffects effects,
    required ChainLog log,
    DateTime Function()? now,
    Duration resendAfter = defaultResendAfter,
    int batchLimit = defaultTrackerBatchLimit,
  }) : _ledger = ledger,
       _effects = effects,
       _log = log,
       _now = now ?? DateTime.now,
       _resendAfter = resendAfter,
       _batchLimit = batchLimit {
    checkListLimit(batchLimit);
  }

  final SubmissionLedger _ledger;
  final EscrowEffects _effects;
  final ChainLog _log;
  final DateTime Function() _now;
  final Duration _resendAfter;
  final int _batchLimit;

  /// Ids already logged as untracked, so each is logged once per tracker.
  final _reportedUntracked = <int>{};

  /// Tracks one batch of [store]. Only a failure to list the batch throws.
  Future<TrackerPassSummary> pass(ChainSubmissionStore store) async {
    final summary = TrackerPassSummary();
    final batch = await store.listSubmitted(limit: _batchLimit);
    summary.listed = batch.length;
    for (final submission in batch) {
      try {
        await _track(store, submission, summary);
      } on LedgerException catch (e) {
        summary.unavailable++;
        _log(
          ChainLogLevel.warning,
          'Chain unavailable for submission ${submission.id}: $e',
        );
      } catch (e) {
        summary.errors++;
        _log(
          ChainLogLevel.error,
          'Tracking submission ${submission.id} failed: $e',
        );
      }
    }
    return summary;
  }

  Future<void> _track(
    ChainSubmissionStore store,
    StoredSubmission submission,
    TrackerPassSummary summary,
  ) async {
    if (_untrackedPurposes.contains(submission.purpose)) {
      _untracked(submission, summary);
      return;
    }
    final lookup = await _ledger.lookup(submission.transactionHash);
    switch (lookup.status) {
      case TransactionStatus.notFound:
        await _notFound(store, submission, lookup, summary);
      case TransactionStatus.failed:
        await _fail(
          store,
          submission,
          SubmissionOutcomeCode.transactionFailed,
          summary,
        );
      case TransactionStatus.success:
        await _succeeded(store, submission, lookup, summary);
    }
  }

  Future<void> _notFound(
    ChainSubmissionStore store,
    StoredSubmission submission,
    TransactionLookup lookup,
    TrackerPassSummary summary,
  ) async {
    final now = _now().toUtc();
    final chainNow = lookup.latestLedgerCloseTime ?? now;
    if (chainNow.isAfter(submission.validUntil)) {
      await _fail(
        store,
        submission,
        SubmissionOutcomeCode.preparationExpired,
        summary,
      );
      return;
    }
    final lastSentAt = submission.lastSentAt;
    if (lastSentAt != null && now.difference(lastSentAt) < _resendAfter) {
      summary.waiting++;
      return;
    }
    final SendTransactionResult result;
    try {
      result = await _ledger.resend(submission.signedEnvelopeXdr);
    } on RpcRequestRejected catch (e) {
      _log(
        ChainLogLevel.warning,
        'The node rejected the envelope of submission ${submission.id}: $e',
      );
      await _fail(
        store,
        submission,
        SubmissionOutcomeCode.submissionRejected,
        summary,
      );
      return;
    }
    await store.recordSend(submission.id, now);
    summary.resent++;
    if (result.status == SendTransactionStatus.error) {
      _log(
        ChainLogLevel.warning,
        'Resending submission ${submission.id} answered ERROR '
        '(${result.errorResultXdr}); it stays submitted until its time '
        'bounds pass',
      );
    }
  }

  Future<void> _succeeded(
    ChainSubmissionStore store,
    StoredSubmission submission,
    TransactionLookup lookup,
    TrackerPassSummary summary,
  ) async {
    final EffectResult? result;
    switch (submission.purpose) {
      case SubmissionPurpose.createJob:
        final event = lookup.jobCreated;
        result = event == null
            ? null
            : await _effects.onJobCreated(submission, event);
      case SubmissionPurpose.fund:
        final event = lookup.jobFunded;
        result = event == null
            ? null
            : await _effects.onFunded(submission, event);
      default:
        _untracked(submission, summary);
        return;
    }
    switch (result) {
      case null:
        await _fail(
          store,
          submission,
          SubmissionOutcomeCode.jobEvidenceUnavailable,
          summary,
        );
      case EffectOk():
        if (await store.markConfirmed(submission.id)) summary.confirmed++;
      case EffectFailed(:final code, :final field):
        _log(
          ChainLogLevel.warning,
          'The effect of submission ${submission.id} failed: $code'
          '${field == null ? '' : ' ($field)'}',
        );
        await _fail(store, submission, code, summary);
    }
  }

  Future<void> _fail(
    ChainSubmissionStore store,
    StoredSubmission submission,
    String code,
    TrackerPassSummary summary,
  ) async {
    if (await store.markFailed(submission.id, code)) summary.failed++;
  }

  void _untracked(StoredSubmission submission, TrackerPassSummary summary) {
    summary.untracked++;
    if (_reportedUntracked.add(submission.id)) {
      _log(
        ChainLogLevel.info,
        'Not tracking submission ${submission.id} '
        '(${submission.purpose.wireName}) yet; it stays submitted',
      );
    }
  }
}
