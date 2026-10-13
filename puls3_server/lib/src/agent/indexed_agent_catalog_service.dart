import '../generated/protocol.dart';
import 'agent_index_repository.dart';
import 'catalog_reader.dart';

/// The agent catalog served from the index, with a chain fallback.
///
/// Reads never touch the chain while the index has rows, so a chain outage
/// does not take the catalog down. When the index is empty (before the first
/// successful indexer pass), it falls back to the on-chain service so the
/// catalog is never reported as empty just because indexing has not run.
final class IndexedAgentCatalogService implements CatalogReader {
  IndexedAgentCatalogService({required AgentIndexRepository index, CatalogReader? fallback})
    : _index = index,
      _fallback = fallback;

  final AgentIndexRepository _index;
  final CatalogReader? _fallback;

  @override
  Future<List<AgentSummary>> list() async {
    final indexed = await _index.list();
    if (indexed.isNotEmpty) return indexed;
    return await _fallback?.list() ?? const [];
  }

  @override
  Future<AgentSummary?> get(String id) async {
    final indexed = await _index.findByAgentId(id);
    if (indexed != null) return indexed;
    // The index has rows but not this id: it is unknown, not a cold index.
    if (!await _index.isEmpty()) return null;
    return _fallback?.get(id);
  }
}
