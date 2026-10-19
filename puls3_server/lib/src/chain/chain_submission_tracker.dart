import '../ledger/ledger_errors.dart';
import '../ledger/soroban_rpc_client.dart';
import 'chain_log.dart';
import 'chain_submission_store.dart';
import 'escrow_deadline.dart';
import 'escrow_effects.dart';
import 'submission_ledger.dart';
import 'submission_values.dart';

/// How long to wait after a send before the same envelope is sent again.
const defaultResendAfter = Duration(seconds: 30);

/// How long the node is assumed to keep a transaction findable when it does
/// not report its oldest ledger: Soroban RPC keeps 17280 ledgers by default,
/// about 24 hours at 5 seconds a ledger.
const defaultRpcRetention = Duration(hours: 24);

/// How many passes in a row may find no escrow event on a successful
/// `createJob` or `fund` before the record fails `JobEvidenceUnavailable`.
/// The node can answer SUCCESS before its event index has caught up.
const evidencePasses = 3;

/// How many `submitted` records one pass handles at most.
const defaultTrackerBatchLimit = 100;

/// Purposes whose final outcomes use codes this tracker does not set yet.
/// `setAgentWallet` expires as `AuthorizationExpired`, and `submit` fails as
/// `EscrowCallFailed` after bounded retries (api.md). They stay `submitted`.
/// `release`, `claimRefund`, `complete`, `reject` and `registerFull` are
/// confirmed when the transaction succeeds, with no hire effect yet (#97).
const _untrackedPurposes = {
  SubmissionPurpose.setAgentWallet,
  SubmissionPurpose.submit,
};

/// The permissionless calls whose third failure is `EscrowCallFailed`.
const _relayPurposes = {
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
///   never be included. A `fund` is first reconciled through the escrow job
///   ([EscrowEffects.reconcileExpiredFund]): landed follows the confirm path,
///   an open job fails `PreparationExpired`. Without proof the record fails
///   `PreparationExpired` while the node still retains the ledgers since it
///   was created (`oldestLedgerCloseTime`, else `rpcRetention`), and
///   `OutcomeUnknown` beyond that: it may have landed unseen. An expired or
///   missing job with covered retention also gives `PreparationExpired`: a
///   fund that landed and was then refunded cannot be told apart from one
///   that never landed.
///   Otherwise the persisted envelope is sent again, with its stored hash as
///   the expected one, when it was never sent or was last sent at least
///   `resendAfter` ago. A resend the node refuses ([RpcRequestRejected])
///   fails `SubmissionRejected`; an `ERROR` status is logged and the record
///   waits for its time bounds.
/// - `FAILED`: fails `TransactionFailed`.
/// - `SUCCESS`: `createJob` and `fund` need their escrow event: with none the
///   record stays `submitted` for [evidencePasses] passes in total (the count
///   is in memory and a restart starts it again), then fails
///   `JobEvidenceUnavailable`. The [EscrowEffects] result, given every valid
///   event of the transaction, decides `confirmed` or the failure code;
///   `giveFeedback` needs no event. `complete`, `reject` and `registerFull`
///   are confirmed with no domain effect: until #97 the hire status does not
///   change, so the app may offer `prepareComplete` again and the contract
///   then rejects it as `TransactionFailed`.
///
/// The chain time is the lookup's latest ledger close time, because the
/// envelope time bounds are checked against it. Only when the node does not
/// report it does the server clock decide expiry. Resend pacing always uses
/// the server clock.
///
/// A record whose chain read or resend fails, or whose effect or store
/// update throws, stays `submitted` and is retried on a later pass; the
/// rest of the batch continues. Every record a pass leaves `submitted`, for
/// any reason, gets [ChainSubmissionStore.recordCheck], so it moves behind
/// the records not yet looked at. Final states are only set through the
/// store's conditional transitions, so concurrent trackers are safe.
final class ChainSubmissionTracker {
  ChainSubmissionTracker({
    required SubmissionLedger ledger,
    required EscrowEffects effects,
    required ChainLog log,
    DateTime Function()? now,
    Duration resendAfter = defaultResendAfter,
    Duration rpcRetention = defaultRpcRetention,
    int batchLimit = defaultTrackerBatchLimit,
  }) : _ledger = ledger,
       _effects = effects,
       _log = log,
       _now = now ?? DateTime.now,
       _resendAfter = resendAfter,
       _rpcRetention = rpcRetention,
       _batchLimit = batchLimit {
    checkListLimit(batchLimit);
  }

  final SubmissionLedger _ledger;
  final EscrowEffects _effects;
  final ChainLog _log;
  final DateTime Function() _now;
  final Duration _resendAfter;
  final Duration _rpcRetention;
  final int _batchLimit;

  /// Ids already logged as untracked, so each is logged once per tracker.
  final _reportedUntracked = <int>{};

  /// Passes that found no escrow event on a successful transaction, by
  /// submission id. In memory only: a restart starts counting again.
  final _missingEvents = <int, int>{};

  /// Tracks one batch of [store]. Only a failure to list the batch throws.
  Future<TrackerPassSummary> pass(ChainSubmissionStore store) async {
    final summary = TrackerPassSummary();
    final batch = await store.listSubmitted(limit: _batchLimit);
    summary.listed = batch.length;
    for (final submission in batch) {
      final before = _missingEvents[submission.id];
      var settled = false;
      try {
        settled = await _track(store, submission, summary);
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
      // The passes must be consecutive: a pass that did not count a missing
      // event for this record (it settled, saw an event, or failed to read
      // the chain) starts the count again.
      if (settled || _missingEvents[submission.id] == before) {
        _missingEvents.remove(submission.id);
      }
      if (!settled) await _recordCheck(store, submission, summary);
    }
    if (batch.length < _batchLimit) {
      // The batch is every `submitted` record: forget the others.
      final listed = {for (final s in batch) s.id};
      _missingEvents.removeWhere((id, _) => !listed.contains(id));
    }
    return summary;
  }

  /// Moves a record that stays `submitted` to the back of the store's list,
  /// so records that never settle cannot starve the others. A failure is
  /// counted and logged like any other per-record error.
  Future<void> _recordCheck(
    ChainSubmissionStore store,
    StoredSubmission submission,
    TrackerPassSummary summary,
  ) async {
    try {
      await store.recordCheck(submission.id, _now().toUtc());
    } catch (e) {
      summary.errors++;
      _log(
        ChainLogLevel.error,
        'Recording the check of submission ${submission.id} failed: $e',
      );
    }
  }

  /// Returns whether the record reached a final state, here or through a
  /// concurrent tracker (the transitions are conditional).
  Future<bool> _track(
    ChainSubmissionStore store,
    StoredSubmission submission,
    TrackerPassSummary summary,
  ) async {
    if (_untrackedPurposes.contains(submission.purpose)) {
      _untracked(submission, summary);
      return false;
    }
    final lookup = await _ledger.lookup(submission.transactionHash);
    return switch (lookup.status) {
      TransactionStatus.notFound => _notFound(
        store,
        submission,
        lookup,
        summary,
      ),
      TransactionStatus.failed => _fail(
        store,
        submission,
        SubmissionOutcomeCode.transactionFailed,
        summary,
      ),
      TransactionStatus.success => _succeeded(
        store,
        submission,
        lookup,
        summary,
      ),
    };
  }

  Future<bool> _notFound(
    ChainSubmissionStore store,
    StoredSubmission submission,
    TransactionLookup lookup,
    TrackerPassSummary summary,
  ) async {
    final now = _now().toUtc();
    final chainNow = lookup.latestLedgerCloseTime ?? now;
    if (chainNow.isAfter(submission.validUntil)) {
      return _expired(store, submission, lookup, chainNow, summary);
    }
    final lastSentAt = submission.lastSentAt;
    if (lastSentAt != null && now.difference(lastSentAt) < _resendAfter) {
      summary.waiting++;
      return false;
    }
    final SendTransactionResult result;
    try {
      result = await _ledger.resend(
        submission.signedEnvelopeXdr,
        submission.transactionHash,
      );
    } on RpcRequestRejected catch (e) {
      _log(
        ChainLogLevel.warning,
        'The node rejected the envelope of submission ${submission.id}: $e',
      );
      return _fail(
        store,
        submission,
        SubmissionOutcomeCode.submissionRejected,
        summary,
      );
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
    return false;
  }

  /// The envelope can never be included. A `fund` is first reconciled
  /// through the escrow job, since the node may simply have lost the
  /// transaction. Without proof, `PreparationExpired` is only true while the
  /// node still retains the ledgers since the record was created; beyond
  /// that the transaction may have landed unseen: `OutcomeUnknown`.
  Future<bool> _expired(
    ChainSubmissionStore store,
    StoredSubmission submission,
    TransactionLookup lookup,
    DateTime chainNow,
    TrackerPassSummary summary,
  ) async {
    if (submission.purpose == SubmissionPurpose.fund) {
      switch (await _effects.reconcileExpiredFund(submission)) {
        case ExpiredFundLanded(:final result):
          return _settle(store, submission, result, summary);
        case ExpiredFundNotLanded():
          return _fail(
            store,
            submission,
            SubmissionOutcomeCode.preparationExpired,
            summary,
          );
        case ExpiredFundUnknown():
          break;
      }
    }
    final covered = _retained(lookup, submission, chainNow);
    return _fail(
      store,
      submission,
      covered
          ? SubmissionOutcomeCode.preparationExpired
          : SubmissionOutcomeCode.outcomeUnknown,
      summary,
    );
  }

  /// Whether the node still retains every ledger since [submission] was
  /// created, so a NOT_FOUND really means the transaction never landed.
  bool _retained(
    TransactionLookup lookup,
    StoredSubmission submission,
    DateTime chainNow,
  ) {
    final oldest = lookup.oldestLedgerCloseTime;
    if (oldest != null) return !oldest.isAfter(submission.createdAt);
    return !chainNow.subtract(_rpcRetention).isAfter(submission.createdAt);
  }

  Future<bool> _succeeded(
    ChainSubmissionStore store,
    StoredSubmission submission,
    TransactionLookup lookup,
    TrackerPassSummary summary,
  ) async {
    final EffectResult result;
    switch (submission.purpose) {
      case SubmissionPurpose.createJob:
        final events = lookup.jobCreated;
        if (events.isEmpty) return _missingEvidence(store, submission, summary);
        result = await _effects.onJobCreated(submission, events);
      case SubmissionPurpose.fund:
        final events = lookup.jobFunded;
        if (events.isEmpty) return _missingEvidence(store, submission, summary);
        result = await _effects.onFunded(submission, events);
      case SubmissionPurpose.giveFeedback:
        result = await _effects.onFeedbackGiven(submission);
      case SubmissionPurpose.release ||
          SubmissionPurpose.claimRefund ||
          SubmissionPurpose.complete ||
          SubmissionPurpose.reject ||
          SubmissionPurpose.registerFull:
        if (await store.markConfirmed(submission.id)) summary.confirmed++;
        return true;
      default:
        _untracked(submission, summary);
        return false;
    }
    return _settle(store, submission, result, summary);
  }

  Future<bool> _settle(
    ChainSubmissionStore store,
    StoredSubmission submission,
    EffectResult result,
    TrackerPassSummary summary,
  ) async {
    switch (result) {
      case EffectOk():
        if (await store.markConfirmed(submission.id)) summary.confirmed++;
        return true;
      case EffectFailed(:final code, :final field):
        _log(
          ChainLogLevel.warning,
          'The effect of submission ${submission.id} failed: $code'
          '${field == null ? '' : ' ($field)'}',
        );
        return _fail(store, submission, code, summary);
    }
  }

  /// A successful `createJob` or `fund` whose transaction shows no escrow
  /// event: the record waits for the next [evidencePasses] - 1 passes in case
  /// the node's event index is late, then fails `JobEvidenceUnavailable`.
  Future<bool> _missingEvidence(
    ChainSubmissionStore store,
    StoredSubmission submission,
    TrackerPassSummary summary,
  ) async {
    final misses = (_missingEvents[submission.id] ?? 0) + 1;
    if (misses >= evidencePasses) {
      return _fail(
        store,
        submission,
        SubmissionOutcomeCode.jobEvidenceUnavailable,
        summary,
      );
    }
    _missingEvents[submission.id] = misses;
    summary.waiting++;
    _log(
      ChainLogLevel.warning,
      'Submission ${submission.id} succeeded without its escrow event '
      '(pass $misses of $evidencePasses); it stays submitted',
    );
    return false;
  }

  /// Always settles the record: `markFailed` either sets `failed` or finds
  /// it already final.
  ///
  /// A `release` or `claim_refund` that fails after two failed envelopes of
  /// the same hire and call is stored as `EscrowCallFailed` instead of
  /// [code]: it is the failure that uses the last attempt (api.md).
  Future<bool> _fail(
    ChainSubmissionStore store,
    StoredSubmission submission,
    String code,
    TrackerPassSummary summary,
  ) async {
    final stored = await _failureCode(store, submission, code);
    if (await store.markFailed(submission.id, stored)) summary.failed++;
    return true;
  }

  Future<String> _failureCode(
    ChainSubmissionStore store,
    StoredSubmission submission,
    String code,
  ) async {
    final hireId = submission.hireId;
    if (hireId == null || !_relayPurposes.contains(submission.purpose)) {
      return code;
    }
    final prior = (await store.listByHire(hireId))
        .where(
          (row) =>
              row.id != submission.id &&
              row.purpose == submission.purpose &&
              row.state == SubmissionState.failed,
        )
        .length;
    return escrowCallFailureCode(priorFailures: prior, code: code);
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
