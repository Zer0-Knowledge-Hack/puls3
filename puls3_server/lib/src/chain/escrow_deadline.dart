import '../ledger/escrow_job.dart';

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
