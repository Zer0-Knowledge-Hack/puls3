import 'package:puls3_domain/puls3_domain.dart';
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'terminal_job_store.dart';

/// SQLSTATE `unique_violation`.
const _uniqueViolation = '23505';

/// Index name from `terminal_job_fact.spy.yaml`.
const _jobIndex = 'terminal_job_fact_job_idx';

/// PostgreSQL-backed [TerminalJobStore] on the `terminal_job_fact` table.
///
/// The reputation registry that uses it lives for the whole process, so it
/// cannot hold the session of the request that built it:
/// [ServerpodTerminalJobStore.new] opens a session with [open] for each call
/// and closes it, and it does not call [open] until the first use.
/// [ServerpodTerminalJobStore.onSession] uses a session the caller owns
/// (tests).
final class ServerpodTerminalJobStore implements TerminalJobStore {
  ServerpodTerminalJobStore(
    Future<Session> Function() open, {
    DateTime Function()? now,
  }) : _open = open,
       _owned = true,
       _now = now ?? DateTime.now;

  ServerpodTerminalJobStore.onSession(
    Session session, {
    DateTime Function()? now,
  }) : _open = (() async => session),
       _owned = false,
       _now = now ?? DateTime.now;

  final Future<Session> Function() _open;
  final bool _owned;
  final DateTime Function() _now;

  Future<T> _withSession<T>(Future<T> Function(Session session) body) async {
    final session = await _open();
    try {
      return await body(session);
    } finally {
      if (_owned) await session.close();
    }
  }

  @override
  Future<ReferencedJob?> find(StellarAddress escrow, int jobId) =>
      _withSession((session) async {
        final row = await TerminalJobFact.db.findFirstRow(
          session,
          where: (t) => t.escrow.equals(escrow.value) & t.jobId.equals(jobId),
        );
        if (row == null) return null;
        return ReferencedJob(
          client: StellarAddress.parse(row.client),
          agentId: AgentId(row.agentId),
          state: JobState.values.byName(row.state),
        );
      });

  @override
  Future<void> save(StellarAddress escrow, int jobId, ReferencedJob job) =>
      _withSession((session) async {
        try {
          await TerminalJobFact.db.insertRow(
            session,
            TerminalJobFact(
              escrow: escrow.value,
              jobId: jobId,
              client: job.client.value,
              agentId: job.agentId.value,
              state: job.state.name,
              observedAt: _now().toUtc(),
            ),
          );
        } on DatabaseQueryException catch (e) {
          // The first fact read from the chain is the one that stays.
          if (e.code == _uniqueViolation && e.constraintName == _jobIndex) {
            return;
          }
          rethrow;
        }
      });
}
