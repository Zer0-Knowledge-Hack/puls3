import '../generated/protocol.dart';
import 'catalog_reader.dart';
import 'hidden_agents.dart';

/// Removes the [HiddenAgents] from an inner [CatalogReader].
///
/// A hidden agent is not in [list] and [get] answers `null` for it, the same
/// as an agent that does not exist, so every surface that reads the catalog
/// (`agent.list`, `agent.get`) stops showing it. The chain is not touched.
final class HiddenCatalogReader implements CatalogReader {
  HiddenCatalogReader({
    required CatalogReader inner,
    required HiddenAgents hidden,
  }) : _inner = inner,
       _hidden = hidden;

  final CatalogReader _inner;
  final HiddenAgents _hidden;

  @override
  Future<List<AgentSummary>> list() async {
    final agents = await _inner.list();
    if (_hidden.ids.isEmpty) return agents;
    return [
      for (final agent in agents)
        if (!_hidden.contains(agent.registryId)) agent,
    ];
  }

  @override
  Future<AgentSummary?> get(String id) async {
    final agent = await _inner.get(id);
    if (agent == null || _hidden.contains(agent.registryId)) return null;
    return agent;
  }
}
