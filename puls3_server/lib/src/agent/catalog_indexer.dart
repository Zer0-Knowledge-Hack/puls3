import '../chain/chain_log.dart';
import '../generated/protocol.dart';
import '../ledger/ledger_errors.dart';
import 'agent_index_repository.dart';
import 'agent_summary_reader.dart';
import 'catalog_id_owner.dart';
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

  /// Agents that may not hold their catalog id, which are not indexed (audit
  /// I-1): a copy of an id another owner registered first, or a Studio id its
  /// draft's owner did not register (#381).
  int foreign = 0;

  /// Rows already in the index that a pass refused and deleted, so a
  /// registration indexed before the rule stops shadowing the right one.
  int removed = 0;

  /// Whether the pass re-hydrated every indexed agent because the event stream
  /// had a gap (retention or truncation).
  bool recoveredAll = false;

  @override
  String toString() =>
      'from ${fromLedger ?? 'bootstrap'} to $toLedger, '
      'events $events, touched $touched, hydrated $hydrated, '
      'skipped $skipped, foreign $foreign, removed $removed${recoveredAll ? ', recoveredAll' : ''}';
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
    CatalogIdOwners owners = const FirstRegistrantOnly(),
  }) : _registry = registry,
       _owners = owners,
       _events = events,
       _repository = repository,
       _log = log;

  final RegistryReader _registry;
  final CatalogIdOwners _owners;
  final RegistryEventReader _events;
  final AgentIndexRepository _repository;
  final ChainLog _log;

  /// Reads the chain once and syncs the index.
  ///
  /// [rehydrateAll] re-reads every indexed agent from state, not just the
  /// ones with new events. The loop sets it on its first pass after a start,
  /// so a change whose event the index missed is recovered on the next
  /// deploy.
  ///
  /// A failure to read the latest ledger or the agent count throws a
  /// [LedgerException], so the caller leaves the index untouched and retries.
  Future<IndexPassSummary> pass({bool rehydrateAll = false}) async {
    final latest = await _events.latestLedger();
    final checkpoint = await _repository.lastProcessedLedger();
    final total = await _registry.totalAgents();
    final summary = IndexPassSummary(fromLedger: checkpoint, toLedger: latest);

    final affected = <int>{};
    var advanceCursor = checkpoint == null;
    var recoverAll = rehydrateAll;
    if (checkpoint != null) {
      try {
        final batch = await _events.eventsSince(checkpoint + 1);
        summary.events = batch.events.length;
        affected.addAll(batch.events.map((event) => event.agentId));
        if (batch.truncated) recoverAll = true;
        advanceCursor = true;
      } on RpcRequestRejected catch (e) {
        // The cursor fell out of the node's retention window. Advance past the
        // gap and re-read every indexed agent, because an agent whose metadata
        // changed inside the gap would otherwise keep its stale values.
        _log(
          ChainLogLevel.warning,
          'Registry events before the cursor are no longer retained; '
          'resetting the catalog cursor and re-hydrating every agent: $e',
        );
        advanceCursor = true;
        recoverAll = true;
      } on LedgerException catch (e) {
        _log(
          ChainLogLevel.warning,
          'Registry events from ${checkpoint + 1} could not be read; '
          'the catalog cursor stays put: $e',
        );
      }
    }

    final indexed = await _repository.registryIds();
    if (recoverAll) affected.addAll(indexed);
    for (var id = 0; id < total; id++) {
      if (!indexed.contains(id)) affected.add(id);
    }
    summary.recoveredAll = recoverAll;

    final ids = affected.where((id) => id >= 0 && id < total).toList()..sort();
    summary.touched = ids.length;

    final agents = <AgentSummary>[];
    // The first registration of each catalog id seen in this pass.
    final first = <String, int>{};
    // Indexed rows this pass refuses: they are deleted, not just skipped.
    final refused = <int>{};
    for (final id in ids) {
      final agent = await readAgentSummary(_registry, id);
      if (agent == null) {
        summary.skipped++;
        continue;
      }
      final refusal = await _refusal(agent, first);
      if (refusal != null) {
        summary.foreign++;
        if (indexed.contains(id)) refused.add(id);
        _log(
          ChainLogLevel.warning,
          'Registry id $id may not hold catalog id ${agent.id}: $refusal. '
          'Not indexed (audit I-1).',
        );
        continue;
      }
      first.putIfAbsent(agent.id, () => id);
      agents.add(agent);
    }
    if (agents.isNotEmpty) await _repository.upsertAll(agents);
    summary.hydrated = agents.length;
    if (refused.isNotEmpty) {
      await _repository.removeAll(refused);
      summary.removed = refused.length;
    }

    if (advanceCursor) await _repository.setLastProcessedLedger(latest);
    return summary;
  }

  /// Why [agent] may not hold its catalog id, or null when it may. [first]
  /// holds the first registration of each id seen in this pass.
  Future<String?> _refusal(AgentSummary agent, Map<String, int> first) async {
    final id = agent.registryId;
    switch (await _owners.claimOf(agent.id)) {
      case NobodyClaim():
        return 'no Studio draft has this id';
      case OwnerClaim(:final owner):
        return await isOwnedBy(_registry, id, owner)
            ? null
            : 'it is not owned by the draft owner ${owner.value}';
      case FirstRegistrantClaim():
        // Every indexed row of a catalog id has the same owner, so any of
        // them stands for the first registration.
        final claimed =
            first[agent.id] ??
            (await _repository.findByAgentId(agent.id))?.registryId;
        if (claimed == null || claimed == id) return null;
        return await mayTakeOverCatalogId(
              _registry,
              earlier: claimed,
              later: id,
            )
            ? null
            : 'registry id $claimed registered it first, with another owner';
    }
  }
}
