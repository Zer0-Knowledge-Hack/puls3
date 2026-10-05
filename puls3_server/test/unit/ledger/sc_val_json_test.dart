import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/ledger/ledger_errors.dart';
import 'package:puls3_server/src/ledger/sc_val_json.dart';
import 'package:test/test.dart';

Object? _recordedResult(String fixture) {
  final response =
      jsonDecode(
            File('test/unit/ledger/fixtures/$fixture').readAsStringSync(),
          )
          as Map<String, Object?>;
  final result = response['result']! as Map<String, Object?>;
  final results = result['results']! as List<Object?>;
  return (results.single! as Map<String, Object?>)['returnValueJson'];
}

final _throwsUnavailable = throwsA(isA<LedgerUnavailable>());

void main() {
  group('bool', () {
    test('reads true and false', () {
      expect(readBool(const {'bool': true}), isTrue);
      expect(readBool(const {'bool': false}), isFalse);
    });

    test('reads a recorded simulation result', () {
      expect(
        readBool(_recordedResult('simulate_agent_exists_true.json')),
        isTrue,
      );
    });

    test('rejects another type', () {
      expect(() => readBool(const {'u32': 1}), _throwsUnavailable);
      expect(() => readBool(const {'bool': 'true'}), _throwsUnavailable);
    });
  });

  group('integers', () {
    test('u32 reads a number and a numeric string', () {
      expect(readU32(const {'u32': 7}), 7);
      expect(readU32(const {'u32': '4294967295'}), 4294967295);
    });

    test('u32 rejects a value above 2^32 - 1', () {
      expect(() => readU32(const {'u32': 4294967296}), _throwsUnavailable);
      expect(() => readU32(const {'u32': -1}), _throwsUnavailable);
    });

    test('u64 reads a string as the RPC sends it, and a number', () {
      expect(readU64(const {'u64': '1791229522'}), 1791229522);
      expect(readU64(const {'u64': 8}), 8);
      expect(readU64(const {'u64': '9007199254740993'}), 9007199254740993);
    });

    test('u64 rejects what does not fit a Dart int', () {
      expect(
        () => readU64(const {'u64': '18446744073709551615'}),
        _throwsUnavailable,
      );
      expect(() => readU64(const {'u64': '-1'}), _throwsUnavailable);
    });

    test('i128 reads to a BigInt, negative values included', () {
      expect(readI128(const {'i128': '5000000'}), BigInt.from(5000000));
      expect(readI128(const {'i128': '-9907'}), BigInt.from(-9907));
      expect(
        readI128(const {'i128': '170141183460469231731687303715884105727'}),
        BigInt.parse('170141183460469231731687303715884105727'),
      );
    });

    test('a number that is not an integer is rejected', () {
      expect(() => readU32(const {'u32': 'abc'}), _throwsUnavailable);
      expect(() => readU64(const {'u64': 1.5}), _throwsUnavailable);
      expect(() => readI128(const {'i128': ''}), _throwsUnavailable);
    });

    test('an integer of another type is rejected', () {
      expect(() => readU32(const {'u64': '7'}), _throwsUnavailable);
    });
  });

  group('text', () {
    test('string and symbol read their value', () {
      expect(readString(const {'string': 'hello'}), 'hello');
      expect(
        readString(_recordedResult('simulate_agent_uri_present.json')),
        'puls3://demo/agt-001',
      );
      expect(readSymbol(const {'symbol': 'transfer'}), 'transfer');
    });

    test('a symbol is not a string', () {
      expect(() => readString(const {'symbol': 'x'}), _throwsUnavailable);
      expect(() => readSymbol(const {'string': 'x'}), _throwsUnavailable);
    });
  });

  group('address', () {
    test('reads an account and a contract strkey', () {
      expect(
        readAddress(
          _recordedResult('simulate_agent_wallet_registered.json'),
        ).value,
        'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY',
      );
      expect(
        readAddress(const {
          'address': 'CD5QZOKGRBV35C5SDT6PG7S72XGG4BHQAC2L56YLNBJDUL4LDMTXFIJJ',
        }).kind,
        StellarAddressKind.contract,
      );
    });

    test('a malformed strkey is a failed decode, not a crash', () {
      expect(
        () => readAddress(const {'address': 'GNOTANADDRESS'}),
        _throwsUnavailable,
      );
    });
  });

  group('bytes', () {
    test('reads hex into bytes', () {
      expect(
        readBytes(const {'bytes': '00ff10'}),
        Uint8List.fromList([0, 255, 16]),
      );
    });

    test('rejects odd-length or non-hex text', () {
      expect(() => readBytes(const {'bytes': '0f1'}), _throwsUnavailable);
      expect(() => readBytes(const {'bytes': 'zz'}), _throwsUnavailable);
    });
  });

  group('void', () {
    test('isVoid is true only for the string "void"', () {
      expect(isVoid('void'), isTrue);
      expect(isVoid(const {'bool': false}), isFalse);
    });

    test('a recorded void result reads as null through readOptional', () {
      expect(
        readOptional(
          _recordedResult('simulate_agent_wallet_void.json'),
          readAddress,
        ),
        isNull,
      );
    });

    test('readOptional reads a present value', () {
      expect(
        readOptional(const {'string': 'a'}, readString),
        'a',
      );
    });
  });

  group('map', () {
    test('keys the entries by symbol and keeps the raw values', () {
      final map = readMap(_recordedResult('simulate_escrow_job_3.json'));

      expect(map.length, 13);
      expect(readU32(map['agent_id']), 7);
      expect(readI128(map['budget']), BigInt.from(5000000));
      expect(readString(map['description']), 'puls3 testnet evidence job');
    });

    test('rejects an entry whose key is not a symbol', () {
      expect(
        () => readMap(const {
          'map': [
            {
              'key': {'u32': 1},
              'val': {'u32': 2},
            },
          ],
        }),
        _throwsUnavailable,
      );
    });

    test('rejects a value that is not a map', () {
      expect(() => readMap(const {'vec': []}), _throwsUnavailable);
      expect(() => readMap('void'), _throwsUnavailable);
      expect(() => readMap(null), _throwsUnavailable);
    });
  });
}
