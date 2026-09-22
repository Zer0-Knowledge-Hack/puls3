import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/agent.dart';

/// Read access to the agent catalog.
abstract interface class AgentRepository {
  Future<List<Agent>> fetchAgents();
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
}
