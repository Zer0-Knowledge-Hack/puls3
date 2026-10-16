import 'package:meta/meta.dart';
import 'package:puls3_domain/puls3_domain.dart' as domain;
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../agent/agent_wallet_custody.dart';
import '../hire/session_wallet.dart';
import '../ledger/stellar_config.dart';
import 'builder_credential.dart';
import 'studio_deploy_service.dart';
import 'studio_deploy_store.dart';
import 'studio_deploy_transport.dart';
import 'studio_deploy_wiring.dart';
import 'builder_task_runner.dart';
import 'serverpod_studio_draft_store.dart';
import 'studio_draft_errors.dart';
import 'studio_draft_service.dart';
import 'studio_draft_transport.dart';
import 'studio_model_policy.dart';
import 'studio_test_errors.dart';
import 'studio_test_run_service.dart';
import 'test_run_quota.dart';

/// Drafts and test runs for the signed-in builder (api.md, `StudioEndpoint`).
///
/// The owner is the session wallet. A draft's prompt is returned only to
/// that wallet. A test run uses the builder's provider credential, never
/// the team Workers AI token, and it creates no hire. Deploy prepares
/// `register_full` and `set_agent_wallet` for the same wallet to sign.
class StudioEndpoint extends Endpoint {
  static SessionWallet? _sessionWallet;
  static StudioDraftService Function(Session session)? _services;
  static StudioTestRunService Function(Session session)? _testRuns;
  static StudioDeployService Function(Session session)? _deploys;
  static StudioDeployWiring? _deployWiring;
  static final MemoryTestRunQuota _quota = MemoryTestRunQuota();
  static final MemoryBuilderCredentialStore _credentials =
      MemoryBuilderCredentialStore();

  /// The process-wide builder credentials. A hire of a Studio agent uses
  /// this store and never the team provider token.
  static BuilderCredentialStore get credentials => _credentials;

  @override
  bool get requireLogin => true;

  static SessionWallet get _wallet =>
      _sessionWallet ?? const WalletSessionWallet();

  /// Replaces the session seam, for tests. `null` restores
  /// [WalletSessionWallet].
  @visibleForTesting
  static set sessionWallet(SessionWallet? wallet) => _sessionWallet = wallet;

  /// Replaces how a request's service is built, for tests. `null` restores
  /// the Postgres store.
  @visibleForTesting
  static set services(StudioDraftService Function(Session session)? builder) =>
      _services = builder;

  /// Replaces how a request's test runs are built, for tests. `null`
  /// restores the in-memory quota and credential store.
  @visibleForTesting
  static set testRuns(
    StudioTestRunService Function(Session session)? builder,
  ) => _testRuns = builder;

  /// Replaces how a request's deploy service is built, for tests. `null`
  /// restores the chain wiring.
  @visibleForTesting
  static set deploys(StudioDeployService Function(Session session)? builder) =>
      _deploys = builder;

  static StudioDraftService _serviceOn(Session session) {
    final builder = _services;
    if (builder != null) return builder(session);
    return StudioDraftService(ServerpodStudioDraftStore(session));
  }

  static StudioTestRunService _testRunsOn(Session session) {
    final builder = _testRuns;
    if (builder != null) return builder(session);
    return StudioTestRunService(
      drafts: _serviceOn(session),
      quota: _quota,
      credentials: _credentials,
      policy: studioServerModelPolicy,
      run: runBuilderTask,
    );
  }

  static StudioDeployService _deploysOn(Session session) {
    final builder = _deploys;
    if (builder != null) return builder(session);
    try {
      return (_deployWiring ??= StudioDeployWiring.fromEnvironment())
          .serviceOn(session);
    } on AgentWalletCustodyUnavailable {
      throw Puls3ApiException(code: 'AgentWalletCreationFailed');
    } on HireConfigurationMissing catch (missing) {
      throw Puls3ApiException(
        code: 'ChainUnavailable',
        details: {'reason': missing.setting},
      );
    }
  }

  /// Creates a draft, or saves a new revision of [draftId].
  ///
  /// [revision] must be the revision the caller last read, unless
  /// [overwrite] is true ("Keep mine").
  Future<StudioDraft> saveDraft(
    Session session,
    AgentManifestDraft draft,
    int? draftId,
    int? revision,
    bool? overwrite,
  ) async {
    final wallet = await _wallet.requireLogin(session);
    try {
      final saved = await _serviceOn(session).save(
        owner: wallet,
        document: draftDocument(draft),
        draftId: draftId,
        revision: revision,
        overwrite: overwrite ?? false,
      );
      return transportStudioDraft(saved);
    } on domain.InvalidManifest catch (e) {
      throw _invalid(e);
    } on StudioDraftMissing {
      throw Puls3ApiException(code: 'DraftNotFound');
    } on StudioDraftNotOwned {
      throw Puls3ApiException(code: 'DraftNotOwned');
    } on StudioDraftRevisionConflict {
      throw Puls3ApiException(code: 'DraftVersionConflict');
    }
  }

  /// One of the caller's drafts.
  Future<StudioDraft> getDraft(Session session, int draftId) async {
    final wallet = await _wallet.requireLogin(session);
    try {
      final draft = await _serviceOn(session).get(
        owner: wallet,
        draftId: draftId,
      );
      return transportStudioDraft(draft);
    } on StudioDraftMissing {
      throw Puls3ApiException(code: 'DraftNotFound');
    } on StudioDraftNotOwned {
      throw Puls3ApiException(code: 'DraftNotOwned');
    }
  }

  /// The caller's drafts, oldest id first. Other wallets' prompts are absent.
  Future<List<StudioDraft>> listDrafts(Session session) async {
    final wallet = await _wallet.requireLogin(session);
    final drafts = await _serviceOn(session).list(wallet);
    return [for (final draft in drafts) transportStudioDraft(draft)];
  }

  /// Runs a saved draft once. No hire and no payment.
  Future<TestRunResult> testRun(
    Session session,
    int draftId,
    String input,
  ) async {
    final wallet = await _wallet.requireLogin(session);
    try {
      final result = await _testRunsOn(session).testRun(
        owner: wallet,
        draftId: draftId,
        input: input,
      );
      return TestRunResult(
        output: result.output,
        remainingDailyRuns: result.remainingDailyRuns,
      );
    } on domain.InvalidManifest catch (e) {
      throw _invalid(e);
    } on StudioDraftMissing {
      throw Puls3ApiException(code: 'DraftNotFound');
    } on StudioDraftNotOwned {
      throw Puls3ApiException(code: 'DraftNotOwned');
    } on StudioInputTooLong {
      throw Puls3ApiException(code: 'InputTooLong');
    } on StudioTestQuotaExceeded catch (e) {
      throw Puls3ApiException(
        code: 'TestQuotaExceeded',
        details: {'resetsAt': e.resetsAt.toUtc().toIso8601String()},
      );
    } on StudioRuntimeUnavailable {
      throw Puls3ApiException(code: 'RuntimeUnavailable');
    } on StudioRunFailed catch (e) {
      throw Puls3ApiException(
        code: 'AgentExecutionFailed',
        details: {'reason': e.code},
      );
    }
  }

  /// Stores the builder's provider credential for later test runs. The
  /// secret is not returned.
  Future<void> saveProviderCredential(
    Session session,
    String provider,
    String secret,
    String? accountId,
  ) async {
    final wallet = await _wallet.requireLogin(session);
    try {
      await _testRunsOn(session).saveCredential(
        owner: wallet,
        credential: BuilderProviderCredential(
          provider: provider,
          secret: secret,
          accountId: accountId,
        ),
      );
    } on StudioRuntimeUnavailable {
      throw Puls3ApiException(code: 'RuntimeUnavailable');
    }
  }

  /// Prepares `register_full` for [draftId], creating the agent wallet.
  Future<DeploySession> prepareDeploy(
    Session session,
    int draftId,
    String builder,
  ) async {
    final wallet = await _wallet.requireLogin(session);
    _requireBuilder(wallet, builder);
    return _deploy(
      () => _deploysOn(session).prepareDeploy(owner: wallet, draftId: draftId),
    );
  }

  /// Submits the signed `register_full` and returns the session.
  Future<DeploySession> submitRegistration(
    Session session,
    int draftId,
    String preparationId,
    String signedTransactionXdr,
  ) async {
    final wallet = await _wallet.requireLogin(session);
    return _deploy(
      () => _deploysOn(session).submitRegistration(
        owner: wallet,
        draftId: draftId,
        preparationId: preparationId,
        signedTransactionXdr: signedTransactionXdr,
      ),
    );
  }

  /// The current deploy. Refreshes a submitted transaction from the chain.
  Future<DeploySession> getDeploySession(Session session, int draftId) async {
    final wallet = await _wallet.requireLogin(session);
    return _deploy(
      () => _deploysOn(
        session,
      ).getDeploySession(owner: wallet, draftId: draftId),
    );
  }

  /// Prepares the builder's `set_agent_wallet` authorization entry.
  Future<DeploySession> prepareWalletAuthorization(
    Session session,
    int draftId,
  ) async {
    final wallet = await _wallet.requireLogin(session);
    return _deploy(
      () => _deploysOn(
        session,
      ).prepareWalletAuthorization(owner: wallet, draftId: draftId),
    );
  }

  /// Submits the signed authorization entry inside the agent-signed envelope.
  Future<DeploySession> submitWalletAuthorization(
    Session session,
    int draftId,
    String preparationId,
    String signedAuthorizationEntryXdr,
  ) async {
    final wallet = await _wallet.requireLogin(session);
    return _deploy(
      () => _deploysOn(session).submitWalletAuthorization(
        owner: wallet,
        draftId: draftId,
        preparationId: preparationId,
        signedAuthorizationEntryXdr: signedAuthorizationEntryXdr,
      ),
    );
  }

  Future<DeploySession> _deploy(
    Future<StudioDeployRow> Function() call,
  ) async {
    try {
      final row = await call();
      return deploySession(row, _deploysOnNetwork());
    } on StudioDraftMissing {
      throw Puls3ApiException(code: 'DraftNotFound');
    } on StudioDraftNotOwned {
      throw Puls3ApiException(code: 'DraftNotOwned');
    } on domain.InvalidManifest catch (error) {
      throw _invalid(error);
    } on Puls3ApiException {
      rethrow;
    }
  }

  String _deploysOnNetwork() {
    final builder = _deploys;
    if (builder != null) return StellarConfig.testnet.networkPassphrase;
    return (_deployWiring ??= StudioDeployWiring.fromEnvironment())
        .networkPassphrase;
  }

  void _requireBuilder(domain.StellarAddress wallet, String builder) {
    final domain.StellarAddress parsed;
    try {
      parsed = domain.StellarAddress.parse(builder);
    } on domain.InvalidStellarAddress {
      throw Puls3ApiException(code: 'InvalidStellarAddress');
    }
    if (parsed != wallet) throw Puls3ApiException(code: 'WalletMismatch');
  }

  Puls3ApiException _invalid(domain.InvalidManifest error) => Puls3ApiException(
    code: 'InvalidManifest',
    details: {'problems': error.problems.map((p) => p.name).join(',')},
  );
}
