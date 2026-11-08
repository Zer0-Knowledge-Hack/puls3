import 'dart:convert';
import 'dart:io';

import 'package:nirium_audit_spike/nirium_audit.dart';
import 'package:stellar_dart/stellar_dart.dart' as stellar;

/// Job 3 `complete` on testnet (docs/submission/serverpod.md).
const job3Tx =
    'ee6dfb528145c0e8d8e2d4420d47598d94c3d6698f2a60125d032e909a8e50c4';
const escrow = 'CBRD7A7MXINM7LREKCL3RMKRQ5UMLGKNHAEYY4JT7MVBBB7R5QV4TPE2';
const ledgerScoutWallet =
    'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY';
const usdcTestnet =
    'USDC:GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5';

Map<String, Object?> fixture(String name) =>
    jsonDecode(File('test/fixtures/$name').readAsStringSync())
        as Map<String, Object?>;

EscrowSettlement job3() => EscrowSettlement.fromHorizon(
  network: 'stellar:testnet',
  tx: fixture('complete-job3-tx.json'),
  operations: fixture('complete-job3-ops.json'),
);

/// A key derived from a fixed seed at run time, so no `S…` literal is in
/// the repo.
ReceiptSigner testSigner([int fill = 7]) => ReceiptSigner.fromSecret(
  stellar.StellarPrivateKey.fromBytes(List.filled(32, fill)).toBase32(),
);

Map<String, Object?> job3Record() =>
    receiptRecord(job3(), agentRegistryId: 7, agentWallet: ledgerScoutWallet);

/// The document Nirium stores for [body], in the shape of its fixtures.
Map<String, Object?> anchoredDoc(Map<String, Object?> body) {
  final record = body['record'] as Map<String, Object?>?;
  final hash = record != null
      ? contentSha256(record)
      : (body['hash'] as String).replaceFirst('sha-256:', '');
  final agent = body['agent'] as Map<String, Object?>;
  return {
    'version': '1.1.0',
    'node': 'audit-external',
    'content_sha256': hash,
    'agent': {
      ...agent,
      'alg': 'ed25519',
      'statement': attestationStatement(hash),
    },
    'record': ?record,
    'network': 'stellar:testnet',
    'tag': ?body['tag'],
    'anchoredAt': '2026-11-07T00:00:00.000Z',
  };
}

/// Escrow job 3 as Soroban RPC returned it (`getLedgerEntries`).
EscrowJob job3Job() =>
    escrowJobFromEntry(fixture('escrow-job3-entry.json')['xdr'] as String);

/// A [JobLookup] that knows only job 3, or answers [job] for it.
JobLookup job3Lookup([EscrowJob? job]) => (contract, jobId) async {
  if (contract != escrow || jobId != '3') {
    throw StateError('unknown job $jobId on $contract');
  }
  return job ?? job3Job();
};

/// The bytes the Nirium gateway served for [cid] (`test/fixtures/<cid>.ipfs`).
List<int> served(String cid) =>
    File('test/fixtures/$cid.ipfs').readAsBytesSync();

/// The record anchor and the hash-only anchor of job 3 (2026-11-07).
const recordCid = 'QmSSRjPwEzpmr9xbEhgAc6xR1Y4rtjJyjckTELR1ra8TuB';
const hashCid = 'QmUrMP68deCRbwyt4EVgkjL2ENWMSgvRQzVFkjSTJGkNWf';

/// The throwaway attesting key of the live run (public key only).
const spikeAttester =
    'GCOHAMUMAKDNXGVGIK2P7MUDBC4BHVINPJ7QXE2Z436BBMBV2RMIGWS4';
