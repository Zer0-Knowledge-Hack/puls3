import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart';

/// The identity-registry events the catalog indexer cares about.
///
/// The types live next to the port (`RegistryEventReader`) so the agent layer
/// does not depend on the ledger adapter. The parser that decodes RPC events
/// into these values is in `ledger/registry_events.dart`.
sealed class RegistryEvent {
  const RegistryEvent(this.agentId);

  /// The on-chain registry id the event is about.
  final int agentId;
}

/// `registered`: a new agent was minted for [owner] with [uri].
final class RegisteredEvent extends RegistryEvent {
  const RegisteredEvent({
    required int agentId,
    required this.owner,
    required this.uri,
  }) : super(agentId);

  final StellarAddress owner;
  final String uri;
}

/// `metadata_set`: the value of [key] for the agent changed to [value].
final class MetadataSetEvent extends RegistryEvent {
  const MetadataSetEvent({
    required int agentId,
    required this.key,
    required this.value,
  }) : super(agentId);

  final String key;
  final Uint8List value;
}

/// `uri_updated`: the agent's metadata uri changed to [uri].
final class UriUpdatedEvent extends RegistryEvent {
  const UriUpdatedEvent({required int agentId, required this.uri})
    : super(agentId);

  final String uri;
}

/// One page batch of registry events.
///
/// [truncated] is true when the reader stopped at its page bound while a cursor
/// remained, so more events exist than were returned. The indexer treats a
/// truncated batch like a gap and re-hydrates every indexed agent.
final class RegistryEventBatch {
  const RegistryEventBatch({required this.events, required this.truncated});

  final List<RegistryEvent> events;
  final bool truncated;
}
