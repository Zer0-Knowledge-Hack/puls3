import 'dart:async';

import 'package:puls3_client/puls3_client.dart' as api;

import '../domain/agent_draft.dart';
import '../hire/wallet_session.dart';
import '../wallet/wallet_port.dart';
import 'deploy_gateway.dart';

/// `client.studio.prepareDeploy`.
typedef PrepareDeployCall =
    Future<api.DeploySession> Function(int draftId, String builder);

/// `client.studio.submitRegistration`.
typedef SubmitRegistrationCall =
    Future<api.DeploySession> Function(
      int draftId,
      String preparationId,
      String signedTransactionXdr,
    );

/// `client.studio.getDeploySession`.
typedef GetDeploySessionCall = Future<api.DeploySession> Function(int draftId);

/// `client.studio.prepareWalletAuthorization`.
typedef PrepareWalletAuthorizationCall =
    Future<api.DeploySession> Function(int draftId);

/// `client.studio.submitWalletAuthorization`.
typedef SubmitWalletAuthorizationCall =
    Future<api.DeploySession> Function(
      int draftId,
      String preparationId,
      String signedAuthorizationEntryXdr,
    );

/// [DeployGateway] over `StudioEndpoint` deploy methods (#35).
///
/// `submitRegistration` and `submitWalletAuthorization` poll
/// `getDeploySession` until the chain confirms. The registration hash is
/// the real `register_full` transaction, so the success sheet can link it.
class ServerDeployGateway implements DeployGateway {
  ServerDeployGateway({
    required this._prepareDeploy,
    required this._submitRegistration,
    required this._getDeploySession,
    required this._prepareWalletAuthorization,
    required this._submitWalletAuthorization,
    required this._wallet,
    this._session,
    this.callTimeout = const Duration(seconds: 30),
    this.pollInterval = const Duration(seconds: 2),
    this.confirmTimeout = const Duration(seconds: 60),
  });

  final PrepareDeployCall _prepareDeploy;
  final SubmitRegistrationCall _submitRegistration;
  final GetDeploySessionCall _getDeploySession;
  final PrepareWalletAuthorizationCall _prepareWalletAuthorization;
  final SubmitWalletAuthorizationCall _submitWalletAuthorization;
  final WalletPort _wallet;
  final WalletSession? _session;
  final Duration callTimeout;
  final Duration pollInterval;
  final Duration confirmTimeout;

  @override
  bool get isDemo => false;

  int? _draftId;

  @override
  Future<PreparedDeploy> prepare(
    AgentDraft draft, {
    required String builder,
  }) async {
    final draftId = draft.draftId;
    if (draftId == null) {
      throw const DeployBackendError('Save the draft before deploying.');
    }
    _draftId = draftId;
    await _signedIn(builder);
    final session = await _call(() => _prepareDeploy(draftId, builder));
    final unsigned = session.preparation?.unsignedTransactionXdr;
    final preparationId = session.preparation?.preparationId;
    if (unsigned == null || unsigned.isEmpty || preparationId == null) {
      throw const DeployBackendError('The server prepared no transaction.');
    }
    return PreparedDeploy(
      preparationId: preparationId,
      unsignedTransaction: unsigned,
    );
  }

  @override
  Future<Registration> submitRegistration(
    PreparedDeploy prepared,
    String signedTransaction,
  ) async {
    final draftId = _requireDraft();
    var session = await _call(
      () => _submitRegistration(
        draftId,
        prepared.preparationId,
        signedTransaction,
      ),
    );
    session = await _untilConfirmed(
      session,
      draftId,
      (current) =>
          current.failureCode != null ||
          (current.agentId != null &&
              current.state != 'registrationSubmitted' &&
              current.state != 'awaitingRegistrationSignature'),
    );
    final agentId = session.agentId;
    final hash = session.preparation?.transaction;
    if (agentId == null || hash == null) {
      throw const DeployBackendError('The registration has no transaction.');
    }
    return Registration(agentId: agentId, transactionHash: hash);
  }

  String? _walletPreparationId;

  @override
  Future<String?> walletAuthorization(Registration _) async {
    final session = await _call(
      () => _prepareWalletAuthorization(_requireDraft()),
    );
    final preparation = session.preparation;
    _walletPreparationId = preparation?.preparationId;
    if (preparation?.purpose == 'setMetadata') {
      return preparation?.unsignedTransactionXdr;
    }
    return preparation?.authorizationEntryXdr;
  }

  @override
  Future<void> submitWalletAuthorization(
    Registration _,
    String signedAuthorizationEntry,
  ) async {
    final draftId = _requireDraft();
    final preparationId = _walletPreparationId;
    if (preparationId == null) {
      throw const DeployBackendError('The wallet step has no preparation.');
    }
    final submitted = await _call(
      () => _submitWalletAuthorization(
        draftId,
        preparationId,
        signedAuthorizationEntry,
      ),
    );
    await _untilConfirmed(
      submitted,
      draftId,
      (current) => current.state == 'active',
    );
  }

  @override
  Future<String> activate(Registration _) async {
    final session = await _call(() => _getDeploySession(_requireDraft()));
    final wallet = session.agentWallet;
    if (session.state != 'active' || wallet == null || wallet.isEmpty) {
      throw const DeployBackendError('The agent wallet is not active.');
    }
    return wallet;
  }

  int _requireDraft() {
    final draftId = _draftId;
    if (draftId == null) {
      throw const DeployBackendError('Save the draft before deploying.');
    }
    return draftId;
  }

  Future<api.DeploySession> _untilConfirmed(
    api.DeploySession session,
    int draftId,
    bool Function(api.DeploySession session) done,
  ) async {
    final started = DateTime.now();
    var current = session;
    while (!done(current)) {
      _throwIfFailed(current);
      if (DateTime.now().difference(started) > confirmTimeout) {
        throw const DeployConnectionError(
          'The chain has not confirmed the transaction yet.',
        );
      }
      await Future.delayed(pollInterval);
      current = await _call(() => _getDeploySession(draftId));
    }
    _throwIfFailed(current);
    return current;
  }

  void _throwIfFailed(api.DeploySession session) {
    final code = session.failureCode;
    if (code == null) return;
    if (code == 'PublicationFailed') {
      throw const DeployBackendError(
        'The agent is registered, but it is not live yet.',
      );
    }
    throw DeployTransactionFailed(
      'The chain rejected the transaction ($code).',
      transactionHash: session.preparation?.transaction,
    );
  }

  Future<void> _signedIn(String owner) async {
    final session = _session;
    if (session == null) return;
    try {
      await session.ensureSignedIn(owner, _wallet.signChallenge);
    } on WalletException {
      throw const DeployBackendError(
        'Sign in with your wallet, then try again.',
      );
    }
  }

  Future<T> _call<T>(Future<T> Function() call) async {
    try {
      return await call().timeout(callTimeout);
    } on api.Puls3ApiException catch (error) {
      throw _map(error);
    } on DeployGatewayException {
      rethrow;
    } on TimeoutException {
      throw const DeployConnectionError('The server did not answer.');
    } on api.ServerpodClientException {
      throw const DeployConnectionError('The server did not answer.');
    }
  }

  DeployGatewayException _map(api.Puls3ApiException error) => switch (error.code) {
    'PreparationExpired' || 'AuthorizationExpired' => DeployPreparationExpired(
      error.message ?? 'That signature expired. Deploy again.',
    ),
    'TransactionFailed' || 'SubmissionRejected' => DeployTransactionFailed(
      error.message ?? 'The chain rejected the transaction.',
    ),
    _ => DeployBackendError(
      error.message ?? 'The server could not deploy this agent.',
    ),
  };
}
