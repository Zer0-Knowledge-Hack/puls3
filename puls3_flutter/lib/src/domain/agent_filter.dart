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
