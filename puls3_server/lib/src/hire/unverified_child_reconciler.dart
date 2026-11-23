import 'package:puls3_domain/puls3_domain.dart' show StellarAddress;

import '../chain/chain_log.dart';
import '../chain/chain_submission_store.dart';
import '../chain/submission_values.dart';
import '../ledger/escrow_job.dart';
import '../ledger/ledger_errors.dart';
import 'child_job_store.dart';
import 'hire_lifecycle_store.dart';
import 'hire_receipt_store.dart';

/// Reconciles child receipt lines whose `create_child_job` could not be
/// proven against the chain (ADR-0011 D7, T6.4.4).
///
/// Such a line is [ReceiptLineState.unverified], or still
/// [ReceiptLineState.pending] once every `create_child_job` of its child is
/// final. Without reconciliation, its child never runs, the parent waits
/// until its own deadline, and the deadline relay never reaches the child,
/// because no job is bound to it.
///
/// User decision 2026-11-23: the child job is looked for on the chain by its
/// fields, not by re-reading the transaction:
/// - The node may have lost the transaction past its retention, which is
///   one of the ways a line becomes unverified, so a re-read fails exactly
///   there.
/// - The escrow keeps no index of children by parent. A child job's id is
///   always above its parent's, so the scan reads every job from the
///   parent's id + 1 up to the first id that does not exist.
///
/// A job matches when its `parent_job_id`, provider, agent, budget, client,
/// evaluator, `expired_at` and zero reserve (D5) are the child's, the same
/// fields `ChildJobEffects` proves from the events. Then:
/// - exactly one match: the line goes back to pending and
///   [ChildJobStore.open] binds, pays and queues the child, as a confirmed
///   `create_child_job` would. A child left with too little time fails its
///   run, and the relay refunds it;
/// - more than one match: it is ambiguous, nothing is written and the line
///   waits;
/// - no match: the line is [ReceiptLineState.notOpened], but only once no
///   `create_child_job` was confirmed and every envelope's `validUntil`
///   has passed. Before that the transaction could still land.
///
/// A line with a `create_child_job` still in flight belongs to the tracker
/// and is skipped. Every write is a conditional pending-only one, so a
/// tracker that reaches the same line at the same time changes nothing
/// twice. Archived jobs are skipped, because an open child is live; any
/// other chain error defers the line to a later pass. The cost is one
/// `get_job` per job created since the parent, and only for these rare
/// lines. Not wired in production until T6.4.5.
final class UnverifiedChildReconciler {
  UnverifiedChildReconciler({
    required HireReceiptStore receipts,
    required HireLifecycleStore hires,
    required ChildJobStore openings,
    required ChainSubmissionStore submissions,
    required EscrowJobReader jobs,
    required StellarAddress escrow,
    DateTime Function()? now,
    ChainLog log = ignoreChainLog,
  }) : _receipts = receipts,
       _hires = hires,
       _openings = openings,
       _submissions = submissions,
       _jobs = jobs,
       _escrow = escrow,
       _now = now ?? DateTime.now,
       _log = log;

  final HireReceiptStore _receipts;
  final HireLifecycleStore _hires;
  final ChildJobStore _openings;
  final ChainSubmissionStore _submissions;
  final EscrowJobReader _jobs;
  final StellarAddress _escrow;
  final DateTime Function() _now;
  final ChainLog _log;

  /// Reconciles every unopened line once. One line that cannot be read is
  /// logged and does not hold the others.
  Future<void> reconcile() async {
    for (final line in await _receipts.listUnopened()) {
      final childHireId = line.childHireId;
      if (childHireId == null) continue;
      try {
        await _reconcile(line, childHireId);
      } on Object catch (e) {
        _log(
          e is LedgerException ? ChainLogLevel.warning : ChainLogLevel.error,
          'Reconciliation of child hire $childHireId deferred: $e',
        );
      }
    }
  }

  Future<void> _reconcile(ReceiptLine line, int childHireId) async {
    final creates = [
      for (final row in await _submissions.listByHire(childHireId))
        if (row.purpose == SubmissionPurpose.createChildJob) row,
    ];
    if (creates.isEmpty || creates.any((row) => !row.state.isFinal)) return;
    final child = await _hires.findHire(childHireId);
    final parentHireId = child?.parentHireId;
    if (child == null || parentHireId == null) return;
    final parentJobId = (await _hires.findHire(parentHireId))?.jobId;
    if (parentJobId == null) return;

    final matches = await _matches(child, line, parentJobId);
    if (matches.length > 1) {
      _log(
        ChainLogLevel.warning,
        'Child hire $childHireId matches jobs '
        '${[for (final m in matches) m.id]}; it stays unreconciled',
      );
      return;
    }
    if (matches.length == 1) {
      final match = matches.single;
      await _receipts.reopenUnverified(childHireId);
      final opened = await _openings.open(
        ChildJobOpening(
          childHireId: childHireId,
          jobId: match.id,
          expiredAt: match.job.expiredAt,
          escrow: _escrow.value,
          transactionHash:
              line.createTransaction ?? creates.last.transactionHash,
          payer: child.consumer,
          payee: line.providerWallet,
          amount: child.price,
        ),
      );
      if (opened == ChildJobOpened.taken) {
        // Another hire holds the job: this child is still not proven.
        await _receipts.markUnverified(childHireId);
        _log(
          ChainLogLevel.warning,
          'Child hire $childHireId matches job ${match.id}, which another '
          'hire holds; it stays ${ReceiptLineState.unverified}',
        );
        return;
      }
      _log(
        ChainLogLevel.info,
        'Child hire $childHireId reconciled with job ${match.id}: '
        '${opened.name}',
      );
      return;
    }
    final landed = creates.any((row) => row.state == SubmissionState.confirmed);
    final now = _now().toUtc();
    final mayLand = creates.any((row) => !now.isAfter(row.validUntil));
    if (landed || mayLand) return;
    await _receipts.reopenUnverified(childHireId);
    if (await _receipts.markNotOpened(childHireId)) {
      _log(
        ChainLogLevel.info,
        'Child hire $childHireId has no job on the chain; its receipt line '
        'is ${ReceiptLineState.notOpened}',
      );
    }
  }

  /// The jobs above [parentJobId] that are this child, read up to the first
  /// id that does not exist.
  Future<List<({int id, EscrowJob job})>> _matches(
    HireRow child,
    ReceiptLine line,
    int parentJobId,
  ) async {
    final found = <({int id, EscrowJob job})>[];
    for (var id = parentJobId + 1; ; id++) {
      final EscrowJob? job;
      try {
        job = await _jobs.escrowJob(id);
      } on LedgerUnavailable catch (e) {
        if (e.archived) continue;
        rethrow;
      }
      if (job == null) return found;
      if (_isChild(job, child, line, parentJobId)) {
        found.add((id: id, job: job));
      }
    }
  }

  static bool _isChild(
    EscrowJob job,
    HireRow child,
    ReceiptLine line,
    int parentJobId,
  ) =>
      job.parentJobId == parentJobId &&
      job.provider.value == line.providerWallet &&
      job.agentId.value == child.agentId &&
      job.budget == BigInt.from(child.price) &&
      line.budget == child.price &&
      job.client.value == child.consumer &&
      job.evaluator.value == child.consumer &&
      job.expiredAt == child.expiredAt &&
      job.reserve == BigInt.from(child.subcontractReserve);
}
