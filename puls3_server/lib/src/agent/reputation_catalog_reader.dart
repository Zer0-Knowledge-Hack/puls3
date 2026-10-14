import 'package:puls3_domain/puls3_domain.dart'
    show AgentId, ReputationRegistry, reputationOf;

import '../generated/protocol.dart';
import 'catalog_reader.dart';

/// How long an agent's reputation is reused before the registry is read again.
const reputationCacheTtl = Duration(seconds: 60);

const _unreadableMessage = 'The agent reputation cannot be read right now.';

/// What the catalog shows of an agent's reputation.
typedef AgentReputation = ({double rating, int paidHireCount});

/// The reputation of agents, read from a [ReputationRegistry] and kept for
/// [ttl].
///
/// It is built once per process, like the on-chain catalog fallback, so the
/// 60 s window is shared by every request. When the registry fails it serves
/// the last values it read, however old, and throws when it never read any:
/// a rating is never made up.
final class ReputationCache {
  ReputationCache({
    required ReputationRegistry registry,
    DateTime Function()? now,
    this.ttl = reputationCacheTtl,
  }) : _registry = registry,
       _now = now ?? DateTime.now;

  final ReputationRegistry _registry;
  final DateTime Function() _now;
  final Duration ttl;
  final _entries = <int, ({AgentReputation value, DateTime readAt})>{};

  /// The reputation of the agent with [registryId].
  ///
  /// Throws [AgentCatalogUnavailable] when the registry fails and nothing was
  /// read before.
  Future<AgentReputation> of(int registryId) async {
    final cached = _entries[registryId];
    final now = _now();
    if (cached != null && now.difference(cached.readAt) < ttl) {
      return cached.value;
    }
    try {
      final feedback = await _registry.feedbacksOf(AgentId(registryId));
      final value = (
        rating: reputationOf(feedback),
        paidHireCount: feedback.length,
      );
      _entries[registryId] = (value: value, readAt: now);
      return value;
    } on Exception {
      if (cached != null) return cached.value;
      throw AgentCatalogUnavailable(message: _unreadableMessage);
    }
  }
}

/// Adds `rating` and `paidHireCount` to every agent of an inner
/// [CatalogReader], with the #11 reputation function and no formula of its
/// own. An agent without feedback keeps the #11 empty-input value and stays
/// listed.
///
/// [list] isolates failures per agent: one whose reputation cannot be read
/// keeps its inner summary (the wire defaults, 4.0 and 0) and is not cached,
/// so one unreadable agent does not hide the catalog. It still throws
/// [AgentCatalogUnavailable] when no agent can be read. [get] never
/// degrades: a rating that failed to refresh must not look like a real one.
final class ReputationCatalogReader implements CatalogReader {
  ReputationCatalogReader({
    required CatalogReader inner,
    required ReputationCache cache,
  }) : _inner = inner,
       _cache = cache;

  final CatalogReader _inner;
  final ReputationCache _cache;

  @override
  Future<List<AgentSummary>> list() async {
    final agents = await _inner.list();
    var unreadable = 0;
    final listed = await Future.wait(
      agents.map((agent) async {
        try {
          return await _withReputation(agent);
        } on AgentCatalogUnavailable {
          unreadable++;
          return agent;
        }
      }),
    );
    if (agents.isNotEmpty && unreadable == agents.length) {
      throw AgentCatalogUnavailable(message: _unreadableMessage);
    }
    return listed;
  }

  @override
  Future<AgentSummary?> get(String id) async {
    final agent = await _inner.get(id);
    return agent == null ? null : _withReputation(agent);
  }

  Future<AgentSummary> _withReputation(AgentSummary agent) async {
    final reputation = await _cache.of(agent.registryId);
    return agent.copyWith(
      rating: reputation.rating,
      paidHireCount: reputation.paidHireCount,
    );
  }
}
