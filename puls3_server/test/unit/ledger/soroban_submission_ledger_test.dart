import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:puls3_server/src/chain/submission_ledger.dart';
import 'package:puls3_server/src/ledger/ledger_errors.dart';
import 'package:puls3_server/src/ledger/soroban_rpc_client.dart';
import 'package:puls3_server/src/ledger/soroban_submission_ledger.dart';
import 'package:puls3_server/src/ledger/stellar_config.dart';
import 'package:test/test.dart';

const _createJobHash =
    '3baba1832b5a1d44330068acd41d5b09fb8e15faab1ba914829c0a0a62d054fb';
const _fundHash =
    '43cd3e8455cafdc08d62a644b8f9dd9174994644b2bdd3e57eaa6893aa5c2437';

Map<String, Object?> _fixture(String name) =>
    jsonDecode(File('test/unit/ledger/fixtures/$name').readAsStringSync())
        as Map<String, Object?>;

/// A fixture answer with [edit] applied to its `result`.
Map<String, Object?> _edited(
  String name,
  void Function(Map<String, Object?> result) edit,
) {
  final answer = _fixture(name);
  edit(answer['result']! as Map<String, Object?>);
  return answer;
}

({SorobanSubmissionLedger ledger, List<Map<String, Object?>> requests}) _ledger(
  Object answer, {
  StellarConfig? config,
}) {
  final requests = <Map<String, Object?>>[];
  final rpc = SorobanRpcClient(
    httpClient: MockClient((request) async {
      requests.add(jsonDecode(request.body) as Map<String, Object?>);
      return http.Response(
        jsonEncode(answer),
        200,
        headers: {'content-type': 'application/json'},
      );
    }),
    url: Uri.parse('https://rpc.example.test'),
    timeout: const Duration(seconds: 1),
  );
  return (
    ledger: SorobanSubmissionLedger(
      rpc,
      escrow: (config ?? StellarConfig.testnet).escrow,
    ),
    requests: requests,
  );
}

void main() {
  group('lookup', () {
    test('a successful create_job carries its JobCreated event', () async {
      final h = _ledger(_fixture('get_transaction_create_job_3.json'));

      final lookup = await h.ledger.lookup(_createJobHash);

      expect(h.requests.single['method'], 'getTransaction');
      expect(
        (h.requests.single['params']! as Map)['hash'],
        _createJobHash,
      );
      expect(lookup.status, TransactionStatus.success);
      expect(
        lookup.latestLedgerCloseTime,
        DateTime.fromMillisecondsSinceEpoch(1791240237 * 1000, isUtc: true),
      );
      expect(lookup.jobCreated!.jobId, 3);
      expect(lookup.jobFunded, isNull);
    });

    test('a successful fund carries its JobFunded event', () async {
      final h = _ledger(_fixture('get_transaction_fund_job_3.json'));

      final lookup = await h.ledger.lookup(_fundHash);

      expect(lookup.status, TransactionStatus.success);
      expect(lookup.jobFunded!.jobId, 3);
      expect(lookup.jobFunded!.amount, BigInt.from(5000000));
      expect(lookup.jobCreated, isNull);
    });

    test('events of a contract other than the configured escrow are '
        'ignored', () async {
      final other = StellarConfig.fromEnvironment({
        'PULS3_STELLAR_ESCROW': StellarConfig.testnet.identityRegistry.value,
      });
      final h = _ledger(
        _fixture('get_transaction_fund_job_3.json'),
        config: other,
      );

      final lookup = await h.ledger.lookup(_fundHash);

      expect(lookup.status, TransactionStatus.success);
      expect(lookup.jobFunded, isNull);
    });

    test('NOT_FOUND keeps the chain close time', () async {
      final h = _ledger(_fixture('get_transaction_not_found.json'));

      final lookup = await h.ledger.lookup('00' * 32);

      expect(lookup.status, TransactionStatus.notFound);
      expect(
        lookup.latestLedgerCloseTime,
        DateTime.fromMillisecondsSinceEpoch(1791146442 * 1000, isUtc: true),
      );
      expect(lookup.jobCreated, isNull);
      expect(lookup.jobFunded, isNull);
    });

    test('FAILED carries no escrow facts', () async {
      final h = _ledger(
        _edited(
          'get_transaction_fund_job_3.json',
          (r) => r['status'] = 'FAILED',
        ),
      );

      final lookup = await h.ledger.lookup(_fundHash);

      expect(lookup.status, TransactionStatus.failed);
      expect(lookup.jobFunded, isNull);
    });

    test('a missing or malformed close time is null', () async {
      final missing = _ledger(
        _edited(
          'get_transaction_not_found.json',
          (r) => r.remove('latestLedgerCloseTime'),
        ),
      );
      final malformed = _ledger(
        _edited(
          'get_transaction_not_found.json',
          (r) => r['latestLedgerCloseTime'] = 'soon',
        ),
      );

      expect(
        (await missing.ledger.lookup('00' * 32)).latestLedgerCloseTime,
        isNull,
      );
      expect(
        (await malformed.ledger.lookup('00' * 32)).latestLedgerCloseTime,
        isNull,
      );
    });

    test('an unknown status is LedgerUnavailable', () {
      final h = _ledger(
        _edited('get_transaction_not_found.json', (r) => r['status'] = 'MAYBE'),
      );

      expect(
        () => h.ledger.lookup('00' * 32),
        throwsA(isA<LedgerUnavailable>()),
      );
    });
  });

  group('resend', () {
    test('sends the persisted envelope unchanged', () async {
      final h = _ledger(_fixture('send_transaction_pending.json'));

      final result = await h.ledger.resend('AAAA');

      expect(h.requests.single['method'], 'sendTransaction');
      expect(h.requests.single['params'], {'transaction': 'AAAA'});
      expect(result.status, SendTransactionStatus.pending);
    });
  });
}
