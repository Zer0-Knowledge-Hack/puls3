import 'agent.dart';

/// Filters [agents] by a free-text [query] (name, description, model or
/// skill) and a set of [skills]: an agent must have every selected skill
/// (docs/blueprints/flows.md, F2).
List<Agent> filterAgents(
  List<Agent> agents, {
  String query = '',
  Set<String> skills = const {},
}) {
  final q = query.trim().toLowerCase();
  return agents
      .where((agent) {
        final matchesSkill =
            skills.isEmpty || skills.every(agent.skills.contains);
        if (!matchesSkill) return false;
        if (q.isEmpty) return true;
        return agent.name.toLowerCase().contains(q) ||
            agent.description.toLowerCase().contains(q) ||
            agent.model.toLowerCase().contains(q) ||
            agent.skills.any((s) => s.toLowerCase().contains(q));
      })
      .toList(growable: false);
}

/// How the Marketplace orders its agents. Each one sorts on data every
/// agent has (price, rating), so it always changes the order for real.
enum AgentSort {
  /// The catalog's own order.
  featured('Featured'),
  priceLowToHigh('Price: low to high'),
  priceHighToLow('Price: high to low'),
  topRated('Top rated');

  const AgentSort(this.label);

  final String label;
}

/// [agents] in [sort] order. Ties keep the catalog order (stable).
List<Agent> sortAgents(List<Agent> agents, AgentSort sort) {
  final indexed = agents.indexed.toList();
  int byIndex((int, Agent) a, (int, Agent) b) => a.$1.compareTo(b.$1);
  int Function((int, Agent), (int, Agent))? compare = switch (sort) {
    AgentSort.featured => null,
    AgentSort.priceLowToHigh => (a, b) => a.$2.priceUsdcStroops.compareTo(
      b.$2.priceUsdcStroops,
    ),
    AgentSort.priceHighToLow => (a, b) => b.$2.priceUsdcStroops.compareTo(
      a.$2.priceUsdcStroops,
    ),
    AgentSort.topRated => (a, b) => b.$2.rating.compareTo(a.$2.rating),
  };
  if (compare == null) return List.unmodifiable(agents);
  indexed.sort((a, b) {
    final c = compare(a, b);
    return c != 0 ? c : byIndex(a, b);
  });
  return List.unmodifiable([for (final (_, agent) in indexed) agent]);
}
