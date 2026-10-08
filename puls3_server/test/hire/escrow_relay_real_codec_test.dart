// The relay service composed with the real StellarEnvelopeCodec: an envelope
// prepared from recorded simulation data, signed with a real ed25519 key
// generated here, and submitted. Deterministic: the key is a fixed seed and
// the clock is the rig's.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;
import 'package:puls3_server/src/chain/submission_values.dart';
import 'package:puls3_server/src/generated/protocol.dart';
import 'package:puls3_server/src/hire/escrow_relay_service.dart';
import 'package:puls3_server/src/ledger/envelope_codec.dart';
import 'package:puls3_server/src/ledger/stellar_envelope_codec.dart';
import 'package:stellar_dart/stellar_dart.dart' as stellar;
import 'package:test/test.dart';

import '../support/relay_rig.dart';

const _testnet = 'Test SDF Network ; September 2015';

stellar.StellarPrivateKey _key(int seed) => stellar.StellarPrivateKey.fromBytes(
  List.generate(32, (i) => (i + seed) & 0xff),
);

StellarAddress _addressOf(stellar.StellarPrivateKey key) =>
    StellarAddress.parse(key.toPublicKey().toAddress().address);

Map<String, Object?> _json(String name) =>
    jsonDecode(File('test/fixtures/escrow_relay/$name').readAsStringSync())
        as Map<String, Object?>;

SimulationData _createSimulation() {
  final result =
      _json('simulate_create_job_3_base64.json')['result']!
          as Map<String, Object?>;
  final first = (result['results']! as List).single as Map<String, Object?>;
  return SimulationData(
    transactionData: result['transactionData']! as String,
    minResourceFee: int.parse('${result['minResourceFee']}'),
    auth: (first['auth']! as List).cast<String>(),
  );
}

/// The fund simulation of job 3 fails on chain, so its Soroban data and auth
/// come from the recorded fund transaction itself.
SimulationData _fundSimulation() {
  final recorded =
      stellar.Envelope.fromXdr(
            base64Decode(
              _json('get_transaction_fund_job_3_xdr.json')['envelopeXdr']!
                  as String,
            ),
          )
          as stellar.TransactionV1Envelope;
  final operation =
      recorded.tx.operations.single.body as stellar.InvokeHostFunctionOperation;
  return SimulationData(
    transactionData: base64Encode(recorded.tx.sorobanData.toXDR()),
    minResourceFee: recorded.tx.fee - inclusionFee,
    auth: [for (final entry in operation.auth) base64Encode(entry.toXDR())],
  );
}

void main() {
  final codec = StellarEnvelopeCodec.forPassphrase(_testnet);
  final consumerKey = _key(1);
  final consumer = _addressOf(consumerKey);
  late RelayRig rig;
  late EscrowRelayService service;

  setUp(() {
    rig = RelayRig();
    service = rig.build(codec: codec);
  });

  /// [unsigned] with one signature of [key] over its transaction hash.
  String sign(stellar.StellarPrivateKey key, String unsigned) {
    final bytes = base64Decode(unsigned);
    final signature = key.sign(codec.parse(unsigned).hash);
    final out = BytesBuilder()
      ..add(bytes.sublist(0, bytes.length - 4)) // the empty signature list
      ..add([0, 0, 0, 1])
      ..add(signature.hint)
      ..add([0, 0, 0, 64])
      ..add(signature.signature);
    return base64Encode(out.takeBytes());
  }

  Future<({int hireId, PreparedTransaction prepared})> prepare(
    SubmissionPurpose purpose,
  ) async {
    if (purpose == SubmissionPurpose.createJob) {
      final hire = await rig.hire(consumer: consumer.value);
      rig.accounts.simulation = _createSimulation();
      return (
        hireId: hire.id,
        prepared: await service.prepareCreateJob(consumer, hire.id),
      );
    }
    final hire = await rig.hire(
      status: HireStatus.open,
      consumer: consumer.value,
    );
    rig.accounts.simulation = _fundSimulation();
    return (
      hireId: hire.id,
      prepared: await service.prepareFund(consumer, hire.id),
    );
  }

  for (final purpose in [SubmissionPurpose.createJob, SubmissionPurpose.fund]) {
    test(
      'a ${purpose.name} signed with a real key is relayed as signed',
      () async {
        final p = await prepare(purpose);
        final xdr = sign(consumerKey, p.prepared.unsignedTransactionXdr!);

        final detail = await service.submitEscrowCall(
          consumer,
          p.hireId,
          p.prepared.preparationId,
          xdr,
        );

        final record = detail.escrowSubmission!;
        expect(record.purpose, purpose.wireName);
        expect(record.state, SubmissionState.submitted.wireName);
        expect(record.transaction, p.prepared.transaction);
        expect(rig.sender.resent, [xdr]);
        final stored = await rig.submissions.findByPreparation(
          p.prepared.preparationId,
        );
        expect(stored!.signedEnvelopeXdr, xdr);
        expect(stored.transactionHash, p.prepared.transaction);
        expect(stored.hireId, p.hireId);
      },
    );
  }

  test(
    'a tampered envelope is EnvelopeMismatch and nothing is stored',
    () async {
      final p = await prepare(SubmissionPurpose.createJob);
      final signed = base64Decode(
        sign(consumerKey, p.prepared.unsignedTransactionXdr!),
      );
      // The last byte of the maxTime of the time bounds (offset 64 + 8 - 1).
      signed[71] ^= 0x01;

      await expectLater(
        service.submitEscrowCall(
          consumer,
          p.hireId,
          p.prepared.preparationId,
          base64Encode(signed),
        ),
        throwsA(api('EnvelopeMismatch', details: {'field': 'timeBounds'})),
      );
      expect(await rig.submissions.listByHire(p.hireId), isEmpty);
      expect(rig.sender.resent, isEmpty);
    },
  );

  test('a signature by another key is InvalidTransactionSignature', () async {
    final p = await prepare(SubmissionPurpose.createJob);
    final xdr = sign(_key(9), p.prepared.unsignedTransactionXdr!);

    await expectLater(
      service.submitEscrowCall(
        consumer,
        p.hireId,
        p.prepared.preparationId,
        xdr,
      ),
      throwsA(
        api('InvalidTransactionSignature', details: {'reason': 'wrongSigner'}),
      ),
    );
    expect(await rig.submissions.listByHire(p.hireId), isEmpty);
    expect(rig.sender.resent, isEmpty);
  });
}
