import 'dart:convert';

import 'package:puls3_domain/puls3_domain.dart';

import '../studio/studio_model_policy.dart';
import 'run_manifest.dart';

/// The manifest a hire runs for a Studio deploy, or [fallback] for the
/// seeded demo agents.
///
/// Each published version stays. A hire asks for the version it paid for.
/// A missing credential is handled by the caller: this source only
/// returns the prompt.
final class StudioRunManifestSource implements RunManifestSource {
  StudioRunManifestSource({
    required this._lookup,
    required this._fallback,
  });

  /// The snapshot and its owner for one registry agent and version.
  final Future<({String? manifestJson, String owner})?> Function(
    int agentId,
    int version,
  )
  _lookup;
  final RunManifestSource _fallback;

  @override
  Future<RunManifest?> find(int agentId, int manifestVersion) async {
    final hit = await _lookup(agentId, manifestVersion);
    final raw = hit?.manifestJson;
    if (hit == null || raw == null) {
      return _fallback.find(agentId, manifestVersion);
    }
    final AgentManifest manifest;
    try {
      manifest = AgentManifestDraft.fromJson(jsonDecode(raw)).validate(
        studioServerModelPolicy,
        ManifestVersion(manifestVersion),
      );
    } on InvalidManifest {
      return _fallback.find(agentId, manifestVersion);
    } on FormatException {
      return _fallback.find(agentId, manifestVersion);
    }
    return OwnedRunManifest(
      owner: hit.owner,
      provider: manifest.model.provider,
      modelId: manifest.model.id,
      systemPrompt: manifest.systemPrompt,
      inputMaxChars: manifest.inputMaxChars,
      outputMaxChars: manifest.outputMaxChars,
    );
  }
}
