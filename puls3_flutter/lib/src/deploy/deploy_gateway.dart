import '../domain/agent_draft.dart';

/// Backend side of the agent deploy flow (#27): the register/deploy endpoint
/// of #18, shaped after the API contract in docs/architecture/api.md (F4-4 to
/// F4-8). The server prepares the unsigned registration, the builder's wallet
/// signs it unchanged, and the server submits, tracks and activates it.
///
/// The demo uses `FakeDeployGateway`; a Serverpod implementation replaces it
/// once the endpoint exists, without touching the flow or its widgets.
abstract interface class DeployGateway {
  /// True for a stand-in that registers nothing on Stellar. The UI then
  /// labels the whole flow and its result as a demo (no "live on Stellar",
  /// no explorer link for a made-up hash).
  bool get isDemo;

  /// Validates [draft] and prepares the unsigned `register_full` envelope with
  /// [builder] as its source.
  Future<PreparedDeploy> prepare(AgentDraft draft, {required String builder});

  /// Submits the wallet-signed registration and waits until it is final.
  ///
  /// Throws [DeployTransactionFailed] when the chain rejects it.
  Future<Registration> submitRegistration(
    PreparedDeploy prepared,
    String signedTransaction,
  );

  /// Binds the agent wallet, publishes the registration file and activates
  /// the agent. Returns the agent's payment wallet.
  Future<String> activate(Registration registration);
}

/// A registration the server prepared and the wallet must sign unchanged.
class PreparedDeploy {
  const PreparedDeploy({
    required this.preparationId,
    required this.unsignedTransaction,
  });

  final String preparationId;

  /// Base64 unsigned transaction envelope.
  final String unsignedTransaction;
}

/// A confirmed on-chain registration.
class Registration {
  const Registration({required this.agentId, required this.transactionHash});

  /// The id the Identity Registry assigned.
  final int agentId;

  /// Lowercase hex hash of the `register_full` transaction.
  final String transactionHash;
}

/// A failure reported by the deploy backend.
sealed class DeployGatewayException implements Exception {
  const DeployGatewayException(this.message);

  /// Safe, user-displayable text.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The backend answered with an error for a step (internal error,
/// unavailable dependency). Retrying the same step is safe.
final class DeployBackendError extends DeployGatewayException {
  const DeployBackendError(super.message);
}

/// The backend could not be reached or did not answer in time. Retrying the
/// same step is safe: submissions are idempotent per preparation (#77).
final class DeployConnectionError extends DeployGatewayException {
  const DeployConnectionError(super.message);
}

/// The preparation can no longer be submitted: its time bounds passed or a
/// newer one superseded it (API contract #77, `PreparationExpired`). A retry
/// needs a new preparation.
final class DeployPreparationExpired extends DeployGatewayException {
  const DeployPreparationExpired(super.message);
}

/// The chain rejected the registration. A retry needs a new preparation.
final class DeployTransactionFailed extends DeployGatewayException {
  const DeployTransactionFailed(super.message, {this.transactionHash});

  /// The failed transaction, when it reached the chain.
  final String? transactionHash;
}
