// Spike gate for issue #96 (escrow relay): can `stellar_dart` carry the
// envelope work the relay needs, or do we fall back to package:crypto plus an
// ed25519 package with hand-written XDR?
//
// Result (stellar_dart 2.3.0, recorded 2026-10-07, Dart 3.10.0):
//   decode + byte-identical re-encode  PASS (Envelope.fromXdr / toVariantXDR)
//   network transaction hash           PASS (equals the on-chain txHash)
//   ed25519 signature verification     PASS (StellarPublicKey.verify)
// Decision: adopt stellar_dart; the fallback is not needed.
//
// Fixtures are real testnet transactions (create_job and fund for job 3),
// fetched read-only through getTransaction with xdrFormat=base64. They are
// the same transactions as test/unit/ledger/fixtures/*_job_3.json, which
// only carry the JSON form of the envelope.
import 'dart:convert';
import 'dart:io';

import 'package:stellar_dart/stellar_dart.dart';
import 'package:test/test.dart';

const _fixtures = [
  'test/fixtures/escrow_relay/get_transaction_create_job_3_xdr.json',
  'test/fixtures/escrow_relay/get_transaction_fund_job_3_xdr.json',
];

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  for (final path in _fixtures) {
    final fixture =
        jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    final xdr = fixture['envelopeXdr'] as String;
    final txHash = fixture['txHash'] as String;
    final name = path.split('/').last;

    group(name, () {
      test('decodes and re-encodes the envelope byte-identically', () {
        final envelope = Envelope.fromXdr(base64Decode(xdr));

        expect(envelope, isA<TransactionV1Envelope>());
        expect(envelope.signatures, hasLength(1));
        // toXDR() omits the envelope-type discriminant; the variant form has it.
        expect(base64Encode(envelope.toVariantXDR()), xdr);
      });

      test('computes the network transaction hash recorded on chain', () {
        final envelope = Envelope.fromXdr(base64Decode(xdr));
        final network = StellarNetwork.testnet;

        // sha256(passphrase) is the network id of the signature payload.
        expect(
          _hex(network.passphraseHash),
          'cee0302d59844d32bdca915c8203dd44b33fbb7edc19051ea37abedf28ecd472',
        );

        final payload = TransactionSignaturePayload(
          networkId: network.passphraseHash,
          taggedTransaction: envelope.tx,
        );
        final payloadBytes = payload.toXDR();

        // networkId || uint32(2) (ENVELOPE_TYPE_TX) || transaction bytes.
        expect(payloadBytes.sublist(0, 32), network.passphraseHash);
        expect(payloadBytes.sublist(32, 36), [0, 0, 0, 2]);
        expect(envelope.txId(network.passphraseHash), txHash);
      });

      test('verifies the ed25519 signature against the source account', () {
        final envelope = Envelope.fromXdr(base64Decode(xdr));
        final tx = (envelope as TransactionV1Envelope).tx;
        final signer = StellarPublicKey.fromPublicBytes(
          (tx.sourceAccount as MuxedAccountEd25519).ed25519,
        );
        // The ed25519 signature is over the transaction hash itself.
        final digest = TransactionSignaturePayload(
          networkId: StellarNetwork.testnet.passphraseHash,
          taggedTransaction: tx,
        ).txHash();
        final signature = envelope.signatures.single;

        expect(signature.hint, signer.hint());
        expect(
          signer.verify(digest: digest, signature: signature.signature),
          isTrue,
        );

        final tampered = List<int>.of(signature.signature)..[0] ^= 0x01;
        expect(signer.verify(digest: digest, signature: tampered), isFalse);
      });
    });
  }
}
