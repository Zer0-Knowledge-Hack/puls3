import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'studio_agent_version.dart';

/// PostgreSQL [AgentVersionStore]. The prompt stays in `manifest_json`.
final class ServerpodStudioAgentVersionStore implements AgentVersionStore {
  ServerpodStudioAgentVersionStore(this._session);

  final Session _session;

  @override
  Future<void> save(AgentVersion version) async {
    final current = await StudioAgentVersionRecord.db.findFirstRow(
      _session,
      where: (t) =>
          t.registryAgentId.equals(version.registryAgentId) &
          t.version.equals(version.version),
    );
    if (current == null) {
      await StudioAgentVersionRecord.db.insertRow(
        _session,
        StudioAgentVersionRecord(
          registryAgentId: version.registryAgentId,
          version: version.version,
          owner: version.owner,
          manifestJson: version.manifestJson,
          updatedAt: version.updatedAt,
        ),
      );
      return;
    }
    await StudioAgentVersionRecord.db.updateRow(
      _session,
      current.copyWith(
        owner: version.owner,
        manifestJson: version.manifestJson,
        updatedAt: version.updatedAt,
      ),
    );
  }

  @override
  Future<AgentVersion?> find(int registryAgentId, int version) async {
    final row = await StudioAgentVersionRecord.db.findFirstRow(
      _session,
      where: (t) =>
          t.registryAgentId.equals(registryAgentId) &
          t.version.equals(version),
    );
    return row == null ? null : _version(row);
  }

  @override
  Future<AgentVersion?> latest(int registryAgentId) async {
    final rows = await StudioAgentVersionRecord.db.find(
      _session,
      where: (t) => t.registryAgentId.equals(registryAgentId),
    );
    StudioAgentVersionRecord? best;
    for (final row in rows) {
      if (best == null || row.version > best.version) best = row;
    }
    return best == null ? null : _version(best);
  }

  AgentVersion _version(StudioAgentVersionRecord row) => AgentVersion(
    registryAgentId: row.registryAgentId,
    version: row.version,
    owner: row.owner,
    manifestJson: row.manifestJson,
    updatedAt: row.updatedAt,
  );
}
