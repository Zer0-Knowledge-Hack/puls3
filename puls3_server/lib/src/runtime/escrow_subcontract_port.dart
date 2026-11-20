import 'dart:math';

import 'package:puls3_domain/puls3_domain.dart' show HireStatus, StellarAddress;

import '../agent/agent_wallet_custody.dart';
import '../chain/chain_log.dart';
import '../chain/chain_submission_store.dart';
import '../chain/escrow_deadline.dart';
import '../chain/submission_values.dart';
import '../generated/protocol.dart' show Puls3ApiException;
import '../hire/escrow_relay_service.dart';
import '../hire/hire_lifecycle_store.dart';
import '../hire/hire_receipt_store.dart';
import '../hire/hire_relay_config.dart';
import '../ledger/envelope_codec.dart';
import '../ledger/escrow_job.dart';
import '../ledger/ledger_errors.dart';
import '../ledger/soroban_rpc_client.dart';
import 'subcontract_port.dart';

/// The escrow's `CHILD_EXPIRY_MARGIN`: a child expires at least this many
/// seconds before the parent's last moment to `submit` (ADR-0011 D3).
const childExpiryMarginSeconds = 600;

/// The time a child needs between opening and its own `submit`: the tracker
/// confirming `create_child_job` and the payment, the run queue, and the
/// child's run, at most 8 loop turns (`defaultMaxLoopTurns`) of the default
/// 120 s runtime timeout (16 min). A child whose expiry leaves less than one
/// approval window plus this headroom is refused with `parent_too_short`.
const childRunHeadroom = Duration(minutes: 30);

/// What the server knows about a child agent before opening its job: the
/// registry wallet the escrow pays, the published manifest version and the
/// current price.
final class ChildAgent {
  const ChildAgent({
    required this.wallet,
    required this.manifestVersion,
    required this.priceStroops,
  });

  final StellarAddress wallet;
  final int manifestVersion;
  final int priceStroops;
}

/// The hireable, deliverable child agent with [registryId], or `null` when it
/// cannot be hired. Production composes it from the same live registry,
/// custody and manifest checks as `HireService.createHire`. A chain read
/// failure is a [LedgerException].
typedef ChildAgentLookup = Future<ChildAgent?> Function(int registryId);

/// [SubcontractPort] on the escrow (ADR-0011 D2, D3, D5, D6): agent A's
/// custodied wallet signs a `create_child_job` that draws the child budget
/// from the parent's reserve, and A is the child's evaluator.
///
/// Every check that can refuse runs before anything is stored, signed or
/// sent, and every refusal is a [SubcontractRefused]. The child hire, its
/// receipt line and the signed `submitted` record are stored in one
/// transaction, then the envelope is sent; the tracker binds the child job
/// once it confirms (T6.2).
///
/// Idempotent per tool call: the child hire's request id is
/// `child:<parentHireId>:<toolCallId>`, and a retry finds it among the
/// parent's receipt lines before any parent check or chain read, so it
/// returns the stored child and reads, signs and sends nothing again.
final class EscrowSubcontractPort implements SubcontractPort {
  EscrowSubcontractPort({
    required HireLifecycleStore hires,
    required HireReceiptStore receipts,
    required ChainSubmissionStore submissions,
    required EscrowJobReader jobs,
    required EscrowRelayService relay,
    required HireRelayConfig config,
    required ChildAgentLookup childAgent,
    required EscrowApprovalWindow approvalWindow,
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
    Duration runHeadroom = childRunHeadroom,
    DateTime Function()? now,
    ChainLog log = ignoreChainLog,
  }) : _hires = hires,
       _receipts = receipts,
       _submissions = submissions,
       _jobs = jobs,
       _relay = relay,
       _config = config,
       _childAgent = childAgent,
       _approvalWindow = approvalWindow,
       _sign = sign,
       _send = send,
       _runHeadroom = runHeadroom,
       _now = now ?? DateTime.now,
       _log = log;

  final HireLifecycleStore _hires;
  final HireReceiptStore _receipts;
  final ChainSubmissionStore _submissions;
  final EscrowJobReader _jobs;
  final EscrowRelayService _relay;
  final HireRelayConfig _config;
  final ChildAgentLookup _childAgent;
  final EscrowApprovalWindow _approvalWindow;
  final Future<String> Function(PreparedEnvelope, StellarAddress) _sign;
  final Future<SendTransactionResult> Function(String, String) _send;
  final Duration _runHeadroom;
  final DateTime Function() _now;
  final ChainLog _log;

  /// The child hire's request id for one `subcontract` call.
  static String requestIdOf(int parentHireId, String toolCallId) =>
      'child:$parentHireId:$toolCallId';

  @override
  Future<int> requestChild(ChildRequest request) async {
    final callId = request.toolCallId;
    if (callId == null || callId.isEmpty) {
      throw ArgumentError.value(
        request.toolCallId,
        'request.toolCallId',
        'a child request needs its tool call id',
      );
    }
    // A retry of a call that already stored its child answers from the
    // database alone, before any parent check or chain read: a parent that
    // since left `funded`, or a chain that cannot be read, must not make the
    // model subcontract again under a new call.
    final requestId = requestIdOf(request.parentHireId, callId);
    final stored = await _storedChild(request.parentHireId, requestId);
    if (stored != null) return _reuse(stored);

    final nowSeconds = _now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final parent = await _hires.findHire(request.parentHireId);
    final jobId = parent?.jobId;
    if (parent == null || jobId == null || parent.status != HireStatus.funded) {
      throw const SubcontractRefused('parent_not_funded');
    }
    final job = await _chain(() => _jobs.escrowJob(jobId));
    if (job == null ||
        job.state != EscrowJobState.funded ||
        nowSeconds >= job.expiredAt) {
      throw const SubcontractRefused('parent_not_funded');
    }

    final approvalWindow = await _chain(_approvalWindow);
    final childExpiry = min(
      nowSeconds + _config.jobDurationSeconds,
      job.expiredAt - approvalWindow - childExpiryMarginSeconds,
    );
    if (childExpiry <= nowSeconds + approvalWindow + _runHeadroom.inSeconds) {
      throw const SubcontractRefused('parent_too_short');
    }

    final budget = request.priceStroops;
    final pending = [
      for (final line in await _receipts.listByParent(parent.id))
        if (line.state == ReceiptLineState.pending && line.childJobId == null)
          line.budget,
    ].fold(0, (sum, b) => sum + b);
    if (budget <= 0 || BigInt.from(budget + pending) > job.reserve) {
      throw const SubcontractRefused('reserve_exceeded');
    }

    final agent = await _chain(() => _childAgent(request.agentRegistryId));
    if (agent == null) throw const SubcontractRefused('agent_unavailable');
    if (agent.priceStroops != budget) {
      throw const SubcontractRefused('price_changed');
    }

    final PreparationDraft draft;
    try {
      draft = await _relay.draftCreateChildJob(
        parentProvider: job.provider,
        parentJobId: jobId,
        provider: agent.wallet,
        evaluator: job.provider,
        expiredAt: childExpiry,
        agentId: request.agentRegistryId,
        budget: budget,
      );
    } on SubcontractRejected catch (e) {
      throw SubcontractRefused(_codeOf(e.error));
    } on LedgerContractError catch (e) {
      _log(
        ChainLogLevel.warning,
        'create_child_job for hire ${parent.id} was rejected with contract '
        'error #${e.code}',
      );
      throw const SubcontractRefused('chain_refused');
    } on LedgerException {
      throw const SubcontractRefused('chain_unavailable');
    } on Puls3ApiException catch (e) {
      // ChainUnavailable or InternalError from the draft: nothing is stored.
      _log(
        ChainLogLevel.warning,
        'Could not prepare create_child_job for hire ${parent.id}: ${e.code}',
      );
      throw const SubcontractRefused('chain_unavailable');
    }

    final String signed;
    try {
      signed = await _sign(draft.envelope, job.provider);
    } on AgentWalletCustodyUnavailable catch (e) {
      _log(
        ChainLogLevel.warning,
        'Could not sign create_child_job for hire ${parent.id}: $e',
      );
      throw const SubcontractRefused('custody_unavailable');
    }

    final hash = draft.envelope.hashHex;
    final (HireRow child, StoredSubmission record) opened;
    try {
      opened = await _receipts.inTransaction((transaction) async {
        final child = await _hires.insertHire(
          NewHire(
            consumer: job.provider.value,
            agentId: request.agentRegistryId,
            price: budget,
            manifestVersion: agent.manifestVersion,
            expiredAt: childExpiry,
            requestId: requestId,
            input: request.task,
            parentHireId: parent.id,
          ),
          transaction: transaction,
        );
        await _receipts.insert(
          NewReceiptLine(
            parentHireId: parent.id,
            childHireId: child.id,
            providerAgentId: request.agentRegistryId,
            providerWallet: agent.wallet.value,
            budget: budget,
            relatedParty: request.isRelatedParty,
            justification: request.justification,
            createTransaction: hash,
          ),
          transaction: transaction,
        );
        final record = await _submissions.insertSubmitted(
          purpose: SubmissionPurpose.createChildJob,
          transactionHash: hash,
          signedEnvelopeXdr: signed,
          validUntil: draft.validUntil,
          hireId: child.id,
          transaction: transaction,
        );
        return (child, record);
      });
    } on HireRequestConflict {
      // A concurrent retry of the same call stored the child first.
      final won = await _storedChild(parent.id, requestId);
      if (won == null) rethrow;
      return _reuse(won);
    } on ChainSubmissionConflict {
      // The same envelope is already stored: another child drafted on the
      // same sequence with the same arguments. Everything rolled back.
      throw const SubcontractRefused('chain_busy');
    }
    final (child, record) = opened;
    await _deliver(child.id, record);
    return child.id;
  }

  /// The child an earlier attempt of the same call stored under
  /// [parentHireId], with its receipt line, or `null`. It reads only the
  /// database: the line and its child hire are stored in one transaction,
  /// and the child's request id names the parent and the tool call.
  Future<(int, ReceiptLine)?> _storedChild(
    int parentHireId,
    String requestId,
  ) async {
    for (final line in await _receipts.listByParent(parentHireId)) {
      final childHireId = line.childHireId;
      if (childHireId == null) continue;
      final child = await _hires.findHire(childHireId);
      if (child?.requestId == requestId) return (childHireId, line);
    }
    return null;
  }

  /// The child an earlier attempt of the same call stored. A child whose
  /// `create_child_job` definitely failed is not reopened: the model gets a
  /// refusal and may subcontract again with a new call.
  static int _reuse((int, ReceiptLine) stored) {
    final (childHireId, line) = stored;
    if (line.state == ReceiptLineState.notOpened) {
      throw const SubcontractRefused('child_not_opened');
    }
    return childHireId;
  }

  /// Sends the stored envelope, as `AgentSubmitSender` does. A node that
  /// cannot be reached leaves the record `submitted`, so the tracker sends
  /// the same envelope again; a node refusal closes the child.
  Future<void> _deliver(int childHireId, StoredSubmission record) async {
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
            'The node refused create_child_job ${record.id}: '
            '${result.errorResultXdr}',
          );
          await _notOpened(childHireId, record);
      }
    } on RpcRequestRejected catch (e) {
      _log(
        ChainLogLevel.warning,
        'The node rejected create_child_job ${record.id}: $e',
      );
      await _notOpened(childHireId, record);
    } on LedgerException catch (e) {
      _log(
        ChainLogLevel.warning,
        'Sending create_child_job ${record.id} failed: $e; it stays submitted',
      );
    }
  }

  Future<Never> _notOpened(int childHireId, StoredSubmission record) async {
    await _submissions.markFailed(
      record.id,
      SubmissionOutcomeCode.submissionRejected,
    );
    await _receipts.markNotOpened(childHireId);
    throw const SubcontractRefused('chain_refused');
  }

  /// Runs a chain read; a failure to read refuses the child, which nothing
  /// has stored yet.
  static Future<T> _chain<T>(Future<T> Function() read) async {
    try {
      return await read();
    } on LedgerException {
      throw const SubcontractRefused('chain_unavailable');
    } on FormatException {
      throw const SubcontractRefused('chain_unavailable');
    }
  }

  static String _codeOf(EscrowSubcontractError error) => switch (error) {
    EscrowSubcontractError.reserveExceeded => 'reserve_exceeded',
    EscrowSubcontractError.childrenOpen => 'children_open',
    EscrowSubcontractError.depthExceeded => 'depth_exceeded',
    EscrowSubcontractError.subcontractCycle => 'subcontract_cycle',
  };
}
