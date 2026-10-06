import 'dart:convert';
import 'dart:io';

import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/ledger/escrow_events.dart';
import 'package:puls3_server/src/ledger/stellar_config.dart';
import 'package:test/test.dart';

final _escrow = StellarConfig.testnet.escrow;
final _client = StellarAddress.parse(
  'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H',
);
final _provider = StellarAddress.parse(
  'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY',
);
final _otherContract = StellarConfig.testnet.identityRegistry;

/// The `result` of a recorded `getTransaction` answer.
Map<String, Object?> _tx(String name) =>
    (jsonDecode(File('test/unit/ledger/fixtures/$name').readAsStringSync())
            as Map<String, Object?>)['result']!
        as Map<String, Object?>;

Map<String, Object?> _createJob() => _tx('get_transaction_create_job_3.json');
Map<String, Object?> _fund() => _tx('get_transaction_fund_job_3.json');

/// The first escrow event of [tx], to edit in place.
Map<String, Object?> _firstEscrowEvent(Map<String, Object?> tx) {
  final groups = (tx['events']! as Map)['contractEventsJson']! as List;
  return groups
      .expand((group) => group as List)
      .cast<Map<String, Object?>>()
      .firstWhere((event) => event['contract_id'] == _escrow.value);
}

Map<String, Object?> _v0(Map<String, Object?> event) =>
    (event['body']! as Map)['v0']! as Map<String, Object?>;

bool _isKey(Object? entry, String symbol) =>
    ((entry! as Map)['key']! as Map)['symbol'] == symbol;

void main() {
  group('firstJobCreated', () {
    test('reads the job_created event of the testnet create_job', () {
      final event = firstJobCreated(_createJob(), escrow: _escrow)!;

      expect(event.jobId, 3);
      expect(event.client, _client);
      expect(event.provider, _provider);
      expect(event.evaluator, _client);
      expect(event.agentId, AgentId(7));
      expect(event.token, StellarConfig.testnet.usdcSac);
      expect(event.budget, BigInt.from(5000000));
      expect(event.expiredAt, 1791747914);
    });

    test('is null for a transaction without that event', () {
      expect(firstJobCreated(_fund(), escrow: _escrow), isNull);
    });

    test('ignores events of another contract', () {
      expect(firstJobCreated(_createJob(), escrow: _otherContract), isNull);
    });

    test('is null unless the transaction succeeded', () {
      final tx = _createJob()..['status'] = 'FAILED';

      expect(firstJobCreated(tx, escrow: _escrow), isNull);
    });

    test('skips an event with a missing field', () {
      final tx = _createJob();
      final data = _v0(_firstEscrowEvent(tx))['data']! as Map;
      (data['map']! as List).removeWhere(
        (entry) => _isKey(entry, 'budget'),
      );

      expect(firstJobCreated(tx, escrow: _escrow), isNull);
    });

    test('skips an event whose job id topic is malformed', () {
      final tx = _createJob();
      (_v0(_firstEscrowEvent(tx))['topics']! as List)[1] = {'u32': 3};

      expect(firstJobCreated(tx, escrow: _escrow), isNull);
    });
  });

  group('firstJobFunded', () {
    test('reads the job_funded event of the testnet fund', () {
      final event = firstJobFunded(_fund(), escrow: _escrow)!;

      expect(event.jobId, 3);
      expect(event.client, _client);
      expect(event.amount, BigInt.from(5000000));
      expect(event.feeBps, 0);
    });

    test('is null for a transaction without that event', () {
      expect(firstJobFunded(_createJob(), escrow: _escrow), isNull);
    });

    test('ignores events of another contract', () {
      expect(firstJobFunded(_fund(), escrow: _otherContract), isNull);
    });

    test('is null unless the transaction succeeded', () {
      final tx = _fund()..['status'] = 'FAILED';

      expect(firstJobFunded(tx, escrow: _escrow), isNull);
    });

    test('skips an event with a field of another type', () {
      final tx = _fund();
      final data = _v0(_firstEscrowEvent(tx))['data']! as Map;
      final amount = (data['map']! as List).cast<Map>().firstWhere(
        (entry) => _isKey(entry, 'amount'),
      );
      amount['val'] = {'u32': 5};

      expect(firstJobFunded(tx, escrow: _escrow), isNull);
    });
  });
}
