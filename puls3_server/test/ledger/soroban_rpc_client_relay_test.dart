// Tests of the relay additions to SorobanRpcClient (issue #96): the account
// sequence through getLedgerEntries and the base64 simulation.
//
// Recorded read-only on testnet on 2026-10-07 (soroban-testnet.stellar.org):
//  - get_ledger_entries_account.json: the account that signed job 3.
//  - get_ledger_entries_missing_account.json: an account that does not exist.
//  - simulate_create_job_3_base64.json: simulateTransaction of the recorded
//    create_job envelope.
//  - simulate_fund_job_3_error_base64.json: simulateTransaction of the
//    recorded fund envelope, which fails because job 3 is already funded.
// The failures below the recorded ones are derived by removing or adding one
// field of a recorded answer; they are marked "derived".
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/ledger/ledger_errors.dart';
import 'package:puls3_server/src/ledger/soroban_rpc_client.dart';
import 'package:test/test.dart';

final _rpcUrl = Uri.parse('https://rpc.example.test');
const _timeout = Duration(milliseconds: 50);

final _account = StellarAddress.parse(
  'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H',
);
final _missing = StellarAddress.parse(
  'GBNFUWS2LJNFUWS2LJNFUWS2LJNFUWS2LJNFUWS2LJNFUWS2LJNFV3TR',
);

/// LedgerKey ACCOUNT (0) | PUBLIC_KEY_TYPE_ED25519 (0) | the 32-byte key.
const _accountKey = 'AAAAAAAAAAACpt+ntemJ2L50UKw7TTzA9PvuQXnpvfpBGVNa5gwugw==';
const _missingKey = 'AAAAAAAAAABaWlpaWlpaWlpaWlpaWlpaWlpaWlpaWlpaWlpaWlpaWg==';

/// The sequence number inside the recorded account entry.
const _accountSequence = 20602318168784916;

Map<String, Object?> _fixture(String name) =>
    jsonDecode(File('test/fixtures/escrow_relay/$name').readAsStringSync())
        as Map<String, Object?>;

SorobanRpcClient _client(http.Client httpClient) => SorobanRpcClient(
  httpClient: httpClient,
  url: _rpcUrl,
  timeout: _timeout,
);

SorobanRpcClient _answering(
  Map<String, Object?> body, {
  void Function(http.Request)? seen,
}) => _client(
  MockClient((request) async {
    seen?.call(request);
    return http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
    );
  }),
);

Map<String, Object?> _result(Map<String, Object?> response) =>
    response['result']! as Map<String, Object?>;

void main() {
  group('accountSequence', () {
    test(
      'asks getLedgerEntries for the account ledger key in base64',
      () async {
        late http.Request request;
        final client = _answering(
          _fixture('get_ledger_entries_account.json'),
          seen: (r) => request = r,
        );

        await client.accountSequence(_account);

        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['method'], 'getLedgerEntries');
        expect(body['params'], {
          'keys': [_accountKey],
          'xdrFormat': 'base64',
        });
      },
    );

    test('builds the key from the address bytes', () async {
      late http.Request request;
      final client = _answering(
        _fixture('get_ledger_entries_missing_account.json'),
        seen: (r) => request = r,
      );

      await client.accountSequence(_missing);

      final body = jsonDecode(request.body) as Map<String, Object?>;
      expect((body['params']! as Map)['keys'], [_missingKey]);
    });

    test('reads the sequence number of the recorded account entry', () async {
      final client = _answering(_fixture('get_ledger_entries_account.json'));

      expect(await client.accountSequence(_account), _accountSequence);
    });

    test('an account that does not exist has no sequence', () async {
      final client = _answering(
        _fixture('get_ledger_entries_missing_account.json'),
      );

      expect(await client.accountSequence(_missing), isNull);
    });

    test('derived: an entry that is not an account is unavailable', () {
      final response = _fixture('get_ledger_entries_account.json');
      final entry =
          ((_result(response)['entries']! as List).single
              as Map<String, Object?>);
      // Same bytes with the LedgerEntryType changed from ACCOUNT (0) to TRUSTLINE (1).
      final bytes = base64Decode(entry['xdr']! as String)..[3] = 1;
      entry['xdr'] = base64Encode(bytes);

      expect(
        _answering(response).accountSequence(_account),
        throwsA(isA<LedgerUnavailable>()),
      );
    });

    test('derived: an entry cut short is unavailable', () {
      final response = _fixture('get_ledger_entries_account.json');
      final entry =
          ((_result(response)['entries']! as List).single
              as Map<String, Object?>);
      entry['xdr'] = base64Encode(
        base64Decode(entry['xdr']! as String).sublist(0, 52),
      );

      expect(
        _answering(response).accountSequence(_account),
        throwsA(isA<LedgerUnavailable>()),
      );
    });

    test('derived: an answer without entries is unavailable', () {
      final response = _fixture('get_ledger_entries_account.json');
      _result(response).remove('entries');

      expect(
        _answering(response).accountSequence(_account),
        throwsA(isA<LedgerUnavailable>()),
      );
    });

    test('an unreachable node is unavailable, never "no account"', () {
      final client = _client(
        MockClient((_) async => http.Response('down', 503)),
      );

      expect(
        client.accountSequence(_account),
        throwsA(isA<LedgerUnavailable>()),
      );
    });
  });

  group('simulateTransactionBase64', () {
    test('posts the envelope with xdrFormat base64', () async {
      late http.Request request;
      final client = _answering(
        _fixture('simulate_create_job_3_base64.json'),
        seen: (r) => request = r,
      );

      await client.simulateTransactionBase64('AAAA');

      final body = jsonDecode(request.body) as Map<String, Object?>;
      expect(body['method'], 'simulateTransaction');
      expect(body['params'], {'transaction': 'AAAA', 'xdrFormat': 'base64'});
    });

    test(
      'returns the Soroban data, minimum fee and auth of the recording',
      () async {
        final response = _fixture('simulate_create_job_3_base64.json');
        final recorded = _result(response);
        final auth =
            ((recorded['results']! as List).single
                    as Map<String, Object?>)['auth']!
                as List;

        final data = await _answering(
          response,
        ).simulateTransactionBase64('AAAA');

        expect(data.transactionData, recorded['transactionData']);
        expect(data.minResourceFee, 3304282);
        expect(data.auth, auth.cast<String>());
        expect(data.auth, hasLength(1));
      },
    );

    test(
      'the contract error of a failed simulation is a LedgerContractError',
      () {
        final client = _answering(
          _fixture('simulate_fund_job_3_error_base64.json'),
        );

        expect(
          client.simulateTransactionBase64('AAAA'),
          throwsA(
            isA<LedgerContractError>().having((e) => e.code, 'code', 2),
          ),
        );
      },
    );

    test('derived: an error without a contract code is unavailable', () {
      final response = _fixture('simulate_fund_job_3_error_base64.json');
      _result(response)['error'] = 'HostError: Error(WasmVm, InvalidAction)';

      expect(
        _answering(response).simulateTransactionBase64('AAAA'),
        throwsA(isA<LedgerUnavailable>()),
      );
    });

    test('derived: archived state that needs a restore is unavailable', () {
      final response = _fixture('simulate_create_job_3_base64.json');
      _result(response)['restorePreamble'] = {
        'transactionData': 'AAAA',
        'minResourceFee': '1',
      };

      expect(
        _answering(response).simulateTransactionBase64('AAAA'),
        throwsA(isA<LedgerUnavailable>()),
      );
    });

    test('derived: no transactionData is unavailable', () {
      final response = _fixture('simulate_create_job_3_base64.json');
      _result(response).remove('transactionData');

      expect(
        _answering(response).simulateTransactionBase64('AAAA'),
        throwsA(isA<LedgerUnavailable>()),
      );
    });

    test('derived: a minResourceFee that is not a number is unavailable', () {
      final response = _fixture('simulate_create_job_3_base64.json');
      _result(response)['minResourceFee'] = 'many';

      expect(
        _answering(response).simulateTransactionBase64('AAAA'),
        throwsA(isA<LedgerUnavailable>()),
      );
    });

    test('derived: a result without auth carries no entries', () async {
      final response = _fixture('simulate_create_job_3_base64.json');
      ((_result(response)['results']! as List).single as Map).remove('auth');

      final data = await _answering(response).simulateTransactionBase64('AAAA');

      expect(data.auth, isEmpty);
      expect(data.minResourceFee, 3304282);
    });

    test('an unreachable node is unavailable', () {
      final client = _client(
        MockClient((_) async => throw http.ClientException('refused')),
      );

      expect(
        client.simulateTransactionBase64('AAAA'),
        throwsA(isA<LedgerUnavailable>()),
      );
    });
  });
}
