/// Decodes identity-registry events from a `getEvents` page
/// (`xdrFormat: "json"`).
///
/// The registry publishes each event with the snake_case event name as the
/// first topic (`contracts/contracts/identity-registry/src/lib.rs`):
///
/// - `registered`: topics `[symbol, u32 agent_id, address owner]`, body
///   `{ agent_uri: String }`.
/// - `metadata_set`: topics `[symbol, u32 agent_id, string key]`, body
///   `{ value: Bytes }`.
/// - `uri_updated`: topics `[symbol, u32 agent_id, address updated_by]`, body
///   `{ new_uri: String }`.
///
/// Events of other contracts, failed calls, unknown names and malformed
/// events are skipped: the indexer only needs the affected agent ids, and a
/// skipped event is recovered by re-reading the agent's state.
///
/// The event types live in `agent/registry_events.dart`, next to the port, so
/// the agent layer does not depend on the ledger adapter.
library;

import 'package:puls3_domain/puls3_domain.dart';

import '../agent/registry_events.dart';
import 'ledger_errors.dart';
import 'sc_val_json.dart';
import 'soroban_rpc_client.dart';

export '../agent/registry_events.dart';

/// Every recognized [registry] event in [events], in order.
///
/// An event whose contract is not [registry], that is not from a successful
/// contract call, or that cannot be decoded is skipped. A caller that only
/// needs the affected agents can use `events.map((e) => e.agentId)`.
List<RegistryEvent> parseRegistryEvents(
  Iterable<RpcEvent> events, {
  required StellarAddress registry,
}) {
  final parsed = <RegistryEvent>[];
  for (final event in events) {
    if (event.contractId != registry.value) continue;
    if (!event.inSuccessfulContractCall) continue;
    final topics = event.topicJson;
    if (topics.isEmpty) continue;
    try {
      final parsedEvent = _parse(event, topics);
      if (parsedEvent != null) parsed.add(parsedEvent);
    } on LedgerUnavailable {
      // A malformed event is skipped; re-reading the agent recovers it.
    }
  }
  return parsed;
}

RegistryEvent? _parse(RpcEvent event, List<Object?> topics) {
  final name = readSymbol(topics[0]);
  switch (name) {
    case 'metadata_set':
      if (topics.length != 3) return null;
      final data = readMap(event.valueJson);
      final value = data['value'];
      if (value == null) return null;
      return MetadataSetEvent(
        agentId: readU32(topics[1]),
        key: readString(topics[2]),
        value: readBytes(value),
      );
    case 'registered':
      if (topics.length != 3) return null;
      final data = readMap(event.valueJson);
      final uri = data['agent_uri'];
      if (uri == null) return null;
      return RegisteredEvent(
        agentId: readU32(topics[1]),
        owner: readAddress(topics[2]),
        uri: readString(uri),
      );
    case 'uri_updated':
      if (topics.length != 3) return null;
      final data = readMap(event.valueJson);
      final uri = data['new_uri'];
      if (uri == null) return null;
      return UriUpdatedEvent(agentId: readU32(topics[1]), uri: readString(uri));
    default:
      return null;
  }
}
