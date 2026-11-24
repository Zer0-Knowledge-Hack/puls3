// agentCallInFlight over the real Stellar codec and the recorded testnet
// create_job envelope of job 3 (see test/ledger/envelope_codec_test.dart).
import 'dart:convert';
import 'dart:io';

import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/chain/agent_call_gate.dart';
import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:puls3_server/src/ledger/stellar_envelope_codec.dart';
import 'package:test/test.dart';

import '../../support/in_memory_chain_submission_store.dart';

final _signer = StellarAddress.parse(
  'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H',
);
final _other = StellarAddress.parse(
  'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY',
);
final _codec = StellarEnvelopeCodec.forPassphrase(
  'Test SDF Network ; September 2015',
);
final _validUntil = DateTime.utc(2026, 10, 7, 12);

String _recordedEnvelope() =>
    (jsonDecode(
              File(
                'test/fixtures/escrow_relay/get_transaction_create_job_3_xdr.json',
              ).readAsStringSync(),
            )
            as Map<String, Object?>)['envelopeXdr']!
        as String;

void main() {
  late InMemoryChainSubmissionStore store;

  setUp(() => store = InMemoryChainSubmissionStore());

  Future<bool> inFlight(StellarAddress signer) => agentCallInFlight(
    submissions: store,
    codec: _codec,
    signer: signer,
  );

  Future<void> submitted(SubmissionPurpose purpose, String envelope) =>
      store.insertSubmitted(
        purpose: purpose,
        transactionHash: 'ab' * 32,
        signedEnvelopeXdr: envelope,
        validUntil: _validUntil,
        hireId: 4,
      );

  test('a submitted call holds only the wallet that signed it', () async {
    await submitted(SubmissionPurpose.submit, _recordedEnvelope());

    expect(await inFlight(_signer), isTrue);
    expect(await inFlight(_other), isFalse);
  });

  test('nothing in flight holds no wallet', () async {
    expect(await inFlight(_signer), isFalse);
  });

  test('a settled call holds no wallet', () async {
    await submitted(SubmissionPurpose.submit, _recordedEnvelope());
    await store.markConfirmed(store.all.single.id);

    expect(await inFlight(_signer), isFalse);
  });

  test('a relay call is not an agent-signed call', () async {
    await submitted(SubmissionPurpose.release, _recordedEnvelope());

    expect(await inFlight(_signer), isFalse);
  });

  test('an unreadable envelope holds every wallet', () async {
    await submitted(SubmissionPurpose.childComplete, 'AAAA');

    expect(await inFlight(_signer), isTrue);
    expect(await inFlight(_other), isTrue);
  });
}
