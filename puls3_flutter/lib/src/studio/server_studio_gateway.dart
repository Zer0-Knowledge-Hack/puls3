import 'dart:async';

import 'package:puls3_client/puls3_client.dart' as api;
import 'package:puls3_domain/puls3_domain.dart';

import '../hire/wallet_session.dart';
import '../wallet/wallet_port.dart';
import 'studio_gateway.dart';

/// `client.studio.saveDraft`.
typedef SaveDraftCall =
    Future<api.StudioDraft> Function(
      api.AgentManifestDraft draft,
      int? draftId,
      int? revision,
      bool? overwrite,
    );

/// `client.studio.getDraft`.
typedef GetDraftCall = Future<api.StudioDraft> Function(int draftId);

/// `client.studio.listDrafts`.
typedef ListDraftsCall = Future<List<api.StudioDraft>> Function();

/// `client.studio.testRun`.
typedef TestRunCall =
    Future<api.TestRunResult> Function(int draftId, String input);

/// `client.studio.saveProviderCredential`.
typedef SaveProviderCredentialCall =
    Future<void> Function(String provider, String secret, String? accountId);

/// [StudioGateway] over `StudioEndpoint` (#35).
///
/// The session wallet is the owner. [signChallenge] signs the SEP-10
/// challenge the first time a wallet is used, the same session hire uses.
/// A test run waits longer than a draft save because the model call can
/// take the runtime timeout. [recordDeploy] does nothing: the server will
/// track its own deploy session.
class ServerStudioGateway implements StudioGateway {
  ServerStudioGateway({
    required this._saveDraft,
    required this._getDraft,
    required this._listDrafts,
    required this._testRun,
    required this._saveProviderCredential,
    required this._wallet,
    this._session,
    this.callTimeout = const Duration(seconds: 30),
    this.testRunTimeout = const Duration(seconds: 150),
  });

  final SaveDraftCall _saveDraft;
  final GetDraftCall _getDraft;
  final ListDraftsCall _listDrafts;
  final TestRunCall _testRun;
  final SaveProviderCredentialCall _saveProviderCredential;
  final WalletPort _wallet;
  final WalletSession? _session;
  final Duration callTimeout;

  /// Longer than [callTimeout]: a model run may use the 120s runtime limit.
  final Duration testRunTimeout;

  @override
  bool get isDemo => false;

  @override
  Future<StudioDraft> saveDraft(
    AgentManifestDraft manifest, {
    required String owner,
    int? draftId,
    int? revision,
    bool overwrite = false,
  }) async {
    await _signedIn(owner);
    final saved = await _call(
      () => _saveDraft(
        _protocolDraft(manifest),
        draftId,
        revision,
        overwrite,
      ),
    );
    return _draft(saved);
  }

  @override
  Future<StudioDraft> getDraft(int draftId, {required String owner}) async {
    await _signedIn(owner);
    return _draft(await _call(() => _getDraft(draftId)));
  }

  @override
  Future<List<StudioDraft>> listDrafts({required String owner}) async {
    await _signedIn(owner);
    final drafts = await _call(_listDrafts);
    return [for (final draft in drafts) _draft(draft)];
  }

  @override
  Future<TestRunResult> testRun(
    int draftId,
    String input, {
    required String owner,
  }) async {
    await _signedIn(owner);
    final result = await _call(
      () => _testRun(draftId, input),
      timeout: testRunTimeout,
    );
    return TestRunResult(
      output: result.output,
      remainingDailyRuns: result.remainingDailyRuns,
    );
  }

  @override
  Future<void> saveProviderCredential({
    required String provider,
    required String secret,
    String? accountId,
    required String owner,
  }) async {
    await _signedIn(owner);
    await _call(() => _saveProviderCredential(provider, secret, accountId));
  }

  @override
  Future<void> recordDeploy(
    int draftId, {
    required String owner,
    required DraftDeployState state,
    String? agentId,
  }) async {}

  Future<void> _signedIn(String owner) async {
    final session = _session;
    if (session == null) return;
    try {
      await session.ensureSignedIn(owner, _wallet.signChallenge);
    } on WalletException {
      throw const StudioUnavailable(
        'Sign in with your wallet, then try again.',
      );
    }
  }

  Future<T> _call<T>(Future<T> Function() call, {Duration? timeout}) async {
    try {
      return await call().timeout(timeout ?? callTimeout);
    } on api.Puls3ApiException catch (e) {
      throw _map(e);
    } on StudioGatewayException {
      rethrow;
    } on TimeoutException {
      throw const StudioUnavailable('The puls3 server did not answer.');
    } on api.ServerpodClientException {
      throw const StudioUnavailable('The puls3 server did not answer.');
    }
  }

  StudioGatewayException _map(api.Puls3ApiException error) =>
      switch (error.code) {
        'InvalidManifest' => StudioInvalidDraft(
          _problems(error.details?['problems']),
        ),
        'DraftVersionConflict' => const StudioDraftConflict(),
        'DraftNotFound' || 'DraftNotOwned' => const StudioDraftNotFound(),
        'InputTooLong' => const StudioInputTooLong(),
        'TestQuotaExceeded' => StudioTestQuotaExceeded(
          resetsAt: DateTime.tryParse(error.details?['resetsAt'] ?? ''),
        ),
        'RuntimeUnavailable' => const StudioUnavailable(
          'The test runner is unavailable.',
        ),
        'AgentExecutionFailed' => StudioRunFailed(
          error.details?['reason'] ?? 'The agent run failed.',
        ),
        'NotAuthenticated' ||
        'AuthenticationUnavailable' => const StudioUnavailable(
          'Sign in with your wallet, then try again.',
        ),
        _ => StudioUnavailable(
          error.message ?? 'The server refused this draft.',
        ),
      };

  List<ManifestProblem> _problems(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    return [
      for (final name in raw.split(','))
        for (final problem in ManifestProblem.values)
          if (problem.name == name) problem,
    ];
  }

  StudioDraft _draft(api.StudioDraft draft) => StudioDraft(
    draftId: draft.draftId,
    manifest: _manifest(draft.manifest),
    revision: draft.revision,
    deployState: switch (draft.deployState) {
      'deploying' => DraftDeployState.deploying,
      'failed' => DraftDeployState.failed,
      'live' => DraftDeployState.live,
      _ => DraftDeployState.draft,
    },
    liveVersion: draft.liveVersion,
    agentId: draft.agentId,
    retryFromStep: draft.retryFromStep,
  );

  AgentManifestDraft _manifest(api.AgentManifestDraft draft) {
    final skills = draft.skills;
    final model = draft.model;
    final price = draft.price;
    return AgentManifestDraft(
      name: draft.name,
      description: draft.description,
      skills: skills == null
          ? null
          : [
              for (final skill in skills)
                Skill(
                  id: skill.id,
                  name: skill.name,
                  description: skill.description ?? '',
                  tags: skill.tags ?? const [],
                ),
            ],
      model: model == null
          ? null
          : ModelId(provider: model.provider, id: model.id),
      systemPrompt: draft.systemPrompt,
      inputType: draft.inputType == null
          ? null
          : InputType.values.byName(draft.inputType!),
      inputMaxChars: draft.inputMaxChars,
      outputType: draft.outputType == null
          ? null
          : OutputType.values.byName(draft.outputType!),
      outputMaxChars: draft.outputMaxChars,
      price: price == null ? null : UsdcAmount.stroops(price.amount),
    );
  }

  api.AgentManifestDraft _protocolDraft(AgentManifestDraft manifest) {
    final skills = manifest.skills;
    final model = manifest.model;
    final price = manifest.price;
    return api.AgentManifestDraft(
      name: manifest.name,
      description: manifest.description,
      skills: skills == null
          ? null
          : [
              for (final skill in skills)
                api.ManifestSkill(
                  id: skill.id,
                  name: skill.name,
                  description: skill.description,
                  tags: skill.tags,
                ),
            ],
      model: model == null
          ? null
          : api.ManifestModel(provider: model.provider, id: model.id),
      systemPrompt: manifest.systemPrompt,
      inputType: manifest.inputType?.name,
      inputMaxChars: manifest.inputMaxChars,
      outputType: manifest.outputType?.name,
      outputMaxChars: manifest.outputMaxChars,
      price: price == null
          ? null
          : api.ManifestPrice(asset: 'USDC', amount: price.stroops),
    );
  }
}
