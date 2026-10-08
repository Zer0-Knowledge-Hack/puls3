import 'dart:convert';
import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart';
import 'package:stellar_dart/stellar_dart.dart' as stellar;

import 'envelope_codec.dart';
import 'strkey.dart';
import 'xdr_invoke_encoder.dart';

// XDR discriminants, from Stellar-transaction.x.
const _envelopeTypeTx = 2;
const _envelopeTypeFeeBump = 5;
const _keyTypeEd25519 = 0;
const _precondTime = 1;
const _memoNone = 0;
const _invokeHostFunction = 24;
const _txExtSorobanData = 1;
const _credentialsSourceAccount = 0;
const _maxUint32 = 0xffffffff;

/// The [EnvelopeCodec] on `stellar_dart`, which the spike proved against
/// recorded testnet envelopes (`test/spike/envelope_spike_test.dart`).
///
/// The envelope is written by hand, so the Soroban data and authorization
/// entries from a simulation go in as the bytes the node sent. `stellar_dart`
/// reads envelopes back, hashes them and verifies signatures.
final class StellarEnvelopeCodec implements EnvelopeCodec {
  StellarEnvelopeCodec(this._network);

  /// A codec for the network with [passphrase]: Stellar's public, test or
  /// future network. Any other passphrase throws.
  factory StellarEnvelopeCodec.forPassphrase(String passphrase) =>
      StellarEnvelopeCodec(stellar.StellarNetwork.fromPassphrase(passphrase));

  final stellar.StellarNetwork _network;

  @override
  PreparedEnvelope build(EnvelopeSpec spec, SimulationData sim) {
    final fee = spec.inclusionFee + sim.minResourceFee;
    if (fee < 0 || fee > _maxUint32) {
      throw ArgumentError.value(fee, 'fee', 'does not fit in a uint32');
    }
    final auth = [for (final entry in sim.auth) base64Decode(entry)];
    for (final entry in auth) {
      if (entry.length < 4 ||
          ByteData.sublistView(entry).getUint32(0) !=
              _credentialsSourceAccount) {
        throw const UnsupportedAuthorization();
      }
    }

    final body = XdrWriter()
      ..uint32(_keyTypeEd25519)
      ..opaque(rawKey(spec.source))
      ..uint32(fee)
      ..int64(spec.accountSequence + 1)
      ..uint32(_precondTime)
      ..uint64(0) // minTime
      ..uint64(spec.validUntil) // maxTime
      ..uint32(_memoNone)
      ..uint32(1) // one operation
      ..uint32(0) // no operation source account
      ..uint32(_invokeHostFunction)
      ..raw(
        encodeInvokeHostFunction(
          contract: spec.contract,
          function: spec.function,
          args: spec.args,
        ),
      )
      ..uint32(auth.length);
    for (final entry in auth) {
      body.raw(entry);
    }
    body
      ..uint32(_txExtSorobanData)
      ..raw(base64Decode(sim.transactionData));

    final envelope = XdrWriter()
      ..uint32(_envelopeTypeTx)
      ..raw(body.bytes)
      ..uint32(0); // no signatures
    final bytes = envelope.bytes;
    final decoded =
        stellar.Envelope.fromXdr(bytes) as stellar.TransactionV1Envelope;
    return PreparedEnvelope(
      envelopeXdr: base64Encode(bytes),
      body: body.bytes,
      hash: _hashOf(decoded),
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
    if (bytes.length >= 4 &&
        ByteData.sublistView(bytes).getUint32(0) == _envelopeTypeFeeBump) {
      throw const InvalidSignedEnvelope(InvalidEnvelopeReason.feeBump);
    }

    final stellar.Envelope decoded;
    try {
      decoded = stellar.Envelope.fromXdr(bytes);
    } on Object {
      // stellar_dart reports a short buffer as a RangeError and a wrong
      // discriminant as its own exception; none of them is a usable envelope.
      throw const InvalidSignedEnvelope(InvalidEnvelopeReason.truncated);
    }
    if (decoded is! stellar.TransactionV1Envelope) {
      // A version 0 envelope cannot carry a Soroban call.
      throw const InvalidSignedEnvelope(InvalidEnvelopeReason.truncated);
    }
    // The decoder ignores bytes after the signature list; re-encoding does not.
    if (decoded.toVariantXDR().length != bytes.length) {
      throw const InvalidSignedEnvelope(InvalidEnvelopeReason.trailingBytes);
    }
    return SignedEnvelope(
      body: Uint8List.fromList(decoded.tx.toXDR()),
      hash: _hashOf(decoded),
      signatures: [
        for (final s in decoded.signatures)
          EnvelopeSignature(
            hint: Uint8List.fromList(s.hint),
            signature: Uint8List.fromList(s.signature),
          ),
      ],
    );
  }

  @override
  String? firstDifference(Uint8List preparedBody, Uint8List signedBody) {
    if (_same(preparedBody, signedBody)) return null;
    final prepared = _groups(preparedBody);
    final signed = _groups(signedBody);
    if (prepared == null || signed == null) return EnvelopeField.other;
    for (final field in _groupOrder) {
      final a = prepared[field];
      final b = signed[field];
      if (a != null && b != null && !_sameValue(a, b)) return field;
    }
    return EnvelopeField.other;
  }

  @override
  SignatureCheck verify(
    SignedEnvelope envelope,
    StellarAddress signer,
    Uint8List hash,
  ) {
    final signatures = envelope.signatures;
    if (signatures.isEmpty) return SignatureCheck.missing;
    if (signatures.length > 1) return SignatureCheck.wrongSigner;
    final key = stellar.StellarPublicKey.fromPublicBytes(rawKey(signer));
    final signature = signatures.single;
    if (!_same(signature.hint, key.hint())) return SignatureCheck.wrongSigner;
    return key.verify(digest: hash, signature: signature.signature)
        ? SignatureCheck.valid
        : SignatureCheck.doesNotVerify;
  }

  Uint8List _hashOf(stellar.TransactionV1Envelope envelope) =>
      Uint8List.fromList(
        stellar.TransactionSignaturePayload(
          networkId: _network.passphraseHash,
          taggedTransaction: envelope.tx,
        ).txHash(),
      );
}

const _groupOrder = [
  EnvelopeField.contract,
  EnvelopeField.function,
  EnvelopeField.arguments,
  EnvelopeField.source,
  EnvelopeField.timeBounds,
];

/// The groups of a transaction body, each as the decoded structure of its
/// parts, or `null` when [body] is not a transaction. The contract, function
/// and arguments groups are absent when the body has no single contract call,
/// so it can only differ as `other`.
///
/// Decoded structures are compared instead of re-encoded bytes because
/// `stellar_dart` cannot serialize a bare `ScVal`, only a whole envelope.
Map<String, List<Object?>>? _groups(Uint8List body) {
  final stellar.TransactionV1Envelope envelope;
  try {
    envelope =
        stellar.Envelope.fromXdr([
              0,
              0,
              0,
              _envelopeTypeTx,
              ...body,
              0,
              0,
              0,
              0,
            ])
            as stellar.TransactionV1Envelope;
  } on Object {
    return null;
  }
  final tx = envelope.tx;
  final groups = <String, List<Object?>>{
    EnvelopeField.source: [tx.sourceAccount.toVariantLayoutStruct()],
    EnvelopeField.timeBounds: [tx.cond.toVariantLayoutStruct()],
  };
  final operation = tx.operations.length == 1
      ? tx.operations.single.body
      : null;
  if (operation is stellar.InvokeHostFunctionOperation) {
    final function = operation.hostFunction;
    if (function is stellar.HostFunctionTypeInvokeContract) {
      final call = function.args;
      groups[EnvelopeField.contract] = [
        call.contractAddress.toVariantLayoutStruct(),
      ];
      groups[EnvelopeField.function] = [call.functionName.value];
      groups[EnvelopeField.arguments] = [
        for (final a in call.args) a.toVariantLayoutStruct(),
      ];
    }
  }
  return groups;
}

bool _same(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Deep equality of decoded XDR structures: maps, lists, numbers, strings.
bool _sameValue(Object? a, Object? b) {
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every((k) => b.containsKey(k) && _sameValue(a[k], b[k]));
  }
  if (a is List && b is List) {
    return a.length == b.length &&
        List.generate(a.length, (i) => _sameValue(a[i], b[i])).every((e) => e);
  }
  return a == b;
}
