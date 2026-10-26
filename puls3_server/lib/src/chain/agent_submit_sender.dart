import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:puls3_domain/puls3_domain.dart';

import '../agent/agent_wallet_custody.dart';
import '../generated/protocol.dart' show Puls3ApiException;
import '../hire/chain_accounts.dart';
import '../ledger/envelope_codec.dart';
import '../ledger/ledger_errors.dart';
import '../ledger/soroban_rpc_client.dart';
import '../ledger/xdr_invoke_encoder.dart' show ScArg;
import 'chain_log.dart';
import 'chain_submission_store.dart';
import 'escrow_deadline.dart';
import 'submission_values.dart';

/// SHA-256 of the UTF-8 run output, the 32-byte escrow `deliverable`.
Uint8List deliverableHash(String output) =>
    Uint8List.fromList(sha256.convert(utf8.encode(output)).bytes);

/// Succeeded funded hires whose agent run is stored and not yet submitted.
abstract interface class DueSubmitSource {
  /// Up to [limit] hires, oldest run first.
  Future<List<DueSubmit>> list({int limit = 10});
}

/// One succeeded run that still needs an on-chain `submit`.
final class DueSubmit {
  const DueSubmit({
    required this.hireId,
    required this.jobId,
    required this.provider,
    required this.result,
  });

  final int hireId;
  final int jobId;

  /// The job's provider: the custodied agent wallet that must sign.
  final StellarAddress provider;

  /// The stored run output; hashed as the deliverable.
  final String result;
}

/// Builds, signs with the agent's custodied key, persists and sends one
/// escrow `submit`.
///
/// One `submit` is in flight at a time, across hires: agent wallets can
/// have more than one funded job, and two envelopes built against the same
/// sequence would be `txBadSeq`. A hire with any non-final submission is
/// skipped too. After [maxEscrowCallAttempts] failed `submit`s the pass
/// stops building another.
///
/// The envelope is stored before it is sent. A node that cannot be reached
/// leaves the record `submitted` so the tracker can send the same envelope
/// again.
final class AgentSubmitSender {
  AgentSubmitSender({
    required ChainSubmissionStore submissions,
    required ChainAccounts accounts,
    required EnvelopeCodec codec,
    required Future<String> Function(
      PreparedEnvelope prepared,
      StellarAddress provider,
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
    required DateTime Function() now,
    required ChainLog log,
  }) : _submissions = submissions,
       _accounts = accounts,
       _codec = codec,
       _sign = sign,
       _send = send,
       _now = now,
       _log = log;

  final ChainSubmissionStore _submissions;
  final ChainAccounts _accounts;
  final EnvelopeCodec _codec;
  final Future<String> Function(
    PreparedEnvelope prepared,
    StellarAddress provider,
  )
  _sign;
  final Future<SendTransactionResult> Function(
    String envelopeXdr,
    String expectedHash,
  )
  _send;
  final DateTime Function() _now;
  final ChainLog _log;

  final StellarAddress escrow;
  final int inclusionFee;
  final int validitySeconds;

  /// Sends [due] unless a `submit` is already in flight, the hire has a
  /// non-final submission, a `submit` already confirmed, or attempts are
  /// exhausted.
  Future<void> send(DueSubmit due) async {
    const purpose = SubmissionPurpose.submit;
    if (await _submissions.hasSubmitted({purpose})) return;
    final existing = await _submissions.listByHire(due.hireId);
    if (existing.any((row) => !row.state.isFinal)) return;
    if (existing.any(
      (row) => row.purpose == purpose && row.state == SubmissionState.confirmed,
    )) {
      return;
    }
    final failed = existing
        .where(
          (row) =>
              row.purpose == purpose && row.state == SubmissionState.failed,
        )
        .length;
    if (failed >= maxEscrowCallAttempts) return;

    final until = _now().toUtc().add(Duration(seconds: validitySeconds));
    final PreparedEnvelope prepared;
    try {
      final sequence = await _accounts.sequenceOf(due.provider);
      final spec = EnvelopeSpec(
        source: due.provider,
        accountSequence: sequence,
        contract: escrow,
        function: 'submit',
        args: [
          ScArg.address(due.provider),
          ScArg.u64(due.jobId),
          ScArg.bytes32(deliverableHash(due.result)),
        ],
        inclusionFee: inclusionFee,
        validUntil: until.millisecondsSinceEpoch ~/ 1000,
      );
      prepared = _codec.build(spec, await _accounts.simulate(spec));
    } on LedgerException catch (e) {
      _log(
        ChainLogLevel.warning,
        'Could not prepare submit for hire ${due.hireId}: $e',
      );
      return;
    } on Puls3ApiException catch (e) {
      _log(
        ChainLogLevel.warning,
        'Could not prepare submit for hire ${due.hireId}: ${e.code}',
      );
      return;
    } on UnsupportedAuthorization {
      _log(
        ChainLogLevel.warning,
        'Could not prepare submit for hire ${due.hireId}: '
        'the simulation asked for authorization',
      );
      return;
    }

    final String signed;
    try {
      signed = await _sign(prepared, due.provider);
    } on AgentWalletCustodyUnavailable catch (e) {
      _log(
        ChainLogLevel.warning,
        'Could not sign submit for hire ${due.hireId}: $e',
      );
      return;
    }

    final StoredSubmission record;
    try {
      record = await _submissions.insertSubmitted(
        purpose: purpose,
        transactionHash: prepared.hashHex,
        signedEnvelopeXdr: signed,
        validUntil: until,
        hireId: due.hireId,
      );
    } on ChainSubmissionConflict {
      _log(
        ChainLogLevel.warning,
        'Hire ${due.hireId} already has a submission for ${prepared.hashHex}',
      );
      return;
    }

    final rejected = escrowCallFailureCode(
      priorFailures: failed,
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
            'The node refused submission ${record.id}: ${result.errorResultXdr}',
          );
          await _submissions.markFailed(record.id, rejected);
      }
    } on RpcRequestRejected catch (e) {
      _log(
        ChainLogLevel.warning,
        'The node rejected submission ${record.id}: $e',
      );
      await _submissions.markFailed(record.id, rejected);
    } on LedgerException catch (e) {
      _log(
        ChainLogLevel.warning,
        'Sending submission ${record.id} failed: $e; it stays submitted',
      );
    }
  }
}
