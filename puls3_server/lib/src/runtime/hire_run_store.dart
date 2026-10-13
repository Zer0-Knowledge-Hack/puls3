import 'package:puls3_domain/puls3_domain.dart' show RuntimeStatus;

/// The failure reason replayed for a failed run stored without one.
const runFailedWithoutReason = 'unknown';

/// The state of one hire's agent run (`hire_run.state`).
enum HireRunState {
  queued,
  running,
  succeeded,
  failed;

  /// The domain [RuntimeStatus] the app shows. A succeeded run stays
  /// `running` until the escrow `submit` lands and the hire is `submitted`
  /// (api.md, "Hire escrow states").
  RuntimeStatus get runtimeStatus => switch (this) {
    HireRunState.queued => RuntimeStatus.queued,
    HireRunState.running || HireRunState.succeeded => RuntimeStatus.running,
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

  /// `running` → `queued` again after a retryable failure: one more attempt,
  /// not taken before [notBefore], with [reason] as the last error. False
  /// when it is not running.
  Future<bool> markRetry(
    int hireId,
    String reason, {
    required DateTime notBefore,
    required DateTime at,
  });

  /// `running` → `succeeded` with [result]. False when it is not running.
  Future<bool> markSucceeded(int hireId, String result, DateTime at);

  /// `queued` or `running` → `failed` with the safe [reason] code. False when
  /// it is in neither state.
  Future<bool> markFailed(int hireId, String reason, DateTime at);
}
