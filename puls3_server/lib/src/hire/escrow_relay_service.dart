import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;

import '../chain/chain_submission_store.dart';
import '../chain/submission_values.dart';
import '../generated/protocol.dart';
import '../ledger/envelope_codec.dart';
import '../ledger/ledger_errors.dart';
import '../ledger/stellar_config.dart';
import '../ledger/xdr_invoke_encoder.dart' show ScArg;
import 'chain_accounts.dart';
import 'escrow_preparation_store.dart';
import 'hire_lifecycle_store.dart';
import 'hire_relay_config.dart';

/// The catalog entry of an agent, or `null` when there is none.
typedef AgentSummaryLookup = Future<AgentSummary?> Function(int registryId);

/// An unsigned envelope built for a hire that may not be stored yet
/// (`createHire` prepares first and persists hire and preparation together).
final class PreparationDraft {
  const PreparationDraft._({
    required this.purpose,
    required this.signer,
    required this.envelope,
    required this.sequence,
    required this.validUntil,
    this.jobExpiredAt,
    this.rejectReason,
  });

  final SubmissionPurpose purpose;
  final StellarAddress signer;
  final PreparedEnvelope envelope;

  /// The sequence number the envelope uses.
  final int sequence;
  final DateTime validUntil;
  final int? jobExpiredAt;
  final String? rejectReason;
}

/// Prepares the escrow calls a session wallet signs and relays the signed
/// envelopes to the chain (api.md Decision A, "Server relay submission").
///
/// The server never signs. A submit is accepted only when the signed
/// envelope is the prepared one plus the session wallet's signature, and the
/// record is stored before the envelope is sent. Chain outcomes of a send
/// never throw: the record carries them and the tracker finishes the job.
///
/// Every failure the wire contract names is a [Puls3ApiException] with the
/// catalog code. A missing setting is a [HireConfigurationMissing].
final class EscrowRelayService {
  EscrowRelayService({
    required EscrowPreparationStore preparations,
    required ChainSubmissionStore submissions,
    required HireLifecycleStore hires,
    required ChainAccounts accounts,
    required EnvelopeCodec codec,
    required LedgerPort agentWallets,
    required StellarConfig stellar,
    required HireRelayConfig config,
    DateTime Function()? now,
    String Function()? newPreparationId,
  }) : _preparations = preparations,
       _submissions = submissions,
       _hires = hires,
       _accounts = accounts,
       _codec = codec,
       _agentWallets = agentWallets,
       _stellar = stellar,
       _config = config,
       _now = now ?? DateTime.now,
       _newPreparationId = newPreparationId ?? _randomPreparationId;

  final EscrowPreparationStore _preparations;
  final ChainSubmissionStore _submissions;
  final HireLifecycleStore _hires;
  final ChainAccounts _accounts;
  final EnvelopeCodec _codec;
  final LedgerPort _agentWallets;
  final StellarConfig _stellar;
  final HireRelayConfig _config;
  final DateTime Function() _now;
  final String Function() _newPreparationId;

  int get _nowSeconds => _now().toUtc().millisecondsSinceEpoch ~/ 1000;

  Future<PreparedTransaction> prepareCreateJob(
    StellarAddress wallet,
    int hireId,
  ) => _prepare(wallet, hireId, SubmissionPurpose.createJob);

  Future<PreparedTransaction> prepareFund(StellarAddress wallet, int hireId) =>
      _prepare(wallet, hireId, SubmissionPurpose.fund);

  Future<PreparedTransaction> prepareComplete(
    StellarAddress wallet,
    int hireId,
  ) => _prepare(wallet, hireId, SubmissionPurpose.complete);

  Future<PreparedTransaction> prepareReject(
    StellarAddress wallet,
    int hireId,
    String reason,
  ) => _prepare(wallet, hireId, SubmissionPurpose.reject, reason: reason);

  Future<PreparedTransaction> _prepare(
    StellarAddress wallet,
    int hireId,
    SubmissionPurpose purpose, {
    String? reason,
  }) async {
    final hire = await _ownedHire(wallet, hireId);
    if (reason != null && reason.trim().isEmpty) {
      throw _api('InvalidRejectReason');
    }
    if (!_allows(purpose, hire.status)) throw _invalidTransition(hire, purpose);
    final records = await _submissions.listByHire(hire.id);
    if (records.any((r) => r.state == SubmissionState.submitted)) {
      throw _api('SubmissionInProgress');
    }
    if (purpose == SubmissionPurpose.fund && records.any(_fundReachedChain)) {
      throw _api('PaymentAlreadySubmitted');
    }

    final PreparationDraft draft;
    switch (purpose) {
      case SubmissionPurpose.createJob:
        draft = await draftCreateJob(
          wallet: wallet,
          provider: await _providerOf(hire.agentId),
          agentId: hire.agentId,
          price: hire.price,
          expiredAt: _nowSeconds + _config.jobDurationSeconds,
        );
      default:
        draft = await _draft(
          wallet: wallet,
          purpose: purpose,
          function: purpose.wireName,
          args: _jobArgs(hire, wallet, purpose, reason),
          rejectReason: reason,
        );
    }
    final stored = await _preparations.inTransaction((transaction) async {
      await _preparations.supersedeCurrent(hire.id, transaction: transaction);
      return _preparations.insert(
        newPreparation(draft, hire.id),
        transaction: transaction,
      );
    });
    return preparedOf(stored);
  }

  /// Builds the first `create_job` of a hire that is not stored yet.
  ///
  /// Nothing is persisted: the caller stores the draft with [newPreparation]
  /// in the transaction that inserts the hire.
  Future<PreparationDraft> draftCreateJob({
    required StellarAddress wallet,
    required StellarAddress provider,
    required int agentId,
    required int price,
    required int expiredAt,
  }) => _draft(
    wallet: wallet,
    purpose: SubmissionPurpose.createJob,
    function: 'create_job',
    args: [
      ScArg.address(wallet),
      ScArg.address(provider),
      ScArg.address(wallet),
      ScArg.u64(expiredAt),
      // The description is not part of the contract with the app (P5).
      const ScArg.string(''),
      const ScArg.voidValue(),
      ScArg.u32(agentId),
      ScArg.address(_stellar.usdcSac),
      ScArg.i128(price),
    ],
    jobExpiredAt: expiredAt,
  );

  /// The row to store for [draft] once its [hireId] is known.
  NewPreparation newPreparation(PreparationDraft draft, int hireId) =>
      NewPreparation(
        preparationId: _newPreparationId(),
        hireId: hireId,
        purpose: draft.purpose,
        signer: draft.signer.value,
        unsignedEnvelopeXdr: draft.envelope.envelopeXdr,
        transactionHash: draft.envelope.hashHex,
        sequence: draft.sequence,
        validUntil: draft.validUntil,
        jobExpiredAt: draft.jobExpiredAt,
        rejectReason: draft.rejectReason,
      );

  /// The wire form of a stored preparation.
  PreparedTransaction preparedOf(StoredPreparation stored) =>
      PreparedTransaction(
        preparationId: stored.preparationId,
        purpose: stored.purpose.wireName,
        signer: stored.signer,
        networkPassphrase: _stellar.networkPassphrase,
        unsignedTransactionXdr: stored.unsignedEnvelopeXdr,
        transaction: stored.transactionHash,
        expiresAt: stored.validUntil,
      );

  /// The `create_job` preparation `createHire` returns for an existing
  /// hire: the current one while unused and unexpired, a fresh one
  /// otherwise, and `null` once the call was submitted or confirmed.
  Future<PreparedTransaction?> currentCreateJob(
    HireRow hire,
    StellarAddress wallet,
  ) async {
    final records = await _submissions.listByHire(hire.id);
    final underway = records.any(
      (r) =>
          r.purpose == SubmissionPurpose.createJob &&
          r.state != SubmissionState.failed,
    );
    if (underway || hire.status != null) return null;
    final current = await _preparations.findCurrent(hire.id);
    if (current != null &&
        current.purpose == SubmissionPurpose.createJob &&
        current.submittedAt == null &&
        _now().toUtc().isBefore(current.validUntil)) {
      return preparedOf(current);
    }
    return prepareCreateJob(wallet, hire.id);
  }

  Future<PreparationDraft> _draft({
    required StellarAddress wallet,
    required SubmissionPurpose purpose,
    required String function,
    required List<ScArg> args,
    int? jobExpiredAt,
    String? rejectReason,
  }) async {
    // Both settings are read before the chain is, so a missing one fails
    // before anything is read or stored.
    final validitySeconds = _config.preparationValiditySeconds;
    final inclusionFee = _config.inclusionFeeStroops;
    final accountSequence = await _accounts.sequenceOf(wallet);
    final validUntil = _nowSeconds + validitySeconds;
    final spec = EnvelopeSpec(
      source: wallet,
      accountSequence: accountSequence,
      contract: _stellar.escrow,
      function: function,
      args: args,
      inclusionFee: inclusionFee,
      validUntil: validUntil,
    );
    final simulation = await _accounts.simulate(spec);
    final PreparedEnvelope envelope;
    try {
      envelope = _codec.build(spec, simulation);
    } on UnsupportedAuthorization {
      throw _api('InternalError');
    }
    return PreparationDraft._(
      purpose: purpose,
      signer: wallet,
      envelope: envelope,
      sequence: accountSequence + 1,
      validUntil: DateTime.fromMillisecondsSinceEpoch(
        validUntil * 1000,
        isUtc: true,
      ),
      jobExpiredAt: jobExpiredAt,
      rejectReason: rejectReason,
    );
  }

  /// The arguments of the calls on an existing job.
  List<ScArg> _jobArgs(
    HireRow hire,
    StellarAddress wallet,
    SubmissionPurpose purpose,
    String? reason,
  ) {
    final jobId = hire.jobId ?? (throw _invalidTransition(hire, purpose));
    return [
      ScArg.address(wallet),
      ScArg.u64(jobId),
      switch (purpose) {
        SubmissionPurpose.fund => ScArg.i128(hire.price),
        SubmissionPurpose.complete => ScArg.bytes32(Uint8List(32)),
        _ => ScArg.bytes32(
          Uint8List.fromList(sha256.convert(utf8.encode(reason!)).bytes),
        ),
      },
      if (purpose == SubmissionPurpose.fund) ScArg.u32(_config.platformFeeBps),
    ];
  }

  Future<StellarAddress> _providerOf(int agentId) async {
    try {
      return await _agentWallets.agentWallet(AgentId(agentId)) ??
          (throw AgentUnavailable(agentId: agentId));
    } on LedgerException {
      throw chainUnavailable();
    }
  }

  Future<HireRow> _ownedHire(StellarAddress wallet, int hireId) async {
    if (hireId < 1) throw _api('InvalidHireId');
    final hire = await _hires.findHire(hireId);
    if (hire == null) throw _api('HireNotFound');
    if (hire.consumer != wallet.value) throw _api('HireNotOwned');
    return hire;
  }

  /// Whether a hire with [status] may take the call of [purpose] (api.md,
  /// "Hire escrow states").
  static bool _allows(SubmissionPurpose purpose, HireStatus? status) =>
      switch (purpose) {
        SubmissionPurpose.createJob => status == null,
        SubmissionPurpose.fund => status == HireStatus.open,
        SubmissionPurpose.complete => status == HireStatus.submitted,
        SubmissionPurpose.reject =>
          status == HireStatus.open ||
              status == HireStatus.funded ||
              status == HireStatus.submitted,
        _ => false,
      };

  /// A `fund` that succeeded on chain although the hire could not be bound
  /// to it: funds moved, so no new funding is prepared.
  static bool _fundReachedChain(StoredSubmission record) =>
      record.purpose == SubmissionPurpose.fund &&
      record.state == SubmissionState.failed &&
      (record.errorCode == SubmissionOutcomeCode.jobMismatch ||
          record.errorCode == SubmissionOutcomeCode.jobEvidenceUnavailable);

  static Puls3ApiException _invalidTransition(
    HireRow hire,
    SubmissionPurpose purpose,
  ) => _api('InvalidHireTransition', {
    if (hire.status case final status?) 'status': status.name,
    'purpose': purpose.wireName,
  });

  static Puls3ApiException _api(String code, [Map<String, String>? details]) =>
      Puls3ApiException(code: code, details: details);
}

String _randomPreparationId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}
