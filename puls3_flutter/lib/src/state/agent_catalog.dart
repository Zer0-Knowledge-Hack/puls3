import 'package:flutter/foundation.dart';

import '../data/agent_repository.dart';
import '../domain/agent.dart';

/// Where the catalog is in its load.
enum CatalogStatus {
  /// Loading, and nothing is shown yet.
  loading,

  /// The agents come from the server catalog.
  ready,

  /// The server failed and the bundled demo catalog is shown instead. The
  /// UI must say so: these agents are not read from the chain.
  demo,

  /// The server failed and there is nothing to show.
  error,
}

/// App-wide catalog (S02): the server catalog plus anything deployed from
/// the Studio during this session. It is the container state for the
/// marketplace; widgets only read it.
class AgentCatalog extends ChangeNotifier {
  AgentCatalog(this._repository, {this._fallback});

  final AgentRepository _repository;

  /// Shown, labelled as a demo, when [_repository] fails.
  final AgentRepository? _fallback;

  List<Agent> _agents = const [];
  List<Agent> _published = const [];
  CatalogStatus _status = CatalogStatus.loading;
  bool _loading = false;
  bool _started = false;
  Object? _error;

  List<Agent> get agents => _agents;
  CatalogStatus get status => _status;
  bool get isLoading => _loading;

  /// The catalog has an answer: server agents or the labelled demo.
  bool get isLoaded =>
      _status == CatalogStatus.ready || _status == CatalogStatus.demo;

  /// Why the last server load failed, until a load succeeds.
  Object? get error => _error;

  /// Every skill in the catalog, in first-seen order.
  List<String> get allSkills {
    final seen = <String>{};
    for (final agent in _agents) {
      seen.addAll(agent.skills);
    }
    return seen.toList(growable: false);
  }

  /// Loads the catalog once; later calls do nothing. Use [retry] after a
  /// failure.
  Future<void> load() {
    if (_started) return Future.value();
    _started = true;
    return _fetch();
  }

  /// Loads the server catalog again, for the Retry action.
  Future<void> retry() {
    _started = true;
    return _fetch();
  }

  Future<void> _fetch() async {
    if (_loading) return;
    _loading = true;
    if (!isLoaded) _status = CatalogStatus.loading;
    notifyListeners();
    try {
      _set(await _repository.fetchAgents(), CatalogStatus.ready);
      _error = null;
    } catch (e) {
      _error = e;
      debugPrint('Agent catalog: server load failed: $e');
      await _useFallback();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _useFallback() async {
    final fallback = _fallback;
    if (fallback != null) {
      try {
        _set(await fallback.fetchAgents(), CatalogStatus.demo);
        return;
      } catch (e) {
        debugPrint('Agent catalog: demo catalog failed too: $e');
      }
    }
    // Keep a previous answer on a failed retry; otherwise it is an error.
    if (!isLoaded) _status = CatalogStatus.error;
  }

  void _set(List<Agent> fetched, CatalogStatus status) {
    final ids = {for (final agent in _published) agent.id};
    _agents = [..._published, ...fetched.where((a) => !ids.contains(a.id))];
    _status = status;
  }

  Agent? byId(String id) {
    for (final agent in _agents) {
      if (agent.id == id) return agent;
    }
    return null;
  }

  /// Reads one agent from the server catalog (S03). Throws when the server
  /// cannot answer; returns null when the agent does not exist. A found
  /// agent replaces its cached copy.
  Future<Agent?> fetchAgent(String id) async {
    final agent = await _repository.fetchAgent(id);
    if (agent != null && _status == CatalogStatus.ready) {
      _agents = [
        for (final cached in _agents) cached.id == id ? agent : cached,
      ];
      notifyListeners();
    }
    return agent;
  }

  /// Adds a freshly deployed agent to the top of the marketplace.
  void publish(Agent agent) {
    _published = [agent, ..._published.where((a) => a.id != agent.id)];
    _agents = [agent, ..._agents.where((a) => a.id != agent.id)];
    notifyListeners();
  }
}
