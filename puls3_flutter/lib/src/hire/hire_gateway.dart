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

/// The caller has no wallet session yet (#136). Nothing was created.
final class HireNotSignedIn extends HireGatewayException {
  const HireNotSignedIn()
    : super('Sign-in with your wallet is not available yet.');
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

/// The server or the chain could not answer. Retrying the same step is
/// safe: every call is idempotent (api.md, contract rule 5).
final class HireBackendUnavailable extends HireGatewayException {
  const HireBackendUnavailable(super.message);
}
