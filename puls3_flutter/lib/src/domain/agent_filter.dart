import 'agent.dart';

/// Filters [agents] by a free-text [query] and a set of [skills] (any match).
List<Agent> filterAgents(
  List<Agent> agents, {
  String query = '',
  Set<String> skills = const {},
}) {
  final q = query.trim().toLowerCase();
  return agents
      .where((agent) {
        final matchesSkill =
            skills.isEmpty || agent.skills.any((s) => skills.contains(s));
        if (!matchesSkill) return false;
        if (q.isEmpty) return true;
        return agent.name.toLowerCase().contains(q) ||
            agent.description.toLowerCase().contains(q) ||
            agent.model.toLowerCase().contains(q) ||
            agent.skills.any((s) => s.toLowerCase().contains(q));
      })
      .toList(growable: false);
}

/// How the marketplace orders its results.
enum AgentSort {
  recommended('Recommended'),
  topRated('Top rated'),
  priceLow('Price: low to high'),
  priceHigh('Price: high to low');

  const AgentSort(this.label);
  final String label;
}

/// [agents] in [sort] order. `recommended` keeps the catalog order.
List<Agent> sortAgents(List<Agent> agents, AgentSort sort) {
  final sorted = [...agents];
  switch (sort) {
    case AgentSort.recommended:
      break;
    case AgentSort.topRated:
      sorted.sort((a, b) => b.rating.compareTo(a.rating));
    case AgentSort.priceLow:
      sorted.sort((a, b) => a.priceUsdcStroops.compareTo(b.priceUsdcStroops));
    case AgentSort.priceHigh:
      sorted.sort((a, b) => b.priceUsdcStroops.compareTo(a.priceUsdcStroops));
  }
  return sorted;
}
