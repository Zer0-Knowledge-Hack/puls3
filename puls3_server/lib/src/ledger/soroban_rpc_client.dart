import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'ledger_errors.dart';

/// JSON-RPC transport to a Soroban RPC node, limited to the two read methods
/// the adapter uses. It has no way to submit a transaction.
///
/// Every failure to obtain a well-formed `result` object is a
/// [LedgerUnavailable]: an unreachable node must never look like "not found".
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
      throw LedgerUnavailable('$method answered a JSON-RPC error');
    }
    final result = decoded['result'];
    if (result is! Map<String, Object?>) {
      throw LedgerUnavailable('$method answered no result object');
    }
    return result;
  }
}
