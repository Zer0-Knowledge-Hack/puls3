import 'dart:convert';

import 'strkey.dart';

/// Why a transaction cannot back a receipt.
final class NotASettlement implements Exception {
  const NotASettlement(this.message);

  final String message;

  @override
  String toString() => 'NotASettlement: $message';
}

/// One token movement out of the escrow in the settle transaction.
final class Transfer {
  const Transfer({required this.to, required this.amount});

  /// The recipient (`G…` or `C…`).
  final String to;

  /// The amount as Horizon prints it, with 7 decimals (`0.5000000`).
  final String amount;

  Map<String, String> toJson() => {'amount': amount, 'to': to};

  @override
  bool operator ==(Object other) =>
      other is Transfer && other.to == to && other.amount == amount;

  @override
  int get hashCode => Object.hash(to, amount);

  @override
  String toString() => 'Transfer($amount -> $to)';
}

/// A settled escrow job, read from the chain: the `complete` call and the
/// transfers it made. Every field is public on the ledger.
final class EscrowSettlement {
  const EscrowSettlement({
    required this.network,
    required this.txHash,
    required this.ledger,
    required this.closedAt,
    required this.escrowContract,
    required this.jobId,
    required this.asset,
    required this.transfers,
  });

  /// Reads a settlement from Horizon's `/transactions/{hash}` ([tx]) and
  /// `/transactions/{hash}/operations` ([operations]) responses.
  ///
  /// Throws [NotASettlement] unless the transaction succeeded and holds one
  /// `complete` call on a contract that moved one asset out of itself.
  factory EscrowSettlement.fromHorizon({
    required String network,
    required Map<String, Object?> tx,
    required Map<String, Object?> operations,
  }) {
    if (tx['successful'] != true) {
      throw const NotASettlement('the transaction did not succeed');
    }
    final records =
        ((operations['_embedded'] as Map?)?['records'] as List?) ?? const [];
    final invokes = records
        .cast<Map<String, Object?>>()
        .where((op) => op['type'] == 'invoke_host_function')
        .toList();
    if (invokes.length != 1) {
      throw NotASettlement(
        'expected one contract call, found ${invokes.length}',
      );
    }
    final op = invokes.single;
    final params = [
      for (final p in (op['parameters'] as List? ?? const []))
        decodeScVal(base64.decode((p as Map)['value'] as String)),
    ];
    if (params.length < 2 || params[0] is! String || params[1] != 'complete') {
      throw const NotASettlement('the call is not an escrow `complete`');
    }
    final contract = params[0] as String;
    if (!contract.startsWith('C')) {
      throw const NotASettlement('the call target is not a contract');
    }
    // complete(caller, job_id, reason): the job id is the first U64 argument.
    final jobId = params.skip(2).whereType<BigInt>().firstOrNull;
    if (jobId == null) {
      throw const NotASettlement('the `complete` call has no job id');
    }

    final changes = (op['asset_balance_changes'] as List? ?? const [])
        .cast<Map<String, Object?>>()
        .where((c) => c['type'] == 'transfer' && c['from'] == contract)
        .toList();
    if (changes.isEmpty) {
      throw const NotASettlement('the escrow paid nothing out');
    }
    final assets = {for (final c in changes) _asset(c)};
    if (assets.length != 1) {
      throw const NotASettlement('the escrow paid out more than one asset');
    }

    return EscrowSettlement(
      network: network,
      txHash: tx['hash'] as String,
      ledger: tx['ledger'] as int,
      closedAt: tx['created_at'] as String,
      escrowContract: contract,
      jobId: jobId.toString(),
      asset: assets.single,
      transfers: [
        for (final c in changes)
          Transfer(to: c['to'] as String, amount: c['amount'] as String),
      ],
    );
  }

  /// `stellar:testnet` or `stellar:pubnet`.
  final String network;
  final String txHash;
  final int ledger;

  /// When the ledger closed (ISO 8601, from Horizon).
  final String closedAt;
  final String escrowContract;

  /// The escrow job id, as a decimal string (it is a u64 on chain).
  final String jobId;

  /// `CODE:ISSUER`, or `native`.
  final String asset;

  /// The escrow's payouts in this transaction: the agent, then any fee.
  final List<Transfer> transfers;

  static String _asset(Map<String, Object?> change) =>
      change['asset_type'] == 'native'
      ? 'native'
      : '${change['asset_code']}:${change['asset_issuer']}';
}
