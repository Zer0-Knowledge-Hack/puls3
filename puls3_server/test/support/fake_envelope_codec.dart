import 'dart:convert';
import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/ledger/envelope_codec.dart';
import 'package:puls3_server/src/ledger/xdr_invoke_encoder.dart';

const _marker = '#sig:';

/// An [EnvelopeCodec] with a transparent format, so service tests can build
/// "signed" envelopes without keys: the envelope is the body, the marker
/// `#sig:` and a signature tag. Tag `ok` verifies, `wrong` is another
/// signer, `bad` does not verify, and an empty tag is unsigned.
///
/// The body holds the source, the sequence, the time bound, the fee and the
/// real XDR of the invoked function, so tests can compare calls byte by byte.
final class FakeEnvelopeCodec implements EnvelopeCodec {
  /// Returned by [firstDifference] when the bodies differ.
  String differenceField = EnvelopeField.arguments;

  Object? buildFailure;

  /// Called by [verify], before it answers; lets a test race the submit.
  void Function()? onVerify;

  final built = <({EnvelopeSpec spec, SimulationData sim})>[];

  @override
  PreparedEnvelope build(EnvelopeSpec spec, SimulationData sim) {
    final failure = buildFailure;
    if (failure != null) throw failure;
    built.add((spec: spec, sim: sim));
    final body = Uint8List.fromList([
      ...utf8.encode(
        '${spec.source.value}|${spec.accountSequence + 1}|${spec.validUntil}|'
        '${spec.inclusionFee + sim.minResourceFee}|',
      ),
      ...encodeInvokeHostFunction(
        contract: spec.contract,
        function: spec.function,
        args: spec.args,
      ),
    ]);
    return PreparedEnvelope(
      envelopeXdr: envelope(body, ''),
      body: body,
      hash: _hash(body),
    );
  }

  @override
  SignedEnvelope parse(String base64) {
    if (base64.isEmpty) {
      throw const InvalidSignedEnvelope(InvalidEnvelopeReason.empty);
    }
    final Uint8List bytes;
    try {
      bytes = base64Decode(base64);
    } on FormatException {
      throw const InvalidSignedEnvelope(InvalidEnvelopeReason.notBase64);
    }
    final text = latin1.decode(bytes);
    final at = text.lastIndexOf(_marker);
    if (at < 0) {
      throw const InvalidSignedEnvelope(InvalidEnvelopeReason.truncated);
    }
    final body = Uint8List.fromList(bytes.sublist(0, at));
    final tag = text.substring(at + _marker.length);
    return SignedEnvelope(
      body: body,
      hash: _hash(body),
      signatures: [
        if (tag.isNotEmpty)
          EnvelopeSignature(hint: Uint8List(4), signature: utf8.encode(tag)),
      ],
    );
  }

  @override
  String? firstDifference(Uint8List preparedBody, Uint8List signedBody) =>
      base64Encode(preparedBody) == base64Encode(signedBody)
      ? null
      : differenceField;

  @override
  SignatureCheck verify(
    SignedEnvelope envelope,
    StellarAddress signer,
    Uint8List hash,
  ) {
    onVerify?.call();
    if (envelope.signatures.isEmpty) return SignatureCheck.missing;
    return switch (utf8.decode(envelope.signatures.single.signature)) {
      'wrong' => SignatureCheck.wrongSigner,
      'bad' => SignatureCheck.doesNotVerify,
      _ => SignatureCheck.valid,
    };
  }

  /// The base64 envelope of [body] with signature [tag].
  static String envelope(List<int> body, String tag) =>
      base64Encode([...body, ...latin1.encode('$_marker$tag')]);

  /// The prepared envelope [unsigned] signed with [tag], optionally with
  /// another [body].
  static String sign(String unsigned, {String tag = 'ok', List<int>? body}) {
    final bytes = base64Decode(unsigned);
    final at = latin1.decode(bytes).lastIndexOf(_marker);
    return envelope(body ?? bytes.sublist(0, at), tag);
  }

  static Uint8List _hash(List<int> body) {
    final hash = Uint8List(32);
    for (var i = 0; i < body.length; i++) {
      hash[i % 32] = (hash[i % 32] * 31 + body[i] + 1) & 0xff;
    }
    return hash;
  }
}
