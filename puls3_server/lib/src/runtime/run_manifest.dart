import 'dart:convert';

import 'package:puls3_domain/puls3_domain.dart' show AgentId, SubcontractOptIn;

import '../agent/registry_reader.dart';
import 'runtime_task.dart';

/// The platform cap on subcontracts per hire (ADR-0011 D8): a manifest may
/// ask for more, but a hire never opens more than this many children.
const subcontractMaxChildrenCap = 2;

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
    this.subcontract,
  });

  final String provider;
  final String modelId;
  final String systemPrompt;
  final int inputMaxChars;
  final int outputMaxChars;

  /// The manifest's opt-in to subcontract, or `null` when the agent never
  /// does. Demo manifests never opt in.
  final SubcontractOptIn? subcontract;

  /// How many children one hire of this manifest may open: the manifest's
  /// `max_children` capped by [subcontractMaxChildrenCap], or 0 without the
  /// opt-in.
  int get effectiveMaxChildren {
    final optIn = subcontract;
    if (optIn == null) return 0;
    return optIn.maxChildren < subcontractMaxChildrenCap
        ? optIn.maxChildren
        : subcontractMaxChildrenCap;
  }

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

/// A [RunManifest] whose model call uses the builder's credential, not the
/// team provider token. [owner] is the builder wallet that stored it.
final class OwnedRunManifest extends RunManifest {
  const OwnedRunManifest({
    required this.owner,
    required super.provider,
    required super.modelId,
    required super.systemPrompt,
    required super.inputMaxChars,
    required super.outputMaxChars,
    super.subcontract,
  });

  final String owner;
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
