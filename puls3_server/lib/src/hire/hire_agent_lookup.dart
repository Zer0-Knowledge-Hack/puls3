import '../agent/agent_index_repository.dart';
import '../agent/catalog_reader.dart';
import 'escrow_relay_service.dart';

/// How a hire finds its agent (audit I-2, #206): one row of the catalog
/// index by registry id, not the whole catalog.
///
/// Registration on the identity registry is permissionless, so the full
/// catalog grows with every registration, and reading it on every hire let
/// anyone make hiring slower. The index answers one agent from the database.
/// Only while the index is still empty (before the indexer's first pass) does
/// it fall back to the on-chain catalog in [fallback].
///
/// An id the index does not have, or a registration superseded by a newer
/// one with the same metadata id, is `null`: the same agents the catalog
/// shows are the ones that can be hired.
AgentSummaryLookup hireAgentLookup({
  required AgentIndexRepository index,
  required CatalogReader fallback,
}) => (registryId) async {
  final indexed = await index.findByRegistryId(registryId);
  if (indexed != null) return indexed;
  // The index has rows but not this agent: unknown or superseded.
  if (!await index.isEmpty()) return null;
  return (await fallback.list())
      .where((agent) => agent.registryId == registryId)
      .firstOrNull;
};
