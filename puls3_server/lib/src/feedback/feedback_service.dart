import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;

import '../chain/chain_submission_store.dart';
import '../chain/submission_values.dart';
import '../generated/protocol.dart';
import '../hire/escrow_preparation_store.dart';
import '../hire/escrow_relay_service.dart';
import '../hire/hire_lifecycle_store.dart';
import '../ledger/ledger_errors.dart';
import 'reputation_calls.dart';

/// The score of the throwaway [Feedback] that carries a hire's facts through
/// the owner rule, which does not depend on the score.
const _probeScore = 1;

/// Lets the consumer of a completed hire rate it: eligibility, the unsigned
/// `give_feedback` and its relay (api.md, `FeedbackEndpoint`).
///
/// The rules are the domain's [checkHireRateable] and [checkFeedbackAllowed];
/// this service only feeds them from the stored hire and the chain and maps
/// the errors to the wire catalog. The call itself is built by
/// [ReputationCalls] and relayed by the [EscrowRelayService], so the server
/// never signs and the Reputation Registry ABI (#14) stays behind a port.
///
/// A hire is rated once a `giveFeedback` submission of it exists that is not
/// `failed`; its transaction is the hire's `feedbackReference`, which
/// `HireQueryService.getHire` derives the same way. No column stores it, so no
/// migration is needed.
final class FeedbackService {
  FeedbackService({
    required HireLifecycleStore hires,
    required ChainSubmissionStore submissions,
    required EscrowPreparationStore preparations,
    required AgentOwnerReader owners,
    required ReputationCalls calls,
    required EscrowRelayService relay,
  }) : _hires = hires,
       _submissions = submissions,
       _preparations = preparations,
       _owners = owners,
       _calls = calls,
       _relay = relay;

  final HireLifecycleStore _hires;
  final ChainSubmissionStore _submissions;
  final EscrowPreparationStore _preparations;
  final AgentOwnerReader _owners;
  final ReputationCalls _calls;
  final EscrowRelayService _relay;

  /// Whether [wallet] may rate hire [hireId] and, when not, which rule says
  /// no. A broken rule is a result here, never an error; only a hire that
  /// cannot be read is.
  ///
  /// Fails with `InvalidHireId`, `HireNotFound`, `HireNotOwned` or
  /// `ChainDataUnavailable`.
  Future<FeedbackEligibility> eligibility(
    StellarAddress wallet,
    int hireId,
  ) async {
    final hire = await _ownedHire(wallet, hireId);
    try {
      await _requireRateable(hire, wallet, await _isRated(hire.id));
    } on Puls3ApiException catch (e) {
      if (!_isRule(e.code)) rethrow;
      return FeedbackEligibility(
        hireId: hireId,
        eligible: false,
        reason: e.code,
      );
    }
    return FeedbackEligibility(hireId: hireId, eligible: true);
  }

  /// The unsigned `give_feedback` of hire [hireId] with [score] and
  /// [comment], when the hire may be rated.
  ///
  /// Fails with the errors of [eligibility], `InvalidFeedback`,
  /// `SubmissionInProgress`, `InvalidHireTransition` or
  /// `HireConfigurationMissing` while no registry is configured.
  Future<PreparedTransaction> prepare(
    StellarAddress wallet,
    int hireId,
    int score,
    String comment,
  ) async {
    final hire = await _ownedHire(wallet, hireId);
    final feedback = _feedbackOf(hire, wallet, score, comment);
    await _requireRateable(hire, wallet, await _isRated(hire.id));
    final call = _calls.giveFeedback(
      client: wallet,
      agent: AgentId(hire.agentId),
      feedback: feedback,
    );
    return _relay.prepareFeedback(wallet, hire.id, call);
  }

  /// Relays the signed `give_feedback` of [preparationId]. The rules are
  /// checked again; a replay of a preparation that was already submitted
  /// returns its record.
  ///
  /// The detail carries the record as `feedbackSubmission` and, unless it
  /// failed, its transaction as `hire.feedbackReference`. The status stays
  /// `completed`.
  Future<HireDetail> submit(
    StellarAddress wallet,
    int hireId,
    String preparationId,
    String signedTransactionXdr,
  ) async {
    final hire = await _ownedHire(wallet, hireId);
    final prepared = await _preparations.findByPreparationId(preparationId);
    if (prepared == null ||
        prepared.hireId != hire.id ||
        prepared.purpose != SubmissionPurpose.giveFeedback) {
      throw _api('PreparationNotFound');
    }
    if (await _submissions.findByPreparation(preparationId) == null) {
      await _requireRateable(hire, wallet, await _isRated(hire.id));
    }
    final detail = await _relay.submitEscrowCall(
      wallet,
      hire.id,
      preparationId,
      signedTransactionXdr,
    );
    final submission = detail.escrowSubmission;
    if (submission == null) return detail;
    final failed = submission.state == SubmissionState.failed.wireName;
    return detail.copyWith(
      hire: failed
          ? detail.hire
          : detail.hire.copyWith(feedbackReference: submission.transaction),
      escrowSubmission: null,
      feedbackSubmission: submission,
    );
  }

  /// Runs the domain rules on [hire] in their fixed order, reading the agent
  /// owner only once the hire rules hold.
  Future<void> _requireRateable(
    HireRow hire,
    StellarAddress wallet,
    bool rated,
  ) async {
    // A hire without a job has not started: it is not completed.
    final status = hire.status ?? HireStatus.open;
    try {
      checkHireRateable(status: status, rated: rated, matchesHire: true);
      final owner = await _ownerOf(hire.agentId);
      checkFeedbackAllowed(
        status: status,
        rated: rated,
        matchesHire: true,
        feedback: _feedbackOf(hire, wallet, _probeScore, ''),
        owner: owner,
      );
    } on HireNotCompleted catch (e) {
      throw _api('HireNotCompleted', {'status': e.status.name});
    } on HireAlreadyRated {
      throw _api('HireAlreadyRated');
    } on FeedbackFromAgentOwner {
      throw _api('FeedbackFromAgentOwner');
    }
  }

  Feedback _feedbackOf(
    HireRow hire,
    StellarAddress wallet,
    int score,
    String comment,
  ) {
    try {
      return Feedback(
        hireId: HireId(hire.id),
        agentId: AgentId(hire.agentId),
        client: wallet,
        score: score,
        comment: comment,
      );
    } on InvalidFeedback catch (e) {
      throw _api('InvalidFeedback', {'reason': e.problem.name});
    }
  }

  /// The owner of the agent, failing closed when the chain cannot say.
  Future<StellarAddress> _ownerOf(int agentId) async {
    try {
      return await _owners.ownerOf(AgentId(agentId)) ??
          (throw _api('ChainDataUnavailable'));
    } on LedgerException {
      throw _api('ChainDataUnavailable');
    }
  }

  Future<bool> _isRated(int hireId) async =>
      (await _submissions.listByHire(hireId)).any(
        (r) =>
            r.purpose == SubmissionPurpose.giveFeedback &&
            r.state != SubmissionState.failed,
      );

  Future<HireRow> _ownedHire(StellarAddress wallet, int hireId) async {
    if (hireId < 1) throw _api('InvalidHireId');
    final hire = await _hires.findHire(hireId);
    if (hire == null) throw _api('HireNotFound');
    if (hire.consumer != wallet.value) throw _api('HireNotOwned');
    return hire;
  }

  static bool _isRule(String code) =>
      code == 'HireNotCompleted' ||
      code == 'HireAlreadyRated' ||
      code == 'FeedbackFromAgentOwner';

  static Puls3ApiException _api(String code, [Map<String, String>? details]) =>
      Puls3ApiException(code: code, details: details);
}
