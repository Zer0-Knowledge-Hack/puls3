import 'package:puls3_domain/puls3_domain.dart' show StellarAddress;

import '../agent/agent_wallet_custody.dart';
import '../chain/agent_submit_sender.dart' show deliverableHashHex;
import '../chain/chain_log.dart';
import '../chain/chain_submission_store.dart';
import '../chain/escrow_deadline.dart';
import '../chain/submission_values.dart';
import '../generated/protocol.dart' show Puls3ApiException;
import '../hire/chain_accounts.dart';
import '../hire/hire_lifecycle_store.dart';
import '../hire/hire_receipt_store.dart';
import '../ledger/envelope_codec.dart';
import '../ledger/ledger_errors.dart';
import '../ledger/soroban_rpc_client.dart';
import '../ledger/xdr_invoke_encoder.dart' show ScArg;
import 'child_verdict.dart';
import 'hire_run_store.dart';
import 'subcontract_setup.dart';
import 'tool_loop.dart';

/// [ChildResultSource] on the child hire's receipt line, run and escrow
/// submissions (ADR-0011 D3, D8). The parent agent A evaluates its child B
/// with the server rule of [judgeChildOutput], and A's custodied wallet
/// signs the verdict as the child's evaluator.
///
/// [resultOf] answers, in order:
///
/// - line `not_opened` (or no line): `ChildFailed('child_not_opened')`;
/// - line `pending` or `unverified`: `null`. An unverified child may have
///   landed; reconciling it against the chain is T6.4, until then the
///   parent keeps waiting;
/// - a confirmed `childComplete`, or a `release` by the deadline relay:
///   `ChildDelivered` with B's stored run result, which A's loop delimits as
///   untrusted data;
/// - a confirmed `childReject`: `ChildFailed` with its reason code;
/// - a confirmed `claim_refund`: `ChildFailed('child_expired')`;
/// - any record of the child still `submitted` (B's `submit`, a verdict,
///   a relay call): `null`;
/// - otherwise the verdict is due once the facts are final: B's `submit`
///   confirmed (complete or reject by the rule, from `Submitted`), B's run
///   failed (reject from `Funded`, `child_run_failed`), or B's run succeeded
///   but its `submit` can never land (reject from `Funded`,
///   `child_not_submitted`). It is signed, stored and sent, and `null` is
///   returned until the tracker confirms it. While B still works, `null`.
///
/// Idempotent: a verdict is only built when the child has no non-final
/// record, so one envelope is in flight per child. A failed verdict is
/// built again on a later pass, up to [maxEscrowCallAttempts]; then the
/// parent waits for the deadline relay to `release` or `claim_refund` the
/// child. Like `AgentSubmitSender`, nothing is built while any agent-signed
/// call ([agentSignedPurposes]) is in flight, so A's sequence is not reused.
///
/// A complete verdict also stores B's deliverable hash on the line, in the
/// same transaction as the verdict record; the tracker fills the rest of the
/// settlement on confirmation (`ChildJobEffects.onChildSettled`).
final class EscrowChildResultSource implements ChildResultSource {
  EscrowChildResultSource({
    required HireReceiptStore receipts,
    required HireLifecycleStore hires,
    required HireRunStore runs,
    required ChainSubmissionStore submissions,
    required ChainAccounts accounts,
    required EnvelopeCodec codec,
    required Future<String> Function(
      PreparedEnvelope prepared,
      StellarAddress signer,
    )
    sign,
    required Future<SendTransactionResult> Function(
      String envelopeXdr,
      String expectedHash,
    )
    send,
    required this.escrow,
    required this.inclusionFee,
    required this.validitySeconds,
    this.maxOutputChars = defaultChildOutputMaxChars,
    DateTime Function()? now,
    ChainLog log = ignoreChainLog,
  }) : _receipts = receipts,
       _hires = hires,
       _runs = runs,
       _submissions = submissions,
       _accounts = accounts,
       _codec = codec,
       _sign = sign,
       _send = send,
       _now = now ?? DateTime.now,
       _log = log;

  final HireReceiptStore _receipts;
  final HireLifecycleStore _hires;
  final HireRunStore _runs;
  final ChainSubmissionStore _submissions;
  final ChainAccounts _accounts;
  final EnvelopeCodec _codec;
  final Future<String> Function(PreparedEnvelope, StellarAddress) _sign;
  final Future<SendTransactionResult> Function(String, String) _send;
  final DateTime Function() _now;
  final ChainLog _log;

  final StellarAddress escrow;
  final int inclusionFee;
  final int validitySeconds;

  /// See [judgeChildOutput].
  final int maxOutputChars;

  @override
  Future<ChildToolResult?> resultOf(int childHireId) async {
    final line = await _receipts.findByChildHire(childHireId);
    if (line == null || line.state == ReceiptLineState.notOpened) {
      return const ChildFailed(ChildVerdictCode.notOpened);
    }
    if (line.state == ReceiptLineState.pending ||
        line.state == ReceiptLineState.unverified) {
      return null;
    }
    final child = await _hires.findHire(childHireId);
    final jobId = child?.jobId;
    if (child == null || jobId == null) return null;

    final rows = await _submissions.listByHire(childHireId);
    final run = await _runs.find(childHireId);
    final output = run?.state == HireRunState.succeeded ? run?.result : null;
    bool confirmed(SubmissionPurpose purpose) => rows.any(
      (row) => row.purpose == purpose && row.state == SubmissionState.confirmed,
    );

    if (confirmed(SubmissionPurpose.childComplete) ||
        confirmed(SubmissionPurpose.release)) {
      return output == null
          ? const ChildFailed(ChildVerdictCode.runFailed)
          : ChildDelivered(output);
    }
    if (confirmed(SubmissionPurpose.childReject)) {
      return ChildFailed(
        _decide(rows, run, output)?.code ?? ChildVerdictCode.runFailed,
      );
    }
    if (confirmed(SubmissionPurpose.claimRefund)) {
      return const ChildFailed(ChildVerdictCode.expired);
    }
    if (rows.any((row) => !row.state.isFinal)) return null;

    final failed = rows
        .where(
          (row) =>
              (row.purpose == SubmissionPurpose.childComplete ||
                  row.purpose == SubmissionPurpose.childReject) &&
              row.state == SubmissionState.failed,
        )
        .length;
    if (failed >= maxEscrowCallAttempts) return null;
    final verdict = _decide(rows, run, output);
    if (verdict == null) return null;
    await _deliver(
      childHireId,
      evaluator: StellarAddress.parse(child.consumer),
      jobId: jobId,
      verdict: verdict,
      priorFailures: failed,
      deliverable: confirmed(SubmissionPurpose.submit) && output != null
          ? deliverableHashHex(output)
          : null,
    );
    return null;
  }

  /// The verdict the final facts call for, or `null` while B still works.
  /// Every input it reads is final once it answers, so a confirmed reject
  /// recomputes the same code.
  ChildVerdict? _decide(
    List<StoredSubmission> rows,
    HireRun? run,
    String? output,
  ) {
    final submits = [
      for (final row in rows)
        if (row.purpose == SubmissionPurpose.submit) row,
    ];
    if (submits.any((row) => row.state == SubmissionState.confirmed)) {
      return judgeChildOutput(output, maxOutputChars: maxOutputChars);
    }
    if (run?.state == HireRunState.failed) {
      return const ChildVerdict.reject(ChildVerdictCode.runFailed);
    }
    final failed = submits.where((row) => row.state == SubmissionState.failed);
    final submitClosed =
        failed.any(
          (row) =>
              row.errorCode == SubmissionOutcomeCode.submitSimulationRejected,
        ) ||
        failed.length >= maxEscrowCallAttempts;
    if (run?.state == HireRunState.succeeded && submitClosed) {
      return const ChildVerdict.reject(ChildVerdictCode.notSubmitted);
    }
    return null;
  }

  /// Builds, signs with [evaluator]'s custodied key, stores and sends one
  /// verdict, as `AgentSubmitSender` does for a `submit`.
  Future<void> _deliver(
    int childHireId, {
    required StellarAddress evaluator,
    required int jobId,
    required ChildVerdict verdict,
    required int priorFailures,
    required String? deliverable,
  }) async {
    if (await _submissions.hasSubmitted(agentSignedPurposes)) return;
    final purpose = verdict.purpose;
    final until = _now().toUtc().add(Duration(seconds: validitySeconds));
    final PreparedEnvelope prepared;
    try {
      final spec = EnvelopeSpec(
        source: evaluator,
        accountSequence: await _accounts.sequenceOf(evaluator),
        contract: escrow,
        function: purpose.contractFunction,
        args: [
          ScArg.address(evaluator),
          ScArg.u64(jobId),
          ScArg.bytes32(verdict.reasonHash),
        ],
        inclusionFee: inclusionFee,
        validUntil: until.millisecondsSinceEpoch ~/ 1000,
      );
      prepared = _codec.build(spec, await _accounts.simulateRaw(spec));
    } on LedgerContractError catch (e) {
      _log(
        ChainLogLevel.warning,
        '${purpose.contractFunction} of child hire $childHireId was rejected '
        'with contract error #${e.code}',
      );
      await _recordSimulationFailure(childHireId, purpose, priorFailures);
      return;
    } on LedgerSimulationError catch (e) {
      _log(
        ChainLogLevel.warning,
        '${purpose.contractFunction} of child hire $childHireId failed: $e',
      );
      await _recordSimulationFailure(childHireId, purpose, priorFailures);
      return;
    } on LedgerException catch (e) {
      _log(
        ChainLogLevel.warning,
        'Could not prepare the verdict of child hire $childHireId: $e',
      );
      return;
    } on Puls3ApiException catch (e) {
      _log(
        ChainLogLevel.warning,
        'Could not prepare the verdict of child hire $childHireId: ${e.code}',
      );
      return;
    } on UnsupportedAuthorization {
      _log(
        ChainLogLevel.warning,
        'Could not prepare the verdict of child hire $childHireId: the '
        'simulation asked for authorization',
      );
      return;
    }

    final String signed;
    try {
      signed = await _sign(prepared, evaluator);
    } on AgentWalletCustodyUnavailable catch (e) {
      _log(
        ChainLogLevel.warning,
        'Could not sign the verdict of child hire $childHireId: $e',
      );
      return;
    }

    final StoredSubmission record;
    try {
      record = await _receipts.inTransaction((transaction) async {
        final record = await _submissions.insertSubmitted(
          purpose: purpose,
          transactionHash: prepared.hashHex,
          signedEnvelopeXdr: signed,
          validUntil: until,
          hireId: childHireId,
          transaction: transaction,
        );
        if (deliverable != null) {
          await _receipts.recordDeliverable(
            childHireId,
            deliverable,
            transaction: transaction,
          );
        }
        return record;
      });
    } on ChainSubmissionConflict {
      _log(
        ChainLogLevel.warning,
        'Child hire $childHireId already has a submission for '
        '${prepared.hashHex}',
      );
      return;
    }

    final rejected = escrowCallFailureCode(
      priorFailures: priorFailures,
      code: SubmissionOutcomeCode.submissionRejected,
    );
    try {
      final result = await _send(
        record.signedEnvelopeXdr,
        record.transactionHash,
      );
      switch (result.status) {
        case SendTransactionStatus.pending || SendTransactionStatus.duplicate:
          await _submissions.recordSend(record.id, _now().toUtc());
        case SendTransactionStatus.tryAgainLater:
          break;
        case SendTransactionStatus.error:
          _log(
            ChainLogLevel.warning,
            'The node refused verdict ${record.id}: ${result.errorResultXdr}',
          );
          await _submissions.markFailed(record.id, rejected);
      }
    } on RpcRequestRejected catch (e) {
      _log(ChainLogLevel.warning, 'The node rejected verdict ${record.id}: $e');
      await _submissions.markFailed(record.id, rejected);
    } on LedgerException catch (e) {
      _log(
        ChainLogLevel.warning,
        'Sending verdict ${record.id} failed: $e; it stays submitted',
      );
    }
  }

  /// Stores a failed verdict for a simulation rejection: no envelope exists,
  /// and it counts toward [maxEscrowCallAttempts].
  Future<void> _recordSimulationFailure(
    int childHireId,
    SubmissionPurpose purpose,
    int priorFailures,
  ) async {
    await _submissions.insertFailed(
      purpose: purpose,
      errorCode: escrowCallFailureCode(
        priorFailures: priorFailures,
        code: SubmissionOutcomeCode.simulationFailed,
      ),
      hireId: childHireId,
    );
  }
}
