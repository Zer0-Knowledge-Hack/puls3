import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/agent.dart';

/// Read access to the agent catalog.
abstract interface class AgentRepository {
  Future<List<Agent>> fetchAgents();

  /// The agent with metadata id [id], or null when there is none.
  Future<Agent?> fetchAgent(String id);
}

/// Finds [id] in a list of agents.
Agent? _findAgent(List<Agent> agents, String id) {
  for (final agent in agents) {
    if (agent.id == id) return agent;
  }
  return null;
}

/// Loads the demo catalog bundled at `assets/mock/demo_agents.json`.
class AssetAgentRepository implements AgentRepository {
  AssetAgentRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const assetPath = 'assets/mock/demo_agents.json';

  final AssetBundle _bundle;

  @override
  Future<List<Agent>> fetchAgents() async {
    final raw = await _bundle.loadString(assetPath);
    return parseAgents(raw);
  }

  @override
  Future<Agent?> fetchAgent(String id) async =>
      _findAgent(await fetchAgents(), id);

  static List<Agent> parseAgents(String raw) {
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => Agent.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }
}

/// In-memory repository, handy for tests and previews.
class InMemoryAgentRepository implements AgentRepository {
  const InMemoryAgentRepository(this.agents);

  final List<Agent> agents;

  @override
  Future<List<Agent>> fetchAgents() async => agents;

  @override
  Future<Agent?> fetchAgent(String id) async => _findAgent(agents, id);
}
