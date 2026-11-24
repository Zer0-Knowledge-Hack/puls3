import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;

import '../agent/custodied_wallets.dart';
import '../chain/chain_submission_store.dart';
import '../chain/escrow_deadline.dart' show maxEscrowCallAttempts;
import '../chain/submission_values.dart';
import '../generated/protocol.dart';
import '../ledger/escrow_job.dart';
import '../ledger/ledger_errors.dart';
import '../runtime/hire_run_store.dart';
import 'escrow_preparation_store.dart';
import 'hire_lifecycle_store.dart';

/// One of the caller's active Studio agents, which pays hires from its own
/// custodied [wallet].
typedef PayingAgent = ({int registryId, String wallet});

/// The `HireDetail.submitErrorCode` value of a hire whose payee the server
/// does not custody (the same rule as `createHire` and the due-submit
/// tracker).
const agentCannotDeliverCode = 'AgentCannotDeliver';

/// Reads one hire for its consumer: `HireEndpoint.getHire` (api.md, F5-5,
/// F6-2, F6-3). It never writes, so polling it is safe. Reading the escrow
/// job for `approvalDeadline` is a chain read, not a submission.
final class HireQueryService {
  HireQueryService({
    required HireLifecycleStore hires,
    required HireRunStore runs,
    required ChainSubmissionStore submissions,
    required Future<AgentSummary?> Function(int registryId) agents,
    EscrowPreparationStore? preparations,
    EscrowJobReader? jobs,
    DateTime Function()? now,
    CustodyLookup? custody,
  }) : _hires = hires,
       _runs = runs,
       _submissions = submissions,
       _agents = agents,
       _preparations = preparations,
       _jobs = jobs,
       _now = now ?? DateTime.now,
       _custody = custody;

  final HireLifecycleStore _hires;
  final HireRunStore _runs;
  final ChainSubmissionStore _submissions;
  final Future<AgentSummary?> Function(int registryId) _agents;
  final EscrowPreparationStore? _preparations;
  final EscrowJobReader? _jobs;
  final DateTime Function() _now;
  final CustodyLookup? _custody;

  /// How many hires [listMyHires] returns at most.
  static const listLimit = 100;

  /// How many characters of the input a [HireSummary] keeps.
  static const inputPreviewLength = 140;

  /// The hires of [wallet], newest first, at most [listLimit]: the list the
  /// app shows so the consumer can get back to any of them. An agent the
  /// catalog cannot name keeps a generic name, so one missing agent never
  /// hides the whole list.
  ///
  /// [agents] are the caller's active Studio agents (the caller checked the
  /// ownership): the hires they made from their own wallet are listed too,
  /// each naming the agent that paid.
  Future<List<HireSummary>> listMyHires(
    StellarAddress wallet, {
    Iterable<PayingAgent> agents = const [],
  }) async {
    final rows = <(HireRow, PayingAgent?)>[
      for (final hire in await _hires.listByConsumer(
        wallet.value,
        limit: listLimit,
      ))
        (hire, null),
    ];
    for (final agent in agents) {
      if (agent.wallet == wallet.value) continue;
      for (final hire in await _hires.listByConsumer(
        agent.wallet,
        limit: listLimit,
      )) {
        rows.add((hire, agent));
      }
    }
    rows.sort((a, b) => b.$1.id.compareTo(a.$1.id));
    if (rows.length > listLimit) rows.removeRange(listLimit, rows.length);
    final names = <int, String>{};
    final now = _now().toUtc();
    final summaries = <HireSummary>[];
    for (final (hire, payer) in rows) {
      final name = names[hire.agentId] ??= await _agentName(hire.agentId);
      final status = hire.status;
      // Only a submitted hire waits on its approval window; a completed one
      // has nothing left to decide, so the chain is not read for it.
      final deadline = status == HireStatus.submitted
          ? await _approvalDeadline(status, hire.jobId)
          : null;
      summaries.add(
        HireSummary(
          id: hire.id,
          agentId: hire.agentId,
          agentName: name,
          status: status?.name,
          priceUsdcStroops: hire.price,
          inputPreview: _preview(hire.input ?? ''),
          approvalDeadline: deadline,
          needsAction: await _needsAction(hire, deadline, now),
          paidByAgentId: payer?.registryId,
          paidByAgentName: payer == null
              ? null
              : names[payer.registryId] ??= await _agentName(
                  payer.registryId,
                ),
        ),
      );
    }
    return summaries;
  }

  /// The consumer must act on a submitted hire whose approval window is
  /// still open (a missing deadline counts as open, like the app does), and
  /// on a funded hire whose run failed: rejecting it refunds the payment.
  Future<bool> _needsAction(
    HireRow hire,
    DateTime? deadline,
    DateTime now,
  ) async {
    switch (hire.status) {
      case HireStatus.submitted:
        return deadline == null || now.isBefore(deadline);
      case HireStatus.funded:
        final run = await _runs.find(hire.id);
        return run?.state == HireRunState.failed;
      default:
        return false;
    }
  }

  static String _preview(String input) {
    final trimmed = input.trim();
    if (trimmed.length <= inputPreviewLength) return trimmed;
    return '${trimmed.substring(0, inputPreviewLength).trimRight()}…';
  }

  Future<String> _agentName(int registryId) async {
    try {
      return (await _agents(registryId))?.name ?? 'Agent #$registryId';
    } on LedgerException {
      return 'Agent #$registryId';
    } on AgentCatalogUnavailable {
      return 'Agent #$registryId';
    }
  }

  /// The hire [hireId] as [wallet], its consumer, sees it: escrow status,
  /// run progress and result, job expiry and the latest escrow submission.
  ///
  /// Fails with `InvalidHireId`, `HireNotFound`, `HireNotOwned` or
  /// `ChainDataUnavailable`.
  Future<HireDetail> getHire(StellarAddress wallet, int hireId) async {
    if (hireId < 1) throw _api('InvalidHireId');
    final hire = await _hires.findHire(hireId);
    if (hire == null) throw _api('HireNotFound');
    if (hire.consumer != wallet.value) throw _api('HireNotOwned');

    final agent = await _agentOf(hire.agentId);
    final run = await _runs.find(hireId);
    final submissions = await _submissions.listByHire(hireId);
    // The rating is its own record: a give_feedback is never the hire's
    // escrow submission (api.md, HireDetail).
    final escrow = _latest(
      submissions.where((s) => s.purpose != SubmissionPurpose.giveFeedback),
    );
    final feedback = _feedbackOf(submissions);
    final feedbackScore = await _feedbackScore(feedback);
    // Run progress is only shown while the hire is funded (api.md, "Hire
    // escrow states"); later states come from the escrow.
    final showsRun = hire.status == HireStatus.funded;
    final jobId = hire.jobId;
    final runFinished = showsRun && run?.state == HireRunState.succeeded;
    return HireDetail(
      hire: hire.toProtocol().copyWith(
        runtimeStatus: showsRun ? run?.state.runtimeStatus.name : null,
        failureReason: showsRun ? run?.failureReason : null,
        // Derived like `FeedbackService.submit` does: no column stores it.
        feedbackReference: feedback != null && !_failed(feedback)
            ? feedback.transactionHash
            : null,
      ),
      agent: agent,
      input: hire.input ?? '',
      result: showsResult(hire.status) ? run?.result : null,
      jobId: jobId,
      expiresAt: jobId == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              hire.expiredAt * 1000,
              isUtc: true,
            ),
      approvalDeadline: await _approvalDeadline(hire.status, jobId),
      runFinished: runFinished,
      submitErrorCode: await _submitErrorCode(hire, submissions),
      escrowSubmission: escrow?.toProtocol(),
      feedbackSubmission: feedback?.toProtocol(),
      feedbackScore: feedbackScore,
    );
  }

  /// Why a funded hire's `submit` cannot land, or null while it can still
  /// happen. A `submit` in flight wins: the tracker owns it.
  ///
  /// A payee the server does not custody can never sign a `submit` (#276),
  /// so an existing funded hire of one reports [agentCannotDeliverCode]. The
  /// other reasons are the terminal submit outcomes: the job expired or was
  /// too late (`SubmitSimulationRejected`), the attempts ran out
  /// (`EscrowCallFailed`), or the outcome may have landed unseen
  /// (`OutcomeUnknown`). Transient simulation failures are left for the
  /// tracker to retry.
  Future<String?> _submitErrorCode(
    HireRow hire,
    List<StoredSubmission> submissions,
  ) async {
    if (hire.status != HireStatus.funded) return null;
    final submits = submissions
        .where((s) => s.purpose == SubmissionPurpose.submit)
        .toList();
    if (submits.any((s) => s.state == SubmissionState.submitted)) return null;
    // An unknown outcome on any escrow call may have moved funds, so every
    // preparation is refused for this hire; report it before the submit-only
    // reasons and before the custody rule.
    if (submissions.any(
      (s) => s.errorCode == SubmissionOutcomeCode.outcomeUnknown,
    )) {
      return SubmissionOutcomeCode.outcomeUnknown;
    }
    final failed = submits.where(_failed).toList();
    if (failed.any(
      (s) => s.errorCode == SubmissionOutcomeCode.submitSimulationRejected,
    )) {
      return SubmissionOutcomeCode.submitSimulationRejected;
    }
    if (failed.length >= maxEscrowCallAttempts) {
      return SubmissionOutcomeCode.escrowCallFailed;
    }
    final custody = _custody;
    final payee = hire.payee;
    if (custody != null && payee != null) {
      final custodied = await custody({payee});
      if (!custodied.contains(payee)) return agentCannotDeliverCode;
    }
    return null;
  }

  /// The score a reloaded S06 shows (#242). It is the one stored with the
  /// non-failed `giveFeedback` preparation. A failed rating has no score.
  Future<int?> _feedbackScore(StoredSubmission? feedback) async {
    final preparations = _preparations;
    final preparationId = feedback?.preparationId;
    if (preparations == null ||
        feedback == null ||
        _failed(feedback) ||
        preparationId == null) {
      return null;
    }
    final preparation = await preparations.findByPreparationId(preparationId);
    return preparation?.feedbackScore;
  }

  /// Whether a hire in [status] shows the agent's output (#204, audit E-1).
  ///
  /// The output is the deliverable, so the client reads it once the agent
  /// has submitted it on chain, to evaluate it (`submitted`), and keeps it
  /// after approving (`completed`). While the hire is `funded` the escrow
  /// still lets the client reject with a full refund, so an output shown
  /// before `submit` lands would be a free service. A `rejected` or
  /// `expired` hire was refunded and shows none.
  static bool showsResult(HireStatus? status) =>
      status == HireStatus.submitted || status == HireStatus.completed;

  /// The job's approval window, once the agent has submitted. A chain read
  /// that fails leaves the deadline unset so the hire stays readable.
  Future<DateTime?> _approvalDeadline(HireStatus? status, int? jobId) async {
    final jobs = _jobs;
    if (jobs == null ||
        jobId == null ||
        (status != HireStatus.submitted && status != HireStatus.completed)) {
      return null;
    }
    try {
      final job = await jobs.escrowJob(jobId);
      if (job == null || job.approvalDeadline <= 0) return null;
      return DateTime.fromMillisecondsSinceEpoch(
        job.approvalDeadline * 1000,
        isUtc: true,
      );
    } on LedgerException {
      return null;
    }
  }

  static StoredSubmission? _latest(Iterable<StoredSubmission> submissions) =>
      submissions.isEmpty
      ? null
      : submissions.reduce((a, b) => b.id > a.id ? b : a);

  static bool _failed(StoredSubmission submission) =>
      submission.state == SubmissionState.failed;

  /// The hire's rating: its `giveFeedback` that is not `failed` (the one that
  /// makes the hire rated), else the latest failed attempt so the client can
  /// show why it did not go through.
  static StoredSubmission? _feedbackOf(List<StoredSubmission> submissions) {
    final given = submissions.where(
      (s) => s.purpose == SubmissionPurpose.giveFeedback,
    );
    return _latest(given.where((s) => !_failed(s))) ?? _latest(given);
  }

  Future<AgentSummary> _agentOf(int registryId) async {
    try {
      return await _agents(registryId) ?? (throw _api('ChainDataUnavailable'));
    } on LedgerException {
      throw _api('ChainDataUnavailable');
    } on AgentCatalogUnavailable {
      throw _api('ChainDataUnavailable');
    }
  }

  static Puls3ApiException _api(String code) => Puls3ApiException(code: code);
}
