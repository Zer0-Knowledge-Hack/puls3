import 'dart:convert';
import 'dart:io';

import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/ledger/escrow_job.dart';
import 'package:puls3_server/src/ledger/ledger_errors.dart';
import 'package:test/test.dart';

final _throwsUnavailable = throwsA(isA<LedgerUnavailable>());

/// The recorded `get_job(3)` return value, as a fresh mutable copy.
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

List<Map<String, Object?>> _entries(Map<String, Object?> job) =>
    (job['map']! as List).cast<Map<String, Object?>>();

Map<String, Object?> _entry(Map<String, Object?> job, String key) =>
    _entries(job).firstWhere((e) => (e['key']! as Map)['symbol'] == key);

void main() {
  group('decodeEscrowJob', () {
    test('decodes the recorded job 3', () {
      final job = decodeEscrowJob(_recordedJob());

      expect(job.agentId, AgentId(7));
      expect(job.budget, BigInt.from(5000000));
      expect(job.feeBps, 0);
      expect(job.expiredAt, 1791747914);
      expect(job.submittedAt, 1791143122);
      expect(job.approvalDeadline, 1791229522);
      expect(job.description, 'puls3 testnet evidence job');
      expect(job.state, EscrowJobState.completed);
      expect(
        job.client,
        StellarAddress.parse(
          'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H',
        ),
      );
      expect(job.evaluator, job.client);
      expect(
        job.provider,
        StellarAddress.parse(
          'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY',
        ),
      );
      expect(
        job.token,
        StellarAddress.parse(
          'CBIELTK6YBZJU5UP2WWQEUCYKLPU6AUNZ2BQ4WWFEIE3USCIHMXQDAMA',
        ),
      );
      expect(
        job.deliverable,
        '179090692d43733fb69b57dca35e077a5af50ad0a37138b76c3e050027bc0665',
      );
    });

    test('a void deliverable is null', () {
      final json = _recordedJob();
      _entry(json, 'deliverable')['val'] = 'void';

      expect(decodeEscrowJob(json).deliverable, isNull);
    });

    test('maps every state index in contract order', () {
      const names = [
        EscrowJobState.open,
        EscrowJobState.funded,
        EscrowJobState.submitted,
        EscrowJobState.completed,
        EscrowJobState.rejected,
        EscrowJobState.expired,
      ];
      for (var index = 0; index < names.length; index++) {
        final json = _recordedJob();
        _entry(json, 'state')['val'] = {'u32': index};

        expect(decodeEscrowJob(json).state, names[index], reason: '$index');
      }
    });

    test('an unknown state index is a shape mismatch', () {
      final json = _recordedJob();
      _entry(json, 'state')['val'] = {'u32': 6};

      expect(() => decodeEscrowJob(json), _throwsUnavailable);
    });

    test('a missing field is a shape mismatch', () {
      final json = _recordedJob();
      (json['map']! as List).removeWhere(
        (e) => ((e as Map)['key']! as Map)['symbol'] == 'budget',
      );

      expect(() => decodeEscrowJob(json), _throwsUnavailable);
    });

    test('a field of the wrong type is a shape mismatch', () {
      final json = _recordedJob();
      _entry(json, 'agent_id')['val'] = {'string': 'seven'};

      expect(() => decodeEscrowJob(json), _throwsUnavailable);
    });

    test('a value that is not a map is a shape mismatch', () {
      expect(() => decodeEscrowJob({'u32': 3}), _throwsUnavailable);
    });
  });
}
