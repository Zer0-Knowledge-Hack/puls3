import 'dart:async';

import 'package:puls3_domain/puls3_domain.dart';

import '../chain/chain_log.dart';
import '../generated/protocol.dart';
import '../ledger/ledger_errors.dart';
import 'agent_summary_reader.dart';
import 'catalog_id_owner.dart';
import 'catalog_reader.dart';
import 'registry_reader.dart';

/// How long a built catalog is served without reading the chain again.
const _catalogTtl = Duration(seconds: 60);

/// How many agents are read at the same time.
const _readConcurrency = 4;

/// Builds the agent catalog from the identity registry and caches it.
///
/// The registry has no list function, so the catalog enumerates the ids
/// `0` to `total_agents - 1`. An agent whose metadata is missing or invalid
/// (for example a superseded registration) is skipped, and so is one that
/// reuses a catalog id another owner registered first (audit I-1, see
/// [mayTakeOverCatalogId]). A chain that cannot be
/// read is different: the refresh is abandoned, the last list built is served
/// when there is one, and [AgentCatalogUnavailable] is thrown otherwise. An
/// outage is never reported as an empty catalog.
final class AgentCatalogService implements CatalogReader {
  AgentCatalogService(
    this._registry, {
    DateTime Function()? now,
    Duration ttl = _catalogTtl,
    int concurrency = _readConcurrency,
    ChainLog log = ignoreChainLog,
    CatalogIdOwners owners = const FirstRegistrantOnly(),
  }) : _owners = owners,
       _now = now ?? DateTime.now,
       _ttl = ttl,
       _concurrency = concurrency,
       _log = log;

  final RegistryReader _registry;
  final CatalogIdOwners _owners;
  final DateTime Function() _now;
  final Duration _ttl;
  final int _concurrency;
  final ChainLog _log;

  List<AgentSummary>? _cached;
  DateTime? _builtAt;
  Future<List<AgentSummary>>? _refresh;

  /// Every valid agent, ordered by registry id.
  @override
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
  @override
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
    } on LedgerException catch (e) {
      // The cause (client timeout, HTTP 504, JSON-RPC -32001, ...) is only in
      // the exception, so log it before it is swallowed.
      final stale = _cached;
      _log(
        ChainLogLevel.warning,
        'Agent catalog rebuild failed (${e.runtimeType}): ${e.message}. '
        '${stale != null ? 'Serving the stale catalog.' : 'No cached catalog.'}',
      );
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
    return List.unmodifiable(await _newestPerId(found));
  }

  /// One agent, or `null` when its metadata is missing or invalid.
  Future<AgentSummary?> _read(int registryId) =>
      readAgentSummary(_registry, registryId);

  /// Orphans may repeat a metadata id: keep one registration per id, by the
  /// claim [_owners] gives it. A Studio id goes to the newest registration of
  /// its draft's owner, and to nobody without a draft. Any other id goes to
  /// the newest registration by the owner who registered it first. For those,
  /// owners are read only when the id repeats.
  Future<List<AgentSummary>> _newestPerId(List<AgentSummary> agents) async {
    final byId = <String, List<AgentSummary>>{};
    for (final agent in [
      ...agents,
    ]..sort((a, b) => a.registryId.compareTo(b.registryId))) {
      (byId[agent.id] ??= []).add(agent);
    }
    final newest = <AgentSummary>[];
    for (final MapEntry(key: id, value: registrations) in byId.entries) {
      final kept = switch (await _owners.claimOf(id)) {
        NobodyClaim() => null,
        OwnerClaim(:final owner) => await _newestOwnedBy(registrations, owner),
        FirstRegistrantClaim() => await _newestOfFirstOwner(registrations),
      };
      if (kept != null) newest.add(kept);
    }
    return newest..sort((a, b) => a.registryId.compareTo(b.registryId));
  }

  /// The newest of [registrations] (oldest first) owned by [owner], or null.
  Future<AgentSummary?> _newestOwnedBy(
    List<AgentSummary> registrations,
    StellarAddress owner,
  ) async {
    for (final agent in registrations.reversed) {
      if (await isOwnedBy(_registry, agent.registryId, owner)) return agent;
    }
    return null;
  }

  /// The newest of [registrations] (oldest first) whose owner is the owner of
  /// the first one.
  Future<AgentSummary> _newestOfFirstOwner(
    List<AgentSummary> registrations,
  ) async {
    final first = registrations.first;
    var kept = first;
    for (final agent in registrations.skip(1)) {
      if (await mayTakeOverCatalogId(
        _registry,
        earlier: first.registryId,
        later: agent.registryId,
      )) {
        kept = agent;
      }
    }
    return kept;
  }
}
