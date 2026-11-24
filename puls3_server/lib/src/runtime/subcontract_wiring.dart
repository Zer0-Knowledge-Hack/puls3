import 'package:puls3_domain/puls3_domain.dart' show StellarAddress;

import '../chain/chain_log.dart';
import '../chain/chain_submission_store.dart';
import '../chain/escrow_deadline.dart';
import '../hire/child_job_store.dart';
import '../hire/chain_accounts.dart';
import '../hire/escrow_relay_service.dart';
import '../hire/hire_lifecycle_store.dart';
import '../hire/hire_receipt_store.dart';
import '../hire/hire_relay_config.dart';
import '../hire/open_children.dart';
import '../hire/unverified_child_reconciler.dart';
import '../ledger/envelope_codec.dart';
import '../ledger/escrow_job.dart';
import '../ledger/soroban_rpc_client.dart';
import 'escrow_child_result_source.dart';
import 'escrow_subcontract_port.dart';
import 'hire_run_store.dart';
import 'subcontract_setup.dart';
import 'subcontract_tools.dart';

/// How long the runtime lets a run, and a pass, take.
typedef RuntimeTimings = ({Duration staleAfter, Duration passTimeout});

/// The timings of a runtime whose runs may take up to [maxTurns] model calls
/// of [timeout] each (ADR-0011 D8: the loop is bounded by a maximum number of
/// turns per hire, and each model segment keeps the runtime timeout).
///
/// - `staleAfter`: a run still `running` after it was interrupted. One
///   segment can hold [maxTurns] calls before it pauses or ends, so it is
///   `timeout * maxTurns` plus the one minute margin a single call had.
/// - `passTimeout`: a pass resumes up to [batchSize] paused runs and then
///   runs up to [batchSize] queued ones, each up to [maxTurns] calls, so it
///   is `2 * batchSize * maxTurns * timeout` plus the same margin. A pass
///   that exceeds it is only logged and abandoned (`TrackerLoop`), and the
///   conditional run writes keep a late finish safe.
///
/// With [maxTurns] of 1 these are the timings of a runtime without the tool
/// loop (one call per run) for the same batch.
RuntimeTimings runtimeTimings({
  required Duration timeout,
  required int batchSize,
  required int maxTurns,
}) {
  const margin = Duration(minutes: 1);
  return (
    staleAfter: timeout * maxTurns + margin,
    passTimeout: timeout * (2 * batchSize * maxTurns) + margin,
  );
}

/// What one runtime pass needs to run opted-in manifests through the tool
/// loop, resume paused runs, and reconcile their children, all over the same
/// stores.
final class SubcontractServices {
  const SubcontractServices({
    required this.setup,
    required this.reconciler,
    required this.childrenOpen,
  });

  /// For `HireRunner`.
  final SubcontractSetup setup;

  /// Opens or closes children whose `create_child_job` was never confirmed
  /// (`UnverifiedChildReconciler`); the pass runs it once.
  final UnverifiedChildReconciler reconciler;

  /// Whether a parent hire still has an open child, for
  /// `AgentSubmitSender.childrenOpen`.
  final Future<bool> Function(int hireId) childrenOpen;

  /// Runs the reconciler once. A failure (an unreadable store, say) is
  /// logged and swallowed: it must never stop the rest of the pass.
  /// [UnverifiedChildReconciler.reconcile] already isolates each line.
  Future<void> reconcileChildren(ChainLog log) async {
    try {
      await reconciler.reconcile();
    } on Object catch (e) {
      log(ChainLogLevel.error, 'Reconciliation of children failed: $e');
    }
  }
}

/// Composes the real [SubcontractPort], [ChildResultSource] and the
/// reconciler of the subcontract executor (T6.1 to T6.4.4) over one set of
/// stores, so they agree on the same receipt lines, hires and submissions.
///
/// The stores are the ones of one database session; build this per pass.
SubcontractServices buildSubcontractServices({
  required HireLifecycleStore hires,
  required HireReceiptStore receipts,
  required HireRunStore runs,
  required ChainSubmissionStore submissions,
  required ChildJobStore openings,
  required EscrowJobReader jobs,
  required EscrowRelayService relay,
  required ChainAccounts accounts,
  required EnvelopeCodec codec,
  required HireRelayConfig config,
  required ChildAgentLookup childAgent,
  required EscrowApprovalWindow approvalWindow,
  required Future<String> Function(
    PreparedEnvelope prepared,
    StellarAddress signer,
  )
  sign,
  required Future<SendTransactionResult> Function(
    String envelopeXdr,
    String expectedHash,
  )
  send,
  required AgentSearch search,
  required StellarAddress escrow,
  required int inclusionFee,
  required int validitySeconds,
  required int maxTurns,
  RunnerLease? lease,
  DateTime Function()? now,
  ChainLog log = ignoreChainLog,
}) {
  final port = EscrowSubcontractPort(
    hires: hires,
    receipts: receipts,
    submissions: submissions,
    jobs: jobs,
    relay: relay,
    codec: codec,
    config: config,
    childAgent: childAgent,
    approvalWindow: approvalWindow,
    sign: sign,
    send: send,
    now: now,
    log: log,
  );
  final children = EscrowChildResultSource(
    receipts: receipts,
    hires: hires,
    runs: runs,
    submissions: submissions,
    accounts: accounts,
    codec: codec,
    sign: sign,
    send: send,
    escrow: escrow,
    inclusionFee: inclusionFee,
    validitySeconds: validitySeconds,
    now: now,
    log: log,
  );
  return SubcontractServices(
    setup: SubcontractSetup(
      search: search,
      port: port,
      children: children,
      lease: lease,
      maxTurns: maxTurns,
    ),
    reconciler: UnverifiedChildReconciler(
      receipts: receipts,
      hires: hires,
      openings: openings,
      submissions: submissions,
      jobs: jobs,
      escrow: escrow,
      now: now,
      log: log,
    ),
    childrenOpen: OpenChildren(receipts: receipts, hires: hires).anyOpen,
  );
}
