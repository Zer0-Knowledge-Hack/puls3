import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/ledger/escrow_job.dart';
import 'package:puls3_server/src/ledger/ledger_errors.dart';
import 'package:puls3_server/src/ledger/soroban_ledger.dart';
import 'package:puls3_server/src/ledger/soroban_rpc_client.dart';
import 'package:puls3_server/src/ledger/stellar_config.dart';
import 'package:puls3_server/src/ledger/xdr_invoke_encoder.dart';
import 'package:test/test.dart';

final _config = StellarConfig.testnet;
final _throwsUnavailable = throwsA(isA<LedgerUnavailable>());

Map<String, Object?> _fixture(String name) =>
    jsonDecode(File('test/unit/ledger/fixtures/$name').readAsStringSync())
        as Map<String, Object?>;

/// A ledger whose RPC answers [body] and records every request it receives.
({SorobanLedger ledger, List<Map<String, Object?>> requests}) _ledgerAnswering(
  Object body, {
  int status = 200,
}) {
  final requests = <Map<String, Object?>>[];
  final client = MockClient((request) async {
    requests.add(jsonDecode(request.body) as Map<String, Object?>);
    return http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );
  });
  final rpc = SorobanRpcClient(
    httpClient: client,
    url: _config.rpcUrl,
    timeout: const Duration(seconds: 1),
  );
  return (ledger: SorobanLedger(rpc, _config), requests: requests);
}

String _expectedEnvelope(
  StellarAddress contract,
  String function,
  ScArg arg,
) => encodeInvokeEnvelope(
  source: _config.simulationSource,
  fee: 100,
  sequence: 0,
  contract: contract,
  function: function,
  args: [arg],
);

Map<String, Object?> _withResultKey(
  String fixture,
  String key,
  Object? value,
) {
  final response = _fixture(fixture);
  (response['result']! as Map<String, Object?>)[key] = value;
  return response;
}

void main() {
  group('agentExists', () {
    test('is true for a registered agent and sends the right call', () async {
      final h = _ledgerAnswering(_fixture('simulate_agent_exists_true.json'));

      expect(await h.ledger.agentExists(AgentId(7)), isTrue);

      expect(h.requests, hasLength(1));
      expect(h.requests.single['method'], 'simulateTransaction');
      final params = h.requests.single['params']! as Map<String, Object?>;
      expect(params['xdrFormat'], 'json');
      expect(
        params['transaction'],
        _expectedEnvelope(
          _config.identityRegistry,
          'agent_exists',
          const ScArg.u32(7),
        ),
      );
    });

    test('is false for an unregistered agent', () async {
      final h = _ledgerAnswering(_fixture('simulate_agent_exists_false.json'));

      expect(await h.ledger.agentExists(AgentId(99999)), isFalse);
    });

    test('a value that is not a bool is unavailable', () {
      final h = _ledgerAnswering(_fixture('simulate_agent_uri_present.json'));

      expect(() => h.ledger.agentExists(AgentId(7)), _throwsUnavailable);
    });
  });

  group('agentUri', () {
    test('returns the recorded uri', () async {
      final h = _ledgerAnswering(_fixture('simulate_agent_uri_present.json'));

      expect(await h.ledger.agentUri(AgentId(7)), 'puls3://demo/agt-001');
      final params = h.requests.single['params']! as Map<String, Object?>;
      expect(
        params['transaction'],
        _expectedEnvelope(
          _config.identityRegistry,
          'agent_uri',
          const ScArg.u32(7),
        ),
      );
    });

    test('UriNotSet (#2) means no uri, not a failure', () async {
      final h = _ledgerAnswering(_fixture('simulate_agent_uri_missing.json'));

      expect(await h.ledger.agentUri(AgentId(99999)), isNull);
    });

    test('a void result is also no uri', () async {
      final h = _ledgerAnswering(
        _fixture('simulate_agent_wallet_void.json'),
      );

      expect(await h.ledger.agentUri(AgentId(1)), isNull);
    });

    test('any other contract error surfaces its code', () {
      final response = _withResultKey(
        'simulate_agent_uri_missing.json',
        'error',
        'HostError: Error(Contract, #3)\n\nEvent log (newest first):',
      );
      final h = _ledgerAnswering(response);

      expect(
        () => h.ledger.agentUri(AgentId(1)),
        throwsA(
          isA<LedgerContractError>().having((e) => e.code, 'code', 3),
        ),
      );
    });
  });

  group('agentWallet', () {
    test('returns the registered wallet', () async {
      final h = _ledgerAnswering(
        _fixture('simulate_agent_wallet_registered.json'),
      );

      final wallet = await h.ledger.agentWallet(AgentId(7));

      expect(
        wallet,
        StellarAddress.parse(
          'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY',
        ),
      );
      final params = h.requests.single['params']! as Map<String, Object?>;
      expect(
        params['transaction'],
        _expectedEnvelope(
          _config.identityRegistry,
          'get_agent_wallet',
          const ScArg.u32(7),
        ),
      );
    });

    test('is null when the contract returns void', () async {
      final h = _ledgerAnswering(
        _fixture('simulate_agent_wallet_void.json'),
      );

      expect(await h.ledger.agentWallet(AgentId(99999)), isNull);
    });
  });

  group('failures', () {
    test('a JSON-RPC error is unavailable', () {
      final h = _ledgerAnswering({
        'jsonrpc': '2.0',
        'id': 1,
        'error': {'code': -32603, 'message': 'internal'},
      });

      expect(() => h.ledger.agentExists(AgentId(7)), _throwsUnavailable);
    });

    test('HTTP 503 is unavailable', () {
      final h = _ledgerAnswering({'error': 'down'}, status: 503);

      expect(() => h.ledger.agentWallet(AgentId(7)), _throwsUnavailable);
    });

    test('a restorePreamble is unavailable, never a false answer', () {
      final response = _withResultKey(
        'simulate_agent_exists_true.json',
        'restorePreamble',
        {'minResourceFee': '1000', 'transactionDataJson': <String, Object?>{}},
      );
      final h = _ledgerAnswering(response);

      expect(() => h.ledger.agentExists(AgentId(7)), _throwsUnavailable);
    });

    test('an unparseable simulation error is unavailable', () {
      final response = _withResultKey(
        'simulate_agent_uri_missing.json',
        'error',
        'HostError: Error(WasmVm, InvalidAction)',
      );
      final h = _ledgerAnswering(response);

      expect(() => h.ledger.agentUri(AgentId(1)), _throwsUnavailable);
    });

    test('an unexpected contract error on agentExists has a code', () {
      final response = _withResultKey(
        'simulate_agent_uri_missing.json',
        'error',
        'HostError: Error(Contract, #2)',
      );
      final h = _ledgerAnswering(response);

      expect(
        () => h.ledger.agentExists(AgentId(1)),
        throwsA(isA<LedgerContractError>().having((e) => e.code, 'code', 2)),
      );
    });

    test('a simulation with no results is unavailable', () {
      final response = _fixture('simulate_agent_exists_true.json');
      (response['result']! as Map<String, Object?>)['results'] = <Object?>[];
      final h = _ledgerAnswering(response);

      expect(() => h.ledger.agentExists(AgentId(7)), _throwsUnavailable);
    });
  });

  group('findPayment', () {
    final hash = TransactionHash.parse(
      '652a575b5d85814c19a4fed0f7d21f40acb35a399c4008d450877ee83e8b31ab',
    );

    test('returns the recorded USDC payment and asks getTransaction', () async {
      final h = _ledgerAnswering(_fixture('get_transaction_success.json'));

      final payment = await h.ledger.findPayment(hash);

      expect(payment?.transaction, hash);
      expect(payment?.hireId, HireId(8));
      expect(payment?.amount, UsdcAmount.stroops(5000000));
      expect(
        payment?.payee.value,
        'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY',
      );
      expect(h.requests, hasLength(1));
      expect(h.requests.single['method'], 'getTransaction');
      expect(h.requests.single['params'], {
        'hash': hash.value,
        'xdrFormat': 'json',
      });
    });

    test('is null for a transaction the RPC does not know', () async {
      final h = _ledgerAnswering(_fixture('get_transaction_not_found.json'));

      expect(await h.ledger.findPayment(hash), isNull);
    });

    test('is null for a FAILED transaction', () async {
      final response = _withResultKey(
        'get_transaction_success.json',
        'status',
        'FAILED',
      );
      final h = _ledgerAnswering(response);

      expect(await h.ledger.findPayment(hash), isNull);
    });

    test('is null when the transfer came from another SAC', () async {
      final other = SorobanLedger(
        SorobanRpcClient(
          httpClient: MockClient(
            (_) async => http.Response(
              jsonEncode(_fixture('get_transaction_success.json')),
              200,
            ),
          ),
          url: _config.rpcUrl,
          timeout: const Duration(seconds: 1),
        ),
        StellarConfig(
          rpcUrl: _config.rpcUrl,
          networkPassphrase: _config.networkPassphrase,
          usdcSac: _config.escrow,
          identityRegistry: _config.identityRegistry,
          escrow: _config.escrow,
          simulationSource: _config.simulationSource,
        ),
      );

      expect(await other.findPayment(hash), isNull);
    });

    test('an outage is unavailable, not "unpaid"', () {
      final h = _ledgerAnswering({'error': 'down'}, status: 503);

      expect(() => h.ledger.findPayment(hash), _throwsUnavailable);
    });
  });

  group('escrowJob', () {
    test(
      'decodes the recorded job 3 and calls get_job on the escrow',
      () async {
        final h = _ledgerAnswering(_fixture('simulate_escrow_job_3.json'));

        final job = await h.ledger.escrowJob(3);

        expect(job?.agentId, AgentId(7));
        expect(job?.state, EscrowJobState.completed);
        expect(job?.budget, BigInt.from(5000000));
        final params = h.requests.single['params']! as Map<String, Object?>;
        expect(
          params['transaction'],
          _expectedEnvelope(_config.escrow, 'get_job', const ScArg.u64(3)),
        );
      },
    );

    test('JobNotFound (#1) is null', () async {
      final h = _ledgerAnswering(_fixture('simulate_escrow_job_missing.json'));

      expect(await h.ledger.escrowJob(999), isNull);
    });

    test('a void result is null', () async {
      final h = _ledgerAnswering(_fixture('simulate_agent_wallet_void.json'));

      expect(await h.ledger.escrowJob(1), isNull);
    });

    test('a different contract error surfaces its code', () {
      final response = _withResultKey(
        'simulate_escrow_job_missing.json',
        'error',
        'HostError: Error(Contract, #2)',
      );
      final h = _ledgerAnswering(response);

      expect(
        () => h.ledger.escrowJob(1),
        throwsA(isA<LedgerContractError>().having((e) => e.code, 'code', 2)),
      );
    });

    test('a result that is not a job map is unavailable', () {
      final h = _ledgerAnswering(_fixture('simulate_agent_exists_true.json'));

      expect(() => h.ledger.escrowJob(3), _throwsUnavailable);
    });
  });
}
