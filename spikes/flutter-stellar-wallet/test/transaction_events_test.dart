import 'dart:convert';

import 'package:flutter_stellar_wallet_spike/transaction_events.dart';
import 'package:flutter_test/flutter_test.dart';

const txHash = 'aa11';
const ledger = 4953089;

Map<String, Object?> event(String id, String hash, {int onLedger = ledger}) => {
  'id': id,
  'ledger': onLedger,
  'txHash': hash,
  'type': 'contract',
};

Map<String, Object?> page(List<Map<String, Object?>> events, String cursor) => {
  'jsonrpc': '2.0',
  'id': 1,
  'result': {'events': events, 'cursor': cursor, 'latestLedger': ledger + 5},
};

final class ScriptedRpc {
  ScriptedRpc(this.pages);
  final List<Map<String, Object?>> pages;
  final requests = <EventsPageRequest>[];

  Future<Map<String, Object?>> fetch(EventsPageRequest request) async {
    requests.add(request);
    return pages[requests.length - 1];
  }
}

void main() {
  test('pages from the transaction ledger with the cursor until the ledger '
      'is exhausted and keeps only the transaction events', () async {
    final rpc = ScriptedRpc([
      page([event('1', 'other'), event('2', 'other')], 'c1'),
      page([event('3', txHash), event('4', 'other')], 'c2'),
      page([
        event('5', txHash),
        event('6', 'other', onLedger: ledger + 1),
      ], 'c3'),
    ]);

    final json = await collectTransactionEvents(
      fetchPage: rpc.fetch,
      txHash: txHash,
      ledger: ledger,
      pageLimit: 2,
    );

    final result = (jsonDecode(json) as Map)['result'] as Map;
    expect((result['events'] as List).map((e) => (e as Map)['id']), ['3', '5']);
    expect(rpc.requests.first.startLedger, ledger);
    expect(rpc.requests.first.endLedger, ledger + 1);
    expect(rpc.requests.first.cursor, isNull);
    expect(rpc.requests.skip(1).map((r) => r.cursor), ['c1', 'c2']);
    expect(rpc.requests.skip(1).every((r) => r.startLedger == null), isTrue);
    expect(rpc.requests.every((r) => r.limit == 2), isTrue);
  });

  test('stops on a short page', () async {
    final rpc = ScriptedRpc([
      page([event('1', txHash)], 'c1'),
    ]);
    await collectTransactionEvents(
      fetchPage: rpc.fetch,
      txHash: txHash,
      ledger: ledger,
      pageLimit: 2,
    );
    expect(rpc.requests, hasLength(1));
  });

  test('fails closed when the exhausted range has no transaction events', () {
    final rpc = ScriptedRpc([
      page([event('1', 'other')], 'c1'),
    ]);
    expect(
      collectTransactionEvents(
        fetchPage: rpc.fetch,
        txHash: txHash,
        ledger: ledger,
        pageLimit: 2,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('fails closed when the page budget runs out', () {
    final rpc = ScriptedRpc([
      for (var i = 0; i < 3; i++)
        page([event('$i-a', txHash), event('$i-b', 'other')], 'c$i'),
    ]);
    expect(
      collectTransactionEvents(
        fetchPage: rpc.fetch,
        txHash: txHash,
        ledger: ledger,
        pageLimit: 2,
        maxPages: 3,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('fails closed on an RPC error or a missing cursor', () async {
    await expectLater(
      collectTransactionEvents(
        fetchPage: ScriptedRpc([
          {
            'jsonrpc': '2.0',
            'id': 1,
            'error': {'code': -32600, 'message': 'bad range'},
          },
        ]).fetch,
        txHash: txHash,
        ledger: ledger,
      ),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      collectTransactionEvents(
        fetchPage: ScriptedRpc([
          {
            'jsonrpc': '2.0',
            'id': 1,
            'result': {
              'events': [event('1', 'other'), event('2', 'other')],
            },
          },
        ]).fetch,
        txHash: txHash,
        ledger: ledger,
        pageLimit: 2,
      ),
      throwsA(isA<StateError>()),
    );
  });
}
