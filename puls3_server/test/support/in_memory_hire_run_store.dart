import 'package:puls3_server/src/runtime/hire_run_store.dart';

/// [HireRunStore] in memory, with the same conditional transitions as the
/// database store. Tests seed queued runs with [enqueue].
final class InMemoryHireRunStore implements HireRunStore {
  final _runs = <int, HireRun>{};
  final _hires = <int, QueuedRun>{};

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
  Future<List<QueuedRun>> listQueued({int limit = 10}) async => [
    for (final run in _runs.values)
      if (run.state == HireRunState.queued) _hires[run.hireId]!,
  ].take(limit).toList();

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
