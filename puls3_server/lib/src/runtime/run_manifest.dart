import 'dart:convert';

import 'package:puls3_domain/puls3_domain.dart' show AgentId;

import '../agent/registry_reader.dart';
import 'runtime_task.dart';

/// The parts of a deployed agent manifest (ADR-0004) the runtime needs. The
/// domain `AgentManifest` (#34) replaces it once deployed manifests are
/// stored; the mapping to [RuntimeTask] stays the same.
final class RunManifest {
  const RunManifest({
    required this.provider,
    required this.modelId,
    required this.systemPrompt,
    required this.inputMaxChars,
    required this.outputMaxChars,
  });

  final String provider;
  final String modelId;
  final String systemPrompt;
  final int inputMaxChars;
  final int outputMaxChars;

  /// The task that runs this manifest on [input].
  RuntimeTask task(String input) => RuntimeTask(
    provider: provider,
    modelId: modelId,
    systemPrompt: systemPrompt,
    input: input,
    maxInputChars: inputMaxChars,
    maxOutputChars: outputMaxChars,
  );
}

/// Finds the manifest a hire runs: the agent's manifest at the version the
/// hire pinned (`Hire.manifestVersion`).
abstract interface class RunManifestSource {
  /// The manifest of [agentId] at [manifestVersion], or `null` when there is
  /// none. An unreadable chain throws, so the caller can retry later.
  Future<RunManifest?> find(int agentId, int manifestVersion);
}

/// A [RunManifestSource] over manifests seeded in code, keyed by the agent's
/// `id` metadata (for example `agt-007`) rather than its registry id, which
/// changes with every deployment.
///
/// It bridges the demo until the #34 chain stores deployed manifests.
final class SeededRunManifestSource implements RunManifestSource {
  SeededRunManifestSource({
    required RegistryReader registry,
    required Map<String, Map<int, RunManifest>> manifests,
  }) : _registry = registry,
       _manifests = manifests;

  final RegistryReader _registry;
  final Map<String, Map<int, RunManifest>> _manifests;

  @override
  Future<RunManifest?> find(int agentId, int manifestVersion) async {
    final raw = await _registry.agentMetadata(AgentId(agentId), 'id');
    if (raw == null) return null;
    final String metadataId;
    try {
      metadataId = utf8.decode(raw).trim();
    } on FormatException {
      return null;
    }
    return _manifests[metadataId]?[manifestVersion];
  }
}
