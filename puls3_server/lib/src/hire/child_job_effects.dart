import 'package:puls3_domain/puls3_domain.dart' show HireStatus, StellarAddress;

import '../chain/chain_log.dart';
import '../chain/chain_submission_store.dart';
import '../chain/escrow_effects.dart';
import '../chain/submission_values.dart';
import '../ledger/escrow_events.dart';
import 'child_job_store.dart';
import 'hire_lifecycle_store.dart';
import 'hire_receipt_store.dart';

/// Runs [action] with the stores a child job effect needs, valid only until
/// it returns, so a composition root can open and close a database session
/// around it.
typedef ChildJobScope =
    Future<T> Function<T>(
      Future<T> Function(
        HireLifecycleStore hires,
        HireReceiptStore receipts,
        ChildJobStore openings,
      )
      action,
    );

/// Failure codes after which the `create_child_job` provably never landed:
/// the transaction failed, the node refused the envelope, or the node still
/// retains every ledger since it was stored and never saw it. Every other
/// code may hide a landed child.
const _neverLanded = {
  SubmissionOutcomeCode.transactionFailed,
  SubmissionOutcomeCode.submissionRejected,
  SubmissionOutcomeCode.preparationExpired,
};

/// The child side of the escrow effects (ADR-0011 D2, D7): what a tracked
/// A-signed `create_child_job` does to the child hire and its receipt line.
///
/// [onChildJobCreated] proves the transaction's events against the stored
/// child before anything is written. The single `ChildJobCreated` must name
/// the parent hire's job, the line's provider wallet, the child's agent and
/// price and a zero reserve (D5); the child job's `JobCreated` must have the
/// child's consumer (the parent agent's wallet) as client and evaluator, the
/// same provider, agent and budget and the child's stored `expired_at`; its
/// `JobFunded` the same client and the budget. Only then does
/// [ChildJobStore.open] bind the job, record the payment (payer the parent
/// agent, payee the subcontracted agent, the transaction as payment) and
/// queue the child's run, with the receipt line, in one transaction.
///
/// Anything that does not match is a terminal `JobMismatch` naming the
/// field (`job_id` when the events are missing, ambiguous or bound
/// elsewhere); nothing is funded. The tracker then calls [onChildJobFailed],
/// which leaves the line [ReceiptLineState.unverified] for reconciliation.
///
/// Applying the same submission again answers ok without writing.
final class ChildJobEffects {
  ChildJobEffects({
    required ChildJobScope scope,
    required StellarAddress escrow,
    ChainLog log = ignoreChainLog,
  }) : _scope = scope,
       _escrow = escrow,
       _log = log;

  final ChildJobScope _scope;

  /// The escrow contract the tracker reads the events from; bound to the
  /// child hire with its job (#273).
  final StellarAddress _escrow;
  final ChainLog _log;

  /// See [EscrowEffects.onChildJobCreated].
  Future<EffectResult> onChildJobCreated(
    StoredSubmission submission,
    List<ChildJobCreatedEvent> children, {
    required List<JobCreatedEvent> created,
    required List<JobFundedEvent> funded,
  }) async {
    final childHireId = submission.hireId;
    // T6.1 stores every create_child_job with its child hire.
    if (childHireId == null) return _mismatch(null);
    return await _scope((hires, receipts, openings) async {
      final child = await hires.findHire(childHireId);
      final parentHireId = child?.parentHireId;
      final line = await receipts.findByChildHire(childHireId);
      // The child, its parent link and its line are stored together, so a
      // missing one cannot appear later: terminal, not retried.
      if (child == null || parentHireId == null || line == null) {
        return _mismatch(null);
      }
      final parentJobId = (await hires.findHire(parentHireId))?.jobId;
      final proof = _prove(
        child,
        line,
        parentJobId,
        children: children,
        created: created,
        funded: funded,
      );
      final childJob = proof.job;
      if (childJob == null) {
        _log(
          ChainLogLevel.warning,
          'create_child_job of child hire $childHireId does not match it '
          '(${proof.field}); it is not funded',
        );
        return _mismatch(proof.field);
      }
      final opened = await openings.open(
        ChildJobOpening(
          childHireId: childHireId,
          jobId: childJob.jobId,
          expiredAt: childJob.expiredAt,
          escrow: _escrow.value,
          transactionHash: submission.transactionHash,
          payer: child.consumer,
          payee: line.providerWallet,
          amount: child.price,
        ),
      );
      return switch (opened) {
        ChildJobOpened.opened ||
        ChildJobOpened.alreadyOpened => const EffectResult.ok(),
        ChildJobOpened.taken => _mismatch(_jobIdField),
      };
    });
  }

  /// See [EscrowEffects.onChildJobFailed]. A [code] that proves the child
  /// never landed marks a `pending` line [ReceiptLineState.notOpened]; any
  /// other marks it [ReceiptLineState.unverified]. A line that already left
  /// `pending` is not changed.
  Future<void> onChildJobFailed(
    StoredSubmission submission,
    String code,
  ) async {
    final childHireId = submission.hireId;
    if (childHireId == null) return;
    final neverLanded = _neverLanded.contains(code);
    final changed = await _scope(
      (hires, receipts, openings) => neverLanded
          ? receipts.markNotOpened(childHireId)
          : receipts.markUnverified(childHireId),
    );
    if (changed) {
      _log(
        ChainLogLevel.warning,
        'create_child_job of child hire $childHireId failed ($code); its '
        'receipt line is '
        '${neverLanded ? ReceiptLineState.notOpened : ReceiptLineState.unverified}',
      );
    }
  }

  /// See [EscrowEffects.onChildSettled]. A `childComplete` moves the line to
  /// `completed` with the fee and payout of the child job's `JobCompleted`
  /// (unset when the transaction shows none for that job); a `childReject`
  /// moves it to `rejected` with both 0, since the budget went back to the
  /// parent's reserve (ADR-0011 D3). Only an opened, unsettled line moves,
  /// so applying the same verdict again writes nothing.
  Future<void> onChildSettled(
    StoredSubmission submission,
    List<JobCompletedEvent> completed,
  ) async {
    final childHireId = submission.hireId;
    if (childHireId == null) return;
    final complete = submission.purpose == SubmissionPurpose.childComplete;
    await _scope((hires, receipts, openings) async {
      final jobId = (await hires.findHire(childHireId))?.jobId;
      final events = completed.where((e) => e.jobId == jobId).toList();
      final event = events.length == 1 ? events.single : null;
      final settled = await receipts.markSettled(
        childHireId,
        state: complete ? HireStatus.completed.name : HireStatus.rejected.name,
        fee: complete ? event?.fee.toInt() : 0,
        payout: complete ? event?.payout.toInt() : 0,
        settleTransaction: submission.transactionHash,
      );
      if (settled && complete && event == null) {
        _log(
          ChainLogLevel.warning,
          'The complete of child hire $childHireId shows no JobCompleted for '
          'job $jobId; its fee and payout stay unset',
        );
      }
    });
  }
}

/// The child's `JobCreated` when every event matches the stored child, or
/// the first mismatching field.
({JobCreatedEvent? job, String? field}) _prove(
  HireRow child,
  ReceiptLine line,
  int? parentJobId, {
  required List<ChildJobCreatedEvent> children,
  required List<JobCreatedEvent> created,
  required List<JobFundedEvent> funded,
}) {
  ({JobCreatedEvent? job, String? field}) mismatch(String field) =>
      (job: null, field: field);
  // One create_child_job call opens one child.
  if (children.length != 1) return mismatch(_jobIdField);
  final event = children.single;
  final budget = BigInt.from(child.price);
  if (parentJobId == null || event.parentJobId != parentJobId) {
    return mismatch('parent_job_id');
  }
  if (event.provider.value != line.providerWallet) return mismatch('provider');
  if (event.agentId.value != child.agentId) return mismatch('agent_id');
  if (event.budget != budget || line.budget != child.price) {
    return mismatch('budget');
  }
  if (event.reserve != BigInt.from(child.subcontractReserve)) {
    return mismatch('reserve');
  }
  final jobs = created.where((e) => e.jobId == event.childJobId).toList();
  final funds = funded.where((e) => e.jobId == event.childJobId).toList();
  if (jobs.length != 1 || funds.length != 1) return mismatch(_jobIdField);
  final job = jobs.single;
  final fund = funds.single;
  if (job.client.value != child.consumer ||
      job.evaluator.value != child.consumer ||
      fund.client.value != child.consumer) {
    return mismatch('client');
  }
  if (job.provider.value != event.provider.value) return mismatch('provider');
  if (job.agentId.value != event.agentId.value) return mismatch('agent_id');
  if (job.budget != budget) return mismatch('budget');
  if (job.expiredAt != child.expiredAt) return mismatch('expired_at');
  if (fund.amount != budget) return mismatch('amount');
  return (job: job, field: null);
}

const _jobIdField = 'job_id';

EffectResult _mismatch(String? field) =>
    EffectResult.failed(SubmissionOutcomeCode.jobMismatch, field: field);
