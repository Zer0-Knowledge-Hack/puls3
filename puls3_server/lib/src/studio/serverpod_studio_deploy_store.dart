import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'studio_deploy_store.dart';

/// PostgreSQL [StudioDeployStore]. One row per draft.
final class ServerpodStudioDeployStore implements StudioDeployStore {
  ServerpodStudioDeployStore(this._session);

  final Session _session;

  @override
  Future<StudioDeployRow?> findByDraft(int draftId) async {
    final row = await StudioDeployRecord.db.findFirstRow(
      _session,
      where: (t) => t.draftId.equals(draftId),
    );
    return row == null ? null : _row(row);
  }

  @override
  Future<StudioDeployRow?> findByManifestHash(String hash) async {
    final rows = await StudioDeployRecord.db.find(_session);
    for (final row in rows) {
      if (row.registrationUri.endsWith('/$hash')) return _row(row);
    }
    return null;
  }

  @override
  Future<StudioDeployRow?> findByRegistryAgent(int agentId) async {
    final row = await StudioDeployRecord.db.findFirstRow(
      _session,
      where: (t) => t.registryAgentId.equals(agentId),
    );
    return row == null ? null : _row(row);
  }

  @override
  Future<StudioDeployRow> save(StudioDeployRow row) async {
    final current = await StudioDeployRecord.db.findFirstRow(
      _session,
      where: (t) => t.draftId.equals(row.draftId),
    );
    if (current == null) {
      final inserted = await StudioDeployRecord.db.insertRow(
        _session,
        _record(row),
      );
      return _row(inserted);
    }
    final updated = await StudioDeployRecord.db.updateRow(
      _session,
      current.copyWith(
        state: row.state,
        agentWallet: row.agentWallet,
        registrationUri: row.registrationUri,
        manifestJson: row.manifestJson,
        preparationId: row.preparationId,
        unsignedEnvelopeXdr: row.unsignedEnvelopeXdr,
        authorizationEntryXdr: row.authorizationEntryXdr,
        signatureExpirationLedger: row.signatureExpirationLedger,
        registrationHash: row.registrationHash,
        walletTxHash: row.walletTxHash,
        registryAgentId: row.registryAgentId,
        expiresAt: row.expiresAt,
        failureCode: row.failureCode,
        retryFromStep: row.retryFromStep,
        walletAuthJson: row.walletAuthJson,
        updatedAt: row.updatedAt,
      ),
    );
    return _row(updated);
  }

  StudioDeployRecord _record(StudioDeployRow row) => StudioDeployRecord(
    draftId: row.draftId,
    owner: row.owner,
    state: row.state,
    agentWallet: row.agentWallet,
    registrationUri: row.registrationUri,
    manifestJson: row.manifestJson,
    preparationId: row.preparationId,
    unsignedEnvelopeXdr: row.unsignedEnvelopeXdr,
    authorizationEntryXdr: row.authorizationEntryXdr,
    signatureExpirationLedger: row.signatureExpirationLedger,
    registrationHash: row.registrationHash,
    walletTxHash: row.walletTxHash,
    registryAgentId: row.registryAgentId,
    expiresAt: row.expiresAt,
    failureCode: row.failureCode,
    retryFromStep: row.retryFromStep,
    walletAuthJson: row.walletAuthJson,
    updatedAt: row.updatedAt,
  );

  StudioDeployRow _row(StudioDeployRecord row) => StudioDeployRow(
    draftId: row.draftId,
    owner: row.owner,
    state: row.state,
    agentWallet: row.agentWallet,
    registrationUri: row.registrationUri,
    manifestJson: row.manifestJson,
    preparationId: row.preparationId,
    unsignedEnvelopeXdr: row.unsignedEnvelopeXdr,
    authorizationEntryXdr: row.authorizationEntryXdr,
    signatureExpirationLedger: row.signatureExpirationLedger,
    registrationHash: row.registrationHash,
    walletTxHash: row.walletTxHash,
    registryAgentId: row.registryAgentId,
    expiresAt: row.expiresAt,
    failureCode: row.failureCode,
    retryFromStep: row.retryFromStep,
    walletAuthJson: row.walletAuthJson,
    updatedAt: row.updatedAt,
  );
}
