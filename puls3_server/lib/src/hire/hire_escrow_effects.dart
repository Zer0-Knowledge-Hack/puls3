import 'package:puls3_domain/puls3_domain.dart';

import '../chain/chain_submission_store.dart';
import '../chain/escrow_effects.dart';
import '../chain/submission_values.dart';
import '../ledger/escrow_events.dart';
import '../ledger/escrow_job.dart';
import 'escrow_preparation_store.dart';
import 'hire_lifecycle_store.dart';

/// Runs [action] with a [HireRepository] that is valid only until it returns,
/// so a composition root can open and close a database session around it.
typedef HireRepositoryScope =
    Future<T> Function<T>(Future<T> Function(HireRepository repository) action);

/// Like [HireRepositoryScope], for the relay's view of a hire and its
/// preparations.
typedef HireLifecycleScope =
    Future<T> Function<T>(
      Future<T> Function(
        HireLifecycleStore hires,
        EscrowPreparationStore preparations,
      )
      action,
    );

/// The hire side of the escrow effects (api.md relay step 5).
///
/// After a successful `create_job`, [onJobCreated] binds the job id to the
/// hire named by the submission, which opens it, and takes the job's
/// `expired_at` from the preparation the submission relayed. A job id that
/// is already bound to another hire, or a hire that already holds another
/// job, is a `JobMismatch` on `job_id`. Applying it again is a no-op.
///
/// After a successful `fund`, [onFunded] reads the job from the escrow,
/// checks it against the hire with [verifyFunding] and, only if every check
/// passes, moves the hire to `funded` through [Hire.fund] and stores the payment
/// with the job id. Anything that does not match is a `JobMismatch` naming
/// the job field; a job the escrow cannot return is `JobEvidenceUnavailable`.
/// A failing chain read is thrown, so the tracker retries the submission. A
/// submission without a hire, or naming an unknown one, can never succeed and
/// is a terminal `JobMismatch` without a field.
///
/// `details.field` is `job_id` whenever the funding cannot be bound to the
/// hire although the job itself may be valid: the hire is already funded by
/// another transaction (replay), or the store reports that the hire, the
/// transaction or the job id is already bound (wrong transaction or
/// duplicate job). They share one field because the contract defines only the
/// job fields; the effect does not report which of them applied.
///
/// Applying the same submission again is harmless: the hire is already funded
/// by its transaction and the effect answers ok without reading the chain.
///
/// The tracker only calls this for transactions the server relayed, and
/// [StoredSubmission.hireId] ties the transaction to its hire. Never call it
/// with a transaction hash a client supplied: anyone can replay a public
/// funding transaction.
final class HireEscrowEffects implements EscrowEffects {
  HireEscrowEffects({
    required HireRepositoryScope repositories,
    required HireLifecycleScope lifecycle,
    required LedgerPort ledger,
    required EscrowJobReader jobs,
    required StellarAddress usdc,
  }) : _repositories = repositories,
       _lifecycle = lifecycle,
       _ledger = ledger,
       _jobs = jobs,
       _usdc = usdc;

  final HireRepositoryScope _repositories;
  final HireLifecycleScope _lifecycle;
  final LedgerPort _ledger;
  final EscrowJobReader _jobs;
  final StellarAddress _usdc;

  @override
  Future<EffectResult> onJobCreated(
    StoredSubmission submission,
    JobCreatedEvent event,
  ) async {
    final hireId = submission.hireId;
    // Like a fund, a create_job the server relayed always carries its hire.
    if (hireId == null) return _mismatch(null);
    return await _lifecycle((hires, preparations) async {
      // A relayed create_job always has its hire and preparation, so a
      // missing one breaks an invariant: thrown, so the tracker retries.
      final hire = await hires.findHire(hireId);
      if (hire == null) throw StateError('hire $hireId does not exist');
      final preparationId = submission.preparationId;
      final preparation = preparationId == null
          ? null
          : await preparations.findByPreparationId(preparationId);
      final expiredAt = preparation?.jobExpiredAt;
      if (expiredAt == null) {
        throw StateError(
          'submission ${submission.id} has no prepared create_job expiry',
        );
      }
      final binding = await hires.bindJob(
        hireId,
        event.jobId,
        expiredAt: expiredAt,
      );
      return switch (binding) {
        JobBinding.bound || JobBinding.alreadyBound => const EffectResult.ok(),
        JobBinding.taken => _mismatch(_jobIdField),
      };
    });
  }

  @override
  Future<EffectResult> onFunded(
    StoredSubmission submission,
    JobFundedEvent event,
  ) async {
    final hireId = submission.hireId;
    // A fund submission the server relayed always carries its hire; if it
    // does not, no retry can ever fix it, so it is a terminal mismatch
    // rather than an error the tracker would retry forever.
    if (hireId == null) return _mismatch(null);
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
    // An unknown hire cannot appear later: terminal, not retried.
    if (hire == null || expiredAt == null) return _mismatch(null);
    switch (hire.status) {
      case HireStatus.open:
        break;
      case HireStatus.funded
          when hire.paymentTransaction?.value == submission.transactionHash:
        return const EffectResult.ok();
      case HireStatus.funded:
        // Another transaction already funded it: this job is not the hire's.
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
        final funded = hire.fund(payment, agentWallet: agentWallet);
        try {
          await repository.recordPayment(funded, payment, event.jobId);
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
