import 'package:puls3_domain/puls3_domain.dart' show StellarAddress;

import '../ledger/contract_reader.dart';
import '../ledger/escrow_job.dart';
import '../ledger/sc_val_json.dart';
import 'submission_values.dart';

/// The escrow's `approval_window` in seconds: how long a consumer has to
/// approve a submitted job before `release` (ADR-0005). The contract owns the
/// value and `set_approval_window` can change it, so the server reads it
/// instead of configuring a copy.
typedef EscrowApprovalWindow = Future<int> Function();

/// [EscrowApprovalWindow] read from the escrow at [escrow] with one
/// `approval_window` simulation. Throws a `LedgerException` when the read
/// fails, and [FormatException] for a value that is not a `u64`.
EscrowApprovalWindow contractApprovalWindow(
  ContractReader reader, {
  required StellarAddress escrow,
}) =>
    () async => readU64(await reader.read(escrow, 'approval_window', const []));

/// How many failed envelopes of one server call a hire may accumulate
/// before the deadline pass stops building another.
const maxEscrowCallAttempts = 3;

/// The code to store when a `release` or `claim_refund` envelope fails with
/// [code].
///
/// [priorFailures] counts the failed envelopes of the same hire and call
/// before this one. The failure that uses the last of
/// [maxEscrowCallAttempts] is `EscrowCallFailed` (api.md); earlier ones keep
/// [code].
String escrowCallFailureCode({
  required int priorFailures,
  required String code,
}) => priorFailures + 1 >= maxEscrowCallAttempts
    ? SubmissionOutcomeCode.escrowCallFailed
    : code;

/// A permissionless escrow call the tracker may submit.
///
/// The contract accepts `release` only for a `Submitted` job at or after
/// `approval_deadline`, and `claim_refund` only for a `Funded` job that
/// `is_expired` reports as expired.
enum EscrowServerCall { release, claimRefund }

/// The call [job] allows at [ledgerTime], or null when neither deadline
/// has been reached.
///
/// [ledgerTime] is the escrow ledger's unix time, the clock `release`
/// compares with `approval_deadline`. [isExpired] is the contract's
/// `is_expired` view, the clock `claim_refund` uses. The server clock is
/// not consulted.
EscrowServerCall? dueEscrowServerCall({
  required EscrowJob job,
  required bool isExpired,
  required int ledgerTime,
}) {
  if (job.state == EscrowJobState.submitted &&
      ledgerTime >= job.approvalDeadline) {
    return EscrowServerCall.release;
  }
  if (job.state == EscrowJobState.funded && isExpired) {
    return EscrowServerCall.claimRefund;
  }
  return null;
}

/// One hire the sweep may submit a server call for.
final class DueEscrowHire {
  const DueEscrowHire({required this.hireId, required this.jobId});

  final int hireId;
  final int jobId;
}

/// Sends one permissionless escrow call. Reading a hire must not call this.
abstract interface class EscrowServerCallSender {
  Future<void> send({
    required int hireId,
    required int jobId,
    required EscrowServerCall call,
  });
}

/// Decides `release` and `claim_refund` from the escrow's own state.
///
/// It reads `get_job` and `is_expired`, then asks [sender] only for a call
/// the contract would accept. A missing job is skipped. Hire reads do not
/// use this type.
final class EscrowDeadlineSweep {
  EscrowDeadlineSweep({
    required EscrowJobReader jobs,
    required EscrowExpiryReader expiry,
    required EscrowServerCallSender sender,
    required this.ledgerTime,
  }) : _jobs = jobs,
       _expiry = expiry,
       _sender = sender;

  final EscrowJobReader _jobs;
  final EscrowExpiryReader _expiry;
  final EscrowServerCallSender _sender;

  /// Unix seconds of the escrow ledger.
  final int ledgerTime;

  /// How many calls [sender] was asked to send.
  Future<int> pass(List<DueEscrowHire> hires) async {
    var sent = 0;
    for (final hire in hires) {
      final job = await _jobs.escrowJob(hire.jobId);
      if (job == null) continue;
      // Only a funded job can be refunded: skip the second read otherwise.
      final expired =
          job.state == EscrowJobState.funded &&
          await _expiry.isExpired(hire.jobId);
      final call = dueEscrowServerCall(
        job: job,
        isExpired: expired,
        ledgerTime: ledgerTime,
      );
      if (call == null) continue;
      await _sender.send(hireId: hire.hireId, jobId: hire.jobId, call: call);
      sent++;
    }
    return sent;
  }
}
