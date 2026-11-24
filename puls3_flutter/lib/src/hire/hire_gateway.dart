import 'wallet_session.dart';

/// Backend side of the hire and pay flow (#91), shaped after the server
/// relay in docs/architecture/api.md (F5-3 to F5-5): the server prepares
/// each escrow call, the consumer's wallet signs it unchanged, and the
/// server submits and tracks it.
///
/// `ServerHireGateway` talks to `HireEndpoint` through the generated client;
/// `FakeHireGateway` is the labelled demo used until the deployed server
/// accepts wallet sessions (#136).
abstract interface class HireGateway {
  /// True for a stand-in that moves no funds. The UI then labels the flow
  /// and its result as a demo, with no explorer link.
  bool get isDemo;

  /// Makes sure the server has a session for [wallet] (#136, SEP-10),
  /// signing a challenge with [sign] when it has none. A demo does nothing.
  Future<void> ensureSignedIn(String wallet, ChallengeSigner sign);

  /// Drops the session after the server refused it, so the next attempt
  /// signs in again.
  Future<void> forgetSession();

  /// Checks, before any signature, that [consumer] can pay
  /// [priceUsdcStroops] (api.md F5-2): throws [HireInsufficientFunds] when
  /// the account, its USDC trustline or its balance is missing. When the
  /// balance cannot be read it returns, and the server's simulation of the
  /// `fund` stays the check. A demo does nothing.
  Future<void> checkFunds(String consumer, int priceUsdcStroops);

  /// What the consumer may fund beside the price before hiring [agentId]
  /// (`HireEndpoint.getHireTerms`, #334). A demo offers no reserve.
  Future<SubcontractTerms> hireTerms(int agentId);

  /// Creates the hire (idempotent per [requestId]) and returns it with the
  /// unsigned `create_job`. [agentId] is the on-chain registry id.
  /// [subcontractReserve] (USDC stroops) is funded beside the price for the
  /// agent's subcontracts, and [allowRelatedParty] lets it subcontract an
  /// agent of the same owner. A retry with the same [requestId] must send
  /// the same values, or the server refuses it (`IdempotencyKeyReused`).
  Future<HireStart> createHire({
    required int agentId,
    required String consumer,
    required String input,
    required String requestId,
    int subcontractReserve = 0,
    bool allowRelatedParty = true,
  });

  /// A fresh unsigned `create_job`, after the previous one expired or failed.
  Future<EscrowPreparation> prepareCreateJob(int hireId);

  /// The unsigned `fund` of [hireId]. Waits while the `create_job` is still
  /// being confirmed, up to the gateway's own limit.
  Future<EscrowPreparation> prepareFund(int hireId);

  /// The unsigned `complete` of a submitted hire (F6 Approve).
  Future<EscrowPreparation> prepareComplete(int hireId);

  /// The unsigned `reject` of [hireId] (F6 Reject and refund). [reason] may
  /// be empty.
  Future<EscrowPreparation> prepareReject(int hireId, String reason);

  /// The unsigned `claim_refund` of a funded hire past `expired_at`, so the
  /// consumer can recover the USDC without the server's relay key.
  Future<EscrowPreparation> prepareClaimRefund(int hireId);

  /// The unsigned `give_feedback` of a completed hire (F7), with [score]
  /// (1 to 5) and an optional [comment].
  Future<EscrowPreparation> prepareFeedback(
    int hireId,
    int score,
    String comment,
  );

  /// Relays the wallet-signed `give_feedback` of [preparation] and returns
  /// its submission. [getHire] reports it as the hire's feedback.
  Future<EscrowSubmission> submitFeedback(
    int hireId,
    EscrowPreparation preparation,
    String signedTransaction,
  );

  /// Relays the wallet-signed envelope of [preparation] and returns its
  /// submission.
  Future<EscrowSubmission> submit(
    int hireId,
    EscrowPreparation preparation,
    String signedTransaction,
  );

  /// The hire as S06 shows it (`HireEndpoint.getHire`). Only the
  /// [consumer] who created it can read it: any other hire is
  /// [HireNotFound].
  Future<HireProgress> getHire(int hireId, String consumer);

  /// The hires of [consumer], the connected wallet, newest first
  /// (`HireEndpoint.listMyHires`). The server lists the session wallet's
  /// hires only, so [consumer] never reaches anyone else's.
  Future<List<HireSummaryItem>> listMyHires(String consumer);
}

/// Where a hire sits in My hires.
enum HireListTab {
  /// The client must approve or reject it, or can get a refund.
  needsAction,

  /// Still moving: being paid, worked on, or delivered.
  inProgress,

  /// Nothing changes any more: completed, rejected or expired.
  finished,
}

/// One row of My hires (api.md `HireSummary`).
class HireSummaryItem {
  const HireSummaryItem({
    required this.hireId,
    required this.agentName,
    required this.inputPreview,
    required this.priceUsdcStroops,
    this.status,
    this.approvalDeadline,
    this.needsAction = false,
    this.paidByAgentId,
    this.paidByAgentName,
  });

  final int hireId;
  final String agentName;

  /// The registry id of the user's Studio agent that hired and paid from its
  /// own wallet; null when the user's wallet paid.
  final int? paidByAgentId;

  /// That agent's name, for "Paid by your agent".
  final String? paidByAgentName;

  /// The first characters of the task the client gave the agent.
  final String inputPreview;
  final int priceUsdcStroops;

  /// `HireStatus` name; null until the `create_job` is confirmed.
  final String? status;

  /// The job's `approval_deadline`, once the agent submitted.
  final DateTime? approvalDeadline;

  /// The server found something for the client to do on this hire.
  final bool needsAction;

  HireListTab get tab {
    if (needsAction) return HireListTab.needsAction;
    return switch (status) {
      'completed' || 'rejected' || 'expired' => HireListTab.finished,
      _ => HireListTab.inProgress,
    };
  }
}

/// Where a hire is, as S06 shows it: the escrow job state (#10, ADR-0005)
/// and, while the hire is funded, the agent run.
enum HireStage {
  /// No confirmed `fund` yet: the job is being created or waits for the
  /// payment.
  awaitingPayment,

  /// Funded; the run waits for the runtime.
  queued,

  /// Funded; the agent is working.
  running,

  /// Funded; the run finished, but the result is hidden until the escrow
  /// `submit` lands. The app says the agent finished and the result is being
  /// recorded (#277).
  recording,

  /// Funded and the run finished with a result, which the agent has not
  /// submitted on chain yet.
  delivered,

  /// Funded, but the run failed for good. The escrow still holds the funds.
  runFailed,

  /// The agent submitted the result; the client approves or rejects it.
  submitted,
  completed,
  rejected,
  expired;

  /// Nothing changes any more without the client, so polling can stop.
  /// A failed run is not final: the client can still reject and refund.
  bool get isFinal => switch (this) {
    completed || rejected || expired => true,
    _ => false,
  };
}

/// One hire read from the server (api.md `HireDetail`).
/// One line of a hire's subcontract receipt (#334, ADR-0011 D6): a child
/// job paid from the hire's reserve, as `HireDetail.receipt` returns it.
class HireReceiptEntry {
  const HireReceiptEntry({
    required this.id,
    this.childHireId,
    this.childJobId,
    required this.providerAgentId,
    required this.providerWallet,
    required this.budgetUsdcStroops,
    this.feeUsdcStroops,
    this.payoutUsdcStroops,
    required this.state,
    this.createTransaction,
    this.createExplorerUrl,
    this.settleTransaction,
    this.settleExplorerUrl,
    this.deliverableHash,
    required this.relatedParty,
    required this.justification,
    required this.createdAt,
  });

  final int id;

  /// The child hire, once it is stored.
  final int? childHireId;

  /// Escrow id of the child job, once its `create_child_job` is confirmed.
  final int? childJobId;

  /// Registry id of the subcontracted agent.
  final int providerAgentId;

  /// StrKey of the subcontracted agent's payment wallet.
  final String providerWallet;

  /// USDC stroops drawn from the reserve as the child budget.
  final int budgetUsdcStroops;

  /// USDC stroops of platform fee, set when the child settles.
  final int? feeUsdcStroops;

  /// USDC stroops paid to the provider, set when the child settles.
  final int? payoutUsdcStroops;

  /// `pending`, `not_opened`, `unverified`, or the child's `HireStatus`
  /// name: open, funded, submitted, completed, rejected, expired.
  final String state;

  /// Lowercase hex hash of the `create_child_job` transaction.
  final String? createTransaction;

  /// StellarExpert link of [createTransaction], when the server built one.
  final String? createExplorerUrl;

  /// Lowercase hex hash of the transaction that settled the child.
  final String? settleTransaction;

  /// StellarExpert link of [settleTransaction], when the server built one.
  final String? settleExplorerUrl;
  final String? deliverableHash;

  /// The provider has the same builder as the hired agent (disclosed, not
  /// banned: ADR-0011 D10).
  final bool relatedParty;

  /// Why the hired agent picked this provider.
  final String justification;
  final DateTime createdAt;
}

class HireProgress {
  const HireProgress({
    required this.hireId,
    required this.agentName,
    required this.priceUsdcStroops,
    required this.input,
    this.status,
    this.runtimeStatus,
    this.failureReason,
    this.rejectedFrom,
    this.result,
    this.paymentTransaction,
    this.paymentExplorerUrl,
    this.approvalDeadline,
    this.expiresAt,
    this.runFinished = false,
    this.submitErrorCode,
    this.decisionTransaction,
    this.decisionExplorerUrl,
    this.feedbackTransaction,
    this.feedbackState,
    this.feedbackErrorCode,
    this.feedbackScore,
    this.feedbackExplorerUrl,
    this.subcontractReserveUsdcStroops = 0,
    this.receipt = const [],
  });

  final int hireId;
  final String agentName;

  /// The price the escrow holds.
  final int priceUsdcStroops;

  /// The task the client gave the agent.
  final String input;

  /// `HireStatus` name: open, funded, submitted, completed, rejected,
  /// expired; null until the `create_job` is confirmed.
  final String? status;

  /// `RuntimeStatus` name while funded: queued, running, failed.
  final String? runtimeStatus;

  /// Safe reason of a failed run.
  final String? failureReason;

  /// The status a reject came from; a reject from `open` is a cancel.
  final String? rejectedFrom;

  /// The agent's output, once the run produced one.
  final String? result;

  /// Lowercase hex hash of the confirmed `fund` transaction.
  final String? paymentTransaction;

  /// StellarExpert link of [paymentTransaction], when the server built one.
  final String? paymentExplorerUrl;

  /// The job's `approval_deadline`, set once the agent submitted.
  final DateTime? approvalDeadline;

  /// The job's `expired_at`, after which the consumer can claim the refund.
  final DateTime? expiresAt;

  /// Whether the agent run succeeded, even while its result is still hidden
  /// before the escrow `submit` (#277).
  final bool runFinished;

  /// Why the server says the agent's `submit` cannot land while the hire is
  /// funded: `AgentCannotDeliver`, `SubmitSimulationRejected`,
  /// `EscrowCallFailed` or `OutcomeUnknown`. Null while it may still land.
  final String? submitErrorCode;

  /// Lowercase hex hash of the confirmed `complete` or `reject` transaction.
  final String? decisionTransaction;

  /// StellarExpert link of [decisionTransaction], when the server built one.
  final String? decisionExplorerUrl;

  /// Lowercase hex hash of the hire's `give_feedback` (`feedbackReference`):
  /// set once it is relayed, and cleared when it failed.
  final String? feedbackTransaction;

  /// `submitted`, `confirmed` or `failed`: the state of the hire's latest
  /// `give_feedback`, if any.
  final String? feedbackState;

  /// Why the latest `give_feedback` failed (`ChainSubmission.errorCode`),
  /// when [feedbackState] is `failed`.
  final String? feedbackErrorCode;

  /// The score of the relayed `give_feedback` (#242): set after a reload
  /// from the score kept with its preparation; null when the rating failed
  /// or was never prepared.
  final int? feedbackScore;

  /// StellarExpert link of [feedbackTransaction], when the server built one.
  final String? feedbackExplorerUrl;

  /// USDC stroops of subcontract reserve the consumer funded beside the
  /// price (ADR-0011 D1); 0 for a hire that never subcontracts.
  final int subcontractReserveUsdcStroops;

  /// The hire's itemized subcontract receipt (ADR-0011 D6), oldest first;
  /// empty when the hire opened no child job.
  final List<HireReceiptEntry> receipt;

  HireStage get stage => switch (status) {
    'funded' when runtimeStatus == 'failed' => HireStage.runFailed,
    // A succeeded run stays `running` until its `submit` lands (api.md,
    // "Hire escrow states"): the result says it finished.
    'funded' when result != null => HireStage.delivered,
    'funded' when runFinished => HireStage.recording,
    'funded' when runtimeStatus == 'running' => HireStage.running,
    'funded' => HireStage.queued,
    'submitted' => HireStage.submitted,
    'completed' => HireStage.completed,
    'rejected' => HireStage.rejected,
    'expired' => HireStage.expired,
    _ => HireStage.awaitingPayment,
  };

  /// The server says the escrow cannot record the result for this hire.
  bool get submitBlocked => submitErrorCode != null;

  /// `OutcomeUnknown` blocks every new preparation, so even a reject would
  /// be refused until the record is resolved.
  bool get submitOutcomeUnknown => submitErrorCode == 'OutcomeUnknown';

  /// A stuck submit the consumer can still reject from `funded`.
  bool get canRejectStuckSubmit =>
      status == 'funded' && submitBlocked && !submitOutcomeUnknown;

  /// Why the result is not recorded, safe to show. Null when it can still
  /// land.
  String? get submitBlockedReason => switch (submitErrorCode) {
    'AgentCannotDeliver' =>
      'This agent cannot deliver this hire: the server cannot sign its '
          'result.',
    'SubmitSimulationRejected' =>
      'The escrow can no longer record the result: the job expired or the '
          'submit was too late.',
    'EscrowCallFailed' =>
      'The result could not be recorded on Stellar after several attempts.',
    'OutcomeUnknown' =>
      'The result may have been recorded, but its status is unknown. Wait '
          'for the job to expire, then claim the refund.',
    _ => null,
  };

  /// F6 Claim refund: the job is still funded past `expired_at`, and no
  /// unknown outcome blocks a new preparation.
  bool canClaimRefundAt(DateTime now) {
    if (status != 'funded' || submitOutcomeUnknown) return false;
    final expires = expiresAt;
    return expires != null && !now.toUtc().isBefore(expires.toUtc());
  }

  /// A reject before any payment: the app calls it cancelled.
  bool get isCancelled => status == 'rejected' && rejectedFrom == 'open';

  /// The approval window is still open. A missing deadline (not submitted
  /// yet, or the server has not filled it) is treated as open.
  bool approvalWindowOpen(DateTime now) {
    final deadline = approvalDeadline;
    if (deadline == null) return true;
    return now.toUtc().isBefore(deadline.toUtc());
  }

  /// F6 Approve: submitted, and the window is still open.
  bool showApproveAt(DateTime now) =>
      stage == HireStage.submitted && approvalWindowOpen(now);

  /// F7 Rate: completed, and no rating relayed yet. A failed rating can be
  /// sent again, unless its outcome is unknown: the server then refuses
  /// every new rating for the hire until the record is resolved.
  bool get canRate =>
      stage == HireStage.completed &&
      feedbackTransaction == null &&
      !feedbackOutcomeUnknown;

  /// The latest rating failed on chain and none landed (`getHire` keeps the
  /// failed record so the app can say why).
  bool get feedbackFailed =>
      feedbackTransaction == null && feedbackState == 'failed';

  /// The latest rating failed as `OutcomeUnknown`: it may have landed unseen,
  /// so the relay blocks new ratings for the hire.
  bool get feedbackOutcomeUnknown =>
      feedbackFailed && feedbackErrorCode == 'OutcomeUnknown';

  /// A rating was relayed and the chain has not confirmed it yet, so the
  /// hire is still worth polling.
  bool get feedbackPending =>
      feedbackTransaction != null && feedbackState == 'submitted';

  /// F6 Reject: a failed run, a funded hire whose submit cannot land, or
  /// submitted before the deadline.
  bool showRejectAt(DateTime now) {
    if (stage == HireStage.runFailed) return true;
    if (canRejectStuckSubmit) return true;
    return stage == HireStage.submitted && approvalWindowOpen(now);
  }
}

/// What a consumer may fund beside the price before hiring one agent
/// (api.md `HireTerms`, ADR-0011 D1 and D8).
class SubcontractTerms {
  const SubcontractTerms({
    required this.reserveMaxStroops,
    required this.maxChildren,
    required this.suggestedReserveStroops,
  });

  /// No subcontracting: the agent did not opt in, the network refuses any
  /// reserve, or the terms could not be read.
  static const none = SubcontractTerms(
    reserveMaxStroops: 0,
    maxChildren: 0,
    suggestedReserveStroops: 0,
  );

  /// The platform ceiling of the reserve, in USDC stroops.
  final int reserveMaxStroops;

  /// How many agents one hire may subcontract; 0 without the opt-in.
  final int maxChildren;

  /// The agent's suggested reserve, in USDC stroops.
  final int suggestedReserveStroops;

  /// The hire form offers a reserve only when both caps allow one.
  bool get offered => maxChildren > 0 && reserveMaxStroops > 0;

  /// The reserve the form starts with: the suggestion, capped by the
  /// ceiling.
  int get prefillStroops =>
      offered ? suggestedReserveStroops.clamp(0, reserveMaxStroops).toInt() : 0;

  /// Whether [reserveStroops] may be funded: 0 always, otherwise up to the
  /// ceiling of an offered reserve.
  bool allows(int reserveStroops) =>
      reserveStroops == 0 ||
      (offered && reserveStroops > 0 && reserveStroops <= reserveMaxStroops);
}

/// A created hire and its first escrow call.
class HireStart {
  const HireStart({required this.hireId, required this.createJob});

  final int hireId;

  /// The unsigned `create_job`; null when an earlier attempt already
  /// submitted it (a retry with the same request id).
  final EscrowPreparation? createJob;
}

/// An escrow call the server prepared and the wallet must sign unchanged.
class EscrowPreparation {
  const EscrowPreparation({
    required this.preparationId,
    required this.purpose,
    required this.unsignedTransaction,
  });

  final String preparationId;

  /// `createJob`, `fund`, `complete`, `reject` or `giveFeedback`.
  final String purpose;

  /// Base64 unsigned transaction envelope.
  final String unsignedTransaction;
}

/// A relayed escrow call.
class EscrowSubmission {
  const EscrowSubmission({
    required this.transactionHash,
    required this.state,
    this.explorerUrl,
  });

  /// Lowercase hex hash of the submitted transaction.
  final String transactionHash;

  /// `submitted`, `confirmed` or `failed`.
  final String state;

  /// The chain confirmed it and, for `fund`, the server checked that the
  /// job matches the hire (api.md, "Funding verification").
  bool get isConfirmed => state == 'confirmed';

  /// StellarExpert link the server built, when it has one.
  final String? explorerUrl;
}

/// A failure reported by the hire backend. [message] is safe to show.
sealed class HireGatewayException implements Exception {
  const HireGatewayException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The server has no valid session for the wallet (#136), or wallet
/// sign-in is not set up on the server. Nothing was created.
final class HireNotSignedIn extends HireGatewayException {
  const HireNotSignedIn()
    : super('Your wallet session ended. Try again to sign in.');
}

/// The server did not accept the wallet's sign-in (expired, already used or
/// unknown challenge, or a signature it could not verify). Nothing was
/// created; trying again asks for a fresh challenge.
final class HireSignInFailed extends HireGatewayException {
  const HireSignInFailed()
    : super('Signing in with your wallet failed. Try again.');
}

/// The agent cannot be hired (unknown on chain or inactive).
final class HireAgentUnavailable extends HireGatewayException {
  const HireAgentUnavailable(super.message);
}

/// The agent's payment wallet is not custodied by the server
/// (`AgentCannotDeliver`), so the server could never sign the escrow `submit`
/// that closes the hire. It refuses before any payment is prepared.
final class HireAgentCannotDeliver extends HireGatewayException {
  const HireAgentCannotDeliver() : super('This agent cannot be hired yet.');
}

/// The server refused the request as invalid. Retrying it unchanged fails
/// again.
final class HireRejected extends HireGatewayException {
  const HireRejected(super.message);
}

/// The preparation can no longer be submitted: prepare the call again.
final class HirePreparationExpired extends HireGatewayException {
  const HirePreparationExpired()
    : super('The transaction expired before it was sent.');
}

/// The submission of a preparation ended for good (`SubmissionRejected`,
/// `TransactionFailed`, or a preparation the server no longer has). The
/// relay is idempotent per preparation, so resending it returns the same
/// failure: the retry must prepare the call again.
final class HireSubmissionFailed extends HireGatewayException {
  const HireSubmissionFailed(super.message);
}

/// The server could not prepare the payment (`ChainUnavailable` with
/// `simulationFailed`). The server cannot tell a short balance from an
/// unreachable node or a missing account, so neither can the app.
final class HirePaymentNotPrepared extends HireGatewayException {
  const HirePaymentNotPrepared()
    : super(
        'The payment could not be prepared. Check that your wallet has '
        'enough testnet USDC and XLM, then try again.',
      );
}

/// The wallet cannot pay the hire: no account, no USDC trustline, or less
/// USDC than the price. Found before any signature, so nothing was signed.
final class HireInsufficientFunds extends HireGatewayException {
  const HireInsufficientFunds(super.message);
}

/// An earlier payment for this hire may have moved funds; never pay again.
final class HirePaymentAlreadySubmitted extends HireGatewayException {
  const HirePaymentAlreadySubmitted()
    : super('A payment for this hire was already sent.');
}

/// The hire is closed (`rejected` or `expired`): it takes no payment.
final class HireClosed extends HireGatewayException {
  const HireClosed() : super('This hire is closed. Start a new hire.');
}

/// The hire already has a rating (`HireAlreadyRated`): each hire is rated
/// once.
final class HireAlreadyRated extends HireGatewayException {
  const HireAlreadyRated() : super('You already rated this hire.');
}

/// The connected wallet is not the one that hired (`HireNotOwned` on a
/// rating). Only the hire's client can rate it.
final class HireWrongWallet extends HireGatewayException {
  const HireWrongWallet() : super('Rate with the wallet that hired.');
}

/// Only a completed hire can be rated (`HireNotCompleted`).
final class HireNotRatable extends HireGatewayException {
  const HireNotRatable() : super('Only a completed hire can be rated.');
}

/// The agent's owner cannot rate it (`FeedbackFromAgentOwner`).
final class HireOwnerCannotRate extends HireGatewayException {
  const HireOwnerCannotRate()
    : super('The owner of this agent cannot rate it.');
}

/// The score or the comment is out of range (`InvalidFeedback`).
final class HireInvalidRating extends HireGatewayException {
  const HireInvalidRating()
    : super('Pick a score from 1 to 5 and keep the comment short.');
}

/// An earlier rating of the hire is still being confirmed
/// (`SubmissionInProgress` on `prepareFeedback`). Waiting is the fix.
final class HireRatingInProgress extends HireGatewayException {
  const HireRatingInProgress()
    : super('A rating for this hire is still being confirmed.');
}

/// An earlier rating's outcome is unknown (`OutcomeUnknown` on
/// `prepareFeedback`): the relay prepares nothing new for the hire until it
/// is resolved, so retrying cannot help.
final class HireRatingOutcomeUnknown extends HireGatewayException {
  const HireRatingOutcomeUnknown()
    : super('Rating this hire is paused until its last rating is resolved.');
}

/// No hire with this id belongs to the connected wallet.
final class HireNotFound extends HireGatewayException {
  const HireNotFound()
    : super('This hire does not exist or belongs to another wallet.');
}

/// The server or the chain could not answer. Retrying the same step is
/// safe: every call is idempotent (api.md, contract rule 5).
final class HireBackendUnavailable extends HireGatewayException {
  const HireBackendUnavailable(super.message);
}
