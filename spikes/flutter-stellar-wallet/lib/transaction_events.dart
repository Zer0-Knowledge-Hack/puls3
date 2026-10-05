import 'dart:convert';

/// One `getEvents` page request. The first page is bounded by ledger range;
/// later pages carry only the RPC cursor, as the RPC requires.
final class EventsPageRequest {
  const EventsPageRequest({
    required this.limit,
    this.startLedger,
    this.endLedger,
    this.cursor,
  });

  final int limit;
  final int? startLedger;

  /// Exclusive upper bound.
  final int? endLedger;
  final String? cursor;
}

/// Fetches one page and returns the raw JSON-RPC response object.
typedef EventsPageFetcher =
    Future<Map<String, Object?>> Function(EventsPageRequest request);

/// Collects every `getEvents` row of [txHash] emitted in [ledger] (the
/// transaction's terminal ledger from `getTransaction`).
///
/// Busy contracts such as the native XLM SAC emit many events per ledger and
/// a transaction's fee and transfer events are not contiguous, so this pages
/// with the RPC cursor until the ledger is exhausted: a short page, an empty
/// page, or an event from a later ledger. Returns a JSON-RPC `getEvents`
/// response containing only the transaction's events.
///
/// Fails closed with [StateError] on an RPC error, a missing cursor, an
/// exhausted page budget, or when no event of the transaction is found.
Future<String> collectTransactionEvents({
  required EventsPageFetcher fetchPage,
  required String txHash,
  required int ledger,
  int pageLimit = 100,
  int maxPages = 50,
}) async {
  final matches = <Map<String, Object?>>[];
  String? cursor;
  for (var pageNumber = 1; pageNumber <= maxPages; pageNumber++) {
    final response = await fetchPage(
      cursor == null
          ? EventsPageRequest(
              limit: pageLimit,
              startLedger: ledger,
              endLedger: ledger + 1,
            )
          : EventsPageRequest(limit: pageLimit, cursor: cursor),
    );
    if (response['error'] != null) {
      throw StateError('getEvents returned an RPC error: ${response['error']}');
    }
    final result = response['result'];
    if (result is! Map || result['events'] is! List) {
      throw StateError('getEvents returned no result.');
    }
    final events = (result['events'] as List).cast<Map<String, Object?>>();

    var passedLedger = false;
    for (final event in events) {
      final eventLedger = event['ledger'];
      if (eventLedger is! int) {
        throw StateError('getEvents row has no ledger.');
      }
      if (eventLedger > ledger) {
        passedLedger = true;
        break;
      }
      if (eventLedger == ledger && event['txHash'] == txHash) {
        matches.add(event);
      }
    }

    if (passedLedger || events.length < pageLimit) {
      if (matches.isEmpty) {
        throw StateError('No getEvents rows found for transaction $txHash.');
      }
      return jsonEncode({
        'jsonrpc': '2.0',
        'id': response['id'],
        'result': {...result, 'events': matches},
      });
    }

    final next = result['cursor'];
    if (next is! String || next.isEmpty || next == cursor) {
      throw StateError('getEvents returned a full page without a new cursor.');
    }
    cursor = next;
  }
  throw StateError(
    'Ledger $ledger was not exhausted within $maxPages getEvents pages.',
  );
}
