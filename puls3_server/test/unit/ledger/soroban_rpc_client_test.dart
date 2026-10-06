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
const _sentHash =
    '7e1b2f3c4d5a69788796a5b4c3d2e1f00112233445566778899aabbccddeeff0';

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

    test(
      'sendTransaction posts the signed envelope without xdrFormat',
      () async {
        late Map<String, Object?> body;
        final client = _client(
          MockClient((request) async {
            body = jsonDecode(request.body) as Map<String, Object?>;
            return _json(_fixture('send_transaction_pending.json'));
          }),
        );

        await client.sendTransaction('AAAA');

        expect(body['method'], 'sendTransaction');
        expect(body['params'], {'transaction': 'AAAA'});
      },
    );
  });

  group('sendTransaction result', () {
    Future<SendTransactionResult> send(String fixture) => _client(
      MockClient((_) async => _json(_fixture(fixture))),
    ).sendTransaction('AAAA');

    Future<SendTransactionResult> sendResult(Map<String, Object?> result) =>
        _client(
          MockClient(
            (_) async => _json({'jsonrpc': '2.0', 'id': 1, 'result': result}),
          ),
        ).sendTransaction('AAAA');

    test('PENDING carries the hash and the latest ledger', () async {
      final result = await send('send_transaction_pending.json');

      expect(result.status, SendTransactionStatus.pending);
      expect(result.hash, _sentHash);
      expect(result.latestLedger, 5024571);
      expect(result.latestLedgerCloseTime, 1791146442);
      expect(result.errorResultXdr, isNull);
    });

    test('DUPLICATE', () async {
      final result = await send('send_transaction_duplicate.json');

      expect(result.status, SendTransactionStatus.duplicate);
      expect(result.hash, _sentHash);
    });

    test('TRY_AGAIN_LATER', () async {
      final result = await send('send_transaction_try_again_later.json');

      expect(result.status, SendTransactionStatus.tryAgainLater);
      expect(result.hash, _sentHash);
    });

    test('ERROR carries the base64 TransactionResult', () async {
      final result = await send('send_transaction_error.json');

      expect(result.status, SendTransactionStatus.error);
      expect(result.hash, _sentHash);
      expect(result.errorResultXdr, 'AAAAAAAAAGT////7AAAAAA==');
    });

    test('ledger fields are optional', () async {
      final result = await sendResult({'status': 'PENDING', 'hash': _sentHash});

      expect(result.latestLedger, isNull);
      expect(result.latestLedgerCloseTime, isNull);
      expect(result.errorResultXdr, isNull);
    });

    test('an unknown status or a missing hash is LedgerUnavailable', () {
      expect(
        () => sendResult({'status': 'SUCCESS', 'hash': _sentHash}),
        _throwsUnavailable,
      );
      expect(() => sendResult({'hash': _sentHash}), _throwsUnavailable);
      expect(() => sendResult({'status': 'PENDING'}), _throwsUnavailable);
      expect(
        () => sendResult({'status': 'PENDING', 'hash': 7}),
        _throwsUnavailable,
      );
    });
  });

  group('failures map to LedgerUnavailable', () {
    test('HTTP 503', () {
      final client = _client(
        MockClient((_) async => http.Response('down', 503)),
      );

      expect(() => client.simulateTransaction('AAAA'), _throwsUnavailable);
      expect(() => client.getTransaction('00' * 32), _throwsUnavailable);
      expect(() => client.sendTransaction('AAAA'), _throwsUnavailable);
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
      expect(() => client.sendTransaction('AAAA'), _throwsUnavailable);
    });

    test('an http client exception', () {
      final client = _client(
        MockClient((_) async => throw http.ClientException('reset')),
      );

      expect(() => client.getTransaction('00' * 32), _throwsUnavailable);
    });

    test('a JSON-RPC server error keeps its code and message', () {
      final client = _client(
        MockClient(
          (_) async => _json({
            'jsonrpc': '2.0',
            'id': 1,
            'error': {'code': -32603, 'message': 'internal error'},
          }),
        ),
      );

      final throwsServerError = throwsA(
        isA<LedgerUnavailable>().having(
          (e) => e.message,
          'message',
          allOf(contains('-32603'), contains('internal error')),
        ),
      );
      expect(() => client.simulateTransaction('AAAA'), throwsServerError);
      expect(() => client.sendTransaction('AAAA'), throwsServerError);
    });

    test('a JSON-RPC error without a numeric code', () {
      final client = _client(
        MockClient(
          (_) async => _json({'jsonrpc': '2.0', 'id': 1, 'error': 'boom'}),
        ),
      );

      expect(() => client.sendTransaction('AAAA'), _throwsUnavailable);
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

  group('a JSON-RPC rejection of the request is RpcRequestRejected', () {
    for (final code in [-32600, -32602]) {
      test('code $code', () {
        final client = _client(
          MockClient(
            (_) async => _json({
              'jsonrpc': '2.0',
              'id': 1,
              'error': {'code': code, 'message': 'invalid transaction'},
            }),
          ),
        );

        final throwsRejected = throwsA(
          isA<RpcRequestRejected>()
              .having((e) => e.code, 'code', code)
              .having((e) => e.rpcMessage, 'rpcMessage', 'invalid transaction'),
        );
        expect(() => client.sendTransaction('AAAA'), throwsRejected);
        expect(() => client.getTransaction('00' * 32), throwsRejected);
      });
    }
  });
}
