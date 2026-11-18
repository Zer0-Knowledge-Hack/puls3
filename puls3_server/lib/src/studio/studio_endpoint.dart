import 'dart:io';

import 'package:meta/meta.dart';
import 'package:puls3_domain/puls3_domain.dart' as domain;
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../agent/aes_gcm_secret_cipher.dart';
import '../agent/agent_wallet_custody.dart';
import '../agent/secret_cipher.dart';
import '../agent/wallet_custody_config.dart';
import '../hire/agent_hire_service.dart';
import '../hire/agent_hire_wiring.dart';
import '../hire/hire_endpoint.dart';
import '../hire/hire_query_service.dart';
import '../hire/session_wallet.dart';
import '../ledger/stellar_config.dart';
import 'builder_credential.dart';
import 'studio_deploy_service.dart';
import 'studio_deploy_store.dart';
import 'studio_deploy_transport.dart';
import 'studio_deploy_wiring.dart';
import 'builder_task_runner.dart';
import 'serverpod_builder_credential_store.dart';
import 'serverpod_studio_deploy_store.dart';
import 'serverpod_studio_draft_store.dart';
import 'studio_draft_errors.dart';
import 'studio_draft_service.dart';
import 'studio_draft_transport.dart';
import 'studio_model_policy.dart';
import 'studio_test_errors.dart';
import 'studio_test_run_service.dart';
import 'test_run_quota.dart';

/// Reads a hire as its client [consumer], for [StudioEndpoint.getAgentHire].
typedef AgentHireReader =
    Future<HireDetail> Function(
      Session session,
      domain.StellarAddress consumer,
      int hireId,
    );

/// Drafts and test runs for the signed-in builder (api.md, `StudioEndpoint`).
///
/// The owner is the session wallet. A draft's prompt is returned only to
/// that wallet. A test run of a paid provider uses the builder's credential;
/// a free `workers-ai` run uses the platform account (#318). Neither creates
/// a hire. Deploy prepares `register_full` and `set_agent_wallet` for the
/// same wallet to sign.
class StudioEndpoint extends Endpoint {
  static SessionWallet? _sessionWallet;
  static StudioDraftService Function(Session session)? _services;
  static StudioTestRunService Function(Session session)? _testRuns;
  static StudioDeployService Function(Session session)? _deploys;
  static StudioDeployWiring? _deployWiring;
  static final MemoryTestRunQuota _quota = MemoryTestRunQuota();
  static final MemoryPaidRunQuota _paidQuota = MemoryPaidRunQuota();

  static StudioTeamTestRunner? _teamTestRunner;

  /// Runs free-model (`workers-ai`) test runs on the platform Workers AI
  /// account (#318). The composition root sets it from the team account and
  /// `workersAiApiToken`; null makes a free test run `RuntimeUnavailable`.
  static set teamTestRunner(StudioTeamTestRunner? runner) =>
      _teamTestRunner = runner;
  static BuilderCredentialStore Function(Session session)? _credentialStores;
  static SecretCipher? _credentialCipher;
  static StudioDeployStore Function(Session session)? _deployStores;
  static AgentHireLauncher? _agentHires;
  static AgentHireReader? _agentHireReads;
  static AgentHireWiring? _agentHireWiring;

  /// Replaces where deploys are read for [hireAgentAs], for tests. `null`
  /// restores the Postgres store.
  @visibleForTesting
  static set deployStores(
    StudioDeployStore Function(Session session)? builder,
  ) => _deployStores = builder;

  /// Replaces how [hireAgentAs] starts a hire, for tests. `null` restores
  /// the background hire on the custodied wallet.
  @visibleForTesting
  static set agentHires(AgentHireLauncher? launcher) => _agentHires = launcher;

  /// Replaces how [getAgentHire] reads a hire, for tests. `null` restores
  /// the hire query service of `HireEndpoint`.
  @visibleForTesting
  static set agentHireReads(AgentHireReader? reader) =>
      _agentHireReads = reader;

  static Future<HireDetail> _readHire(
    Session session,
    domain.StellarAddress consumer,
    int hireId,
  ) {
    final override = _agentHireReads;
    if (override != null) return override(session, consumer, hireId);
    final HireQueryService? query;
    try {
      query = HireEndpoint.servicesOf(session).query;
    } on HireConfigurationMissing catch (missing) {
      throw Puls3ApiException(
        code: 'ChainUnavailable',
        details: {'reason': missing.setting},
      );
    }
    if (query == null) throw Puls3ApiException(code: 'ChainUnavailable');
    return query.getHire(consumer, hireId);
  }

  /// Where deploys are read, honouring [deployStores]: `HireEndpoint`
  /// lists the hires of the caller's active agents with it.
  static StudioDeployStore deployStoreOf(Session session) =>
      _deployStoreOn(session);

  static StudioDeployStore _deployStoreOn(Session session) {
    final builder = _deployStores;
    if (builder != null) return builder(session);
    return ServerpodStudioDeployStore(session);
  }

  static AgentHireLauncher _agentHireLauncher() {
    final override = _agentHires;
    if (override != null) return override;
    try {
      return (_agentHireWiring ??= AgentHireWiring.fromEnvironment()).launcher;
    } on AgentWalletCustodyUnavailable {
      throw Puls3ApiException(code: 'AgentWalletUnavailable');
    } on ArgumentError {
      throw Puls3ApiException(code: 'AgentWalletUnavailable');
    } on HireConfigurationMissing catch (missing) {
      throw Puls3ApiException(
        code: 'ChainUnavailable',
        details: {'reason': missing.setting},
      );
    }
  }

  /// The builder credentials in [session]'s database (#235), encrypted with
  /// the custody key. Paid test runs and every paid hire of a Studio agent
  /// read this store. Free `workers-ai` runs use the team account instead.
  ///
  /// Throws [StudioRuntimeUnavailable] when `PULS3_AGENT_WALLET_SECRET_KEY`
  /// is missing or invalid: no credential is stored in plain text or in
  /// memory instead.
  static BuilderCredentialStore credentialsOn(Session session) {
    final override = _credentialStores;
    if (override != null) return override(session);
    return ServerpodBuilderCredentialStore(
      session,
      cipher: _credentialCipher ??= _cipherFromEnvironment(),
    );
  }

  static SecretCipher _cipherFromEnvironment() {
    final WalletCustodyConfig custody;
    try {
      custody = WalletCustodyConfig.fromEnvironment(Platform.environment);
    } on AgentWalletCustodyUnavailable {
      throw const StudioRuntimeUnavailable();
    } on ArgumentError {
      throw const StudioRuntimeUnavailable();
    }
    return AesGcmSecretCipher(
      keys: {custody.keyVersion: custody.secretKey},
      writeKeyVersion: custody.keyVersion,
    );
  }

  /// Replaces where builder credentials are stored, for tests. `null`
  /// restores the encrypted Postgres store.
  @visibleForTesting
  static set credentialStores(
    BuilderCredentialStore Function(Session session)? builder,
  ) => _credentialStores = builder;

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
  /// restores the in-memory quota and the [credentialsOn] store.
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
      paidQuota: _paidQuota,
      credentials: credentialsOn(session),
      policy: studioServerModelPolicy,
      run: runBuilderTask,
      runTeam:
          _teamTestRunner ??
          (_) async => throw const StudioRuntimeUnavailable(),
    );
  }

  static StudioDeployService _deploysOn(Session session) {
    final builder = _deploys;
    if (builder != null) return builder(session);
    try {
      return (_deployWiring ??= StudioDeployWiring.fromEnvironment()).serviceOn(
        session,
      );
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
    } on StudioCredentialMissing {
      throw Puls3ApiException(code: 'CredentialMissing');
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
    } on StudioCredentialInvalid {
      throw Puls3ApiException(code: 'CredentialInvalid');
    } on StudioProviderUnsupported {
      throw Puls3ApiException(code: 'ProviderUnsupported');
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

  /// Makes the caller's live Studio agent [hiringAgentId] hire [agentId] on
  /// [input], spending at most [budgetUsdcStroops] (#312, SOW week 2).
  ///
  /// The hiring agent's custodied wallet signs `create_job`, `fund` and
  /// `complete`; no human signs. Returns once the hire exists; the rest runs
  /// on the server and every tx hash is logged with `[agent-hire]`.
  Future<AgentHireStarted> hireAgentAs(
    Session session,
    int hiringAgentId,
    int agentId,
    String input,
    int budgetUsdcStroops,
  ) async {
    final wallet = await _wallet.requireLogin(session);
    if (hiringAgentId == agentId) {
      throw Puls3ApiException(code: 'SelfHireNotAllowed');
    }
    if (input.trim().isEmpty) {
      throw Puls3ApiException(code: 'InvalidHire', message: 'input is empty');
    }
    if (budgetUsdcStroops <= 0) {
      throw Puls3ApiException(
        code: 'InvalidHire',
        message: 'budget must be positive',
      );
    }
    final deploy = await _deployStoreOn(
      session,
    ).findByRegistryAgent(hiringAgentId);
    if (deploy == null ||
        deploy.owner != wallet.value ||
        deploy.state != 'active') {
      throw Puls3ApiException(code: 'HiringAgentNotOwned');
    }
    final hiringWallet = domain.StellarAddress.parse(deploy.agentWallet);
    final launch = _agentHireLauncher();
    try {
      final hireId = await launch(
        session: session,
        hiringWallet: hiringWallet,
        agentId: agentId,
        input: input,
        budgetUsdcStroops: budgetUsdcStroops,
        requestId:
            'agent-$hiringAgentId-hires-$agentId-'
            '${DateTime.now().toUtc().microsecondsSinceEpoch}',
      );
      return AgentHireStarted(
        hireId: hireId,
        hiringWallet: hiringWallet.value,
        state: 'started',
      );
    } on AgentHireOverBudget catch (e) {
      throw Puls3ApiException(
        code: 'BudgetExceeded',
        details: {
          'priceUsdcStroops': '${e.priceUsdcStroops}',
          'budgetUsdcStroops': '${e.budgetUsdcStroops}',
        },
      );
    } on AgentHireRefused catch (e) {
      throw Puls3ApiException(code: 'AgentHireRefused', message: e.message);
    } on AgentUnavailable {
      throw Puls3ApiException(code: 'AgentNotFound');
    } on AgentCannotDeliver {
      throw Puls3ApiException(code: 'AgentCannotDeliver');
    } on HireRequestInvalid catch (e) {
      throw Puls3ApiException(code: 'InvalidHire', message: e.message);
    } on HireLedgerUnavailable {
      throw Puls3ApiException(code: 'ChainUnavailable');
    }
  }

  /// The hire [hireId] that the caller's live Studio agent [hiringAgentId]
  /// made with [hireAgentAs] (#312), as the hire detail screen shows it:
  /// escrow status, the `fund` and latest escrow transactions and, once
  /// delivered, the hired agent's result. Read-only, so the app polls it.
  ///
  /// The caller must own the active agent, as for [hireAgentAs]
  /// (`HiringAgentNotOwned`), and the hire's client must be that agent's
  /// wallet (`HireNotOwned`).
  Future<HireDetail> getAgentHire(
    Session session,
    int hiringAgentId,
    int hireId,
  ) async {
    final wallet = await _wallet.requireLogin(session);
    final deploy = await _deployStoreOn(
      session,
    ).findByRegistryAgent(hiringAgentId);
    if (deploy == null ||
        deploy.owner != wallet.value ||
        deploy.state != 'active') {
      throw Puls3ApiException(code: 'HiringAgentNotOwned');
    }
    final hiringWallet = domain.StellarAddress.parse(deploy.agentWallet);
    final detail = await _readHire(session, hiringWallet, hireId);
    if (detail.hire.consumer != hiringWallet.value) {
      throw Puls3ApiException(code: 'HireNotOwned');
    }
    return detail;
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
