import '../chain/chain_log.dart';
import '../generated/protocol.dart';
import '../ledger/ledger_errors.dart';
import 'agent_index_repository.dart';
import 'agent_summary_reader.dart';
import 'registry_event_reader.dart';
import 'registry_reader.dart';

/// What one [CatalogIndexer.pass] did, for logging.
final class IndexPassSummary {
  IndexPassSummary({required this.fromLedger, required this.toLedger});

  /// The cursor this pass started from, or `null` for the first pass.
  final int? fromLedger;

  /// The node's latest ledger when the pass started.
  final int toLedger;

  /// Registry events read since [fromLedger].
  int events = 0;

  /// Agents considered for hydration (new, changed, or missing from the index).
  int touched = 0;

  /// Agents written to the index.
  int hydrated = 0;

  /// Agents whose metadata is missing or invalid (for example superseded
  /// registrations), which are not indexed.
  int skipped = 0;

  @override
  String toString() =>
      'from ${fromLedger ?? 'bootstrap'} to $toLedger, '
      'events $events, touched $touched, hydrated $hydrated, '
      'skipped $skipped';
}

/// Syncs the catalog index from the identity registry.
///
/// The first pass bootstraps from registry state (`total_agents` and each
/// agent's metadata), because the RPC only keeps about 7 days of events and
/// the demo agents predate that. Later passes read the registry events after
/// the stored cursor to find the agents that changed, then hydrate them from
/// state. Any agent missing from the index is always hydrated, so a new
/// registration is recovered even if its event was missed.
///
/// The chain is the source of truth; the index is a cache that keeps serving
/// reads while the chain is down.
final class CatalogIndexer {
  CatalogIndexer({
    required RegistryReader registry,
    required RegistryEventReader events,
    required AgentIndexRepository repository,
    required ChainLog log,
  }) : _registry = registry,
       _events = events,
       _repository = repository,
       _log = log;

  final RegistryReader _registry;
  final RegistryEventReader _events;
  final AgentIndexRepository _repository;
  final ChainLog _log;

  /// Reads the chain once and syncs the index.
  ///
  /// A failure to read the latest ledger or the agent count throws a
  /// [LedgerException], so the caller leaves the index untouched and retries.
  Future<IndexPassSummary> pass() async {
    final latest = await _events.latestLedger();
    final checkpoint = await _repository.lastProcessedLedger();
    final total = await _registry.totalAgents();
    final summary = IndexPassSummary(fromLedger: checkpoint, toLedger: latest);

    final affected = <int>{};
    var advanceCursor = checkpoint == null;
    if (checkpoint != null) {
      try {
        final events = await _events.eventsSince(checkpoint + 1);
        summary.events = events.length;
        affected.addAll(events.map((event) => event.agentId));
        advanceCursor = true;
      } on RpcRequestRejected catch (e) {
        // The cursor fell out of the node's retention window. Advance past
        // the gap; the missing agents are recovered from state below.
        _log(
          ChainLogLevel.warning,
          'Registry events before the cursor are no longer retained; '
          'resetting the catalog cursor: $e',
        );
        advanceCursor = true;
      } on LedgerException catch (e) {
        _log(
          ChainLogLevel.warning,
          'Registry events from ${checkpoint + 1} could not be read; '
          'the catalog cursor stays put: $e',
        );
      }
    }

    final indexed = await _repository.registryIds();
    for (var id = 0; id < total; id++) {
      if (!indexed.contains(id)) affected.add(id);
    }

    final ids = affected.where((id) => id >= 0 && id < total).toList()..sort();
    summary.touched = ids.length;

    final agents = <AgentSummary>[];
    for (final id in ids) {
      final agent = await readAgentSummary(_registry, id);
      if (agent == null) {
        summary.skipped++;
        continue;
      }
      agents.add(agent);
    }
    if (agents.isNotEmpty) await _repository.upsertAll(agents);
    summary.hydrated = agents.length;

    if (advanceCursor) await _repository.setLastProcessedLedger(latest);
    return summary;
  }
}
