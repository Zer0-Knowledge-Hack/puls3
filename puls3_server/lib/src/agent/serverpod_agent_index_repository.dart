import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'agent_index_repository.dart';

/// PostgreSQL-backed implementation of [AgentIndexRepository] using the
/// Serverpod ORM.
///
/// [network] is the resume cursor key (the Stellar network passphrase), so a
/// database shared by two networks keeps one cursor per network.
class ServerpodAgentIndexRepository implements AgentIndexRepository {
  ServerpodAgentIndexRepository(this.session, {required this.network});

  final Session session;
  final String network;

  @override
  Future<List<AgentSummary>> list() async {
    final rows = await AgentRecord.db.find(
      session,
      orderBy: (t) => t.registryId,
    );
    final newest = <String, AgentRecord>{};
    for (final row in rows) {
      final current = newest[row.agentId];
      if (current == null || row.registryId > current.registryId) {
        newest[row.agentId] = row;
      }
    }
    final summaries = newest.values.map(_summary).toList()
      ..sort((a, b) => a.registryId.compareTo(b.registryId));
    return List.unmodifiable(summaries);
  }

  @override
  Future<AgentSummary?> findByAgentId(String agentId) async {
    final rows = await AgentRecord.db.find(
      session,
      where: (t) => t.agentId.equals(agentId),
      orderBy: (t) => t.registryId,
    );
    if (rows.isEmpty) return null;
    return _summary(rows.last);
  }

  @override
  Future<Set<int>> registryIds() async {
    final rows = await AgentRecord.db.find(session);
    return {for (final row in rows) row.registryId};
  }

  @override
  Future<bool> isEmpty() async {
    final row = await AgentRecord.db.findFirstRow(session);
    return row == null;
  }

  @override
  Future<void> upsertAll(List<AgentSummary> agents) async {
    for (final agent in agents) {
      final existing = await AgentRecord.db.findFirstRow(
        session,
        where: (t) => t.registryId.equals(agent.registryId),
      );
      if (existing == null) {
        await AgentRecord.db.insertRow(session, _record(agent));
      } else {
        existing.agentId = agent.id;
        existing.name = agent.name;
        existing.description = agent.description;
        existing.skills = agent.skills;
        existing.priceUsdcStroops = agent.priceUsdcStroops;
        existing.wallet = agent.wallet;
        existing.model = agent.model;
        await AgentRecord.db.updateRow(session, existing);
      }
    }
  }

  @override
  Future<int?> lastProcessedLedger() async {
    final state = await CatalogIndexState.db.findFirstRow(
      session,
      where: (t) => t.network.equals(network),
    );
    return state?.lastProcessedLedger;
  }

  @override
  Future<void> setLastProcessedLedger(int ledger) async {
    final now = DateTime.now().toUtc();
    final state = await CatalogIndexState.db.findFirstRow(
      session,
      where: (t) => t.network.equals(network),
    );
    if (state == null) {
      await CatalogIndexState.db.insertRow(
        session,
        CatalogIndexState(
          network: network,
          lastProcessedLedger: ledger,
          updatedAt: now,
        ),
      );
    } else {
      state.lastProcessedLedger = ledger;
      state.updatedAt = now;
      await CatalogIndexState.db.updateRow(session, state);
    }
  }

  AgentSummary _summary(AgentRecord row) => AgentSummary(
    id: row.agentId,
    registryId: row.registryId,
    name: row.name,
    description: row.description,
    skills: row.skills,
    priceUsdcStroops: row.priceUsdcStroops,
    wallet: row.wallet,
    model: row.model,
  );

  AgentRecord _record(AgentSummary agent) => AgentRecord(
    registryId: agent.registryId,
    agentId: agent.id,
    name: agent.name,
    description: agent.description,
    skills: agent.skills,
    priceUsdcStroops: agent.priceUsdcStroops,
    wallet: agent.wallet,
    model: agent.model,
  );
}
