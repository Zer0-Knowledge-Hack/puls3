import 'package:puls3_domain/puls3_domain.dart';

/// The facts of escrow jobs the server read in a final state, kept so a
/// rating still counts after the job's entry archives (#273).
///
/// A job in a final state (`Completed`, `Rejected`, `Expired`) never changes
/// again, so a stored fact is a cache of the chain, not a second source of
/// truth: readers consult it only when `get_job` says the entry is archived,
/// never to overrule a job they can read.
abstract interface class TerminalJobStore {
  /// The fact stored for [jobId] on [escrow], or null when there is none.
  Future<ReferencedJob?> find(StellarAddress escrow, int jobId);

  /// Stores [job], read from [escrow] as job [jobId] in a final state. A fact
  /// already stored for that job is kept: the first one is the one read from
  /// the chain, and a final state does not change.
  Future<void> save(StellarAddress escrow, int jobId, ReferencedJob job);
}
