import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart';

import 'xdr_invoke_encoder.dart' show ScArg;

/// What the server builds for a client to sign: one `InvokeHostFunction` call
/// from [source] with the signer's [accountSequence], a time window that
/// closes at [validUntil], and the fee the simulation asked for on top of
/// [inclusionFee].
final class EnvelopeSpec {
  const EnvelopeSpec({
    required this.source,
    required this.accountSequence,
    required this.contract,
    required this.function,
    required this.args,
    required this.inclusionFee,
    required this.validUntil,
  });

  /// The session wallet: transaction source and signer.
  final StellarAddress source;

  /// The sequence number the source account has on chain now. The envelope
  /// uses the next one.
  final int accountSequence;
  final StellarAddress contract;
  final String function;
  final List<ScArg> args;

  /// The inclusion fee in stroops, from configuration.
  final int inclusionFee;

  /// Unix seconds: the `maxTime` of the time bounds (`minTime` is 0).
  final int validUntil;
}

/// The parts of a `simulateTransaction` answer the envelope needs. They stay
/// in the base64 XDR the node sent; the codec never decodes them.
final class SimulationData {
  const SimulationData({
    required this.transactionData,
    required this.minResourceFee,
    this.auth = const [],
  });

  /// The base64 XDR `SorobanTransactionData`.
  final String transactionData;

  /// The minimum resource fee in stroops.
  final int minResourceFee;

  /// The base64 XDR `SorobanAuthorizationEntry` list of the first result.
  final List<String> auth;
}

/// An unsigned envelope ready to hand to the wallet.
final class PreparedEnvelope {
  const PreparedEnvelope({
    required this.envelopeXdr,
    required this.body,
    required this.hash,
  });

  /// The unsigned `TransactionEnvelope`, base64 XDR.
  final String envelopeXdr;

  /// The `Transaction` bytes the signature covers.
  final Uint8List body;

  /// The 32-byte network transaction hash.
  final Uint8List hash;

  /// [hash] as 64 lowercase hex characters, the form `getTransaction` takes.
  String get hashHex => hexOf(hash);
}

/// [bytes] as lowercase hex.
String hexOf(Uint8List bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// One `DecoratedSignature` of an envelope.
final class EnvelopeSignature {
  const EnvelopeSignature({required this.hint, required this.signature});

  /// The last 4 bytes of the signer's public key.
  final Uint8List hint;
  final Uint8List signature;
}

/// A well-formed, version 1 envelope received from a client.
final class SignedEnvelope {
  const SignedEnvelope({
    required this.body,
    required this.hash,
    required this.signatures,
  });

  /// The `Transaction` bytes, compared with the prepared body.
  final Uint8List body;

  /// The network transaction hash of [body].
  final Uint8List hash;
  final List<EnvelopeSignature> signatures;

  /// [hash] as 64 lowercase hex characters.
  String get hashHex => hexOf(hash);
}

/// Why [EnvelopeCodec.parse] refused an envelope.
enum InvalidEnvelopeReason {
  /// The input is the empty string.
  empty,

  /// The input is not base64.
  notBase64,

  /// The bytes end before the envelope does, or are not an envelope.
  truncated,

  /// Bytes follow the signature list.
  trailingBytes,

  /// The envelope is `ENVELOPE_TYPE_TX_FEE_BUMP`.
  feeBump,
}

/// `InvalidSignedEnvelope`: the signed XDR is not a plain transaction
/// envelope.
final class InvalidSignedEnvelope implements Exception {
  const InvalidSignedEnvelope(this.reason);

  final InvalidEnvelopeReason reason;

  @override
  String toString() => 'InvalidSignedEnvelope: ${reason.name}';
}

/// The simulation returned an authorization entry that the source account's
/// own signature does not cover. The relay never signs for anyone else, so
/// the call cannot be prepared.
final class UnsupportedAuthorization implements Exception {
  const UnsupportedAuthorization();

  @override
  String toString() =>
      'UnsupportedAuthorization: only SOURCE_ACCOUNT credentials are relayed';
}

/// The result of checking an envelope's signature against its signer.
enum SignatureCheck {
  /// Exactly one signature, from the signer, valid over the hash.
  valid,

  /// The envelope has no signature.
  missing,

  /// There is more than one signature, or its hint is not the signer's.
  wrongSigner,

  /// The signer's signature fails ed25519 verification over the hash.
  doesNotVerify,
}

/// `EnvelopeMismatch.details.field` values.
abstract final class EnvelopeField {
  static const contract = 'contract';
  static const function = 'function';
  static const arguments = 'arguments';
  static const source = 'source';
  static const timeBounds = 'timeBounds';

  /// Fee, sequence number, Soroban data, memo, envelope type, or anything
  /// else outside the named groups.
  static const other = 'other';
}

/// Builds the envelopes the server prepares and checks the ones clients sign.
///
/// It is the only place that knows the XDR layout. `stellar_dart` is behind
/// it; the pure-Dart fallback of the spike would be a second adapter.
abstract interface class EnvelopeCodec {
  /// The unsigned envelope for [spec]: sequence `accountSequence + 1`, fee
  /// `inclusionFee + minResourceFee`, time bounds `[0, validUntil]`, and
  /// [sim]'s Soroban data and authorization entries spliced in unchanged.
  ///
  /// Throws [UnsupportedAuthorization] when an entry's credentials are not
  /// `SOURCE_ACCOUNT`.
  PreparedEnvelope build(EnvelopeSpec spec, SimulationData sim);

  /// Reads a client's base64 envelope. Throws [InvalidSignedEnvelope].
  SignedEnvelope parse(String base64);

  /// The first group, as an [EnvelopeField], in which two different bodies
  /// differ: contract, function, arguments, source, timeBounds, then other.
  /// `null` when the bodies are equal.
  String? firstDifference(Uint8List preparedBody, Uint8List signedBody);

  /// Checks [envelope]'s signatures against [signer] over [hash].
  SignatureCheck verify(
    SignedEnvelope envelope,
    StellarAddress signer,
    Uint8List hash,
  );
}
