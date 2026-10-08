import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'hire_run_store.dart';

/// PostgreSQL-backed [HireRunStore] using the Serverpod ORM.
///
/// Runs are created by [enqueue], which the hire repository calls in the
/// same transaction that records the hire's payment.
final class ServerpodHireRunStore implements HireRunStore {
  ServerpodHireRunStore(this.session);

  final Session session;

  /// Queues the run of hire [hireId], inside [transaction] when given. The
  /// unique `hireId` index makes a second call fail, which aborts the
  /// transaction that would have recorded a second payment.
  static Future<void> enqueue(
    Session session,
    int hireId,
    DateTime at, {
    Transaction? transaction,
  }) => HireRunRecord.db.insertRow(
    session,
    HireRunRecord(
      hireId: hireId,
      state: HireRunState.queued.name,
      queuedAt: at,
    ),
    transaction: transaction,
  );

  @override
  Future<HireRun?> find(int hireId) async {
    final record = await HireRunRecord.db.findFirstRow(
      session,
      where: (t) => t.hireId.equals(hireId),
    );
    return record == null ? null : _run(record);
  }

  @override
  Future<List<QueuedRun>> listQueued({int limit = 10}) async {
    final runs = await HireRunRecord.db.find(
      session,
      where: (t) => t.state.equals(HireRunState.queued.name),
      orderBy: (t) => t.id,
      limit: limit,
    );
    if (runs.isEmpty) return const [];
    final hires = {
      for (final hire in await HireRecord.db.find(
        session,
        where: (t) => t.id.inSet(runs.map((r) => r.hireId).toSet()),
      ))
        hire.id!: hire,
    };
    return [
      for (final run in runs)
        if (hires[run.hireId] case final hire?)
          QueuedRun(
            hireId: run.hireId,
            agentId: hire.agentId,
            manifestVersion: hire.manifestVersion,
            input: hire.input ?? '',
          ),
    ];
  }

  @override
  Future<List<int>> listRunningStartedBefore(DateTime before) async {
    final runs = await HireRunRecord.db.find(
      session,
      where: (t) =>
          t.state.equals(HireRunState.running.name) &
          (t.startedAt < before.toUtc()),
    );
    return [for (final run in runs) run.hireId];
  }

  @override
  Future<bool> markRunning(int hireId, DateTime at) async {
    final updated = await HireRunRecord.db.updateWhere(
      session,
      columnValues: (t) => [
        t.state(HireRunState.running.name),
        t.startedAt(at.toUtc()),
      ],
      where: (t) =>
          t.hireId.equals(hireId) & t.state.equals(HireRunState.queued.name),
    );
    return updated.isNotEmpty;
  }

  @override
  Future<bool> markSucceeded(int hireId, String result, DateTime at) async {
    final updated = await HireRunRecord.db.updateWhere(
      session,
      columnValues: (t) => [
        t.state(HireRunState.succeeded.name),
        t.result(result),
        t.finishedAt(at.toUtc()),
      ],
      where: (t) =>
          t.hireId.equals(hireId) & t.state.equals(HireRunState.running.name),
    );
    return updated.isNotEmpty;
  }

  @override
  Future<bool> markFailed(int hireId, String reason, DateTime at) async {
    final updated = await HireRunRecord.db.updateWhere(
      session,
      columnValues: (t) => [
        t.state(HireRunState.failed.name),
        t.failureReason(reason),
        t.finishedAt(at.toUtc()),
      ],
      where: (t) =>
          t.hireId.equals(hireId) &
          t.state.inSet({
            HireRunState.queued.name,
            HireRunState.running.name,
          }),
    );
    return updated.isNotEmpty;
  }

  static HireRun _run(HireRunRecord record) => HireRun(
    hireId: record.hireId,
    state: HireRunState.parse(record.state),
    queuedAt: record.queuedAt,
    startedAt: record.startedAt,
    finishedAt: record.finishedAt,
    result: record.result,
    failureReason: record.failureReason,
  );
}
