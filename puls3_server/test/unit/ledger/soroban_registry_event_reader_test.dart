import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:puls3_server/src/ledger/soroban_registry_event_reader.dart';
import 'package:puls3_server/src/ledger/soroban_rpc_client.dart';
import 'package:puls3_server/src/ledger/stellar_config.dart';
import 'package:test/test.dart';

const _registry =
    'CD5QZOKGRBV35C5SDT6PG7S72XGG4BHQAC2L56YLNBJDUL4LDMTXFIJJ';

/// A `getEvents` page with [count] (deliberately unparsable) events and an
/// optional cursor.
Map<String, Object?> _page({required int count, String? cursor}) => {
  'jsonrpc': '2.0',
  'id': 1,
  'result': {
    'events': [
      for (var i = 0; i < count; i++)
        {
          'ledger': 1,
          'contractId': _registry,
          'topicJson': <Object?>[],
          'valueJson': 'void',
          'inSuccessfulContractCall': true,
        },
    ],
    'latestLedger': 1000,
    'cursor': ?cursor,
  },
};

SorobanRegistryEventReader readerOver(
  http.Client client, {
  Map<String, String>? environment,
}) => SorobanRegistryEventReader(
  SorobanRpcClient(
    httpClient: client,
    url: Uri.parse('https://rpc.example.test'),
    timeout: const Duration(milliseconds: 50),
  ),
  StellarConfig.fromEnvironment(
    environment ?? const {'PULS3_STELLAR_IDENTITY_REGISTRY': _registry},
  ),
);

void main() {
  test('a short page is complete and stops after one request', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response(jsonEncode(_page(count: 2)), 200);
    });

    final batch = await readerOver(client).eventsSince(10);

    expect(calls, 1);
    expect(batch.truncated, isFalse);
  });

  test('a full page is followed with the cursor', () async {
    final bodies = <Map<String, Object?>>[];
    var calls = 0;
    final client = MockClient((request) async {
      bodies.add(jsonDecode(request.body) as Map<String, Object?>);
      calls++;
      return http.Response(
        jsonEncode(calls == 1 ? _page(count: 100, cursor: 'c1') : _page(count: 1)),
        200,
      );
    });

    final batch = await readerOver(client).eventsSince(10);

    expect(calls, 2);
    expect(batch.truncated, isFalse);
    expect(
      (bodies.first['params']! as Map)['startLedger'],
      10,
      reason: 'the first page uses the ledger range',
    );
    final secondParams = bodies[1]['params']! as Map;
    expect(secondParams.containsKey('startLedger'), isFalse);
    expect((secondParams['pagination']! as Map)['cursor'], 'c1');
  });

  test('the page bound reports truncation', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response(
        jsonEncode(_page(count: 100, cursor: 'always')),
        200,
      );
    });

    final batch = await readerOver(client).eventsSince(10);

    expect(batch.truncated, isTrue);
    expect(calls, 1000, reason: 'the reader stops at its page bound');
  });
}
