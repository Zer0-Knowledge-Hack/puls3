import 'package:flutter/foundation.dart';

import '../data/agent_repository.dart';
import '../domain/agent.dart';

/// App-wide catalog: the mock agents plus anything deployed from the Studio
/// during this session.
class AgentCatalog extends ChangeNotifier {
  AgentCatalog(this._repository);

  final AgentRepository _repository;

  List<Agent> _agents = const [];
  bool _loading = false;
  bool _loaded = false;
  Object? _error;

  List<Agent> get agents => _agents;
  bool get isLoading => _loading;
  bool get isLoaded => _loaded;
  Object? get error => _error;

  /// Every skill in the catalog, in first-seen order.
  List<String> get allSkills {
    final seen = <String>{};
    for (final agent in _agents) {
      seen.addAll(agent.skills);
    }
    return seen.toList(growable: false);
  }

  Future<void> load() async {
    if (_loading || _loaded) return;
    _loading = true;
    notifyListeners();
    try {
      final fetched = await _repository.fetchAgents();
      _agents = [..._agents, ...fetched];
      _loaded = true;
    } catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Agent? byId(String id) {
    for (final agent in _agents) {
      if (agent.id == id) return agent;
    }
    return null;
  }

  /// Adds a freshly deployed agent to the top of the marketplace.
  void publish(Agent agent) {
    _agents = [agent, ..._agents.where((a) => a.id != agent.id)];
    notifyListeners();
  }
}
