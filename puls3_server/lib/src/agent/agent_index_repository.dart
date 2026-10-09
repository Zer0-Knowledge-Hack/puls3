import '../generated/protocol.dart';

/// Stores and reads the catalog index.
///
/// Implemented by the backend (Serverpod ORM on PostgreSQL). The indexer
/// writes through [upsertAll]; the catalog endpoint reads through [list] and
/// [findByAgentId]. A read never touches the chain.
abstract interface class AgentIndexRepository {
  /// Every indexed agent, newest registration per metadata id, ordered by
  /// registry id.
  Future<List<AgentSummary>> list();

  /// The newest indexed agent with metadata id [agentId], or `null` when
  /// there is none.
  Future<AgentSummary?> findByAgentId(String agentId);

  /// The registry ids already indexed, so the indexer re-reads only what is
  /// missing or changed.
  Future<Set<int>> registryIds();

  /// Whether the index has no rows, so a read may fall back to the chain. A
  /// read must not touch the chain while the index has rows.
  Future<bool> isEmpty();

  /// Inserts or replaces [agents] by registry id. Running it twice with the
  /// same agents leaves the index unchanged.
  Future<void> upsertAll(List<AgentSummary> agents);

  /// The last ledger the indexer processed, or `null` before the first pass.
  Future<int?> lastProcessedLedger();

  /// Stores [ledger] as the last processed ledger.
  Future<void> setLastProcessedLedger(int ledger);
}
