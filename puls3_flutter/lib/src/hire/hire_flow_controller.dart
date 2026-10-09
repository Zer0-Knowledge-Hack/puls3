import 'dart:math';

import 'package:flutter/foundation.dart';

import '../domain/agent.dart';
import '../state/wallet_controller.dart';
import '../wallet/wallet_port.dart';
import 'hire_gateway.dart';

/// Where the hire is (api.md F5-3 to F5-5).
enum HireStep {
  /// Not started: the review screen.
  review,
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
/// id per flow so a retry returns the same hire instead of a second one.
class HireFlowController extends ChangeNotifier {
  HireFlowController({
    required this.agent,
    required this._gateway,
    required this._wallet,
    String? requestId,
  }) : requestId = requestId ?? _newRequestId();

  final Agent agent;
  final HireGateway _gateway;
  final WalletController _wallet;

  /// The `createHire` idempotency key, fixed for this flow.
  final String requestId;

  HireStep _step = HireStep.review;
  String? _error;
  bool _running = false;
  bool _disposed = false;

  int? _hireId;
  EscrowPreparation? _createJob;
  bool _createJobSent = false;
  EscrowPreparation? _fund;
  EscrowSubmission? _payment;

  HireStep get step => _step;
  bool get isRunning => _running;
  bool get isDemo => _gateway.isDemo;

  /// Why the last run stopped, safe to show; null when it did not fail.
  String? get error => _error;

  int? get hireId => _hireId;

  /// The relayed `fund`, once the flow is done.
  EscrowSubmission? get payment => _payment;

  /// Starts the flow, or resumes it after an error, with [input] as the
  /// work request.
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

      var hireId = _hireId;
      if (hireId == null) {
        _set(HireStep.creating);
        final start = await _gateway.createHire(
          agentId: agentId ?? 0,
          consumer: consumer,
          input: input,
          requestId: requestId,
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
          onExpired: () {
            _createJob = null;
          },
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
        onExpired: () {
          _fund = null;
        },
      );
      _set(HireStep.done);
    } on Object catch (e) {
      if (_disposed) return;
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

  /// Relays a signed envelope; an expired preparation is dropped so the
  /// retry prepares a new one instead of resending it.
  Future<EscrowSubmission> _submit(
    int hireId,
    EscrowPreparation preparation,
    String signed, {
    required VoidCallback onExpired,
  }) async {
    try {
      return await _gateway.submit(hireId, preparation, signed);
    } on HirePreparationExpired {
      onExpired();
      rethrow;
    }
  }

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
