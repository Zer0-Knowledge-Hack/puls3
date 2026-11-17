import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/ledger/terminal_job_store.dart';

/// A [TerminalJobStore] in memory, with the same rules as the PostgreSQL one:
/// a stored fact is never replaced.
final class InMemoryTerminalJobStore implements TerminalJobStore {
  final facts = <(String, int), ReferencedJob>{};
  var saves = 0;

  @override
  Future<ReferencedJob?> find(StellarAddress escrow, int jobId) async =>
      facts[(escrow.value, jobId)];

  @override
  Future<void> save(
    StellarAddress escrow,
    int jobId,
    ReferencedJob job,
  ) async {
    saves++;
    facts.putIfAbsent((escrow.value, jobId), () => job);
  }
}
