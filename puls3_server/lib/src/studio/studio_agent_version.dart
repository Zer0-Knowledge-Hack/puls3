import 'dart:convert';

/// One published snapshot of a Studio agent.
///
/// A hire keeps the version it paid for. A later deploy adds the next row
/// and does not replace this one. The prompt stays in [manifestJson].
final class AgentVersion {
  const AgentVersion({
    required this.registryAgentId,
    required this.version,
    required this.owner,
    required this.manifestJson,
    required this.updatedAt,
  });

  final int registryAgentId;
  final int version;
  final String owner;
  final String manifestJson;
  final DateTime updatedAt;
}

/// Persistence for [AgentVersion], keyed by registry agent and version.
abstract interface class AgentVersionStore {
  Future<void> save(AgentVersion version);

  Future<AgentVersion?> find(int registryAgentId, int version);

  /// The highest stored version of [registryAgentId], or null.
  Future<AgentVersion?> latest(int registryAgentId);
}

/// Process-local [AgentVersionStore].
final class MemoryAgentVersionStore implements AgentVersionStore {
  final _rows = <String, AgentVersion>{};

  @override
  Future<void> save(AgentVersion version) async {
    _rows['${version.registryAgentId}:${version.version}'] = version;
  }

  @override
  Future<AgentVersion?> find(int registryAgentId, int version) async =>
      _rows['$registryAgentId:$version'];

  @override
  Future<AgentVersion?> latest(int registryAgentId) async {
    AgentVersion? best;
    for (final row in _rows.values) {
      if (row.registryAgentId != registryAgentId) continue;
      if (best == null || row.version > best.version) best = row;
    }
    return best;
  }
}

/// The pending version carried on a deploy row while `set_metadata` is
/// in flight. Null when [raw] is a wallet-auth draft or empty.
final class VersionUpdate {
  const VersionUpdate({required this.version, required this.manifestJson});

  final int version;
  final String manifestJson;
}

VersionUpdate? versionUpdateOf(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return null;
  }
  if (decoded is! Map) return null;
  final version = decoded['versionUpdate'];
  final manifestJson = decoded['manifestJson'];
  if (version is! int || manifestJson is! String || manifestJson.isEmpty) {
    return null;
  }
  return VersionUpdate(version: version, manifestJson: manifestJson);
}

String versionUpdateJson({
  required int version,
  required String manifestJson,
}) => jsonEncode({'versionUpdate': version, 'manifestJson': manifestJson});
