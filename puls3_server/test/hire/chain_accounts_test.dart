// Tests of the ChainAccounts adapter (issue #96): the signer's sequence number
// and the simulation of an escrow call, over the recorded testnet answers in
// test/fixtures/escrow_relay (see soroban_rpc_client_relay_test.dart for how
// they were recorded).
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/generated/protocol.dart'
    show Puls3ApiException;
import 'package:puls3_server/src/hire/chain_accounts.dart';
import 'package:puls3_server/src/ledger/envelope_codec.dart';
import 'package:puls3_server/src/ledger/soroban_rpc_client.dart';
import 'package:puls3_server/src/ledger/xdr_invoke_encoder.dart';
import 'package:test/test.dart';

final _signer = StellarAddress.parse(
  'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H',
);
final _missing = StellarAddress.parse(
  'GBNFUWS2LJNFUWS2LJNFUWS2LJNFUWS2LJNFUWS2LJNFUWS2LJNFV3TR',
);
final _escrow = StellarAddress.parse(
  'CBRD7A7MXINM7LREKCL3RMKRQ5UMLGKNHAEYY4JT7MVBBB7R5QV4TPE2',
);

String _fixture(String name) =>
    File('test/fixtures/escrow_relay/$name').readAsStringSync();

/// A node that answers each JSON-RPC method with the given recorded body, and
/// remembers the requests.
({RpcChainAccounts accounts, List<Map<String, Object?>> requests}) _node(
  Map<String, String> answers,
) {
  final requests = <Map<String, Object?>>[];
  final client = SorobanRpcClient(
    httpClient: MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, Object?>;
      requests.add(body);
      final answer = answers[body['method']];
      if (answer == null) return http.Response('no such method', 404);
      return http.Response(
        answer,
        200,
        headers: {'content-type': 'application/json'},
      );
    }),
    url: Uri.parse('https://rpc.example.test'),
    timeout: const Duration(milliseconds: 50),
  );
  return (accounts: RpcChainAccounts(client), requests: requests);
}

EnvelopeSpec _spec({int accountSequence = 20602318168784913}) => EnvelopeSpec(
  source: _signer,
  accountSequence: accountSequence,
  contract: _escrow,
  function: 'fund',
  args: [
    ScArg.address(_signer),
    const ScArg.u64(3),
    const ScArg.i128(5000000),
    const ScArg.u32(0),
  ],
  inclusionFee: 100,
  validUntil: 1791750000,
);

/// `ChainUnavailable` with `details.reason = simulationFailed` (P3), and
/// nothing of the node's own text in the message.
final _chainUnavailable = throwsA(
  isA<Puls3ApiException>()
      .having((e) => e.code, 'code', 'ChainUnavailable')
      .having((e) => e.details, 'details', {'reason': 'simulationFailed'})
      .having(
        (e) => '${e.message}',
        'message',
        isNot(anyOf(contains('HostError'), contains('rpc.example'))),
      ),
);

void main() {
  group('sequenceOf', () {
    test('returns the sequence number recorded for the account', () async {
      final node = _node({
        'getLedgerEntries': _fixture('get_ledger_entries_account.json'),
      });

      expect(await node.accounts.sequenceOf(_signer), 20602318168784916);
    });

    test('a second account gets its own key in the request', () async {
      final node = _node({
        'getLedgerEntries': _fixture('get_ledger_entries_account.json'),
      });

      await node.accounts.sequenceOf(_signer);
      await node.accounts.sequenceOf(_missing).then((_) {}, onError: (_) {});

      final keys = [
        for (final r in node.requests) (r['params']! as Map)['keys'],
      ];
      expect(keys, [
        ['AAAAAAAAAAACpt+ntemJ2L50UKw7TTzA9PvuQXnpvfpBGVNa5gwugw=='],
        ['AAAAAAAAAABaWlpaWlpaWlpaWlpaWlpaWlpaWlpaWlpaWlpaWlpaWg=='],
      ]);
    });

    test('an account that is not on the ledger cannot be prepared for', () {
      final node = _node({
        'getLedgerEntries': _fixture('get_ledger_entries_missing_account.json'),
      });

      expect(node.accounts.sequenceOf(_missing), _chainUnavailable);
    });

    test('an unreachable node is ChainUnavailable', () {
      final node = _node({});

      expect(node.accounts.sequenceOf(_signer), _chainUnavailable);
    });
  });

  group('simulate', () {
    test('returns the recorded Soroban data, fee and auth', () async {
      final node = _node({
        'simulateTransaction': _fixture('simulate_create_job_3_base64.json'),
      });
      final recorded =
          (jsonDecode(_fixture('simulate_create_job_3_base64.json'))
                  as Map<String, Object?>)['result']!
              as Map<String, Object?>;

      final data = await node.accounts.simulate(_spec());

      expect(data.transactionData, recorded['transactionData']);
      expect(data.minResourceFee, 3304282);
      expect(data.auth, hasLength(1));
    });

    test('sends the unsigned call with the next sequence number', () async {
      final node = _node({
        'simulateTransaction': _fixture('simulate_create_job_3_base64.json'),
      });

      await node.accounts.simulate(_spec(accountSequence: 7));
      await node.accounts.simulate(_spec(accountSequence: 8));

      String sent(int i) =>
          (node.requests[i]['params']! as Map)['transaction']! as String;
      String expected(int sequence) => encodeInvokeEnvelope(
        source: _signer,
        fee: 100,
        sequence: sequence,
        contract: _escrow,
        function: 'fund',
        args: _spec().args,
      );
      expect(sent(0), expected(8));
      expect(sent(1), expected(9));
      expect((node.requests[0]['params']! as Map)['xdrFormat'], 'base64');
    });

    test('a simulation the contract rejects is ChainUnavailable (P3)', () {
      final node = _node({
        'simulateTransaction': _fixture(
          'simulate_fund_job_3_error_base64.json',
        ),
      });

      expect(node.accounts.simulate(_spec()), _chainUnavailable);
    });

    test('an unreachable node is ChainUnavailable', () {
      final node = _node({});

      expect(node.accounts.simulate(_spec()), _chainUnavailable);
    });
  });
}
