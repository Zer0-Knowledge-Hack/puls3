import 'package:puls3_domain/puls3_domain.dart' show RuntimeStatus;

/// The failure reason replayed for a failed run stored without one.
const runFailedWithoutReason = 'unknown';

/// The state of one hire's agent run (`hire_run.state`).
enum HireRunState {
  queued,
  running,

  /// The loop opened a child hire and stopped (ADR-0011 D8): the loop state
  /// is stored, no model call is open and nothing holds the runtime timeout.
  /// A later pass resumes it once the child finished.
  awaitingChild,
  succeeded,
  failed;

  /// The domain [RuntimeStatus] the app shows. A succeeded run stays
  /// `running` until the escrow `submit` lands and the hire is `submitted`
  /// (api.md, "Hire escrow states"). A run waiting for its child is still
  /// working on the hire, so it shows `running` too: waiting for a
  /// subcontract is run data, not a hire or runtime state (ADR-0011 D7).
  RuntimeStatus get runtimeStatus => switch (this) {
    HireRunState.queued => RuntimeStatus.queued,
    HireRunState.running ||
    HireRunState.awaitingChild ||
    HireRunState.succeeded => RuntimeStatus.running,
    HireRunState.failed => RuntimeStatus.failed,
  };

  static HireRunState parse(String value) =>
      HireRunState.values.firstWhere((s) => s.name == value);
}

/// One hire's run as stored.
final class HireRun {
  const HireRun({
    required this.hireId,
    required this.state,
    required this.queuedAt,
    this.startedAt,
    this.finishedAt,
    this.result,
    this.failureReason,
    this.loopState,
    this.pendingToolCallId,
    this.childHireId,
    this.childRequest,
  });

  final int hireId;
  final HireRunState state;
  final DateTime queuedAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  /// The agent's output, once the run succeeded.
  final String? result;

  /// A safe `RuntimeFailure` code, once the run failed.
  final String? failureReason;

  /// The tool loop's state (`tool_loop_codec.dart`), once the loop paused
  /// or was retried mid-conversation.
  final String? loopState;

  /// The `subcontract` call the paused loop waits on; set only while
  /// [state] is [HireRunState.awaitingChild], like [childHireId] and
  /// [childRequest].
  final String? pendingToolCallId;
  final int? childHireId;

  /// The encoded `ChildRequest`: justification, D10 verdict and ranking.
  final String? childRequest;
}

/// A queued run with the hire data the runner needs.
final class QueuedRun {
  const QueuedRun({
    required this.hireId,
    required this.agentId,
    required this.manifestVersion,
    required this.input,
    required this.expiredAt,
    this.attempts = 0,
    this.reserveStroops = 0,
    this.loopState,
  });

  final int hireId;

  /// The agent's registry id.
  final int agentId;
  final int manifestVersion;

  /// The consumer's task input. Empty for a hire that predates the column.
  final String input;

  /// The escrow job's `expired_at`, in unix seconds. A run that cannot end
  /// before it can never be submitted.
  final int expiredAt;

  /// Retries already made after a retryable provider failure.
  final int attempts;

  /// The subcontract reserve the hire funded, in stroops (0 without one).
  final int reserveStroops;

  /// The loop state a retried tool loop continues from, or `null` to start.
  final String? loopState;
}

/// A run waiting for its child, with what the runner needs to resume it.
final class AwaitingRun {
  const AwaitingRun({
    required this.hireId,
    required this.agentId,
    required this.manifestVersion,
    required this.input,
    required this.expiredAt,
    required this.attempts,
    required this.reserveStroops,
    required this.loopState,
    required this.pendingToolCallId,
    required this.childHireId,
    required this.childRequest,
  });

  final int hireId;
  final int agentId;
  final int manifestVersion;
  final String input;

  /// See [QueuedRun.expiredAt].
  final int expiredAt;
  final int attempts;
  final int reserveStroops;
  final String loopState;
  final String pendingToolCallId;
  final int childHireId;
  final String childRequest;
}

/// Persists agent runs. Every transition is one conditional write, so a
/// second runner, or a retry after a crash, never moves a run twice.
abstract interface class HireRunStore {
  /// The run of hire [hireId], or `null` when it has none.
  Future<HireRun?> find(int hireId);

  /// Up to [limit] queued runs, oldest first. With [now], runs waiting for a
  /// retry (`notBefore` after [now]) are left out.
  Future<List<QueuedRun>> listQueued({int limit = 10, DateTime? now});

  /// The hire ids of runs still `running` that started before [before].
  Future<List<int>> listRunningStartedBefore(DateTime before);

  /// `queued` → `running`. False when the run is not queued (another runner
  /// took it, or it does not exist).
  Future<bool> markRunning(int hireId, DateTime at);

  /// The runs in [HireRunState.awaitingChild], up to [limit], oldest first.
  Future<List<AwaitingRun>> listAwaitingChild({int limit = 10});

  /// `running` → `queued` again after a retryable failure: one more attempt,
  /// not taken before [notBefore], with [reason] as the last error. A
  /// [loopState] replaces the stored one, so the next attempt continues the
  /// conversation; without it the stored one is kept. False when it is not
  /// running.
  Future<bool> markRetry(
    int hireId,
    String reason, {
    required DateTime notBefore,
    required DateTime at,
    String? loopState,
  });

  /// `running` → `awaitingChild`, storing the loop state, the pending call,
  /// the child hire and its encoded request. False when it is not running.
  Future<bool> markAwaitingChild(
    int hireId, {
    required String loopState,
    required String pendingToolCallId,
    required int childHireId,
    required String childRequest,
    required DateTime at,
  });

  /// `awaitingChild` → `running` at [at] (the stale sweep counts from it),
  /// clearing the pending call, child hire and request; the loop state is
  /// kept for a retry. False when it is not awaiting.
  Future<bool> markResumed(int hireId, DateTime at);

  /// `running` → `succeeded` with [result]. False when it is not running.
  Future<bool> markSucceeded(int hireId, String result, DateTime at);

  /// `queued`, `running` or `awaitingChild` → `failed` with the safe
  /// [reason] code. False when it is in none of them.
  Future<bool> markFailed(int hireId, String reason, DateTime at);
}
