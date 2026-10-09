import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart';

import 'envelope_codec.dart';

/// A server-signed SEP-10 challenge transaction.
final class BuiltChallenge {
  const BuiltChallenge({
    required this.envelopeXdr,
    required this.body,
    required this.hash,
  });

  /// Base64 `TransactionEnvelope`, including the server signature.
  final String envelopeXdr;

  /// The `Transaction` bytes the signatures cover.
  final Uint8List body;

  /// The 32-byte network transaction hash.
  final Uint8List hash;
}

/// Builds and checks SEP-10 challenge transactions.
///
/// The cryptography stays in the adapter. [parse] is the same envelope reader
/// the escrow relay uses, so a fee-bump, truncated or trailing envelope fails
/// the same way.
abstract interface class Sep10Codec {
  /// A challenge for [wallet] whose first `manage_data` value is the base64
  /// of [nonce] (48 bytes) and whose time bounds are `[now, now + 900s]`.
  BuiltChallenge build({
    required StellarAddress wallet,
    required List<int> nonce,
    required DateTime now,
  });

  /// Reads a base64 envelope. Throws [InvalidSignedEnvelope].
  SignedEnvelope parse(String xdr);

  /// Whether [signature] is a valid signature of [hash] by [key].
  bool verifies(
    StellarAddress key,
    EnvelopeSignature signature,
    Uint8List hash,
  );
}
