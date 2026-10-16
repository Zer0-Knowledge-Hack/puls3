import 'package:puls3_domain/puls3_domain.dart';

/// Backend side of the Studio drafts, test runs and "My agents" (#35), shaped
/// after `StudioEndpoint` in docs/architecture/api.md and flows F8, F9 and
/// F11. The server owns drafts per wallet session (#136) and validates the
/// manifest again with the domain rules (#34).
///
/// The demo uses `FakeStudioGateway`; a Serverpod implementation replaces it
/// once the endpoint exists, without touching the screens or their widgets.
abstract interface class StudioGateway {
  /// True for a stand-in that stores nothing on the server and runs no
  /// model. The UI then labels drafts and test runs as a demo.
  bool get isDemo;

  /// Saves [manifest] for [owner] (F8). A new draft when [draftId] is null;
  /// otherwise a new revision of it, refused with [StudioDraftConflict] when
  /// [revision] is not the latest one, unless [overwrite] is set ("Keep
  /// mine").
  ///
  /// [owner] is the connected wallet. The server reads it from the wallet
  /// session; the demo keeps drafts per wallet with it.
  Future<StudioDraft> saveDraft(
    AgentManifestDraft manifest, {
    required String owner,
    int? draftId,
    int? revision,
    bool overwrite = false,
  });

  /// Reads one of [owner]'s drafts, for "Continue editing" (F11-3).
  Future<StudioDraft> getDraft(int draftId, {required String owner});

  /// [owner]'s drafts and deployed agents (F11).
  Future<List<StudioDraft>> listDrafts({required String owner});

  /// Runs a saved, valid draft once on [input] (F9): no payment, nothing on
  /// chain.
  Future<TestRunResult> testRun(
    int draftId,
    String input, {
    required String owner,
  });

  /// Stores the builder's provider credential for later test runs. The
  /// secret is not returned. Workers AI also needs [accountId].
  Future<void> saveProviderCredential({
    required String provider,
    required String secret,
    String? accountId,
    required String owner,
  });

  /// Records the outcome of a deploy started from the Studio. The server
  /// tracks its own deploy sessions (`getDeploySession`), so its adapter
  /// ignores this; the demo needs it to list the agent as live.
  Future<void> recordDeploy(
    int draftId, {
    required String owner,
    required DraftDeployState state,
    String? agentId,
  });
}

/// Where a draft is in its life (`StudioDraft.deployState`).
enum DraftDeployState {
  /// Saved, never deployed.
  draft,

  /// A deploy session is in progress.
  deploying,

  /// The last deploy failed; it can be resumed.
  failed,

  /// Deployed: hirers see [StudioDraft.liveVersion].
  live,
}

/// A saved draft (`StudioDraft` in the API contract).
class StudioDraft {
  const StudioDraft({
    required this.draftId,
    required this.manifest,
    required this.revision,
    this.deployState = DraftDeployState.draft,
    this.liveVersion,
    this.agentId,
    this.retryFromStep,
  });

  final int draftId;
  final AgentManifestDraft manifest;

  /// Increases on every save; a stale one is a [StudioDraftConflict].
  final int revision;
  final DraftDeployState deployState;

  /// The deployed manifest version, once live.
  final int? liveVersion;

  /// The catalog id of the deployed agent, when it is listed.
  final String? agentId;

  /// The deploy step to resume from, when a deploy is in progress or failed
  /// (`DeploySession.retryFromStep`).
  final int? retryFromStep;

  String get name => manifest.name ?? 'Untitled agent';

  /// True when the draft passes every deploy rule, so it can be test-run.
  bool isDeployable(ModelPolicy policy) =>
      manifest.problemsForDeploy(policy).isEmpty;
}

/// The answer of a test run (`TestRunResult`).
class TestRunResult {
  const TestRunResult({required this.output, required this.remainingDailyRuns});

  final String output;
  final int remainingDailyRuns;
}

/// A failure reported by the Studio backend.
sealed class StudioGatewayException implements Exception {
  const StudioGatewayException(this.message);

  /// Safe, user-displayable text.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The server refused the manifest (`InvalidManifest`): the same domain
/// problems the form shows.
final class StudioInvalidDraft extends StudioGatewayException {
  const StudioInvalidDraft(this.problems)
    : super('The server refused the agent: check the fields.');

  final List<ManifestProblem> problems;
}

/// A newer revision was saved elsewhere (`DraftVersionConflict`).
final class StudioDraftConflict extends StudioGatewayException {
  const StudioDraftConflict()
    : super('This draft was saved somewhere else since you opened it.');
}

/// The draft does not exist or belongs to another wallet (`DraftNotFound`,
/// `DraftNotOwned`).
final class StudioDraftNotFound extends StudioGatewayException {
  const StudioDraftNotFound()
    : super('This draft is not available for the connected wallet.');
}

/// Today's free test runs are used (`TestQuotaExceeded`).
final class StudioTestQuotaExceeded extends StudioGatewayException {
  const StudioTestQuotaExceeded({this.resetsAt})
    : super('You used today\'s test runs.');

  /// When the quota resets, if the server says.
  final DateTime? resetsAt;
}

/// The input is longer than the draft accepts (`InputTooLong`).
final class StudioInputTooLong extends StudioGatewayException {
  const StudioInputTooLong()
    : super('The input is longer than this agent accepts.');
}

/// The agent ran and failed (`AgentExecutionFailed`), with a safe reason.
final class StudioRunFailed extends StudioGatewayException {
  const StudioRunFailed(super.message);
}

/// The server, or its test runner, could not be reached
/// (`RuntimeUnavailable`, no answer). Retrying is safe.
final class StudioUnavailable extends StudioGatewayException {
  const StudioUnavailable(super.message);
}
