import 'dart:convert';

import 'package:puls3_domain/puls3_domain.dart';

import 'studio_draft_errors.dart';
import 'studio_draft_row.dart';
import 'studio_draft_store.dart';

/// A draft the owner is allowed to see, prompt included.
final class OwnedStudioDraft {
  const OwnedStudioDraft({
    required this.draftId,
    required this.manifest,
    required this.revision,
    required this.deployState,
    this.liveVersion,
    this.agentId,
    this.retryFromStep,
  });

  final int draftId;
  final AgentManifestDraft manifest;
  final int revision;
  final String deployState;
  final int? liveVersion;
  final String? agentId;
  final int? retryFromStep;
}

/// Creates, updates, reads and lists drafts for one wallet.
///
/// [document] is the domain wire JSON (`AgentManifestDraft.toJson` /
/// `fromJson`). Validation is the domain's. A non-owner never receives a
/// parsed manifest: [get] and [save] of someone else's id throw
/// [StudioDraftNotOwned] before the document is decoded for the caller.
final class StudioDraftService {
  StudioDraftService(this._store, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final StudioDraftStore _store;
  final DateTime Function() _now;

  Future<OwnedStudioDraft> save({
    required StellarAddress owner,
    required Object? document,
    int? draftId,
    int? revision,
    bool overwrite = false,
  }) async {
    if (draftId == null) {
      final manifest = AgentManifestDraft.fromJson(document);
      final row = await _store.insert(
        owner: owner.value,
        manifestJson: jsonEncode(manifest.toJson()),
        updatedAt: _now().toUtc(),
      );
      return _owned(row, manifest);
    }
    if (draftId < 1) throw const StudioDraftMissing();
    // Ownership before validation, so a foreign draft's prompt is never
    // decoded for this caller and a bad payload cannot change the row.
    await _requireOwned(draftId, owner.value);
    final manifest = AgentManifestDraft.fromJson(document);
    final row = await _store.update(
      id: draftId,
      owner: owner.value,
      manifestJson: jsonEncode(manifest.toJson()),
      expectedRevision: revision,
      overwrite: overwrite,
      updatedAt: _now().toUtc(),
    );
    return _owned(row, manifest);
  }

  Future<OwnedStudioDraft> get({
    required StellarAddress owner,
    required int draftId,
  }) async {
    if (draftId < 1) throw const StudioDraftMissing();
    final row = await _requireOwned(draftId, owner.value);
    return _owned(row, _decode(row));
  }

  Future<void> markLive({
    required int draftId,
    required int liveVersion,
    required String agentId,
  }) => _store.markLive(
    id: draftId,
    liveVersion: liveVersion,
    agentId: agentId,
    updatedAt: _now().toUtc(),
  );

  Future<List<OwnedStudioDraft>> list(StellarAddress owner) async {
    final rows = await _store.listByOwner(owner.value);
    return [for (final row in rows) _owned(row, _decode(row))];
  }

  Future<StudioDraftRow> _requireOwned(int draftId, String owner) async {
    final row = await _store.find(draftId);
    if (row == null) throw const StudioDraftMissing();
    if (row.owner != owner) throw const StudioDraftNotOwned();
    return row;
  }

  OwnedStudioDraft _owned(StudioDraftRow row, AgentManifestDraft manifest) {
    return OwnedStudioDraft(
      draftId: row.id,
      manifest: manifest,
      revision: row.revision,
      deployState: row.deployState,
      liveVersion: row.liveVersion,
      agentId: row.agentId,
      retryFromStep: row.retryFromStep,
    );
  }

  AgentManifestDraft _decode(StudioDraftRow row) =>
      AgentManifestDraft.fromJson(jsonDecode(row.manifestJson));
}
