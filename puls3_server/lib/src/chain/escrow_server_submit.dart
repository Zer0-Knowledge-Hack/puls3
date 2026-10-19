import 'package:puls3_domain/puls3_domain.dart';
import 'package:stellar_dart/stellar_dart.dart' as stellar;

import '../generated/protocol.dart' show Puls3ApiException;
import '../hire/chain_accounts.dart';
import '../hire/hire_lifecycle_store.dart';
import '../ledger/envelope_codec.dart';
import '../ledger/escrow_job.dart';
import '../ledger/ledger_errors.dart';
import '../ledger/soroban_rpc_client.dart';
import '../ledger/stellar_envelope_codec.dart';
import '../ledger/xdr_invoke_encoder.dart' show ScArg;
import 'chain_log.dart';
import 'chain_submission_store.dart';
import 'escrow_deadline.dart';
import 'submission_values.dart';

/// The calls the relay account signs. Only one of them is in flight at a
/// time (see [RelayEscrowCallSender]).
const _relayPurposes = {
  SubmissionPurpose.release,
  SubmissionPurpose.claimRefund,
};

/// The relay account behind the Serverpod password `escrowRelaySigningKey`.
///
/// A missing or blank password means deadline submissions stay off. A value
/// that is not a Stellar secret throws [ArgumentError] and the message does
/// not contain the value. [toString] never includes the secret.
final class EscrowRelayAccount {
  const EscrowRelayAccount({required this.secret, required this.address});

  /// Stellar secret seed (`S…`). Never log this.
  final String secret;

  /// Public account (`G…`) of [secret]. It is the source of `release` and
  /// `claim_refund`.
  final StellarAddress address;

  @override
  String toString() => 'EscrowRelayAccount(${address.value})';
}

/// The relay account for [raw], or null when the password is missing.
EscrowRelayAccount? relaySigningAccount(String? raw) {
  final trimmed = raw?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  try {
    final key = stellar.StellarPrivateKey.fromBase32(trimmed);
    return EscrowRelayAccount(
      secret: key.toBase32(),
      address: StellarAddress.parse(key.toPublicKey().toAddress().address),
    );
  } on Object {
    throw ArgumentError('escrowRelaySigningKey must be a Stellar secret key');
  }
}

/// Builds, signs, persists and sends one permissionless escrow call.
///
/// Nothing is built while any relay call is still `submitted`, for any
/// hire: the relay account's sequence is read from the ledger, so a second
/// envelope built before the first is applied would reuse it and the node
/// would refuse it (`txBadSeq`), using up one of the hire's attempts. A
/// hire with a non-final submission is skipped too: one escrow submission
/// per hire is in flight at a time.
///
/// The envelope is stored before it is sent. A node that cannot be reached
/// leaves the record `submitted` so the tracker can send the same envelope
/// again.
final class RelayEscrowCallSender implements EscrowServerCallSender {
  RelayEscrowCallSender({
    required ChainSubmissionStore submissions,
    required ChainAccounts accounts,
    required EnvelopeCodec codec,
    required String Function(PreparedEnvelope prepared) sign,
    required Future<SendTransactionResult> Function(
      String envelopeXdr,
      String expectedHash,
    )
    send,
    required this.source,
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
  final String Function(PreparedEnvelope prepared) _sign;
  final Future<SendTransactionResult> Function(
    String envelopeXdr,
    String expectedHash,
  )
  _send;
  final DateTime Function() _now;
  final ChainLog _log;

  final StellarAddress source;
  final StellarAddress escrow;
  final int inclusionFee;
  final int validitySeconds;

  @override
  Future<void> send({
    required int hireId,
    required int jobId,
    required EscrowServerCall call,
  }) async {
    final purpose = _purpose(call);
    if (await _submissions.hasSubmitted(_relayPurposes)) return;
    final existing = await _submissions.listByHire(hireId);
    if (existing.any((row) => !row.state.isFinal)) return;
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
      final sequence = await _accounts.sequenceOf(source);
      final spec = EnvelopeSpec(
        source: source,
        accountSequence: sequence,
        contract: escrow,
        function: _function(call),
        args: [ScArg.u64(jobId)],
        inclusionFee: inclusionFee,
        validUntil: until.millisecondsSinceEpoch ~/ 1000,
      );
      prepared = _codec.build(spec, await _accounts.simulate(spec));
    } on LedgerException catch (e) {
      _log(
        ChainLogLevel.warning,
        'Could not prepare ${purpose.wireName} for hire $hireId: $e',
      );
      return;
    } on Puls3ApiException catch (e) {
      _log(
        ChainLogLevel.warning,
        'Could not prepare ${purpose.wireName} for hire $hireId: ${e.code}',
      );
      return;
    } on UnsupportedAuthorization {
      _log(
        ChainLogLevel.warning,
        'Could not prepare ${purpose.wireName} for hire $hireId: '
        'the simulation asked for authorization',
      );
      return;
    }

    final StoredSubmission record;
    try {
      record = await _submissions.insertSubmitted(
        purpose: purpose,
        transactionHash: prepared.hashHex,
        signedEnvelopeXdr: _sign(prepared),
        validUntil: until,
        hireId: hireId,
      );
    } on ChainSubmissionConflict {
      _log(
        ChainLogLevel.warning,
        'Hire $hireId already has a submission for ${prepared.hashHex}',
      );
      return;
    }

    // This envelope is the failed + 1th: the one that uses the last attempt
    // is labelled EscrowCallFailed.
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

/// How many hires one deadline pass reads from the escrow. Each one costs a
/// `get_job` simulation (and `is_expired` for a funded job), every tracker
/// interval.
const defaultDeadlineBatchLimit = 20;

/// One deadline pass: list a page of hires with a job, read the ledger
/// clock, and send the call the contract allows. A read of a hire does not
/// run this.
///
/// Each pass reads the hires after [afterId]; [pass] returns where the next
/// one starts, back to 0 after the last page, so every hire is swept.
final class EscrowDeadlineRunner {
  EscrowDeadlineRunner({
    required EscrowJobReader jobs,
    required EscrowExpiryReader expiry,
    required EscrowServerCallSender sender,
    required HireLifecycleStore hires,
    required Future<int> Function() ledgerTime,
    required ChainLog log,
    this.afterId = 0,
    this.limit = defaultDeadlineBatchLimit,
  }) : _jobs = jobs,
       _expiry = expiry,
       _sender = sender,
       _hires = hires,
       _ledgerTime = ledgerTime,
       _log = log;

  final EscrowJobReader _jobs;
  final EscrowExpiryReader _expiry;
  final EscrowServerCallSender _sender;
  final HireLifecycleStore _hires;
  final Future<int> Function() _ledgerTime;
  final ChainLog _log;
  final int afterId;
  final int limit;

  /// Sweeps one page and returns the `afterId` of the next pass.
  Future<int> pass() async {
    final int time;
    try {
      time = await _ledgerTime();
    } on LedgerException catch (e) {
      _log(ChainLogLevel.warning, 'Deadline pass skipped: $e');
      return afterId;
    }
    final rows = await _hires.listWithJob(afterId: afterId, limit: limit);
    final due = [
      for (final row in rows)
        if (row.jobId != null) DueEscrowHire(hireId: row.id, jobId: row.jobId!),
    ];
    final sent = await EscrowDeadlineSweep(
      jobs: _jobs,
      expiry: _expiry,
      sender: _sender,
      ledgerTime: time,
    ).pass(due);
    if (sent > 0) {
      _log(ChainLogLevel.info, 'Deadline pass found $sent due escrow call(s)');
    }
    return rows.length < limit ? 0 : rows.last.id;
  }
}

/// Signs [prepared] with the relay secret. The secret is not logged.
String signWithRelay(
  StellarEnvelopeCodec codec,
  PreparedEnvelope prepared,
  String secret,
) => codec.sign(prepared, stellar.StellarPrivateKey.fromBase32(secret));

SubmissionPurpose _purpose(EscrowServerCall call) => switch (call) {
  EscrowServerCall.release => SubmissionPurpose.release,
  EscrowServerCall.claimRefund => SubmissionPurpose.claimRefund,
};

String _function(EscrowServerCall call) => switch (call) {
  EscrowServerCall.release => 'release',
  EscrowServerCall.claimRefund => 'claim_refund',
};
