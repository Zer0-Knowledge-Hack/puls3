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

  /// Queues a run for every paid hire that has none, and returns how many it
  /// queued. Hires paid before the `hire_run` table existed have a payment
  /// but no run; new payments queue their run in the same transaction. The
  /// runtime calls it once at startup.
  Future<int> enqueueMissing(DateTime at) async {
    final paid = {
      for (final payment in await HirePaymentRecord.db.find(session))
        payment.hireId,
    };
    if (paid.isEmpty) return 0;
    final withRun = {
      for (final run in await HireRunRecord.db.find(
        session,
        where: (t) => t.hireId.inSet(paid),
      ))
        run.hireId,
    };
    var queued = 0;
    for (final hireId in paid.difference(withRun).toList()..sort()) {
      try {
        await enqueue(session, hireId, at.toUtc());
        queued++;
      } on DatabaseQueryException catch (e) {
        // Another instance queued it first: the unique index kept one run.
        // Any other database error is not a duplicate and is rethrown.
        if (!isDuplicateRun(code: e.code, constraintName: e.constraintName)) {
          rethrow;
        }
      }
    }
    return queued;
  }

  @override
  Future<HireRun?> find(int hireId) async {
    final record = await HireRunRecord.db.findFirstRow(
      session,
      where: (t) => t.hireId.equals(hireId),
    );
    return record == null ? null : _run(record);
  }

  @override
  Future<List<QueuedRun>> listQueued({int limit = 10, DateTime? now}) async {
    final runs = await HireRunRecord.db.find(
      session,
      where: (t) {
        final queued = t.state.equals(HireRunState.queued.name);
        if (now == null) return queued;
        return queued &
            (t.notBefore.equals(null) | (t.notBefore <= now.toUtc()));
      },
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
            expiredAt: hire.expiredAt,
            attempts: run.attempts,
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
  Future<bool> markRetry(
    int hireId,
    String reason, {
    required DateTime notBefore,
    required DateTime at,
  }) async {
    final run = await HireRunRecord.db.findFirstRow(
      session,
      where: (t) =>
          t.hireId.equals(hireId) & t.state.equals(HireRunState.running.name),
    );
    if (run == null) return false;
    // Conditional on the attempts read, so two writers count one retry.
    final updated = await HireRunRecord.db.updateWhere(
      session,
      columnValues: (t) => [
        t.state(HireRunState.queued.name),
        t.attempts(run.attempts + 1),
        t.notBefore(notBefore.toUtc()),
        t.lastError(reason),
        t.startedAt(null),
      ],
      where: (t) =>
          t.hireId.equals(hireId) &
          t.state.equals(HireRunState.running.name) &
          t.attempts.equals(run.attempts),
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

/// Whether a failed insert into `hire_run` is the unique violation
/// (SQLSTATE 23505) of `hire_run_hire_idx`: the hire already has its run.
bool isDuplicateRun({required String? code, required String? constraintName}) =>
    code == _uniqueViolation && constraintName == _hireIndex;

/// SQLSTATE of a unique violation.
const _uniqueViolation = '23505';

/// The unique index on `hire_run.hireId` (`hire_run.spy.yaml`).
const _hireIndex = 'hire_run_hire_idx';
