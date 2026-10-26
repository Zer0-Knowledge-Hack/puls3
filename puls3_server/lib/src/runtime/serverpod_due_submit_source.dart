import 'package:puls3_domain/puls3_domain.dart';
import 'package:serverpod/serverpod.dart';

import '../chain/agent_submit_sender.dart';
import '../generated/protocol.dart';
import '../hire/serverpod_hire_repository.dart';
import 'hire_run_store.dart';

/// [DueSubmitSource] over `hire_run`, `hire` and `hire_payment`.
///
/// Only funded hires with a succeeded run, a job id and a payment payee
/// (the agent wallet that must sign `submit`) are returned.
final class ServerpodDueSubmitSource implements DueSubmitSource {
  ServerpodDueSubmitSource(this._session);

  final Session _session;

  @override
  Future<List<DueSubmit>> list({int limit = 10}) async {
    if (limit < 1) {
      throw ArgumentError.value(limit, 'limit', 'must be at least 1');
    }
    final runs = await HireRunRecord.db.find(
      _session,
      where: (t) => t.state.equals(HireRunState.succeeded.name),
      orderBy: (t) => t.id,
      limit: limit * 3,
    );
    if (runs.isEmpty) return const [];
    final hires = ServerpodHireRepository(_session);
    final due = <DueSubmit>[];
    for (final run in runs) {
      final result = run.result;
      if (result == null) continue;
      final hire = await hires.findHire(run.hireId);
      if (hire == null ||
          hire.status != HireStatus.funded ||
          hire.jobId == null) {
        continue;
      }
      final payment = await HirePaymentRecord.db.findFirstRow(
        _session,
        where: (t) => t.hireId.equals(run.hireId),
      );
      if (payment == null) continue;
      due.add(
        DueSubmit(
          hireId: run.hireId,
          jobId: hire.jobId!,
          provider: StellarAddress.parse(payment.payee),
          result: result,
        ),
      );
      if (due.length >= limit) break;
    }
    return due;
  }
}
