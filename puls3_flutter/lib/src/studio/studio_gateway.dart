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

  /// Makes [owner]'s live agent [hiringAgentId] hire the catalog agent
  /// [agentId] on [input], paying at most [budgetUsdcStroops] from its own
  /// wallet (#312). The rest of the hire runs on the server: follow it with
  /// [getAgentHire]. Refusals are [StudioAgentHireRefused].
  Future<AgentHireStart> hireAgentAs({
    required int hiringAgentId,
    required int agentId,
    required String input,
    required int budgetUsdcStroops,
    required String owner,
  });

  /// Where the hire [hireId] of [owner]'s agent [hiringAgentId] is.
  /// Read-only, so the app polls it.
  Future<AgentHireProgress> getAgentHire({
    required int hiringAgentId,
    required int hireId,
    required String owner,
  });
}

/// A hire one agent started as the client of another (`AgentHireStarted`).
class AgentHireStart {
  const AgentHireStart({required this.hireId, required this.hiringWallet});

  final int hireId;

  /// The hiring agent's wallet: it pays the hire.
  final String hiringWallet;
}

/// One read of an agent-to-agent hire (`HireDetail`, reduced to what the
/// Studio shows).
class AgentHireProgress {
  const AgentHireProgress({
    required this.hireId,
    this.status,
    this.runtimeStatus,
    this.failureReason,
    this.result,
    this.fundTransaction,
    this.lastPurpose,
    this.lastTransaction,
    this.lastFailed = false,
  });

  final int hireId;

  /// Escrow state: open, funded, submitted, completed, rejected, expired.
  final String? status;

  /// queued, running or failed while the hire is funded.
  final String? runtimeStatus;
  final String? failureReason;

  /// The hired agent's answer, once it delivered it.
  final String? result;

  /// The confirmed `fund` transaction hash: the payment into the escrow.
  final String? fundTransaction;

  /// The latest escrow submission: its purpose (createJob, fund, submit,
  /// complete...) and transaction hash.
  final String? lastPurpose;
  final String? lastTransaction;
  final bool lastFailed;

  /// No later read can change it.
  bool get isFinal =>
      status == 'completed' ||
      status == 'rejected' ||
      status == 'expired' ||
      runtimeStatus == 'failed' ||
      lastFailed;
}

/// Why the server refused an agent-to-agent hire or its read.
enum AgentHireRefusal {
  /// `HiringAgentNotOwned`: not the caller's live agent.
  notOwned,

  /// `SelfHireNotAllowed`.
  selfHire,

  /// `InvalidHire`: empty instructions or a budget that is not positive.
  invalid,

  /// `BudgetExceeded`: the hired agent costs more than the budget.
  budgetExceeded,

  /// `AgentWalletUnavailable`: the agent wallet cannot sign right now.
  walletUnavailable,

  /// `ChainUnavailable`: the Stellar network or its settings.
  chainUnavailable,

  /// `AgentNotFound`, `AgentCannotDeliver`, `AgentHireRefused`.
  agentUnavailable,

  /// `HireNotOwned`, `HireNotFound`: the hire is not this agent's.
  hireNotOwned,
}

/// The server refused an agent-to-agent hire; the UI words [reason].
final class StudioAgentHireRefused extends StudioGatewayException {
  const StudioAgentHireRefused(this.reason)
    : super('The server refused this hire.');

  final AgentHireRefusal reason;
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

/// The builder has no usable provider credential for the draft's model
/// (`CredentialMissing`). Saving a credential in the playground and retrying
/// is safe.
final class StudioCredentialMissing extends StudioGatewayException {
  const StudioCredentialMissing()
    : super('Save a valid provider credential, then run the draft again.');
}

/// The credential the builder tried to save was refused (`CredentialInvalid`):
/// an empty secret or Workers AI without an account id.
final class StudioCredentialInvalid extends StudioGatewayException {
  const StudioCredentialInvalid()
    : super('This provider credential is not valid. Check it and try again.');
}

/// The provider in the credential is not served (`ProviderUnsupported`).
final class StudioProviderUnsupported extends StudioGatewayException {
  const StudioProviderUnsupported()
    : super('This provider is not supported. Pick another model.');
}
