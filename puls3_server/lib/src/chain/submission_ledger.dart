import '../ledger/escrow_events.dart';
import '../ledger/ledger_errors.dart';
import '../ledger/soroban_rpc_client.dart';

/// The `status` of a `getTransaction` answer.
enum TransactionStatus {
  /// Included and succeeded; final.
  success,

  /// Included and failed; final.
  failed,

  /// Not known to the node: not yet included, never sent, or older than
  /// its retention window.
  notFound,
}

/// What the chain says about one transaction hash.
final class TransactionLookup {
  const TransactionLookup({
    required this.status,
    this.latestLedgerCloseTime,
    this.jobCreated,
    this.jobFunded,
  });

  final TransactionStatus status;

  /// Close time of the latest ledger the node knows: the chain's "now",
  /// which the envelope time bounds are checked against. `null` when the
  /// node did not report it.
  final DateTime? latestLedgerCloseTime;

  /// The configured escrow's `job_created` event, on [TransactionStatus.success].
  final JobCreatedEvent? jobCreated;

  /// The configured escrow's `job_funded` event, on [TransactionStatus.success].
  final JobFundedEvent? jobFunded;
}

/// The chain as the submission tracker needs it.
abstract interface class SubmissionLedger {
  /// Looks up the transaction [hash] (64-character hex).
  ///
  /// Throws a [LedgerException] when the chain cannot answer; an unknown
  /// hash is [TransactionStatus.notFound], never an exception.
  Future<TransactionLookup> lookup(String hash);

  /// Sends a persisted, signed [envelopeXdr] again, unchanged.
  ///
  /// Throws [RpcRequestRejected] when the node refuses the envelope itself
  /// and [LedgerUnavailable] when the outcome is unknown.
  Future<SendTransactionResult> resend(String envelopeXdr);
}
