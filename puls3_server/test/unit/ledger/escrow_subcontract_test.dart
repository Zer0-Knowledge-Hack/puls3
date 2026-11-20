import 'dart:convert';
import 'dart:io';

import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/ledger/escrow_events.dart';
import 'package:puls3_server/src/ledger/escrow_job.dart';
import 'package:puls3_server/src/ledger/ledger_errors.dart';
import 'package:puls3_server/src/ledger/stellar_config.dart';
import 'package:test/test.dart';

/// The escrow v0.2.0 additions of ADR-0011: the four subcontract events, the
/// new `Job` fields and the contract errors 124 to 127.

final _escrow = StellarConfig.testnet.escrow;
const _client = 'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H';
const _provider = 'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY';

Map<String, Object?> _entry(String key, Object? val) => {
  'key': {'symbol': key},
  'val': val,
};

/// One escrow event as `getTransaction` (`xdrFormat: "json"`) reports it.
Map<String, Object?> _event(
  String name,
  int topicJobId,
  Map<String, Object?> fields, {
  String? contract,
}) => {
  'ext': 'v0',
  'contract_id': contract ?? _escrow.value,
  'type': 'contract',
  'body': {
    'v0': {
      'topics': [
        {'symbol': name},
        {'u64': '$topicJobId'},
      ],
      'data': {
        'map': [
          for (final MapEntry(:key, :value) in fields.entries)
            _entry(key, value),
        ],
      },
    },
  },
};

Map<String, Object?> _tx(
  List<Map<String, Object?>> events, {
  String status = 'SUCCESS',
}) => {
  'status': status,
  'events': {
    'contractEventsJson': [events],
  },
};

/// The recorded v0.1 `get_job(3)` return value, as a fresh mutable copy.
Map<String, Object?> _recordedJob() {
  final response =
      jsonDecode(
            File(
              'test/unit/ledger/fixtures/simulate_escrow_job_3.json',
            ).readAsStringSync(),
          )
          as Map<String, Object?>;
  final result = response['result']! as Map<String, Object?>;
  final first = (result['results']! as List).single as Map<String, Object?>;
  return jsonDecode(jsonEncode(first['returnValueJson']))
      as Map<String, Object?>;
}

/// [job] with the v0.2.0 puls3 fields appended.
Map<String, Object?> _withReserveFields(
  Map<String, Object?> job, {
  Object? parent = 'void',
}) {
  (job['map']! as List).addAll([
    _entry('reserve', {'i128': '1500000'}),
    _entry('reserve_funded', {'i128': '2000000'}),
    _entry('open_children', {'u32': 1}),
    _entry('parent_job_id', parent),
    _entry('depth', {'u32': parent == 'void' ? 0 : 1}),
  ]);
  return job;
}

void main() {
  group('subcontract events (ADR-0011 D6)', () {
    test('reads reserve_funded', () {
      final tx = _tx([
        _event('reserve_funded', 3, {
          'client': {'address': _client},
          'reserve': {'i128': '2000000'},
        }),
      ]);

      final event = allReserveFunded(tx, escrow: _escrow).single;

      expect(event.jobId, 3);
      expect(event.client, StellarAddress.parse(_client));
      expect(event.reserve, BigInt.from(2000000));
    });

    test('reads child_job_created, keyed by the parent job', () {
      final tx = _tx([
        _event('child_job_created', 3, {
          'child_job_id': {'u64': '4'},
          'provider': {'address': _provider},
          'agent_id': {'u32': 9},
          'budget': {'i128': '500000'},
          'reserve': {'i128': '0'},
          'depth': {'u32': 1},
          'parent_reserve_left': {'i128': '1500000'},
        }),
      ]);

      final event = allChildJobCreated(tx, escrow: _escrow).single;

      expect(event.parentJobId, 3);
      expect(event.childJobId, 4);
      expect(event.provider, StellarAddress.parse(_provider));
      expect(event.agentId, AgentId(9));
      expect(event.budget, BigInt.from(500000));
      expect(event.reserve, BigInt.zero);
      expect(event.depth, 1);
      expect(event.parentReserveLeft, BigInt.from(1500000));
    });

    test('reads reserve_returned', () {
      final tx = _tx([
        _event('reserve_returned', 3, {
          'child_job_id': {'u64': '4'},
          'amount': {'i128': '500000'},
          'to_client': {'bool': true},
        }),
      ]);

      final event = allReserveReturned(tx, escrow: _escrow).single;

      expect(event.parentJobId, 3);
      expect(event.childJobId, 4);
      expect(event.amount, BigInt.from(500000));
      expect(event.toClient, isTrue);
    });

    test('reads reserve_refunded', () {
      final tx = _tx([
        _event('reserve_refunded', 3, {
          'client': {'address': _client},
          'amount': {'i128': '1500000'},
          'deferred': {'bool': false},
        }),
      ]);

      final event = allReserveRefunded(tx, escrow: _escrow).single;

      expect(event.jobId, 3);
      expect(event.client, StellarAddress.parse(_client));
      expect(event.amount, BigInt.from(1500000));
      expect(event.deferred, isFalse);
    });

    test('skips other names, other contracts, failed and malformed', () {
      final good = _event('reserve_refunded', 3, {
        'client': {'address': _client},
        'amount': {'i128': '1'},
        'deferred': {'bool': false},
      });
      final missing = _event('reserve_refunded', 5, {
        'client': {'address': _client},
      });
      final foreign = _event(
        'reserve_refunded',
        6,
        {
          'client': {'address': _client},
          'amount': {'i128': '1'},
          'deferred': {'bool': false},
        },
        contract: StellarConfig.testnet.identityRegistry.value,
      );
      final tx = _tx([good, missing, foreign]);

      expect(allReserveRefunded(tx, escrow: _escrow).map((e) => e.jobId), [3]);
      expect(allReserveFunded(tx, escrow: _escrow), isEmpty);
      expect(
        allReserveRefunded(_tx([good], status: 'FAILED'), escrow: _escrow),
        isEmpty,
      );
    });
  });

  group('decodeEscrowJob with the v0.2.0 fields (ADR-0011 D1)', () {
    test('a v0.1 job reads as a root job with no reserve', () {
      final job = decodeEscrowJob(_recordedJob());

      expect(job.reserve, BigInt.zero);
      expect(job.reserveFunded, BigInt.zero);
      expect(job.openChildren, 0);
      expect(job.parentJobId, isNull);
      expect(job.depth, 0);
    });

    test('a v0.2.0 root job reads its reserve', () {
      final job = decodeEscrowJob(_withReserveFields(_recordedJob()));

      expect(job.reserve, BigInt.from(1500000));
      expect(job.reserveFunded, BigInt.from(2000000));
      expect(job.openChildren, 1);
      expect(job.parentJobId, isNull);
      expect(job.depth, 0);
      expect(job.budget, BigInt.from(5000000), reason: 'v0.1 fields kept');
    });

    test('a v0.2.0 child job reads its parent and depth', () {
      final job = decodeEscrowJob(
        _withReserveFields(_recordedJob(), parent: {'u64': '3'}),
      );

      expect(job.parentJobId, 3);
      expect(job.depth, 1);
    });

    test('a present field of the wrong type is unavailable', () {
      final job = _withReserveFields(_recordedJob());
      final entries = (job['map']! as List).cast<Map<String, Object?>>();
      entries.firstWhere(
        (e) => (e['key']! as Map)['symbol'] == 'reserve',
      )['val'] = {
        'u32': 1,
      };

      expect(() => decodeEscrowJob(job), throwsA(isA<LedgerUnavailable>()));
    });
  });

  group('subcontract contract errors (ADR-0011)', () {
    test('124 to 127 map to typed errors', () {
      expect(
        {for (final e in EscrowSubcontractError.values) e.code: e},
        {
          124: EscrowSubcontractError.reserveExceeded,
          125: EscrowSubcontractError.childrenOpen,
          126: EscrowSubcontractError.depthExceeded,
          127: EscrowSubcontractError.subcontractCycle,
        },
      );
    });

    test('a contract error is read by code; other codes are not ours', () {
      expect(
        EscrowSubcontractError.of(
          const LedgerContractError(126, 'create_child_job failed with #126'),
        ),
        EscrowSubcontractError.depthExceeded,
      );
      expect(EscrowSubcontractError.fromCode(123), isNull);
      expect(EscrowSubcontractError.fromCode(128), isNull);
    });

    test('the code is read from a simulation error text', () {
      expect(
        EscrowSubcontractError.fromCode(
          contractErrorCode('HostError: Error(Contract, #124)')!,
        ),
        EscrowSubcontractError.reserveExceeded,
      );
    });
  });
}
