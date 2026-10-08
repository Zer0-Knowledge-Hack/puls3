import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;

import '../chain/chain_submission_store.dart';
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
    final latest = submissions.isEmpty
        ? null
        : submissions.reduce((a, b) => b.id > a.id ? b : a);
    // Run progress is only shown while the hire is funded (api.md, "Hire
    // escrow states"); later states come from the escrow.
    final showsRun = hire.status == HireStatus.funded;
    final jobId = hire.jobId;
    return HireDetail(
      hire: hire.toProtocol().copyWith(
        runtimeStatus: showsRun ? run?.state.runtimeStatus.name : null,
        failureReason: showsRun ? run?.failureReason : null,
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
      escrowSubmission: latest?.toProtocol(),
    );
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
