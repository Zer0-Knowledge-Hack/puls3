import 'dart:convert';
import 'dart:io';

import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/ledger/invoked_contract.dart';
import 'package:puls3_server/src/ledger/xdr_invoke_encoder.dart';
import 'package:test/test.dart';

const _escrow = 'CBRD7A7MXINM7LREKCL3RMKRQ5UMLGKNHAEYY4JT7MVBBB7R5QV4TPE2';
const _source = 'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H';

void main() {
  group('invokedCallOf (#307)', () {
    test('reads the contract and function of an invoke envelope', () {
      final envelope = encodeInvokeEnvelope(
        source: StellarAddress.parse(_source),
        fee: 100,
        sequence: 1,
        contract: StellarAddress.parse(_escrow),
        function: 'create_job',
        args: [ScArg.u64(3)],
      );

      final call = invokedCallOf(envelope);

      expect(call?.contract.value, _escrow);
      expect(call?.function, 'create_job');
    });

    test('reads the real create_job of job 3 on the testnet escrow', () {
      // The signed envelope the relay stored for job 3 (testnet, #97).
      final fixture =
          jsonDecode(
                File(
                  'test/fixtures/escrow_relay/'
                  'get_transaction_create_job_3_xdr.json',
                ).readAsStringSync(),
              )
              as Map<String, Object?>;
      final result = (fixture['result'] ?? fixture) as Map<String, Object?>;

      final call = invokedCallOf(result['envelopeXdr']! as String);

      expect(call?.contract.value, _escrow);
      expect(call?.function, 'create_job');
    });

    test('anything that is not an invoke envelope is null', () {
      expect(invokedCallOf(''), isNull);
      expect(invokedCallOf('not base64!'), isNull);
      expect(invokedCallOf(base64Encode([0, 0, 0, 2, 1, 2])), isNull);
    });
  });
}
