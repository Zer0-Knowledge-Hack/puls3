import 'package:puls3_domain/puls3_domain.dart';

import '../ledger/escrow_job.dart';
import '../ledger/invoked_contract.dart';
import '../ledger/ledger_errors.dart';

/// A hire bound to an escrow job, with no escrow stored (it predates the
/// `hire.escrow` column of #273).
typedef HireWithoutEscrow = ({
  int hireId,
  int jobId,
  String consumer,
  int agentId,
});

/// The hire rows the backfill reads and writes.
abstract interface class HireEscrowRows {
  /// Every hire with a job id and no escrow, oldest first.
  Future<List<HireWithoutEscrow>> withoutEscrow();

  /// Stores [escrow] on [hireId] only while its escrow is still empty, and
  /// says whether it did. A hire that has its own escrow is never changed.
  Future<bool> setEscrowIfEmpty(int hireId, String escrow);

  /// The signed envelope of [hireId]'s confirmed `create_job` submission, or
  /// `null` when it has none. The server stores it when it relays the call.
  Future<String?> confirmedCreateJobEnvelope(int hireId);
}

/// What the backfill found for one hire.
enum BackfillOutcome {
  /// The job is on this escrow, for the same client and agent.
  matched,

  /// This escrow has no job with that id.
  noSuchJob,

  /// This escrow has a job with that id, for another client or agent: the
  /// hire was funded on another escrow.
  otherJob,

  /// The job is archived on this escrow, so `get_job` cannot be read, but
  /// the hire's confirmed `create_job` envelope invoked this escrow: the job
  /// was created here (#384 review).
  matchedFromEnvelope,

  /// The job is archived on this escrow and no confirmed `create_job`
  /// envelope of the hire names it, so it cannot be checked.
  archived,
}

/// One hire and what the backfill did with it.
typedef BackfillLine = ({
  HireWithoutEscrow hire,
  BackfillOutcome outcome,
  bool written,
});

/// Fills `hire.escrow` for hires that predate the column, so they keep their
/// escrow after the configured one is rotated (#307, ADR-0009).
///
/// It is run once per environment, before its first escrow rotation, with the
/// escrow those hires were funded on passed in. No address is written by a
/// migration, so a database whose hires came from another escrow (a local or
/// test one) is never given the wrong one.
///
/// Each hire is checked against the chain first: its escrow is written only
/// when [jobs] (reading [escrow]) has that job id for the same client and
/// agent. Anything else stays empty and is reported, so a wrong address
/// writes nothing. A hire that already has an escrow is never read or
/// changed. Without [apply] nothing is written at all.
///
/// A chain that cannot be read stops the run with the [LedgerException]; the
/// rows written before it stay correct, and a rerun skips them.
final class HireEscrowBackfill {
  HireEscrowBackfill({
    required HireEscrowRows rows,
    required EscrowJobReader jobs,
    required this.escrow,
  }) : _rows = rows,
       _jobs = jobs;

  final HireEscrowRows _rows;
  final EscrowJobReader _jobs;

  /// The escrow the hires are checked against, and written when they match.
  final StellarAddress escrow;

  Future<List<BackfillLine>> run({required bool apply}) async {
    final lines = <BackfillLine>[];
    for (final hire in await _rows.withoutEscrow()) {
      final outcome = await _check(hire);
      final matched =
          outcome == BackfillOutcome.matched ||
          outcome == BackfillOutcome.matchedFromEnvelope;
      final written =
          apply &&
          matched &&
          await _rows.setEscrowIfEmpty(hire.hireId, escrow.value);
      lines.add((hire: hire, outcome: outcome, written: written));
    }
    return lines;
  }

  Future<BackfillOutcome> _check(HireWithoutEscrow hire) async {
    final EscrowJob? job;
    try {
      job = await _jobs.escrowJob(hire.jobId);
    } on LedgerUnavailable catch (e) {
      if (!e.archived) rethrow;
      return await _createdHere(hire.hireId)
          ? BackfillOutcome.matchedFromEnvelope
          : BackfillOutcome.archived;
    }
    if (job == null) return BackfillOutcome.noSuchJob;
    final sameHire =
        job.client.value == hire.consumer && job.agentId.value == hire.agentId;
    return sameHire ? BackfillOutcome.matched : BackfillOutcome.otherJob;
  }

  /// Whether [hireId]'s confirmed `create_job` invoked [escrow]. An archived
  /// job cannot be read, but the envelope that created it is stored.
  Future<bool> _createdHere(int hireId) async {
    final envelope = await _rows.confirmedCreateJobEnvelope(hireId);
    if (envelope == null) return false;
    final call = invokedCallOf(envelope);
    return call != null &&
        call.function == 'create_job' &&
        call.contract == escrow;
  }
}
