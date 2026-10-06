import 'package:puls3_domain/puls3_domain.dart';

import '../chain/submission_ledger.dart';
import 'escrow_events.dart';
import 'ledger_errors.dart';
import 'soroban_rpc_client.dart';

const _statuses = {
  'SUCCESS': TransactionStatus.success,
  'FAILED': TransactionStatus.failed,
  'NOT_FOUND': TransactionStatus.notFound,
};

/// [SubmissionLedger] over Soroban RPC `getTransaction` and
/// `sendTransaction`. Escrow events count only when [escrow] emitted them.
final class SorobanSubmissionLedger implements SubmissionLedger {
  SorobanSubmissionLedger(this._rpc, {required StellarAddress escrow})
    : _escrow = escrow;

  final SorobanRpcClient _rpc;
  final StellarAddress _escrow;

  @override
  Future<TransactionLookup> lookup(String hash) async {
    final tx = await _rpc.getTransaction(hash);
    final status = _statuses[tx['status']];
    if (status == null) {
      throw LedgerUnavailable('getTransaction answered no known status');
    }
    return TransactionLookup(
      status: status,
      latestLedgerCloseTime: _unixSeconds(tx['latestLedgerCloseTime']),
      jobCreated: firstJobCreated(tx, escrow: _escrow),
      jobFunded: firstJobFunded(tx, escrow: _escrow),
    );
  }

  @override
  Future<SendTransactionResult> resend(String envelopeXdr) =>
      _rpc.sendTransaction(envelopeXdr);
}

/// Unix seconds sent as a numeric string or a number, as UTC.
DateTime? _unixSeconds(Object? value) {
  final seconds = switch (value) {
    int() => value,
    String() => int.tryParse(value),
    _ => null,
  };
  return seconds == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
}
