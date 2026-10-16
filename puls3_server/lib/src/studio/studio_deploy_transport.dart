import '../generated/protocol.dart';
import 'studio_agent_version.dart';
import 'studio_deploy_store.dart';

/// The client view of [row]. The `register_full` hash stays on
/// `preparation.transaction` through the wallet step, so the success sheet
/// can link the transaction that created the agent.
DeploySession deploySession(StudioDeployRow row, String networkPassphrase) {
  return DeploySession(
    state: row.state,
    preparation: _preparation(row, networkPassphrase),
    agentId: row.registryAgentId,
    agentWallet: row.agentWallet,
    failureCode: row.failureCode,
    retryFromStep: row.retryFromStep,
  );
}

PreparedTransaction? _preparation(StudioDeployRow row, String network) {
  final preparationId = row.preparationId;
  final expiresAt = row.expiresAt;
  if (preparationId == null || expiresAt == null) return null;
  final update = versionUpdateOf(row.walletAuthJson);
  if (update != null &&
      row.unsignedEnvelopeXdr != null &&
      (row.state == 'awaitingWalletAuthorization' ||
          row.state == 'walletAuthorizationSubmitted')) {
    return PreparedTransaction(
      preparationId: preparationId,
      purpose: 'setMetadata',
      signer: row.owner,
      networkPassphrase: network,
      unsignedTransactionXdr: row.unsignedEnvelopeXdr,
      transaction: row.walletTxHash ?? row.registrationHash,
      expiresAt: expiresAt,
    );
  }
  if (row.authorizationEntryXdr != null &&
      (row.state == 'awaitingWalletAuthorization' ||
          row.state == 'walletAuthorizationSubmitted' ||
          row.state == 'active')) {
    return PreparedTransaction(
      preparationId: preparationId,
      purpose: 'setAgentWallet',
      signer: row.owner,
      networkPassphrase: network,
      authorizationEntryXdr: row.authorizationEntryXdr,
      signatureExpirationLedger: row.signatureExpirationLedger,
      transaction: row.registrationHash,
      expiresAt: expiresAt,
    );
  }
  final unsigned = row.unsignedEnvelopeXdr;
  if (unsigned == null) return null;
  return PreparedTransaction(
    preparationId: preparationId,
    purpose: 'registerFull',
    signer: row.owner,
    networkPassphrase: network,
    unsignedTransactionXdr: unsigned,
    transaction: row.registrationHash,
    expiresAt: expiresAt,
  );
}
