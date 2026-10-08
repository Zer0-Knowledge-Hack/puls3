import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'ledger_errors.dart';

/// The `status` of a `sendTransaction` answer.
enum SendTransactionStatus {
  /// Accepted for inclusion; poll `getTransaction` for the final result.
  pending,

  /// The node already has this transaction.
  duplicate,

  /// The node did not take the transaction now; the same envelope may be
  /// sent again later.
  tryAgainLater,

  /// Rejected; [SendTransactionResult.errorResultXdr] says why.
  error,
}

/// A typed `sendTransaction` answer. It says whether the node took the
/// envelope, not whether the transaction succeeded.
final class SendTransactionResult {
  const SendTransactionResult({
    required this.status,
    required this.hash,
    this.latestLedger,
    this.latestLedgerCloseTime,
    this.errorResultXdr,
  });

  final SendTransactionStatus status;

  /// The 64-character hex transaction hash.
  final String hash;
  final int? latestLedger;

  /// Unix seconds.
  final int? latestLedgerCloseTime;

  /// The base64 XDR `TransactionResult` of an [SendTransactionStatus.error].
  final String? errorResultXdr;
}

/// One contract event of a `getEvents` page (`xdrFormat: "json"`).
final class RpcEvent {
  const RpcEvent({
    required this.ledger,
    required this.contractId,
    required this.topicJson,
    required this.valueJson,
    required this.inSuccessfulContractCall,
    this.txHash,
  });

  /// The ledger sequence the event was emitted in.
  final int ledger;

  /// The contract that emitted the event.
  final String contractId;

  /// The event topics as ScVal JSON, in order.
  final List<Object?> topicJson;

  /// The event body as ScVal JSON.
  final Object? valueJson;

  final bool inSuccessfulContractCall;

  /// The transaction that emitted the event, when the node reports it.
  final String? txHash;
}

/// One page of `getEvents`.
final class EventPage {
  const EventPage({
    required this.events,
    required this.latestLedger,
    this.cursor,
  });

  final List<RpcEvent> events;

  /// The most recent ledger the node knows about.
  final int latestLedger;

  /// Pass to [SorobanRpcClient.getEvents] to read the next page, if any.
  final String? cursor;
}

/// A `getEvents` filter. The MVP only needs `type: contract`.
final class RpcEventFilter {
  const RpcEventFilter({required this.contractIds, this.type = 'contract'});

  final String type;
  final List<String> contractIds;
}

const _sendStatuses = {
  'PENDING': SendTransactionStatus.pending,
  'DUPLICATE': SendTransactionStatus.duplicate,
  'TRY_AGAIN_LATER': SendTransactionStatus.tryAgainLater,
  'ERROR': SendTransactionStatus.error,
};

/// JSON-RPC transport to a Soroban RPC node: the two read methods the adapter
/// uses, plus `sendTransaction` for envelopes the server already signed and
/// persisted. It never signs.
///
/// Every failure to obtain a well-formed `result` object is a
/// [LedgerException]: an unreachable node must never look like "not found".
/// A JSON-RPC `invalid request` or `invalid params` error is a
/// [RpcRequestRejected] (the node refused this request); every other
/// failure, including other JSON-RPC errors, is a [LedgerUnavailable]. Both
/// keep the JSON-RPC code and message in their text.
final class SorobanRpcClient {
  /// [timeout] has no default: the composition root chooses it.
  SorobanRpcClient({
    required http.Client httpClient,
    required Uri url,
    required Duration timeout,
  }) : _http = httpClient,
       _url = url,
       _timeout = timeout;

  final http.Client _http;
  final Uri _url;
  final Duration _timeout;

  /// `simulateTransaction` for an unsigned envelope in base64 XDR. Returns the
  /// JSON-RPC `result`, with ScVal values in JSON form.
  Future<Map<String, Object?>> simulateTransaction(String envelope) =>
      _call('simulateTransaction', {
        'transaction': envelope,
        'xdrFormat': 'json',
      });

  /// `getTransaction` for a 64-character hex [hash]. Returns the JSON-RPC
  /// `result`, which has `status` `NOT_FOUND` for an unknown or expired hash.
  Future<Map<String, Object?>> getTransaction(String hash) =>
      _call('getTransaction', {'hash': hash, 'xdrFormat': 'json'});

  /// `getLatestLedger`: the sequence of the most recent ledger the node has.
  /// A result without a numeric `sequence` is a [LedgerUnavailable].
  Future<int> getLatestLedger() async {
    const method = 'getLatestLedger';
    final result = await _call(method, {});
    final sequence = result['sequence'];
    if (sequence is! int) {
      throw LedgerUnavailable('$method answered no sequence');
    }
    return sequence;
  }

  /// `getEvents` with `xdrFormat: "json"`.
  ///
  /// A ledger range and a cursor are mutually exclusive: pass [startLedger]
  /// for the first page and [cursor] for a later one, never both. `getEvents`
  /// only reaches events inside the node's retention window (about 7 days);
  /// a range older than that is rejected. A result without an `events` list
  /// and a `latestLedger` is a [LedgerUnavailable].
  Future<EventPage> getEvents({
    int? startLedger,
    int? endLedger,
    List<RpcEventFilter> filters = const [],
    String? cursor,
    int? limit,
  }) async {
    if (startLedger == null && cursor == null) {
      throw ArgumentError('getEvents needs a startLedger or a cursor');
    }
    final pagination = <String, Object?>{
      'limit': ?limit,
      'cursor': ?cursor,
    };
    final result = await _call('getEvents', {
      'startLedger': ?startLedger,
      'endLedger': ?endLedger,
      if (filters.isNotEmpty)
        'filters': [
          for (final filter in filters)
            {'type': filter.type, 'contractIds': filter.contractIds},
        ],
      if (pagination.isNotEmpty) 'pagination': pagination,
      'xdrFormat': 'json',
    });
    return _eventPage(result);
  }

  EventPage _eventPage(Map<String, Object?> result) {
    final rawEvents = result['events'];
    final latestLedger = result['latestLedger'];
    if (rawEvents is! List || latestLedger is! int) {
      throw LedgerUnavailable('getEvents answered no events and latestLedger');
    }
    final events = <RpcEvent>[];
    for (final raw in rawEvents) {
      if (raw is! Map) {
        throw LedgerUnavailable('getEvents answered a malformed event');
      }
      final ledger = raw['ledger'];
      final contractId = raw['contractId'];
      final topics = raw['topicJson'];
      if (ledger is! int || contractId is! String || topics is! List) {
        throw LedgerUnavailable('getEvents answered a malformed event');
      }
      events.add(
        RpcEvent(
          ledger: ledger,
          contractId: contractId,
          topicJson: topics,
          valueJson: raw['valueJson'],
          inSuccessfulContractCall: raw['inSuccessfulContractCall'] == true,
          txHash: raw['txHash'] is String ? raw['txHash'] as String : null,
        ),
      );
    }
    final cursor = result['cursor'];
    return EventPage(
      events: events,
      latestLedger: latestLedger,
      cursor: cursor is String ? cursor : null,
    );
  }

  /// `sendTransaction` for a signed envelope in base64 XDR. A transport
  /// failure or an answer without a known `status` and a `hash` is a
  /// [LedgerUnavailable]: the caller cannot know whether the node took it.
  /// A [RpcRequestRejected] means the node refused the envelope itself, so
  /// sending it again cannot succeed. Status `ERROR` is a result, not an
  /// exception.
  Future<SendTransactionResult> sendTransaction(String envelopeXdr) async {
    const method = 'sendTransaction';
    final result = await _call(method, {'transaction': envelopeXdr});
    final status = _sendStatuses[result['status']];
    final hash = result['hash'];
    if (status == null || hash is! String) {
      throw LedgerUnavailable('$method answered no known status and hash');
    }
    final latestLedger = result['latestLedger'];
    final closeTime = result['latestLedgerCloseTime'];
    final errorResult = result['errorResultXdr'];
    return SendTransactionResult(
      status: status,
      hash: hash,
      latestLedger: latestLedger is int ? latestLedger : null,
      latestLedgerCloseTime: closeTime is String
          ? int.tryParse(closeTime)
          : (closeTime is int ? closeTime : null),
      errorResultXdr: errorResult is String ? errorResult : null,
    );
  }

  Future<Map<String, Object?>> _call(
    String method,
    Map<String, Object?> params,
  ) async {
    final http.Response response;
    try {
      response = await _http
          .post(
            _url,
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({
              'jsonrpc': '2.0',
              'id': 1,
              'method': method,
              'params': params,
            }),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw LedgerUnavailable('$method timed out after $_timeout');
    } on SocketException catch (e) {
      throw LedgerUnavailable('$method could not connect: ${e.message}');
    } on http.ClientException catch (e) {
      throw LedgerUnavailable('$method failed: ${e.message}');
    }
    if (response.statusCode < 200 || response.statusCode > 299) {
      throw LedgerUnavailable('$method answered HTTP ${response.statusCode}');
    }
    return _result(method, response.body);
  }

  Map<String, Object?> _result(String method, String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw LedgerUnavailable('$method answered a body that is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw LedgerUnavailable('$method answered JSON that is not an object');
    }
    if (decoded.containsKey('error')) {
      throw _rpcError(method, decoded['error']);
    }
    final result = decoded['result'];
    if (result is! Map<String, Object?>) {
      throw LedgerUnavailable('$method answered no result object');
    }
    return result;
  }

  /// A JSON-RPC `error` object as an exception that keeps its code and
  /// message. Only `invalid request` and `invalid params` say the request
  /// itself was refused; every other code may pass on a retry.
  LedgerException _rpcError(String method, Object? error) {
    final code = error is Map ? error['code'] : null;
    final rpcMessage = error is Map ? '${error['message'] ?? ''}' : '';
    if (code is! int) {
      return LedgerUnavailable('$method answered a malformed JSON-RPC error');
    }
    final description = '$method answered JSON-RPC error $code: $rpcMessage';
    return _rejectedRequestCodes.contains(code)
        ? RpcRequestRejected(code, rpcMessage, description)
        : LedgerUnavailable(description);
  }
}

/// JSON-RPC `invalid request` and `invalid params`.
const _rejectedRequestCodes = {-32600, -32602};
