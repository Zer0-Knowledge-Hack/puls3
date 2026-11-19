import 'package:puls3_domain/puls3_domain.dart' show HireStatus;
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart' show HirePaymentRecord, HireRecord;
import '../runtime/serverpod_hire_run_store.dart';
import 'child_job_store.dart';
import 'serverpod_hire_receipt_store.dart';

/// PostgreSQL-backed [ChildJobStore] on `hire`, `hire_payment`, `hire_run`
/// and `hire_receipt_line`.
///
/// The writes run in one transaction. A conditional write that finds the
/// child already bound or its line no longer `pending`, and a unique
/// violation of `hire_payment` or `hire_run` (a concurrent tracker won),
/// roll everything back; the store then reads what is stored to answer
/// [ChildJobOpened.alreadyOpened] or [ChildJobOpened.taken].
final class ServerpodChildJobStore implements ChildJobStore {
  ServerpodChildJobStore(this._session, {DateTime Function()? now})
    : _now = now ?? DateTime.now,
      _receipts = ServerpodHireReceiptStore(_session);

  final Session _session;
  final DateTime Function() _now;
  final ServerpodHireReceiptStore _receipts;

  @override
  Future<ChildJobOpened> open(ChildJobOpening opening) async {
    final before = await _stored(opening);
    if (before != null) return before;
    try {
      return await _session.db.transaction((transaction) async {
        final id = opening.childHireId;
        final bound = await HireRecord.db.updateWhere(
          _session,
          columnValues: (t) => [
            t.jobId(opening.jobId),
            t.expiredAt(opening.expiredAt),
            t.escrow(opening.escrow),
          ],
          where: (t) => t.id.equals(id) & t.jobId.equals(null),
          transaction: transaction,
        );
        if (bound.isEmpty) throw const _NotOpenable();
        await HirePaymentRecord.db.insertRow(
          _session,
          HirePaymentRecord(
            hireId: id,
            transactionHash: opening.transactionHash,
            jobId: opening.jobId,
            payer: opening.payer,
            payee: opening.payee,
            amount: opening.amount,
          ),
          transaction: transaction,
        );
        await ServerpodHireRunStore.enqueue(
          _session,
          id,
          _now().toUtc(),
          transaction: transaction,
        );
        final line = await _receipts.markOpened(
          id,
          childJobId: opening.jobId,
          createTransaction: opening.transactionHash,
          state: HireStatus.funded.name,
          transaction: transaction,
        );
        if (!line) throw const _NotOpenable();
        return ChildJobOpened.opened;
      });
    } on _NotOpenable {
      return await _stored(opening) ?? ChildJobOpened.taken;
    } on DatabaseQueryException catch (e) {
      if (e.code != _uniqueViolation) rethrow;
      return await _stored(opening) ?? ChildJobOpened.taken;
    }
  }

  /// What is already stored for the child: [ChildJobOpened.alreadyOpened]
  /// when it holds this job and is paid by this transaction,
  /// [ChildJobOpened.taken] when it holds another job or payment, `null`
  /// when it is not opened yet.
  Future<ChildJobOpened?> _stored(ChildJobOpening opening) async {
    final id = opening.childHireId;
    final hire = await HireRecord.db.findById(_session, id);
    if (hire == null) throw StateError('hire $id does not exist');
    final payment = await HirePaymentRecord.db.findFirstRow(
      _session,
      where: (t) => t.hireId.equals(id),
    );
    if (payment != null) {
      return payment.transactionHash == opening.transactionHash &&
              hire.jobId == opening.jobId
          ? ChildJobOpened.alreadyOpened
          : ChildJobOpened.taken;
    }
    return hire.jobId == null ? null : ChildJobOpened.taken;
  }
}

/// Rolls the opening back when a conditional write changed nothing.
final class _NotOpenable implements Exception {
  const _NotOpenable();
}

/// SQLSTATE of a unique violation.
const _uniqueViolation = '23505';
