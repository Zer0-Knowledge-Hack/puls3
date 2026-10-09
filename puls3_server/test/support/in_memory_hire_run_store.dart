import 'package:puls3_server/src/runtime/hire_run_store.dart';

/// [HireRunStore] in memory, with the same conditional transitions as the
/// database store. Tests seed queued runs with [enqueue].
final class InMemoryHireRunStore implements HireRunStore {
  final _runs = <int, HireRun>{};
  final _hires = <int, QueuedRun>{};
  final _attempts = <int, int>{};
  final _notBefore = <int, DateTime>{};
  final lastErrors = <int, String>{};

  /// Queues the run of [hire] at [at]. Throws [StateError] when the hire
  /// already has a run, like the unique index.
  void enqueue(QueuedRun hire, DateTime at) {
    if (_runs.containsKey(hire.hireId)) {
      throw StateError('hire ${hire.hireId} already has a run');
    }
    _hires[hire.hireId] = hire;
    _runs[hire.hireId] = HireRun(
      hireId: hire.hireId,
      state: HireRunState.queued,
      queuedAt: at,
    );
  }

  @override
  Future<HireRun?> find(int hireId) async => _runs[hireId];

  @override
  Future<List<QueuedRun>> listQueued({int limit = 10, DateTime? now}) async => [
    for (final run in _runs.values)
      if (run.state == HireRunState.queued &&
          (now == null ||
              _notBefore[run.hireId] == null ||
              !_notBefore[run.hireId]!.isAfter(now)))
        _withAttempts(_hires[run.hireId]!),
  ].take(limit).toList();

  QueuedRun _withAttempts(QueuedRun run) => QueuedRun(
    hireId: run.hireId,
    agentId: run.agentId,
    manifestVersion: run.manifestVersion,
    input: run.input,
    expiredAt: run.expiredAt,
    attempts: _attempts[run.hireId] ?? 0,
  );

  /// Retries recorded for [hireId].
  int attemptsOf(int hireId) => _attempts[hireId] ?? 0;

  /// When a retried run of [hireId] may be taken again.
  DateTime? notBeforeOf(int hireId) => _notBefore[hireId];

  @override
  Future<bool> markRetry(
    int hireId,
    String reason, {
    required DateTime notBefore,
    required DateTime at,
  }) async {
    final run = _runs[hireId];
    if (run == null || run.state != HireRunState.running) return false;
    _runs[hireId] = HireRun(
      hireId: hireId,
      state: HireRunState.queued,
      queuedAt: run.queuedAt,
    );
    _attempts[hireId] = (_attempts[hireId] ?? 0) + 1;
    _notBefore[hireId] = notBefore;
    lastErrors[hireId] = reason;
    return true;
  }

  @override
  Future<List<int>> listRunningStartedBefore(DateTime before) async => [
    for (final run in _runs.values)
      if (run.state == HireRunState.running && run.startedAt!.isBefore(before))
        run.hireId,
  ];

  @override
  Future<bool> markRunning(int hireId, DateTime at) async {
    final run = _runs[hireId];
    if (run == null || run.state != HireRunState.queued) return false;
    _runs[hireId] = HireRun(
      hireId: hireId,
      state: HireRunState.running,
      queuedAt: run.queuedAt,
      startedAt: at,
    );
    return true;
  }

  @override
  Future<bool> markSucceeded(int hireId, String result, DateTime at) async {
    final run = _runs[hireId];
    if (run == null || run.state != HireRunState.running) return false;
    _runs[hireId] = HireRun(
      hireId: hireId,
      state: HireRunState.succeeded,
      queuedAt: run.queuedAt,
      startedAt: run.startedAt,
      finishedAt: at,
      result: result,
    );
    return true;
  }

  @override
  Future<bool> markFailed(int hireId, String reason, DateTime at) async {
    final run = _runs[hireId];
    if (run == null ||
        (run.state != HireRunState.queued &&
            run.state != HireRunState.running)) {
      return false;
    }
    _runs[hireId] = HireRun(
      hireId: hireId,
      state: HireRunState.failed,
      queuedAt: run.queuedAt,
      startedAt: run.startedAt,
      finishedAt: at,
      failureReason: reason,
    );
    return true;
  }
}
