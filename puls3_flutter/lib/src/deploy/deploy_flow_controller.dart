import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/agent_draft.dart';
import '../domain/stellar_explorer.dart';
import '../state/wallet_controller.dart';
import '../wallet/wallet_port.dart';
import 'deploy_gateway.dart';

/// The steps of a deploy, in order (ADR-0004, #18).
enum DeployStep { preparing, awaitingSignature, registering, activating, live }

/// Why a deploy stopped. Every kind maps to one human message and one
/// recovery action (see [DeployFlowController.retry]).
enum DeployErrorKind {
  /// The builder declined the wallet prompt. Retry asks to sign again.
  signatureRejected,

  /// No wallet is installed, unlocked or connected. Retry repeats the step.
  walletUnavailable,

  /// The wallet is on another network. Retry repeats the step.
  wrongNetwork,

  /// The wallet account changed after the transaction was prepared for the
  /// previous one. Retry prepares a new transaction for the current account.
  accountChanged,

  /// The chain rejected the registration. Retry prepares a new transaction.
  transactionFailed,

  /// The prepared transaction expired or was superseded before it was
  /// submitted. Retry prepares a new one.
  preparationExpired,

  /// The wallet did not answer the signature request in time. Retry asks
  /// again.
  walletTimeout,

  /// The backend could not be reached or timed out. Retry repeats the step.
  connection,

  /// The backend answered with data the app cannot verify. Retry repeats
  /// the step.
  invalidResponse,

  /// The backend reported an error. Retry repeats the step.
  backendError,
}

/// A stopped deploy: what went wrong and at which step.
@immutable
class DeployError {
  const DeployError({
    required this.kind,
    required this.step,
    this.detail,
    this.transactionHash,
  });

  final DeployErrorKind kind;

  /// The step that failed. The flow stays on it until a retry.
  final DeployStep step;

  /// Safe technical detail for "Show details": a backend message or a
  /// validation reason. Never a stack trace, a key or a signed payload.
  final String? detail;

  /// The failed transaction, when it reached the chain.
  final String? transactionHash;
}

/// A live agent. Every value comes from a verified backend response.
@immutable
class DeployResult {
  const DeployResult({
    required this.agentId,
    required this.transactionHash,
    required this.agentWallet,
    this.isDemo = false,
  });

  final int agentId;

  /// The confirmed `register_full` transaction, 64 lowercase hex chars.
  final String transactionHash;

  /// The wallet the agent is paid to.
  final String agentWallet;

  /// From a demo gateway: nothing was registered and the values are made
  /// up, so they must not be presented as on-chain facts.
  final bool isDemo;

  /// The registration transaction on the testnet explorer; null for a demo,
  /// whose hash does not exist.
  Uri? get explorerUrl =>
      isDemo ? null : Uri.parse(stellarExpertTxUrl(transactionHash));
}

final _transactionHash = RegExp(r'^[0-9a-f]{64}$');
final _accountAddress = RegExp(r'^G[A-Z2-7]{55}$');

/// Drives one deploy of [draft] through [DeployStep]s.
///
/// It never starts two runs at once, keeps every finished step so a retry
/// resumes where it stopped, and verifies each backend answer before using
/// it. The wallet is the only signer: this class only hands it the
/// server-prepared transaction.
class DeployFlowController extends ChangeNotifier {
  DeployFlowController({
    required this.draft,
    required DeployGateway gateway,
    required WalletController wallet,
    this.stepTimeout,
    this.signatureTimeout,
  }) : _gateway = gateway,
       _wallet = wallet;

  final AgentDraft draft;
  final DeployGateway _gateway;
  final WalletController _wallet;

  /// Upper bound for each backend step. The wallet step has none: the user
  /// may take their time to read and sign. Null disables it.
  final Duration? stepTimeout;

  /// Upper bound for each wallet prompt (connect and sign), so a popup that
  /// never answers does not leave the flow stuck. Null disables it.
  final Duration? signatureTimeout;

  /// True while a wallet prompt (connect or sign) is open. The user may
  /// leave then: a wallet that never answers must not trap them.
  bool get isWaitingForWallet => _waitingForWallet;
  bool _waitingForWallet = false;

  /// The gateway is a stand-in: the flow and its result are a demo.
  bool get isDemo => _gateway.isDemo;

  DeployStep _step = DeployStep.preparing;
  DeployError? _error;
  DeployResult? _result;
  bool _running = false;
  bool _disposed = false;

  String? _builder;
  PreparedDeploy? _prepared;
  String? _signed;
  Registration? _registration;

  DeployStep get step => _step;
  DeployError? get error => _error;
  DeployResult? get result => _result;

  /// The confirmed registration, known before activation finishes.
  Registration? get registration => _registration;
  bool get isLive => _step == DeployStep.live;

  /// True while a step is in flight. Retry is a no-op meanwhile.
  bool get isRunning => _running;

  /// Starts the deploy. A second call while it runs, or after it went
  /// live, does nothing; use [retry] after an error.
  Future<void> start() => _run();

  /// Runs the flow again after an error, from the step its kind requires:
  /// a new transaction after [DeployErrorKind.transactionFailed] or
  /// [DeployErrorKind.accountChanged], the failed step otherwise.
  Future<void> retry() {
    final error = _error;
    if (error == null || _running) return Future.value();
    if (error.kind == DeployErrorKind.transactionFailed ||
        error.kind == DeployErrorKind.preparationExpired ||
        error.kind == DeployErrorKind.accountChanged) {
      _builder = null;
      _prepared = null;
      _signed = null;
      _registration = null;
    }
    return _run();
  }

  Future<void> _run() async {
    if (_running || isLive) return;
    _running = true;
    _error = null;
    _notify();
    try {
      final prepared =
          _prepared ??
          await _attempt<PreparedDeploy>(DeployStep.preparing, () async {
            final builder = await _waitForWallet(_wallet.connect());
            _builder = builder;
            return _verifyPrepared(
              await _backend(_gateway.prepare(draft, builder: builder)),
            );
          });
      _prepared = prepared;

      final signed =
          _signed ??
          await _attempt<String>(DeployStep.awaitingSignature, () async {
            // The transaction names the account it was prepared for. If the
            // wallet switched account since, it cannot sign it.
            if (_wallet.address != _builder) throw const _AccountChanged();
            return _waitForWallet(
              _wallet.signTransaction(prepared.unsignedTransaction),
            );
          });
      _signed = signed;

      final registration =
          _registration ??
          await _attempt<Registration>(
            DeployStep.registering,
            () async => _verifyRegistration(
              await _backend(_gateway.submitRegistration(prepared, signed)),
            ),
          );
      _registration = registration;

      final agentWallet = await _attempt<String>(
        DeployStep.activating,
        () async =>
            _verifyWallet(await _backend(_gateway.activate(registration))),
      );
      _result = DeployResult(
        agentId: registration.agentId,
        transactionHash: registration.transactionHash,
        agentWallet: agentWallet,
        isDemo: _gateway.isDemo,
      );
      _step = DeployStep.live;
    } on _Stopped catch (stopped) {
      _error = stopped.error;
    } on _Cancelled {
      // The flow was closed mid-run: stop without starting further steps.
      return;
    } finally {
      _running = false;
      _notify();
    }
  }

  /// Marks a wallet prompt as open and applies [signatureTimeout] to it.
  Future<T> _waitForWallet<T>(Future<T> prompt) async {
    _waitingForWallet = true;
    _notify();
    try {
      final timeout = signatureTimeout;
      return await (timeout == null
          ? prompt
          : prompt.timeout(
              timeout,
              onTimeout: () => throw const _WalletTimeout(),
            ));
    } finally {
      _waitingForWallet = false;
      _notify();
    }
  }

  /// Applies [stepTimeout] to a backend call.
  Future<T> _backend<T>(Future<T> call) {
    final timeout = stepTimeout;
    return timeout == null ? call : call.timeout(timeout);
  }

  /// Moves to [step], runs [action] and turns its failure into a
  /// [DeployError] for that step.
  Future<T> _attempt<T>(DeployStep step, Future<T> Function() action) async {
    if (_disposed) throw const _Cancelled();
    _step = step;
    _notify();
    final T value;
    try {
      value = await action();
    } on Object catch (e, stack) {
      // A bug must stay visible to developers; the user still gets a
      // recoverable error instead of a frozen flow.
      if (e is Error) {
        FlutterError.reportError(
          FlutterErrorDetails(exception: e, stack: stack, library: 'deploy'),
        );
      }
      if (_disposed) throw const _Cancelled();
      throw _Stopped(_errorFor(e, step));
    }
    if (_disposed) throw const _Cancelled();
    return value;
  }

  DeployError _errorFor(Object e, DeployStep step) => switch (e) {
    WalletSignatureRejected() => DeployError(
      kind: DeployErrorKind.signatureRejected,
      step: step,
    ),
    WalletUnavailable() => DeployError(
      kind: DeployErrorKind.walletUnavailable,
      step: step,
    ),
    WalletWrongNetwork() => DeployError(
      kind: DeployErrorKind.wrongNetwork,
      step: step,
    ),
    _AccountChanged() => DeployError(
      kind: DeployErrorKind.accountChanged,
      step: step,
    ),
    DeployTransactionFailed(:final message, :final transactionHash) =>
      DeployError(
        kind: DeployErrorKind.transactionFailed,
        step: step,
        detail: message,
        transactionHash: transactionHash,
      ),
    _WalletTimeout() => DeployError(
      kind: DeployErrorKind.walletTimeout,
      step: step,
    ),
    DeployPreparationExpired(:final message) => DeployError(
      kind: DeployErrorKind.preparationExpired,
      step: step,
      detail: message,
    ),
    DeployConnectionError(:final message) => DeployError(
      kind: DeployErrorKind.connection,
      step: step,
      detail: message,
    ),
    TimeoutException() => DeployError(
      kind: DeployErrorKind.connection,
      step: step,
      detail: switch (stepTimeout) {
        final limit? => 'No answer from the server in ${limit.inSeconds} s.',
        null => 'No answer from the server.',
      },
    ),
    _InvalidResponse(:final reason) => DeployError(
      kind: DeployErrorKind.invalidResponse,
      step: step,
      detail: reason,
    ),
    DeployBackendError(:final message) => DeployError(
      kind: DeployErrorKind.backendError,
      step: step,
      detail: message,
    ),
    // Anything unexpected is a backend failure of this step, so the builder
    // can always retry. Its text is never shown: it may not be safe.
    _ => DeployError(kind: DeployErrorKind.backendError, step: step),
  };

  PreparedDeploy _verifyPrepared(PreparedDeploy prepared) {
    if (prepared.preparationId.isEmpty ||
        prepared.unsignedTransaction.isEmpty) {
      throw const _InvalidResponse('The prepared transaction is empty.');
    }
    return prepared;
  }

  Registration _verifyRegistration(Registration registration) {
    if (registration.agentId < 0) {
      throw const _InvalidResponse('The agent id is negative.');
    }
    if (!_transactionHash.hasMatch(registration.transactionHash)) {
      throw const _InvalidResponse('The transaction hash is malformed.');
    }
    return registration;
  }

  String _verifyWallet(String wallet) {
    if (!_accountAddress.hasMatch(wallet)) {
      throw const _InvalidResponse('The agent wallet is not a G… address.');
    }
    return wallet;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class _Stopped implements Exception {
  const _Stopped(this.error);
  final DeployError error;
}

class _AccountChanged implements Exception {
  const _AccountChanged();
}

class _WalletTimeout implements Exception {
  const _WalletTimeout();
}

/// The controller was disposed while a step was in flight.
class _Cancelled implements Exception {
  const _Cancelled();
}

class _InvalidResponse implements Exception {
  const _InvalidResponse(this.reason);
  final String reason;
}
