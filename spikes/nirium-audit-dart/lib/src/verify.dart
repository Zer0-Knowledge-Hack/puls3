import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'receipt.dart';
import 'settlement.dart';

/// Reads the settlement in a transaction (Horizon in production).
typedef SettlementLookup = Future<EscrowSettlement> Function(String txHash);

/// The outcome of [verifyReceipt]. [ok] only when [failures] is empty.
final class ReceiptCheck {
  const ReceiptCheck(this.failures, {this.record});

  /// Each reason the receipt is not trusted, in the order checked.
  final List<String> failures;

  /// The record that was checked (from the document, or the local copy).
  final Map<String, Object?>? record;

  bool get ok => failures.isEmpty;
}

/// Verifies an anchored receipt [doc] without calling Nirium.
///
/// - The record is the one in [doc], or [localRecord] for a hash-only
///   anchor. When both exist they must be the same.
/// - Its sha-256 must equal `content_sha256`, both in puls3's canonical form
///   and as Nirium hashes it (`JSON.stringify` of the stored record).
/// - The `agent` attestation is required, its key must be [trustedKey], and
///   the signature must cover the recomputed hash. Nirium's own verifier
///   accepts a document without a signature; a puls3 receipt does not.
/// - The record must match the chain: the transaction read by [chain] is a
///   `complete` on the same escrow and job, with the same asset and
///   transfers, and the named agent wallet was paid.
///
/// The CID itself is not recomputed: the document is trusted to be what the
/// gateway served for that CID.
Future<ReceiptCheck> verifyReceipt(
  Map<String, Object?> doc, {
  required String trustedKey,
  required SettlementLookup chain,
  Map<String, Object?>? localRecord,
}) async {
  final failures = <String>[];
  final anchored = doc['record'];
  if (anchored != null && anchored is! Map<String, Object?>) {
    return const ReceiptCheck(['the document record is not an object']);
  }
  final record = (anchored as Map<String, Object?>?) ?? localRecord;
  if (record == null) {
    return const ReceiptCheck([
      'hash-only anchor: the record is needed to verify it',
    ]);
  }

  final declared = doc['content_sha256'];
  final String hash;
  try {
    hash = contentSha256(record);
  } on ArgumentError catch (e) {
    return ReceiptCheck(['the record is not canonical: ${e.message}']);
  }
  if (declared != hash) {
    failures.add('content_sha256 does not match the record');
  }
  if (anchored != null) {
    // As Nirium's verifier hashes it, key order as stored.
    final asStored = sha256.convert(utf8.encode(jsonEncode(anchored)));
    if ('$asStored' != declared) {
      failures.add('the stored record is not in canonical key order');
    }
    if (localRecord != null &&
        canonicalJson(localRecord) != canonicalJson(anchored)) {
      failures.add('the anchored record differs from the local copy');
    }
  }

  final agent = doc['agent'];
  if (agent is! Map) {
    failures.add('the receipt is not attested');
  } else if (agent['key'] != trustedKey) {
    failures.add('attested by ${agent['key']}, not by puls3 ($trustedKey)');
  } else if (!verifyAttestation(
    key: trustedKey,
    statement: attestationStatement(hash),
    signature: '${agent['signature']}',
  )) {
    failures.add('the attestation signature does not cover this record');
  }

  failures.addAll(await _checkChain(record, doc, chain));
  return ReceiptCheck(failures, record: record);
}

Future<List<String>> _checkChain(
  Map<String, Object?> record,
  Map<String, Object?> doc,
  SettlementLookup chain,
) async {
  final unknown = record.keys.toSet().difference(receiptFields);
  if (record['schema'] != receiptSchema || unknown.isNotEmpty) {
    return ['not a $receiptSchema record (extra fields: $unknown)'];
  }
  if (doc['network'] != null && doc['network'] != record['network']) {
    return ['anchored on ${doc['network']}, record says ${record['network']}'];
  }

  final EscrowSettlement settlement;
  try {
    settlement = await chain(record['settle_tx'] as String);
  } on NotASettlement catch (e) {
    return ['the transaction is not a settlement: ${e.message}'];
  } on Object catch (e) {
    return ['the chain could not be read: $e'];
  }

  final failures = <String>[];
  void same(String field, Object? onChain) {
    if (record[field] != onChain) {
      failures.add('$field: record ${record[field]}, chain $onChain');
    }
  }

  same('network', settlement.network);
  same('escrow_contract', settlement.escrowContract);
  same('job_id', settlement.jobId);
  same('ledger', '${settlement.ledger}');
  same('closed_at', settlement.closedAt);
  same('asset', settlement.asset);
  final transfers = [
    for (final t in (record['transfers'] as List? ?? const []))
      Transfer(to: '${(t as Map)['to']}', amount: '${t['amount']}'),
  ];
  if (!_sameList(transfers, settlement.transfers)) {
    failures.add('transfers: record $transfers, chain ${settlement.transfers}');
  }
  final wallet = (record['agent'] as Map?)?['wallet'];
  if (!settlement.transfers.any((t) => t.to == wallet)) {
    failures.add('the agent wallet $wallet was not paid in this transaction');
  }
  return failures;
}

bool _sameList(List<Transfer> a, List<Transfer> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
