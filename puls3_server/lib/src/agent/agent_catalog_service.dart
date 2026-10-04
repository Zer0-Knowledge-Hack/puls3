import 'dart:async';
import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart';

import '../generated/protocol.dart';
import '../ledger/ledger_errors.dart';
import 'agent_metadata.dart';
import 'registry_reader.dart';

/// How long a built catalog is served without reading the chain again.
const _catalogTtl = Duration(seconds: 60);

/// How many agents are read at the same time.
const _readConcurrency = 4;

/// Builds the agent catalog from the identity registry and caches it.
///
/// The registry has no list function, so the catalog enumerates the ids
/// `0` to `total_agents - 1`. An agent whose metadata is missing or invalid
/// (for example a superseded registration) is skipped. A chain that cannot be
/// read is different: the refresh is abandoned, the last list built is served
/// when there is one, and [AgentCatalogUnavailable] is thrown otherwise. An
/// outage is never reported as an empty catalog.
final class AgentCatalogService {
  AgentCatalogService(
    this._registry, {
    DateTime Function()? now,
    Duration ttl = _catalogTtl,
    int concurrency = _readConcurrency,
  }) : _now = now ?? DateTime.now,
       _ttl = ttl,
       _concurrency = concurrency;

  final RegistryReader _registry;
  final DateTime Function() _now;
  final Duration _ttl;
  final int _concurrency;

  List<AgentSummary>? _cached;
  DateTime? _builtAt;
  Future<List<AgentSummary>>? _refresh;

  /// Every valid agent, ordered by registry id.
  Future<List<AgentSummary>> list() {
    final cached = _cached;
    final builtAt = _builtAt;
    if (cached != null &&
        builtAt != null &&
        _now().difference(builtAt) < _ttl) {
      return Future.value(cached);
    }
    return _refresh ??= _rebuild().whenComplete(() => _refresh = null);
  }

  /// The agent whose metadata id is [id], or `null` when there is none.
  Future<AgentSummary?> get(String id) async {
    for (final agent in await list()) {
      if (agent.id == id) return agent;
    }
    return null;
  }

  Future<List<AgentSummary>> _rebuild() async {
    try {
      final built = await _build();
      _cached = built;
      _builtAt = _now();
      return built;
    } on LedgerException {
      final stale = _cached;
      if (stale != null) return stale;
      throw AgentCatalogUnavailable(
        message: 'The agent catalog cannot be read from the chain right now.',
      );
    }
  }

  Future<List<AgentSummary>> _build() async {
    final total = await _registry.totalAgents();
    final ids = Iterable<int>.generate(total).iterator;
    final found = <AgentSummary>[];
    var aborted = false;

    Future<void> worker() async {
      while (!aborted && ids.moveNext()) {
        final agent = await _read(ids.current);
        if (agent != null) found.add(agent);
      }
    }

    try {
      await Future.wait([
        for (var i = 0; i < _concurrency; i++) worker(),
      ], eagerError: true);
    } on Object {
      aborted = true;
      rethrow;
    }
    return List.unmodifiable(_newestPerId(found));
  }

  /// One agent, or `null` when its metadata is missing or invalid.
  Future<AgentSummary?> _read(int registryId) async {
    final agent = AgentId(registryId);

    Future<Uint8List?> metadata(String key) =>
        _registry.agentMetadata(agent, key);

    final id = parseAgentId(await metadata('id'));
    if (id == null) return null;
    final name = parseName(await metadata('name'));
    final description = parseDescription(await metadata('description'));
    final skills = parseSkills(await metadata('skills'));
    final price = parsePriceUsdcStroops(await metadata('priceUsdcStroops'));
    if (name == null ||
        description == null ||
        skills == null ||
        price == null) {
      return null;
    }
    final model = parseModel(await metadata('model'));
    final wallet = await _registry.agentWallet(agent);
    return AgentSummary(
      id: id,
      registryId: registryId,
      name: name,
      description: description,
      skills: skills,
      priceUsdcStroops: price,
      wallet: wallet?.value,
      model: model,
    );
  }

  /// Orphans may repeat a metadata id: keep the newest registration.
  List<AgentSummary> _newestPerId(List<AgentSummary> agents) {
    final newest = <String, AgentSummary>{};
    for (final agent in agents) {
      final current = newest[agent.id];
      if (current == null || agent.registryId > current.registryId) {
        newest[agent.id] = agent;
      }
    }
    return newest.values.toList()
      ..sort((a, b) => a.registryId.compareTo(b.registryId));
  }
}
