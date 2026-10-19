import '../ledger/escrow_events.dart';
import 'chain_log.dart';
import 'chain_submission_store.dart';
import 'submission_values.dart';

/// The outcome of applying a confirmed escrow transaction to the domain.
sealed class EffectResult {
  const EffectResult();

  /// The effect is applied (or was already applied).
  const factory EffectResult.ok() = EffectOk;

  /// The transaction succeeded but does not belong to its hire. [code] is
  /// [SubmissionOutcomeCode.jobMismatch] or
  /// [SubmissionOutcomeCode.jobEvidenceUnavailable]; [field] names the
  /// mismatching job field, when there is one (api.md, funding
  /// verification). Any other code throws [ArgumentError].
  factory EffectResult.failed(String code, {String? field}) = EffectFailed;
}

final class EffectOk extends EffectResult {
  const EffectOk();
}

final class EffectFailed extends EffectResult {
  EffectFailed(this.code, {this.field}) {
    if (!_effectCodes.contains(code)) {
      throw ArgumentError.value(code, 'code', 'is not a job outcome code');
    }
  }

  final String code;
  final String? field;
}

const _effectCodes = {
  SubmissionOutcomeCode.jobMismatch,
  SubmissionOutcomeCode.jobEvidenceUnavailable,
};

/// What the escrow says about a `fund` whose transaction the node can no
/// longer find after its `validUntil`.
sealed class ExpiredFund {
  const ExpiredFund();
}

/// The fund landed although the node does not know the transaction: the job
/// is `Funded` or later. [result] is the fund effect applied to it.
final class ExpiredFundLanded extends ExpiredFund {
  const ExpiredFundLanded(this.result);

  final EffectResult result;
}

/// The job is still `Open`: the fund never landed.
final class ExpiredFundNotLanded extends ExpiredFund {
  const ExpiredFundNotLanded();
}

/// The escrow cannot say: no hire or job id to read, no such job, or an
/// `Expired` job.
final class ExpiredFundUnknown extends ExpiredFund {
  const ExpiredFundUnknown();
}

/// Applies the domain effect of a successful relayed transaction (api.md
/// relay step 5): record the job id after `create_job`, `Hire.fund` after
/// `fund`, confirm the rating after `give_feedback`.
///
/// The tracker marks the submission `confirmed` or `failed` only after an
/// effect returns, so a crash in between applies the effect again on the
/// next pass. Implementations must therefore be idempotent: applying the
/// same event to the same submission twice has the effect of once and
/// returns the same result. An exception leaves the submission `submitted`
/// and is retried.
abstract interface class EscrowEffects {
  /// After a successful `create_job` ([SubmissionPurpose.createJob]).
  /// [events] are all the valid `job_created` events of the transaction, in
  /// order; the implementation picks the one that belongs to the hire.
  Future<EffectResult> onJobCreated(
    StoredSubmission submission,
    List<JobCreatedEvent> events,
  );

  /// After a successful `fund` ([SubmissionPurpose.fund]). [events] are all
  /// the valid `job_funded` events of the transaction, in order.
  Future<EffectResult> onFunded(
    StoredSubmission submission,
    List<JobFundedEvent> events,
  );

  /// After a successful `give_feedback` ([SubmissionPurpose.giveFeedback]).
  ///
  /// No event is needed: the signed envelope is the one the server prepared
  /// for this hire, so a successful transaction is the registry recording
  /// the hire's feedback. Confirming the submission is what exposes it as the
  /// hire's `feedbackReference` (no column stores it).
  Future<EffectResult> onFeedbackGiven(StoredSubmission submission);

  /// For a `fund` that is NOT_FOUND past its `validUntil`: reads the escrow
  /// job of the submission's hire to tell whether the fund landed anyway
  /// (the node may have lost the transaction, not the ledger).
  ///
  /// Reading the job can fail; the exception leaves the submission
  /// `submitted` for a later pass.
  Future<ExpiredFund> reconcileExpiredFund(StoredSubmission submission);
}

/// Accepts every effect without changing anything, and logs it. Used until
/// the hire lifecycle (#96) provides the real effects.
final class NoopEscrowEffects implements EscrowEffects {
  const NoopEscrowEffects({ChainLog log = ignoreChainLog}) : _log = log;

  final ChainLog _log;

  @override
  Future<EffectResult> onJobCreated(
    StoredSubmission submission,
    List<JobCreatedEvent> events,
  ) async {
    _log(
      ChainLogLevel.info,
      'No escrow effect for job ${_jobIds(events.map((e) => e.jobId))} created by submission '
      '${submission.id}',
    );
    return const EffectResult.ok();
  }

  @override
  Future<EffectResult> onFunded(
    StoredSubmission submission,
    List<JobFundedEvent> events,
  ) async {
    _log(
      ChainLogLevel.info,
      'No escrow effect for job ${_jobIds(events.map((e) => e.jobId))} funded by submission '
      '${submission.id}',
    );
    return const EffectResult.ok();
  }

  @override
  Future<EffectResult> onFeedbackGiven(StoredSubmission submission) async {
    _log(
      ChainLogLevel.info,
      'No effect for the feedback of hire ${submission.hireId} given by '
      'submission ${submission.id}',
    );
    return const EffectResult.ok();
  }

  @override
  Future<ExpiredFund> reconcileExpiredFund(StoredSubmission submission) async =>
      const ExpiredFundUnknown();
}

String _jobIds(Iterable<int> ids) => ids.join(', ');
