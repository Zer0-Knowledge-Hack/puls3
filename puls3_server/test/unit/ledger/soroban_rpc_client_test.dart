import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:puls3_server/src/ledger/ledger_errors.dart';
import 'package:puls3_server/src/ledger/soroban_rpc_client.dart';
import 'package:test/test.dart';

final _rpcUrl = Uri.parse('https://rpc.example.test');
const _timeout = Duration(milliseconds: 50);
final _throwsUnavailable = throwsA(isA<LedgerUnavailable>());

Map<String, Object?> _fixture(String name) =>
    jsonDecode(File('test/unit/ledger/fixtures/$name').readAsStringSync())
        as Map<String, Object?>;

SorobanRpcClient _client(http.Client httpClient) => SorobanRpcClient(
  httpClient: httpClient,
  url: _rpcUrl,
  timeout: _timeout,
);

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  group('requests', () {
    test('simulate posts the envelope with xdrFormat json', () async {
      late http.Request seen;
      final client = _client(
        MockClient((request) async {
          seen = request;
          return _json(_fixture('simulate_agent_exists_true.json'));
        }),
      );

      final result = await client.simulateTransaction('AAAA');

      expect(seen.method, 'POST');
      expect(seen.url, _rpcUrl);
      expect(seen.headers['content-type'], startsWith('application/json'));
      final body = jsonDecode(seen.body) as Map<String, Object?>;
      expect(body['jsonrpc'], '2.0');
      expect(body['method'], 'simulateTransaction');
      expect(body['params'], {'transaction': 'AAAA', 'xdrFormat': 'json'});
      expect(result['latestLedger'], isA<int>());
      expect(
        ((result['results']! as List).single as Map)['returnValueJson'],
        {'bool': true},
      );
    });

    test('getTransaction posts the hash with xdrFormat json', () async {
      late Map<String, Object?> body;
      final client = _client(
        MockClient((request) async {
          body = jsonDecode(request.body) as Map<String, Object?>;
          return _json(_fixture('get_transaction_success.json'));
        }),
      );

      final result = await client.getTransaction('ab' * 32);

      expect(body['method'], 'getTransaction');
      expect(body['params'], {'hash': 'ab' * 32, 'xdrFormat': 'json'});
      expect(result['status'], 'SUCCESS');
    });

    test('only the two read methods exist, never sendTransaction', () async {
      final methods = <String>[];
      final client = _client(
        MockClient((request) async {
          methods.add(
            (jsonDecode(request.body) as Map<String, Object?>)['method']!
                as String,
          );
          return _json(_fixture('get_transaction_not_found.json'));
        }),
      );

      await client.simulateTransaction('AAAA');
      await client.getTransaction('00' * 32);

      expect(methods, ['simulateTransaction', 'getTransaction']);
    });
  });

  group('failures map to LedgerUnavailable', () {
    test('HTTP 503', () {
      final client = _client(
        MockClient((_) async => http.Response('down', 503)),
      );

      expect(() => client.simulateTransaction('AAAA'), _throwsUnavailable);
      expect(() => client.getTransaction('00' * 32), _throwsUnavailable);
    });

    test('HTTP 4xx', () {
      final client = _client(
        MockClient((_) async => http.Response('nope', 429)),
      );

      expect(() => client.simulateTransaction('AAAA'), _throwsUnavailable);
    });

    test('a timeout', () {
      final client = _client(
        MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          return _json(_fixture('simulate_agent_exists_true.json'));
        }),
      );

      expect(() => client.simulateTransaction('AAAA'), _throwsUnavailable);
    });

    test('a connection error', () {
      final client = _client(
        MockClient((_) async => throw const SocketException('refused')),
      );

      expect(() => client.simulateTransaction('AAAA'), _throwsUnavailable);
    });

    test('an http client exception', () {
      final client = _client(
        MockClient((_) async => throw http.ClientException('reset')),
      );

      expect(() => client.getTransaction('00' * 32), _throwsUnavailable);
    });

    test('a JSON-RPC error object on a 200 response', () {
      final client = _client(
        MockClient(
          (_) async => _json({
            'jsonrpc': '2.0',
            'id': 1,
            'error': {'code': -32602, 'message': 'invalid params'},
          }),
        ),
      );

      expect(() => client.simulateTransaction('AAAA'), _throwsUnavailable);
    });

    test('a body that is not JSON', () {
      final client = _client(
        MockClient((_) async => http.Response('<html>', 200)),
      );

      expect(() => client.simulateTransaction('AAAA'), _throwsUnavailable);
    });

    test('JSON that has no result object', () {
      final client = _client(
        MockClient((_) async => _json({'jsonrpc': '2.0', 'id': 1})),
      );
      final listClient = _client(MockClient((_) async => _json([1, 2])));

      expect(() => client.getTransaction('00' * 32), _throwsUnavailable);
      expect(() => listClient.getTransaction('00' * 32), _throwsUnavailable);
    });
  });
}
