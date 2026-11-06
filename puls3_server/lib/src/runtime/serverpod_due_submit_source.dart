import 'package:puls3_domain/puls3_domain.dart';
import 'package:serverpod/serverpod.dart';

import '../chain/agent_submit_sender.dart';
import '../chain/escrow_deadline.dart';
import '../chain/submission_values.dart';
import '../generated/protocol.dart';
import '../hire/hire_settlement.dart';
import '../hire/serverpod_hire_repository.dart';
import 'hire_run_store.dart';

/// [DueSubmitSource] over `hire_run`, `hire`, `hire_payment`,
/// `chain_submission` and `agent_wallet`.
///
/// Only funded hires with a succeeded run, a job id and a payment payee
/// (the agent wallet that must sign `submit`) are returned.
///
/// A `succeeded` run never changes state, so the oldest runs are not
/// enough: hires that already settled, that used up their `submit`
/// attempts, or whose payee has no custodied wallet would fill the window
/// for good. Runs are read in pages after an id cursor, and each page drops
/// those hires with one query per table before any hire is loaded.
final class ServerpodDueSubmitSource implements DueSubmitSource {
  ServerpodDueSubmitSource(this._session);

  final Session _session;

  @override
  Future<List<DueSubmit>> list({int limit = 10}) async {
    if (limit < 1) {
      throw ArgumentError.value(limit, 'limit', 'must be at least 1');
    }
    final hires = ServerpodHireRepository(_session);
    final due = <DueSubmit>[];
    var after = 0;
    while (due.length < limit) {
      final runs = await HireRunRecord.db.find(
        _session,
        where: (t) =>
            t.state.equals(HireRunState.succeeded.name) & (t.id > after),
        orderBy: (t) => t.id,
        limit: limit * 3,
      );
      if (runs.isEmpty) break;
      after = runs.last.id!;

      final hireIds = {for (final run in runs) run.hireId};
      final closed = await _closedHires(hireIds);
      final payees = {
        for (final payment in await HirePaymentRecord.db.find(
          _session,
          where: (t) => t.hireId.inSet(hireIds),
        ))
          payment.hireId: payment.payee,
      };
      final custodied = await _custodied(payees.values.toSet());

      for (final run in runs) {
        final result = run.result;
        final payee = payees[run.hireId];
        if (result == null ||
            payee == null ||
            closed.contains(run.hireId) ||
            !custodied.contains(payee)) {
          continue;
        }
        final hire = await hires.findHire(run.hireId);
        if (hire == null ||
            hire.status != HireStatus.funded ||
            hire.jobId == null) {
          continue;
        }
        due.add(
          DueSubmit(
            hireId: run.hireId,
            jobId: hire.jobId!,
            provider: StellarAddress.parse(payee),
            result: result,
          ),
        );
        if (due.length >= limit) break;
      }
    }
    return due;
  }

  /// Hires of [hireIds] that will never take a `submit`: one of
  /// [settlementPurposes] confirmed, or [maxEscrowCallAttempts] failed
  /// `submit`s.
  Future<Set<int>> _closedHires(Set<int> hireIds) async {
    final rows = await ChainSubmission.db.find(
      _session,
      where: (t) =>
          t.hireId.inSet(hireIds) &
          t.state.inSet({
            SubmissionState.confirmed.wireName,
            SubmissionState.failed.wireName,
          }) &
          t.purpose.inSet({
            for (final purpose in settlementPurposes) purpose.wireName,
          }),
    );
    final closed = <int>{};
    final failedSubmits = <int, int>{};
    for (final row in rows) {
      final hireId = row.hireId!;
      if (row.state == SubmissionState.confirmed.wireName) {
        closed.add(hireId);
      } else if (row.purpose == SubmissionPurpose.submit.wireName) {
        failedSubmits.update(hireId, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    for (final MapEntry(key: hireId, value: failed) in failedSubmits.entries) {
      if (failed >= maxEscrowCallAttempts) closed.add(hireId);
    }
    return closed;
  }

  /// The addresses of [payees] that have a custodied agent wallet, so the
  /// server can sign their `submit`.
  Future<Set<String>> _custodied(Set<String> payees) async {
    if (payees.isEmpty) return const {};
    final wallets = await AgentWallet.db.find(
      _session,
      where: (t) => t.address.inSet(payees),
    );
    return {for (final wallet in wallets) wallet.address};
  }
}
