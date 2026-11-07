import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:stellar_dart/stellar_dart.dart' as stellar;

import 'settlement.dart';

/// The schema id puls3 writes into every receipt record.
const receiptSchema = 'puls3.escrow.settlement.v1';

/// The `agent.id` label puls3 attests with.
const attesterId = 'puls3';

/// The receipt record for [settlement]: only public chain data, plus which
/// puls3 agent was paid. No prompt, result, secret or data about the person
/// who hired.
///
/// Throws [ArgumentError] when [agentWallet] received nothing in the
/// settlement, so a receipt never names an agent the escrow did not pay.
Map<String, Object?> receiptRecord(
  EscrowSettlement settlement, {
  required int agentRegistryId,
  required String agentWallet,
}) {
  if (!settlement.transfers.any((t) => t.to == agentWallet)) {
    throw ArgumentError.value(
      agentWallet,
      'agentWallet',
      'received nothing in ${settlement.txHash}',
    );
  }
  return {
    'agent': {'registry_id': '$agentRegistryId', 'wallet': agentWallet},
    'asset': settlement.asset,
    'closed_at': settlement.closedAt,
    'escrow_contract': settlement.escrowContract,
    'job_id': settlement.jobId,
    'ledger': '${settlement.ledger}',
    'network': settlement.network,
    'schema': receiptSchema,
    'settle_tx': settlement.txHash,
    'transfers': [for (final t in settlement.transfers) t.toJson()],
  };
}

/// The fields a receipt record may hold. A test pins this list so a field
/// with private data cannot slip in unnoticed.
const receiptFields = {
  'agent',
  'asset',
  'closed_at',
  'escrow_contract',
  'job_id',
  'ledger',
  'network',
  'schema',
  'settle_tx',
  'transfers',
};

/// [value] as compact JSON with object keys in lexicographic order, the
/// form Nirium hashes (`JSON.stringify` of the stored record).
///
/// Throws [ArgumentError] for a non-ASCII string or a number: Dart and
/// JavaScript agree on how to print ASCII strings, not on every double, so
/// a receipt keeps its values as ASCII strings.
String canonicalJson(Object? value) => jsonEncode(_canonical(value));

Object? _canonical(Object? value) => switch (value) {
  null || bool() => value,
  String() when value.codeUnits.every((c) => c >= 0x20 && c < 0x7f) => value,
  String() => throw ArgumentError.value(value, 'value', 'must be ASCII'),
  Map() => {
    for (final key in (value.keys.cast<String>().toList()..sort()))
      key: _canonical(value[key]),
  },
  List() => [for (final item in value) _canonical(item)],
  _ => throw ArgumentError.value(value, 'value', 'must be a string'),
};

/// sha-256 hex of [record] in [canonicalJson] form.
String contentSha256(Map<String, Object?> record) =>
    sha256.convert(utf8.encode(canonicalJson(record))).toString();

/// What the attesting key signs for a record whose hash is [contentHash].
String attestationStatement(String contentHash) =>
    'nirium-audit-v1:$contentHash';

/// Signs receipt statements with puls3's attesting key.
///
/// [toString] shows only the address, so the secret cannot reach output.
final class ReceiptSigner {
  ReceiptSigner._(this._key, this.address);

  /// Parses an `S…` [secret]. Throws [FormatException] without echoing it.
  factory ReceiptSigner.fromSecret(String secret) {
    final stellar.StellarPrivateKey key;
    try {
      key = stellar.StellarPrivateKey.fromBase32(secret.trim());
    } on Object {
      throw const FormatException('the key file does not hold an S… key');
    }
    return ReceiptSigner._(key, key.toPublicKey().toAddress().baseAddress);
  }

  /// A new random key, for `bin/keygen.dart`.
  factory ReceiptSigner.random() {
    final random = Random.secure();
    return ReceiptSigner._fromKey(
      stellar.StellarPrivateKey.fromBytes([
        for (var i = 0; i < 32; i++) random.nextInt(256),
      ]),
    );
  }

  factory ReceiptSigner._fromKey(stellar.StellarPrivateKey key) =>
      ReceiptSigner._(key, key.toPublicKey().toAddress().baseAddress);

  final stellar.StellarPrivateKey _key;

  /// The attesting key as a Stellar address (`G…`).
  final String address;

  /// The `S…` secret, only for writing the key file.
  String exportSecret() => _key.toBase32();

  /// base64 ed25519 signature over [attestationStatement] of [contentHash].
  String sign(String contentHash) => base64.encode(
    _key.sign(utf8.encode(attestationStatement(contentHash))).signature,
  );

  @override
  String toString() => 'ReceiptSigner($address)';
}

/// True when [signature] (base64 or hex) is [key]'s ed25519 signature of
/// [statement]. False for a malformed key or signature.
bool verifyAttestation({
  required String key,
  required String statement,
  required String signature,
}) {
  try {
    final publicKey = stellar.StellarPublicKey.fromAddress(
      stellar.StellarAddress.fromBase32Addr(key),
    );
    return publicKey.verify(
      digest: utf8.encode(statement),
      signature: _signatureBytes(signature),
    );
  } on Object {
    return false;
  }
}

Uint8List _signatureBytes(String signature) {
  final text = signature.trim();
  if (RegExp(r'^[0-9a-fA-F]{128}$').hasMatch(text)) {
    return Uint8List.fromList([
      for (var i = 0; i < 128; i += 2)
        int.parse(text.substring(i, i + 2), radix: 16),
    ]);
  }
  return base64.decode(text);
}

/// How much of the evidence goes to Nirium.
enum AnchorMode {
  /// The record itself is anchored and public on IPFS.
  record,

  /// Only its sha-256 is anchored; puls3 keeps the record.
  hash,
}

/// The `POST /api/audit/log` body for [record], attested by [signer].
Map<String, Object?> anchorBody(
  Map<String, Object?> record, {
  required ReceiptSigner signer,
  required AnchorMode mode,
  String? tag,
}) {
  final hash = contentSha256(record);
  return {
    if (mode == AnchorMode.record)
      'record': jsonDecode(canonicalJson(record))
    else
      'hash': 'sha-256:$hash',
    'tag': ?tag,
    'agent': {
      'id': attesterId,
      'key': signer.address,
      'signature': signer.sign(hash),
    },
  };
}
