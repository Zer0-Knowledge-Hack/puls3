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

/// Applies the domain effect of a successful escrow transaction (api.md
/// relay step 5): record the job id after `create_job`, `Hire.fund` after
/// `fund`.
///
/// The tracker marks the submission `confirmed` or `failed` only after an
/// effect returns, so a crash in between applies the effect again on the
/// next pass. Implementations must therefore be idempotent: applying the
/// same event to the same submission twice has the effect of once and
/// returns the same result. An exception leaves the submission `submitted`
/// and is retried.
abstract interface class EscrowEffects {
  /// After a successful `create_job` ([SubmissionPurpose.createJob]).
  Future<EffectResult> onJobCreated(
    StoredSubmission submission,
    JobCreatedEvent event,
  );

  /// After a successful `fund` ([SubmissionPurpose.fund]).
  Future<EffectResult> onFunded(
    StoredSubmission submission,
    JobFundedEvent event,
  );
}

/// Accepts every effect without changing anything, and logs it. Used until
/// the hire lifecycle (#96) provides the real effects.
final class NoopEscrowEffects implements EscrowEffects {
  const NoopEscrowEffects({ChainLog log = ignoreChainLog}) : _log = log;

  final ChainLog _log;

  @override
  Future<EffectResult> onJobCreated(
    StoredSubmission submission,
    JobCreatedEvent event,
  ) async {
    _log(
      ChainLogLevel.info,
      'No escrow effect for job ${event.jobId} created by submission '
      '${submission.id}',
    );
    return const EffectResult.ok();
  }

  @override
  Future<EffectResult> onFunded(
    StoredSubmission submission,
    JobFundedEvent event,
  ) async {
    _log(
      ChainLogLevel.info,
      'No escrow effect for job ${event.jobId} funded by submission '
      '${submission.id}',
    );
    return const EffectResult.ok();
  }
}
