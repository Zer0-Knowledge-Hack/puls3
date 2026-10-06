import 'package:puls3_domain/puls3_domain.dart';

import '../chain/chain_log.dart';
import '../chain/chain_submission_store.dart';
import '../chain/escrow_effects.dart';
import '../chain/submission_values.dart';
import '../ledger/escrow_events.dart';
import '../ledger/escrow_job.dart';

/// Runs [action] with a [HireRepository] that is valid only until it returns,
/// so a composition root can open and close a database session around it.
typedef HireRepositoryScope =
    Future<T> Function<T>(Future<T> Function(HireRepository repository) action);

/// The hire side of the escrow effects (api.md relay step 5).
///
/// After a successful `fund`, [onFunded] reads the job from the escrow,
/// checks it against the hire with [verifyFunding] and, only if every check
/// passes, moves the hire to `paid` through [Hire.pay] and stores the payment
/// with the job id. Anything that does not match is a `JobMismatch` naming
/// the job field; a job the escrow cannot return is `JobEvidenceUnavailable`.
/// A failing chain read is thrown, so the tracker retries the submission.
///
/// Applying the same submission again is harmless: the hire is already paid
/// by its transaction and the effect answers ok without reading the chain.
///
/// The tracker only calls this for transactions the server relayed, and
/// [StoredSubmission.hireId] ties the transaction to its hire. Never call it
/// with a transaction hash a client supplied: anyone can replay a public
/// funding transaction.
final class HireEscrowEffects implements EscrowEffects {
  HireEscrowEffects({
    required HireRepositoryScope repositories,
    required LedgerPort ledger,
    required EscrowJobReader jobs,
    required StellarAddress usdc,
    ChainLog log = ignoreChainLog,
  }) : _repositories = repositories,
       _ledger = ledger,
       _jobs = jobs,
       _usdc = usdc,
       _noJobCreatedEffect = NoopEscrowEffects(log: log);

  final HireRepositoryScope _repositories;
  final LedgerPort _ledger;
  final EscrowJobReader _jobs;
  final StellarAddress _usdc;
  final EscrowEffects _noJobCreatedEffect;

  /// Recording the job id after `create_job` belongs to the hire lifecycle
  /// (#96); until it exists the event is only logged.
  @override
  Future<EffectResult> onJobCreated(
    StoredSubmission submission,
    JobCreatedEvent event,
  ) => _noJobCreatedEffect.onJobCreated(submission, event);

  @override
  Future<EffectResult> onFunded(
    StoredSubmission submission,
    JobFundedEvent event,
  ) async {
    final hireId = submission.hireId;
    if (hireId == null) {
      throw StateError('Fund submission ${submission.id} has no hire');
    }
    return await _repositories(
      (repository) => _fund(repository, HireId(hireId), submission, event),
    );
  }

  Future<EffectResult> _fund(
    HireRepository repository,
    HireId hireId,
    StoredSubmission submission,
    JobFundedEvent event,
  ) async {
    final hire = await repository.findById(hireId);
    final expiredAt = await repository.preparedExpiry(hireId);
    if (hire == null || expiredAt == null) {
      throw StateError(
        'Fund submission ${submission.id} names unknown hire ${hireId.value}',
      );
    }
    switch (hire.status) {
      case HireStatus.requested:
        break;
      case HireStatus.paid
          when hire.paymentTransaction?.value == submission.transactionHash:
        return const EffectResult.ok();
      case HireStatus.paid:
        // Another transaction already paid it: this job is not the hire's.
        return _mismatch(_jobIdField);
      default:
        return _mismatch(null);
    }

    final job = await _jobs.escrowJob(event.jobId);
    if (job == null) {
      return EffectResult.failed(SubmissionOutcomeCode.jobEvidenceUnavailable);
    }
    final agentWallet = await _ledger.agentWallet(hire.agentId);
    if (agentWallet == null) return _mismatch(_providerField);

    final verdict = verifyFunding(
      hire,
      _fundedJob(event.jobId, job),
      transaction: TransactionHash.parse(submission.transactionHash),
      usdc: _usdc,
      agentWallet: agentWallet,
      expiredAt: expiredAt,
    );
    switch (verdict) {
      case FundingRejected(:final reason):
        return _mismatch(reason.field);
      case FundingAccepted(:final payment):
        final paid = hire.pay(payment, agentWallet: agentWallet);
        try {
          await repository.recordPayment(paid, payment, event.jobId);
        } on HirePaymentConflict {
          // The hire, the transaction or the job is already bound.
          return _mismatch(_jobIdField);
        }
        return const EffectResult.ok();
    }
  }
}

const _jobIdField = 'job_id';
const _providerField = 'provider';

EffectResult _mismatch(String? field) =>
    EffectResult.failed(SubmissionOutcomeCode.jobMismatch, field: field);

FundedJob _fundedJob(int jobId, EscrowJob job) => FundedJob(
  jobId: jobId,
  client: job.client,
  evaluator: job.evaluator,
  provider: job.provider,
  token: job.token,
  agentId: job.agentId,
  budget: job.budget,
  expiredAt: job.expiredAt,
  state: switch (job.state) {
    EscrowJobState.open => JobState.open,
    EscrowJobState.funded => JobState.funded,
    EscrowJobState.submitted => JobState.submitted,
    EscrowJobState.completed => JobState.completed,
    EscrowJobState.rejected => JobState.rejected,
    EscrowJobState.expired => JobState.expired,
  },
);
