import 'dart:convert';
import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart';
import 'package:stellar_dart/stellar_dart.dart' as stellar;

import 'sep10_codec.dart';
import 'stellar_envelope_codec.dart';
import 'strkey.dart';
import 'envelope_codec.dart';

export 'sep10_codec.dart';

/// [Sep10Codec] on `stellar_dart`.
///
/// The challenge is a classic transaction: source and signer are the server
/// key, sequence is 0, fee is the 100-stroop base fee (it is never submitted),
/// and the two `manage_data` operations follow SEP-10 v3.4.1.
final class StellarSep10Codec implements Sep10Codec {
  StellarSep10Codec({
    required String signingKey,
    required this.homeDomain,
    required this.webAuthDomain,
    required String networkPassphrase,
  }) : _server = stellar.StellarPrivateKey.fromBase32(signingKey),
       _network = stellar.StellarNetwork.fromPassphrase(networkPassphrase),
       _envelopes = StellarEnvelopeCodec.forPassphrase(networkPassphrase);

  final stellar.StellarPrivateKey _server;
  final stellar.StellarNetwork _network;
  final StellarEnvelopeCodec _envelopes;

  /// `<homeDomain> auth` is the first operation's name.
  final String homeDomain;

  /// Value of the `web_auth_domain` operation.
  final String webAuthDomain;

  @override
  BuiltChallenge build({
    required StellarAddress wallet,
    required List<int> nonce,
    required DateTime now,
  }) {
    if (nonce.length != 48) {
      throw ArgumentError('nonce must be 48 bytes');
    }
    final serverAccount = _server.toPublicKey().toAddress().address;
    final min = BigInt.from(now.toUtc().millisecondsSinceEpoch ~/ 1000);
    final tx = stellar.StellarTransactionV1(
      sourceAccount: stellar.MuxedAccount.fromBase32Address(serverAccount),
      fee: _baseFee,
      seqNum: BigInt.zero,
      cond: stellar.PrecondTime(
        stellar.TimeBounds(minTime: min, maxTime: min + BigInt.from(900)),
      ),
      operations: [
        stellar.Operation(
          sourceAccount: stellar.MuxedAccount.fromBase32Address(wallet.value),
          body: stellar.ManageDataOperation(
            dataName: '$homeDomain auth',
            dataValue: utf8.encode(base64Encode(nonce)),
          ),
        ),
        stellar.Operation(
          sourceAccount: stellar.MuxedAccount.fromBase32Address(serverAccount),
          body: stellar.ManageDataOperation(
            dataName: 'web_auth_domain',
            dataValue: utf8.encode(webAuthDomain),
          ),
        ),
      ],
    );
    final hash = Uint8List.fromList(
      stellar.TransactionSignaturePayload(
        networkId: _network.passphraseHash,
        taggedTransaction: tx,
      ).txHash(),
    );
    final envelope = stellar.TransactionV1Envelope(
      tx: tx,
      signatures: [_server.sign(hash)],
    );
    return BuiltChallenge(
      envelopeXdr: base64Encode(envelope.toVariantXDR()),
      body: Uint8List.fromList(tx.toXDR()),
      hash: hash,
    );
  }

  @override
  SignedEnvelope parse(String xdr) => _envelopes.parse(xdr);

  @override
  bool verifies(
    StellarAddress key,
    EnvelopeSignature signature,
    Uint8List hash,
  ) {
    final public = stellar.StellarPublicKey.fromPublicBytes(rawKey(key));
    if (!_same(signature.hint, public.hint())) return false;
    try {
      return public.verify(digest: hash, signature: signature.signature);
    } on Object {
      // A corrupted signature can fall outside the ed25519 scalar range.
      // That is not a valid signature; it is not an error to report.
      return false;
    }
  }
}

/// Classic base fee, in stroops. A SEP-10 challenge is not submitted.
const _baseFee = 100;

bool _same(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
