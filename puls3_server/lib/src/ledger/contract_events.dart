/// Walks the contract events of a `getTransaction` result.
library;

/// The contract events of [tx], in order.
///
/// Reads `events.contractEventsJson`, which the RPC groups per operation, and
/// flattens it. If that field is missing, walks `events` for any map that
/// looks like a contract event.
Iterable<Object?> contractEvents(Map<String, Object?> tx) sync* {
  final events = tx['events'];
  if (events is! Map) return;
  final recorded = events['contractEventsJson'];
  if (recorded is List) {
    for (final item in recorded) {
      if (item is List) {
        yield* item;
      } else {
        yield item;
      }
    }
    return;
  }
  yield* _walk(events);
}

/// The `topics` and `data` of [event] when it is a `v0` event of
/// [contractId], or `null`.
({List<Object?> topics, Object? data})? contractEventBody(
  Object? event,
  String contractId,
) {
  if (event is! Map || event['contract_id'] != contractId) return null;
  final body = event['body'];
  final v0 = body is Map ? body['v0'] : null;
  if (v0 is! Map) return null;
  final topics = v0['topics'];
  if (topics is! List) return null;
  return (topics: topics, data: v0['data']);
}

Iterable<Object?> _walk(Object? node) sync* {
  if (node is Map) {
    if (node['type'] == 'contract' && node.containsKey('contract_id')) {
      yield node;
      return;
    }
    for (final child in node.values) {
      yield* _walk(child);
    }
  } else if (node is List) {
    for (final child in node) {
      yield* _walk(child);
    }
  }
}
