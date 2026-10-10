import 'dart:math';

import 'package:flutter/foundation.dart';

import '../domain/agent.dart';
import '../state/wallet_controller.dart';
import '../wallet/wallet_port.dart';
import 'hire_flow_store.dart';
import 'hire_gateway.dart';

/// Where the hire is (api.md F5-3 to F5-5).
enum HireStep {
  /// Not started: the review screen.
  review,

  /// Signing the SEP-10 challenge that opens the wallet session (#136).
  signingIn,
  creating,
  signingCreateJob,
  submittingCreateJob,
  preparingFund,
  signingFund,
  submittingFund,

  /// The payment reached the escrow (or the demo finished).
  done,
}

/// The hire and pay flow (#91): create the hire, sign and relay
/// `create_job`, then sign and relay `fund`. The wallet signs each envelope
/// unchanged and returns it; the server submits.
///
/// It never runs twice, resumes from the failed step, and keeps one request
/// id per hire so a retry returns the same hire instead of a second one.
/// The request id and the task are kept in [HireFlowStore] until the hire is
/// paid: a closed sheet or a restarted app resumes the same hire, so the
/// consumer never pays twice (`createHire` is idempotent per request id).
class HireFlowController extends ChangeNotifier {
  HireFlowController({
    required this.agent,
    required this._gateway,
    required this._wallet,
    required this._store,
    String? requestId,
  }) : _requestId = requestId ?? _newRequestId();

  final Agent agent;
  final HireGateway _gateway;
  final WalletController _wallet;
  final HireFlowStore _store;

  String _requestId;
  String? _resumedInput;
  String? _storeKey;

  /// The task sent with `createHire`, fixed once the hire is started: the
  /// same request id with another task is `IdempotencyKeyReused`.
  String? _task;

  HireStep _step = HireStep.review;
  String? _error;
  bool _running = false;
  bool _disposed = false;

  int? _hireId;
  EscrowPreparation? _createJob;
  bool _createJobSent = false;
  EscrowPreparation? _fund;
  EscrowSubmission? _payment;

  /// The `createHire` idempotency key of this hire.
  String get requestId => _requestId;

  /// Whether the task can still change: not once the hire was started.
  bool get canEditTask => _task == null;

  HireStep get step => _step;
  bool get isRunning => _running;
  bool get isDemo => _gateway.isDemo;

  /// Why the last run stopped, safe to show; null when it did not fail.
  String? get error => _error;

  int? get hireId => _hireId;

  /// The relayed `fund`, once the flow is done.
  EscrowSubmission? get payment => _payment;

  /// The task of an unfinished hire with this agent that this flow resumes;
  /// null for a new hire.
  String? get resumedInput => _resumedInput;

  /// Adopts the unfinished hire of [consumer] with this agent, if any, so
  /// confirming resumes it. Returns its task.
  String? restore(String consumer) {
    final key = _keyFor(consumer);
    if (_storeKey == key) return _resumedInput;
    // Another account: nothing of the previous account's hire carries over.
    if (_storeKey != null) _resetHire();
    _storeKey = key;
    final pending = _store.read(key);
    if (pending != null) {
      _requestId = pending.requestId;
      _resumedInput = _task = pending.input;
      _notify();
    }
    return _resumedInput;
  }

  /// Starts the flow, or resumes it after an error, with [input] as the
  /// work request. A resumed hire keeps its own task.
  Future<void> run(String input) async {
    if (_running || _step == HireStep.done) return;
    _running = true;
    _error = null;
    _notify();
    try {
      await _wallet.connect();
      final consumer = _wallet.address!;
      final agentId = agent.registryId;
      if (agentId == null && !_gateway.isDemo) {
        throw const HireAgentUnavailable(
          'This agent is not registered on chain, so it cannot be hired.',
        );
      }
      // A new payment is checked before any signature, the sign-in
      // included (F5-2). A resumed hire may have paid already, so its
      // balance says nothing: the server decides.
      restore(consumer);
      if (_fund == null && _resumedInput == null) {
        await _gateway.checkFunds(consumer, agent.priceUsdcStroops);
      }
      // The server only accepts calls from a signed-in wallet (#136).
      _set(HireStep.signingIn);
      await _gateway.ensureSignedIn(consumer, _wallet.signChallenge);
      // Same request id and task as an unfinished hire, or a new one kept
      // until this hire is paid.
      restore(consumer);
      final task = _task ??= input;
      _store.write(
        _storeKey!,
        PendingHire(requestId: _requestId, input: task),
      );

      var hireId = _hireId;
      if (hireId == null) {
        _set(HireStep.creating);
        final start = await _gateway.createHire(
          agentId: agentId ?? 0,
          consumer: consumer,
          input: task,
          requestId: _requestId,
        );
        hireId = _hireId = start.hireId;
        _createJob = start.createJob;
        // No create_job back: an earlier attempt already submitted it.
        _createJobSent = start.createJob == null;
      }

      if (!_createJobSent) {
        final createJob = _createJob ??= await _prepare(
          HireStep.creating,
          () => _gateway.prepareCreateJob(hireId!),
        );
        _set(HireStep.signingCreateJob);
        final signed = await _wallet.signTransaction(
          createJob.unsignedTransaction,
        );
        _set(HireStep.submittingCreateJob);
        await _submit(
          hireId,
          createJob,
          signed,
          prepareAgain: () => _createJob = null,
        );
        _createJobSent = true;
      }

      final fund = _fund ??= await _prepare(
        HireStep.preparingFund,
        () => _gateway.prepareFund(hireId!),
      );
      _set(HireStep.signingFund);
      final signed = await _wallet.signTransaction(fund.unsignedTransaction);
      _set(HireStep.submittingFund);
      _payment = await _submit(
        hireId,
        fund,
        signed,
        prepareAgain: () => _fund = null,
      );
      _finish();
      _set(HireStep.done);
    } on Object catch (e) {
      if (_disposed) return;
      // Paid already, or closed: this hire is over, a new one may start.
      if (e is HirePaymentAlreadySubmitted || e is HireClosed) _finish();
      // A refused session is dropped, so the retry signs in again.
      if (e is HireNotSignedIn || e is HireSignInFailed) {
        await _gateway.forgetSession();
      }
      _error = _message(e);
      debugPrint('Hire flow stopped at $_step: ${e.runtimeType}');
    } finally {
      _running = false;
      _notify();
    }
  }

  Future<EscrowPreparation> _prepare(
    HireStep step,
    Future<EscrowPreparation> Function() prepare,
  ) {
    _set(step);
    return prepare();
  }

  /// Relays a signed envelope. A final failure of the preparation (expired,
  /// rejected, failed on chain) drops it so the retry prepares a new one: the
  /// relay is idempotent per preparation and would return the same failure.
  /// An uncertain failure (no answer) keeps it, so the retry resends the
  /// same envelope and the relay never submits it twice.
  Future<EscrowSubmission> _submit(
    int hireId,
    EscrowPreparation preparation,
    String signed, {
    required VoidCallback prepareAgain,
  }) async {
    try {
      return await _gateway.submit(hireId, preparation, signed);
    } on HirePreparationExpired {
      prepareAgain();
      rethrow;
    } on HireSubmissionFailed {
      prepareAgain();
      rethrow;
    }
  }

  void _resetHire() {
    _requestId = _newRequestId();
    _resumedInput = null;
    _task = null;
    _hireId = null;
    _createJob = null;
    _createJobSent = false;
    _fund = null;
    _payment = null;
    _step = HireStep.review;
  }

  /// The hire needs no resuming any more.
  void _finish() {
    final key = _storeKey;
    if (key != null) _store.remove(key);
    _resumedInput = null;
  }

  String _keyFor(String consumer) =>
      pendingHireKey(consumer, '${agent.registryId ?? agent.id}');

  void _set(HireStep step) {
    if (_disposed) throw const _Cancelled();
    _step = step;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  static String _message(Object e) => switch (e) {
    WalletException() => walletErrorMessage(e),
    HireGatewayException(:final message) => message,
    // Unknown failures can happen after the payment was relayed: never
    // claim that no funds moved.
    _ =>
      'The operation could not be completed. Check the transaction '
          'status before trying again.',
  };

  static String _newRequestId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// The flow was closed while it ran.
final class _Cancelled implements Exception {
  const _Cancelled();
}

/// A human message for a wallet failure. In every case nothing was signed,
/// so no funds moved.
String walletErrorMessage(WalletException e) => switch (e) {
  WalletSignatureRejected() =>
    'You cancelled the payment in your wallet. No funds moved.',
  WalletWrongNetwork() =>
    'Switch your wallet to Stellar Testnet, then try again.',
  WalletNotInstalled() => 'No wallet found. Install Freighter, then try again.',
  WalletUnavailable() => 'Open or unlock your wallet, then try again.',
  WalletTimedOut() =>
    'Your wallet did not answer. Open it, then try again. No funds moved.',
  WalletAccountChanged() =>
    'Your wallet account changed. Reconnect, then try again.',
  WalletInvalidPayload() =>
    'This payment could not be signed safely. No funds moved.',
};
