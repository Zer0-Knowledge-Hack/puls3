import 'package:puls3_domain/puls3_domain.dart' show HireStatus;
import 'package:puls3_server/src/hire/child_job_store.dart';
import 'package:puls3_server/src/hire/hire_lifecycle_store.dart';
import 'package:puls3_server/src/hire/hire_receipt_store.dart';

import 'in_memory_hire_lifecycle_store.dart';
import 'in_memory_hire_receipt_store.dart';

/// In-memory [ChildJobStore] over an in-memory hire and receipt store, with
/// the same rules as the Serverpod one. [payments] and [queued] stand in for
/// `hire_payment` and `hire_run`.
final class InMemoryChildJobStore implements ChildJobStore {
  InMemoryChildJobStore(this._hires, this._receipts);

  final InMemoryHireLifecycleStore _hires;
  final InMemoryHireReceiptStore _receipts;

  /// The payment recorded for each child hire, by hire id.
  final payments = <int, ChildJobOpening>{};

  /// The hire ids whose run was queued, in order.
  final queued = <int>[];

  @override
  Future<ChildJobOpened> open(ChildJobOpening opening) async {
    final id = opening.childHireId;
    final hire = await _hires.findHire(id);
    if (hire == null) throw StateError('hire $id does not exist');
    final paid = payments[id];
    if (paid != null) {
      return paid.transactionHash == opening.transactionHash &&
              hire.jobId == opening.jobId
          ? ChildJobOpened.alreadyOpened
          : ChildJobOpened.taken;
    }
    final paidElsewhere = payments.values.any(
      (p) =>
          p.transactionHash == opening.transactionHash ||
          p.jobId == opening.jobId,
    );
    final line = await _receipts.findByChildHire(id);
    if (hire.jobId != null ||
        paidElsewhere ||
        line?.state != ReceiptLineState.pending) {
      return ChildJobOpened.taken;
    }
    final binding = await _hires.bindJob(
      id,
      opening.jobId,
      expiredAt: opening.expiredAt,
      escrow: opening.escrow,
    );
    if (binding != JobBinding.bound) return ChildJobOpened.taken;
    await _receipts.markOpened(
      id,
      childJobId: opening.jobId,
      createTransaction: opening.transactionHash,
      state: HireStatus.funded.name,
    );
    payments[id] = opening;
    queued.add(id);
    _hires.statusOverride[id] = HireStatus.funded;
    return ChildJobOpened.opened;
  }
}
