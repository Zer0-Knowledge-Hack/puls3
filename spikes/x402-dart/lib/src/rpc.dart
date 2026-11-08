import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// The result of `simulateTransaction` that the client uses.
final class Simulation {
  Simulation({
    required this.auth,
    required this.transactionData,
    required this.minResourceFee,
  });

  /// `SorobanAuthorizationEntry` XDR blobs of the first result.
  final List<Uint8List> auth;

  /// `SorobanTransactionData` XDR.
  final Uint8List transactionData;
  final int minResourceFee;
}

final class SimulationFailed implements Exception {
  SimulationFailed(this.message);

  final String message;

  @override
  String toString() => 'SimulationFailed: $message';
}

/// The Soroban RPC calls the client makes.
abstract interface class SorobanRpc {
  Future<int> latestLedger();

  /// The mean close time of recent ledgers, in whole seconds (rounded up).
  Future<int> ledgerCloseSeconds();

  Future<Simulation> simulate(Uint8List envelope);
}

/// [SorobanRpc] over JSON-RPC.
final class HttpSorobanRpc implements SorobanRpc {
  HttpSorobanRpc(this.url, {http.Client? client})
    : _http = client ?? http.Client();

  final Uri url;
  final http.Client _http;
  var _id = 0;

  static const _sampleLedgers = 20;
  static const _fallbackCloseSeconds = 5;

  @override
  Future<int> latestLedger() async {
    final result = await _call('getLatestLedger', const {});
    return result['sequence'] as int;
  }

  @override
  Future<int> ledgerCloseSeconds() async {
    try {
      final latest = await latestLedger();
      final result = await _call('getLedgers', {
        'startLedger': latest - _sampleLedgers + 1,
        'pagination': {'limit': _sampleLedgers},
      });
      final ledgers = (result['ledgers'] as List).cast<Map<String, Object?>>();
      if (ledgers.length < 2) return _fallbackCloseSeconds;
      final first = int.parse('${ledgers.first['ledgerCloseTime']}');
      final last = int.parse('${ledgers.last['ledgerCloseTime']}');
      final seconds = ((last - first) / (ledgers.length - 1)).ceil();
      return seconds > 0 ? seconds : _fallbackCloseSeconds;
    } on Object {
      return _fallbackCloseSeconds;
    }
  }

  @override
  Future<Simulation> simulate(Uint8List envelope) async {
    final result = await _call('simulateTransaction', {
      // No authMode: the RPC records auth when the envelope has none and
      // enforces the signed entries when it has them.
      'transaction': base64.encode(envelope),
    });
    final error = result['error'];
    if (error != null) throw SimulationFailed('$error');
    if (result['restorePreamble'] != null) {
      throw SimulationFailed('archived ledger entries need a restore');
    }
    final results = result['results'];
    final first = results is List && results.isNotEmpty
        ? results.first as Map<String, Object?>
        : const <String, Object?>{};
    return Simulation(
      auth: [
        for (final entry in (first['auth'] as List?) ?? const [])
          base64.decode(entry as String),
      ],
      transactionData: base64.decode(result['transactionData'] as String),
      minResourceFee: int.parse('${result['minResourceFee']}'),
    );
  }

  Future<Map<String, Object?>> _call(
    String method,
    Map<String, Object?> params,
  ) async {
    final response = await _http.post(
      url,
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'jsonrpc': '2.0',
        'id': ++_id,
        'method': method,
        'params': params,
      }),
    );
    if (response.statusCode != 200) {
      throw SimulationFailed('$method: HTTP ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, Object?>;
    final error = body['error'];
    if (error != null) throw SimulationFailed('$method: $error');
    return body['result'] as Map<String, Object?>;
  }
}
