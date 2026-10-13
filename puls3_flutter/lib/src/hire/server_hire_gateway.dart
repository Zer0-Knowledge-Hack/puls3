import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:puls3_client/puls3_client.dart';

import 'hire_gateway.dart';
import 'wallet_funds.dart';
import 'wallet_session.dart';

/// `client.hire.createHire`.
typedef CreateHireCall =
    Future<CreateHireResult> Function(
      int agentId,
      String consumer,
      String input,
      String requestId,
    );

/// `client.hire.prepareCreateJob` or `client.hire.prepareFund`.
typedef PrepareEscrowCall = Future<PreparedTransaction> Function(int hireId);

/// `client.hire.submitEscrowCall`.
typedef SubmitEscrowCall =
    Future<HireDetail> Function(
      int hireId,
      String preparationId,
      String signedTransactionXdr,
    );

/// `client.hire.getHire`.
typedef GetHireCall = Future<HireDetail> Function(int hireId, String consumer);

/// [HireGateway] over `HireEndpoint` (api.md, F5-3 to F5-5, F6).
///
/// [prepareFund] waits for the `create_job` confirmation by asking again
/// while the server answers that the job is still being created
/// (`InvalidHireTransition` with no status, or `SubmissionInProgress`), up
/// to [confirmationTimeout].
class ServerHireGateway implements HireGateway {
  ServerHireGateway({
    required this._createHire,
    required this._prepareCreateJob,
    required this._prepareFund,
    required this._submitEscrowCall,
    required this._getHire,
    this._session,
    this._readFunds,
    this.callTimeout = const Duration(seconds: 30),
    this.pollInterval = const Duration(seconds: 3),
    this.confirmationTimeout = const Duration(minutes: 2),
  });

  final CreateHireCall _createHire;
  final PrepareEscrowCall _prepareCreateJob;
  final PrepareEscrowCall _prepareFund;
  final SubmitEscrowCall _submitEscrowCall;
  final GetHireCall _getHire;

  /// The wallet session (#136). Without it, the server is called with no
  /// session and answers `NotAuthenticated`.
  final WalletSession? _session;

  /// Reads the consumer's USDC before any signature (api.md F5-2). Without
  /// it, the server's simulation of the `fund` is the only check.
  final ReadWalletFunds? _readFunds;

  /// Upper bound for one server call.
  final Duration callTimeout;

  /// Pause between two checks while the `create_job` confirms.
  final Duration pollInterval;

  /// Upper bound for the `create_job` confirmation.
  final Duration confirmationTimeout;

  @override
  bool get isDemo => false;

  @override
  Future<void> ensureSignedIn(String wallet, ChallengeSigner sign) async {
    final session = _session;
    if (session == null) return;
    await _call(() => session.ensureSignedIn(wallet, sign));
  }

  @override
  Future<void> forgetSession() async => _session?.forget();

  @override
  Future<void> checkFunds(String consumer, int priceUsdcStroops) async {
    final readFunds = _readFunds;
    if (readFunds == null) return;
    final WalletFunds funds;
    try {
      funds = await readFunds(consumer).timeout(callTimeout);
    } on Object catch (e) {
      // An unreadable balance never blocks a payment: the server simulates
      // the `fund` before anything is signed.
      debugPrint('Wallet funds not checked: ${e.runtimeType}');
      return;
    }
    requireFunds(funds, priceUsdcStroops);
  }

  @override
  Future<HireStart> createHire({
    required int agentId,
    required String consumer,
    required String input,
    required String requestId,
  }) async {
    final result = await _call(
      () => _createHire(agentId, consumer, input, requestId),
    );
    final prepared = result.preparedCreateJob;
    return HireStart(
      hireId: result.hire.id,
      createJob: prepared == null ? null : _preparation(prepared),
    );
  }

  @override
  Future<EscrowPreparation> prepareCreateJob(int hireId) async =>
      _preparation(await _call(() => _prepareCreateJob(hireId)));

  @override
  Future<EscrowPreparation> prepareFund(int hireId) async {
    final deadline = DateTime.now().add(confirmationTimeout);
    while (true) {
      try {
        return _preparation(
          await _call(() => _prepareFund(hireId), fund: true),
        );
      } on _JobNotReady {
        if (DateTime.now().isAfter(deadline)) {
          throw const HireBackendUnavailable(
            'The escrow job is taking longer than usual to confirm. '
            'Try again in a moment.',
          );
        }
        await Future<void>.delayed(pollInterval);
      }
    }
  }

  @override
  Future<EscrowSubmission> submit(
    int hireId,
    EscrowPreparation preparation,
    String signedTransaction,
  ) async {
    final detail = await _call(
      () => _submitEscrowCall(
        hireId,
        preparation.preparationId,
        signedTransaction,
      ),
    );
    final submission = detail.escrowSubmission;
    if (submission == null) {
      throw const HireBackendUnavailable(
        'The server did not report the submission.',
      );
    }
    if (submission.state == 'failed') {
      throw _outcome(submission.errorCode);
    }
    return EscrowSubmission(
      transactionHash: submission.transaction,
      state: submission.state,
      explorerUrl: submission.explorerUrl ?? detail.paymentExplorerUrl,
    );
  }

  @override
  Future<HireProgress> getHire(int hireId, String consumer) async {
    final detail = await _call(() => _getHire(hireId, consumer));
    final hire = detail.hire;
    // The latest submission is the `fund` until the agent submits, so it
    // also carries the payment link when the hire has no payment yet.
    final latest = detail.escrowSubmission;
    final fund = latest != null && latest.purpose == 'fund' ? latest : null;
    final paymentTransaction = hire.paymentTransaction ?? fund?.transaction;
    return HireProgress(
      hireId: hire.id,
      agentName: detail.agent.name,
      priceUsdcStroops: hire.price,
      input: detail.input,
      status: hire.status,
      runtimeStatus: hire.runtimeStatus,
      failureReason: hire.failureReason,
      rejectedFrom: hire.rejectedFrom,
      result: detail.result,
      paymentTransaction: paymentTransaction,
      paymentExplorerUrl:
          detail.paymentExplorerUrl ??
          (fund?.transaction == paymentTransaction ? fund?.explorerUrl : null),
    );
  }

  EscrowPreparation _preparation(PreparedTransaction prepared) {
    final xdr = prepared.unsignedTransactionXdr;
    if (xdr == null || xdr.isEmpty) {
      throw const HireRejected('The server sent no transaction to sign.');
    }
    return EscrowPreparation(
      preparationId: prepared.preparationId,
      purpose: prepared.purpose,
      unsignedTransaction: xdr,
    );
  }

  /// Runs one server call and maps its failure to a [HireGatewayException].
  Future<T> _call<T>(Future<T> Function() call, {bool fund = false}) async {
    try {
      return await call().timeout(callTimeout);
    } on Puls3ApiException catch (e) {
      throw _map(e, fund: fund);
    } on TimeoutException {
      throw const HireBackendUnavailable('The puls3 server did not answer.');
    } on ServerpodClientException {
      throw const HireBackendUnavailable('The puls3 server did not answer.');
    }
  }

  /// api.md, "Typed error transport" and the `HireEndpoint` rows.
  static Exception _map(Puls3ApiException e, {required bool fund}) {
    final reason = e.details?['reason'];
    return switch (e.code) {
      'AuthenticationUnavailable' ||
      'NotAuthenticated' => const HireNotSignedIn(),
      // walletAuth (api.md): the challenge or its signature was refused;
      // a new attempt asks for a fresh challenge.
      'ChallengeNotFound' ||
      'ChallengeExpired' ||
      'ChallengeConsumed' ||
      'InvalidWalletSignature' => const HireSignInFailed(),
      'ChallengeRateLimited' => const HireBackendUnavailable(
        'Too many sign-in attempts. Wait a minute, then try again.',
      ),
      'InvalidHireId' ||
      'HireNotFound' ||
      'HireNotOwned' => const HireNotFound(),
      'AgentNotFound' || 'AgentInactive' => const HireAgentUnavailable(
        'This agent is not accepting hires.',
      ),
      'PreparationExpired' => const HirePreparationExpired(),
      'PaymentAlreadySubmitted' => const HirePaymentAlreadySubmitted(),
      'ChainUnavailable' when fund && reason == 'simulationFailed' =>
        const HirePaymentNotPrepared(),
      // The create_job is still confirming (no status yet, or its
      // submission in flight): prepareFund asks again.
      'InvalidHireTransition' when fund && e.details?['status'] == null =>
        const _JobNotReady(),
      'SubmissionInProgress' when fund => const _JobNotReady(),
      // A resumed hire that is already paid: never prepare a second fund.
      'InvalidHireTransition'
          when fund &&
              const {
                'funded',
                'submitted',
                'completed',
              }.contains(e.details?['status']) =>
        const HirePaymentAlreadySubmitted(),
      'InvalidHireTransition'
          when const {'rejected', 'expired'}.contains(e.details?['status']) =>
        const HireClosed(),
      // The server no longer has this preparation: prepare it again.
      'PreparationNotFound' => const HireSubmissionFailed(
        'The prepared transaction is no longer available. Try again to '
        'prepare a new one.',
      ),
      'ChainUnavailable' ||
      'ChainDataUnavailable' ||
      'PersistenceUnavailable' => const HireBackendUnavailable(
        'Stellar Testnet could not be reached. Try again in a moment.',
      ),
      _ => HireRejected(e.message ?? 'The server refused this hire.'),
    };
  }

  /// A submission the server tracked and marked `failed`.
  static HireGatewayException _outcome(String? code) => switch (code) {
    'PreparationExpired' => const HirePreparationExpired(),
    // Final failures of this preparation: the retry prepares a new one.
    'SubmissionRejected' || 'TransactionFailed' => HireSubmissionFailed(
      'The network rejected the transaction ($code). Try again to prepare '
      'a new one.',
    ),
    // The fund transaction succeeded but does not match this hire: the
    // funds moved and stay in the escrow (api.md F5-5).
    'JobMismatch' || 'JobEvidenceUnavailable' => const HireRejected(
      'The payment does not match this hire. The funds stay in the escrow '
      'and return to you after the job expires.',
    ),
    _ => HireRejected(
      'The network rejected the transaction'
      '${code == null ? '' : ' ($code)'}.',
    ),
  };
}

/// The `create_job` is not confirmed yet.
final class _JobNotReady implements Exception {
  const _JobNotReady();
}
