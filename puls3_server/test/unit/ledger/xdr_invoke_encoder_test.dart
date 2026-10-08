import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/ledger/xdr_invoke_encoder.dart';
import 'package:test/test.dart';

final _source = StellarAddress.parse(
  'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY',
);
final _registry = StellarAddress.parse(
  'CD5QZOKGRBV35C5SDT6PG7S72XGG4BHQAC2L56YLNBJDUL4LDMTXFIJJ',
);

const _sourceKey =
    '0b4c57a6dc82a43c051d40acd4d86a71bc098ed287e75e74d2b024119366e4c4';
const _registryKey =
    'fb0cb946886bbe8bb21cfcf37e5fd5cc6e04f000b4befb0b68523a2f8b1b2772';

String _hex(String base64Value) => base64Decode(
  base64Value,
).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  group('encodeInvokeEnvelope', () {
    test('agent_exists(7) equals the hand-computed XDR bytes', () {
      final envelope = encodeInvokeEnvelope(
        source: _source,
        fee: 100,
        sequence: 0,
        contract: _registry,
        function: 'agent_exists',
        args: const [ScArg.u32(7)],
      );

      expect(
        _hex(envelope),
        [
          '00000002', // ENVELOPE_TYPE_TX
          '00000000', _sourceKey, // KEY_TYPE_ED25519 + source key
          '00000064', // fee 100
          '0000000000000000', // sequence 0
          '00000000', // PRECOND_NONE
          '00000000', // MEMO_NONE
          '00000001', // one operation
          '00000000', // no operation source
          '00000018', // INVOKE_HOST_FUNCTION
          '00000000', // HOST_FUNCTION_TYPE_INVOKE_CONTRACT
          '00000001', _registryKey, // SC_ADDRESS_TYPE_CONTRACT + hash
          '0000000c', '6167656e745f657869737473', // "agent_exists", 12 bytes
          '00000001', // one argument
          '00000003', '00000007', // SCV_U32 7
          '00000000', // no auth entries
          '00000000', // transaction ext v0
          '00000000', // no signatures
        ].join(),
      );
    });

    test(
      'equals the base64 that stellar contract invoke --build-only wrote',
      () {
        final golden =
            jsonDecode(
                  File(
                    'test/unit/ledger/fixtures/envelope_agent_exists_7.json',
                  ).readAsStringSync(),
                )
                as Map<String, Object?>;

        final envelope = encodeInvokeEnvelope(
          source: _source,
          fee: golden['fee']! as int,
          sequence: int.parse(golden['sequence']! as String),
          contract: _registry,
          function: 'agent_exists',
          args: const [ScArg.u32(7)],
        );

        expect(envelope, golden['base64']);
      },
    );

    test('pads a function name that is not a multiple of 4 bytes', () {
      final envelope = encodeInvokeEnvelope(
        source: _source,
        fee: 100,
        sequence: 0,
        contract: _registry,
        function: 'get_job',
        args: const [ScArg.u64(3)],
      );

      expect(
        _hex(envelope).substring(_hex(envelope).indexOf(_registryKey) + 64),
        [
          '00000007', '6765745f6a6f6200', // "get_job" + 1 pad byte
          '00000001', // one argument
          '00000005', '0000000000000003', // SCV_U64 3
          '00000000', '00000000', '00000000', // auth, ext, signatures
        ].join(),
      );
    });

    group('ScArg.string', () {
      /// The hex of the bytes after the function name: one `ScArg.string`
      /// argument followed by auth, extension and signatures.
      String argument(String value) {
        final hex = _hex(
          encodeInvokeEnvelope(
            source: _source,
            fee: 100,
            sequence: 0,
            contract: _registry,
            function: 'get_metadata',
            args: [ScArg.string(value)],
          ),
        );
        // Skip the function name (length word + 12 bytes) and the arg count.
        final start = hex.indexOf(_registryKey) + 64 + 8 + 24 + 8;
        return hex.substring(start, hex.length - 3 * 8);
      }

      test('writes discriminant 14, the byte length and no padding', () {
        expect(
          argument('name'),
          ['0000000e', '00000004', '6e616d65'].join(),
        );
      });

      test('pads a 2-byte string with 2 zero bytes', () {
        expect(argument('id'), ['0000000e', '00000002', '69640000'].join());
      });

      test('writes only discriminant and length for an empty string', () {
        expect(argument(''), ['0000000e', '00000000'].join());
      });

      test('counts UTF-8 bytes, not characters, and pads to 4', () {
        // "é" is 2 bytes (c3a9); "añ" is 3 bytes plus 1 padding byte.
        expect(argument('é'), ['0000000e', '00000002', 'c3a90000'].join());
        expect(argument('añ'), ['0000000e', '00000003', '61c3b100'].join());
      });

      test('equals the base64 that stellar contract invoke wrote', () {
        final golden =
            jsonDecode(
                  File(
                    'test/unit/ledger/fixtures/'
                    'envelope_get_metadata_7_name.json',
                  ).readAsStringSync(),
                )
                as Map<String, Object?>;

        final envelope = encodeInvokeEnvelope(
          source: _source,
          fee: golden['fee']! as int,
          sequence: int.parse(golden['sequence']! as String),
          contract: _registry,
          function: 'get_metadata',
          args: [const ScArg.u32(7), ScArg.string('name')],
        );

        expect(envelope, golden['base64']);
      });
    });

    group('ScArg address, i128 and void', () {
      /// The hex of one argument sent to `get_metadata`, cut out the same way
      /// as in the `ScArg.string` group.
      String argument(ScArg arg) {
        final hex = _hex(
          encodeInvokeEnvelope(
            source: _source,
            fee: 100,
            sequence: 0,
            contract: _registry,
            function: 'get_metadata',
            args: [arg],
          ),
        );
        final start = hex.indexOf(_registryKey) + 64 + 8 + 24 + 8;
        return hex.substring(start, hex.length - 3 * 8);
      }

      test('writes an account address as SC_ADDRESS_TYPE_ACCOUNT', () {
        expect(
          argument(ScArg.address(_source)),
          ['00000012', '00000000', '00000000', _sourceKey].join(),
        );
      });

      test('writes a contract address as SC_ADDRESS_TYPE_CONTRACT', () {
        expect(
          argument(ScArg.address(_registry)),
          ['00000012', '00000001', _registryKey].join(),
        );
      });

      test('writes a positive i128 as hi 0 and the value in lo', () {
        expect(
          argument(const ScArg.i128(5000000)),
          ['0000000a', '0000000000000000', '00000000004c4b40'].join(),
        );
      });

      test('sign-extends a negative i128 into hi', () {
        expect(
          argument(const ScArg.i128(-1)),
          ['0000000a', 'ffffffffffffffff', 'ffffffffffffffff'].join(),
        );
      });

      test('writes void as the bare SCV_VOID discriminant', () {
        expect(argument(const ScArg.voidValue()), '00000001');
      });

      test('writes a 32-byte value as SCV_BYTES with its length', () {
        final value = Uint8List.fromList(List.generate(32, (i) => i));
        expect(
          argument(ScArg.bytes32(value)),
          [
            '0000000d',
            '00000020',
            for (final b in value) b.toRadixString(16).padLeft(2, '0'),
          ].join(),
        );
      });

      test('rejects a value that is not 32 bytes', () {
        expect(() => ScArg.bytes32(Uint8List(31)), throwsArgumentError);
      });
    });

    test('encodes a sequence above 2^32 as a big-endian int64', () {
      final envelope = encodeInvokeEnvelope(
        source: _source,
        fee: 100,
        sequence: 20920643964895254,
        contract: _registry,
        function: 'agent_exists',
        args: const [ScArg.u32(7)],
      );

      expect(
        _hex(envelope).substring(8 + 8 + 64 + 8, 8 + 8 + 64 + 8 + 16),
        '004a533700000016',
      );
    });
  });
}
