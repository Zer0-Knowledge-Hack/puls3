import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;

import '../chain/chain_submission_store.dart';
import '../chain/submission_values.dart';
import '../generated/protocol.dart';
import '../ledger/ledger_errors.dart';
import '../runtime/hire_run_store.dart';
import 'hire_lifecycle_store.dart';

/// Reads one hire for its consumer: `HireEndpoint.getHire` (api.md, F5-5,
/// F6-2, F6-3). It has no side effects, so polling it is safe.
final class HireQueryService {
  HireQueryService({
    required HireLifecycleStore hires,
    required HireRunStore runs,
    required ChainSubmissionStore submissions,
    required Future<AgentSummary?> Function(int registryId) agents,
  }) : _hires = hires,
       _runs = runs,
       _submissions = submissions,
       _agents = agents;

  final HireLifecycleStore _hires;
  final HireRunStore _runs;
  final ChainSubmissionStore _submissions;
  final Future<AgentSummary?> Function(int registryId) _agents;

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
    // Run progress is only shown while the hire is funded (api.md, "Hire
    // escrow states"); later states come from the escrow.
    final showsRun = hire.status == HireStatus.funded;
    final jobId = hire.jobId;
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
      result: run?.result,
      jobId: jobId,
      expiresAt: jobId == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              hire.expiredAt * 1000,
              isUtc: true,
            ),
      escrowSubmission: escrow?.toProtocol(),
      feedbackSubmission: feedback?.toProtocol(),
    );
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
