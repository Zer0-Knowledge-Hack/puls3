import '../generated/protocol.dart';

/// A read-only view of the agent catalog.
///
/// The endpoint depends on this, never on the RPC client. The on-chain
/// service (`AgentCatalogService`) and the index-backed service
/// (`IndexedAgentCatalogService`) implement it.
abstract interface class CatalogReader {
  /// Every agent in the catalog, ordered by registry id.
  Future<List<AgentSummary>> list();

  /// The agent with metadata id [id], or `null` when there is none.
  Future<AgentSummary?> get(String id);
}
