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

/// Appends a copy of the first escrow event of [tx] for job [jobId] after it.
void _addEvent(Map<String, Object?> tx, int jobId) {
  final first = _firstEscrowEvent(tx);
  final copy = jsonDecode(jsonEncode(first)) as Map<String, Object?>;
  (_v0(copy)['topics']! as List)[1] = {'u64': '$jobId'};
  final groups = (tx['events']! as Map)['contractEventsJson']! as List;
  groups.firstWhere((group) => (group as List).contains(first)).add(copy);
}

Map<String, Object?> _v0(Map<String, Object?> event) =>
    (event['body']! as Map)['v0']! as Map<String, Object?>;

bool _isKey(Object? entry, String symbol) =>
    ((entry! as Map)['key']! as Map)['symbol'] == symbol;

void main() {
  group('allJobCreated', () {
    test('reads the job_created event of the testnet create_job', () {
      final event = allJobCreated(_createJob(), escrow: _escrow).single;

      expect(event.jobId, 3);
      expect(event.client, _client);
      expect(event.provider, _provider);
      expect(event.evaluator, _client);
      expect(event.agentId, AgentId(7));
      expect(event.token, StellarConfig.testnet.usdcSac);
      expect(event.budget, BigInt.from(5000000));
      expect(event.expiredAt, 1791747914);
    });

    test('is empty for a transaction without that event', () {
      expect(allJobCreated(_fund(), escrow: _escrow), isEmpty);
    });

    test('ignores events of another contract', () {
      expect(allJobCreated(_createJob(), escrow: _otherContract), isEmpty);
    });

    test('is empty unless the transaction succeeded', () {
      final tx = _createJob()..['status'] = 'FAILED';

      expect(allJobCreated(tx, escrow: _escrow), isEmpty);
    });

    test('skips an event with a missing field', () {
      final tx = _createJob();
      final data = _v0(_firstEscrowEvent(tx))['data']! as Map;
      (data['map']! as List).removeWhere(
        (entry) => _isKey(entry, 'budget'),
      );

      expect(allJobCreated(tx, escrow: _escrow), isEmpty);
    });

    test('skips an event whose job id topic is malformed', () {
      final tx = _createJob();
      (_v0(_firstEscrowEvent(tx))['topics']! as List)[1] = {'u32': 3};

      expect(allJobCreated(tx, escrow: _escrow), isEmpty);
    });
  });

  group('several events', () {
    test('every valid job_created is returned in order', () {
      final tx = _createJob();
      _addEvent(tx, 4);

      final events = allJobCreated(tx, escrow: _escrow);

      expect(events.map((e) => e.jobId), [3, 4]);
      expect(events.map((e) => e.budget), everyElement(BigInt.from(5000000)));
    });

    test('every valid job_funded is returned in order', () {
      final tx = _fund();
      _addEvent(tx, 4);
      _addEvent(tx, 5);

      final events = allJobFunded(tx, escrow: _escrow);

      expect(events.map((e) => e.jobId), [3, 4, 5]);
    });

    test('a malformed event between valid ones is skipped', () {
      final tx = _fund();
      _addEvent(tx, 4);
      final groups = (tx['events']! as Map)['contractEventsJson']! as List;
      final events = (groups.single as List).cast<Map<String, Object?>>();
      // The last event is the copy for job 4: break its job id topic, then
      // add a valid copy for job 6 after it.
      (_v0(events.last)['topics']! as List)[1] = {'u32': 4};
      _addEvent(tx, 6);

      expect(allJobFunded(tx, escrow: _escrow).map((e) => e.jobId), [3, 6]);
    });
  });

  group('allJobFunded', () {
    test('reads the job_funded event of the testnet fund', () {
      final event = allJobFunded(_fund(), escrow: _escrow).single;

      expect(event.jobId, 3);
      expect(event.client, _client);
      expect(event.amount, BigInt.from(5000000));
      expect(event.feeBps, 0);
    });

    test('is empty for a transaction without that event', () {
      expect(allJobFunded(_createJob(), escrow: _escrow), isEmpty);
    });

    test('ignores events of another contract', () {
      expect(allJobFunded(_fund(), escrow: _otherContract), isEmpty);
    });

    test('is empty unless the transaction succeeded', () {
      final tx = _fund()..['status'] = 'FAILED';

      expect(allJobFunded(tx, escrow: _escrow), isEmpty);
    });

    test('skips an event with a field of another type', () {
      final tx = _fund();
      final data = _v0(_firstEscrowEvent(tx))['data']! as Map;
      final amount = (data['map']! as List).cast<Map>().firstWhere(
        (entry) => _isKey(entry, 'amount'),
      );
      amount['val'] = {'u32': 5};

      expect(allJobFunded(tx, escrow: _escrow), isEmpty);
    });
  });
}
