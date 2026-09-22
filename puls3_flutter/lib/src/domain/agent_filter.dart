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
