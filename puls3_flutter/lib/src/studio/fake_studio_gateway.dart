import 'package:puls3_domain/puls3_domain.dart';

import 'studio_gateway.dart';

/// Demo [StudioGateway]: drafts kept in memory per wallet, test runs that
/// echo a canned answer, no network. It stands in for `StudioEndpoint` until
/// #35 ships.
class FakeStudioGateway implements StudioGateway {
  FakeStudioGateway({
    this.delay = const Duration(milliseconds: 400),
    this.dailyRuns = 10,
    this.policy,
    Iterable<(String owner, StudioDraft draft)> seed = const [],
  }) {
    for (final (owner, draft) in seed) {
      _drafts[draft.draftId] = (owner: owner, draft: draft);
      if (draft.draftId >= _nextId) _nextId = draft.draftId + 1;
    }
  }

  @override
  bool get isDemo => true;

  final Duration delay;

  /// Free test runs per wallet and day (ADR-0004 decision 6).
  final int dailyRuns;

  /// The rules test runs check; null accepts any provider and model.
  final ModelPolicy? policy;

  /// Thrown by the next call of each kind, then cleared: lets tests and the
  /// demo console show the error states.
  StudioGatewayException? nextSaveError;
  StudioGatewayException? nextListError;
  StudioGatewayException? nextRunError;

  final Map<int, ({String owner, StudioDraft draft})> _drafts = {};
  final Map<String, int> _runsUsed = {};
  int _nextId = 1;

  @override
  Future<StudioDraft> saveDraft(
    AgentManifestDraft manifest, {
    required String owner,
    int? draftId,
    int? revision,
    bool overwrite = false,
  }) async {
    await Future<void>.delayed(delay);
    _throwIfSet(nextSaveError, () => nextSaveError = null);
    if (draftId == null) {
      final draft = StudioDraft(
        draftId: _nextId++,
        manifest: manifest,
        revision: 1,
      );
      _drafts[draft.draftId] = (owner: owner, draft: draft);
      return draft;
    }
    final current = _owned(draftId, owner);
    if (!overwrite && revision != current.revision) {
      throw const StudioDraftConflict();
    }
    final saved = StudioDraft(
      draftId: draftId,
      manifest: manifest,
      revision: current.revision + 1,
      deployState: current.deployState,
      liveVersion: current.liveVersion,
      agentId: current.agentId,
    );
    _drafts[draftId] = (owner: owner, draft: saved);
    return saved;
  }

  @override
  Future<StudioDraft> getDraft(int draftId, {required String owner}) async {
    await Future<void>.delayed(delay);
    return _owned(draftId, owner);
  }

  @override
  Future<List<StudioDraft>> listDrafts({required String owner}) async {
    await Future<void>.delayed(delay);
    _throwIfSet(nextListError, () => nextListError = null);
    return [
      for (final entry in _drafts.values)
        if (entry.owner == owner) entry.draft,
    ];
  }

  @override
  Future<TestRunResult> testRun(
    int draftId,
    String input, {
    required String owner,
  }) async {
    await Future<void>.delayed(delay);
    _throwIfSet(nextRunError, () => nextRunError = null);
    final draft = _owned(draftId, owner);
    final rules = policy;
    if (rules != null && !draft.isDeployable(rules)) {
      throw StudioInvalidDraft(draft.manifest.problemsForDeploy(rules));
    }
    final max = draft.manifest.inputMaxChars;
    if (max != null && input.length > max) throw const StudioInputTooLong();
    final used = _runsUsed[owner] ?? 0;
    if (used >= dailyRuns) throw const StudioTestQuotaExceeded();
    _runsUsed[owner] = used + 1;
    return TestRunResult(
      output:
          'Demo run: ${draft.name} received ${input.trim().length} '
          'characters. A real test run answers with the agent\'s model once '
          'the Studio server is live.',
      remainingDailyRuns: dailyRuns - used - 1,
    );
  }

  @override
  Future<void> saveProviderCredential({
    required String provider,
    required String secret,
    String? accountId,
    required String owner,
  }) async {}

  @override
  Future<void> recordDeploy(
    int draftId, {
    required String owner,
    required DraftDeployState state,
    String? agentId,
  }) async {
    final current = _owned(draftId, owner);
    final live = state == DraftDeployState.live;
    _drafts[draftId] = (
      owner: owner,
      draft: StudioDraft(
        draftId: draftId,
        manifest: current.manifest,
        revision: current.revision,
        deployState: state,
        liveVersion: live
            ? (current.liveVersion ?? 0) + 1
            : current.liveVersion,
        agentId: agentId ?? current.agentId,
      ),
    );
  }

  StudioDraft _owned(int draftId, String owner) {
    final entry = _drafts[draftId];
    if (entry == null || entry.owner != owner) {
      throw const StudioDraftNotFound();
    }
    return entry.draft;
  }

  void _throwIfSet(StudioGatewayException? error, void Function() clear) {
    if (error == null) return;
    clear();
    throw error;
  }
}
