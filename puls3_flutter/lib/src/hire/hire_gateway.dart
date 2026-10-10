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

  /// Creates the hire (idempotent per [requestId]) and returns it with the
  /// unsigned `create_job`. [agentId] is the on-chain registry id.
  Future<HireStart> createHire({
    required int agentId,
    required String consumer,
    required String input,
    required String requestId,
  });

  /// A fresh unsigned `create_job`, after the previous one expired or failed.
  Future<EscrowPreparation> prepareCreateJob(int hireId);

  /// The unsigned `fund` of [hireId]. Waits while the `create_job` is still
  /// being confirmed, up to the gateway's own limit.
  Future<EscrowPreparation> prepareFund(int hireId);

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
  bool get isFinal => switch (this) {
    runFailed || completed || rejected || expired => true,
    _ => false,
  };
}

/// One hire read from the server (api.md `HireDetail`).
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

  HireStage get stage => switch (status) {
    'funded' when runtimeStatus == 'failed' => HireStage.runFailed,
    // A succeeded run stays `running` until its `submit` lands (api.md,
    // "Hire escrow states"): the result says it finished.
    'funded' when result != null => HireStage.delivered,
    'funded' when runtimeStatus == 'running' => HireStage.running,
    'funded' => HireStage.queued,
    'submitted' => HireStage.submitted,
    'completed' => HireStage.completed,
    'rejected' => HireStage.rejected,
    'expired' => HireStage.expired,
    _ => HireStage.awaitingPayment,
  };

  /// A reject before any payment: the app calls it cancelled.
  bool get isCancelled => status == 'rejected' && rejectedFrom == 'open';
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

  /// `createJob` or `fund`.
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

/// An earlier payment for this hire may have moved funds; never pay again.
final class HirePaymentAlreadySubmitted extends HireGatewayException {
  const HirePaymentAlreadySubmitted()
    : super('A payment for this hire was already sent.');
}

/// The hire is closed (`rejected` or `expired`): it takes no payment.
final class HireClosed extends HireGatewayException {
  const HireClosed() : super('This hire is closed. Start a new hire.');
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
