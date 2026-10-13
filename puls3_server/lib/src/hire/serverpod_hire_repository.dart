import 'package:meta/meta.dart';
import 'package:puls3_domain/puls3_domain.dart';
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart' hide Hire, Payment;
import '../runtime/hire_run_store.dart';
import '../runtime/serverpod_hire_run_store.dart';
import 'hire_lifecycle_store.dart';

/// PostgreSQL-backed implementation of [HireRepository] using Serverpod ORM.
///
/// A unique violation (SQLSTATE 23505) surfaces as a [DatabaseQueryException]
/// whose `constraintName` is the violated index; [recordPayment] maps the
/// three `hire_payment` indexes to [HirePaymentConflict].
///
/// It is also the [HireLifecycleStore]: the relay's view of a hire adds the
/// idempotency key, the input and the escrow job id (design D10).
///
/// Recording a payment also queues the hire's agent run (#20) in the same
/// transaction, so every funded hire has exactly one run.
class ServerpodHireRepository implements HireRepository, HireLifecycleStore {
  ServerpodHireRepository(this.session, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final Session session;
  final DateTime Function() _now;

  @override
  Future<Hire> create({
    required AgentId agentId,
    required StellarAddress consumer,
    required UsdcAmount price,
    required int manifestVersion,
    required int expiredAt,
  }) async {
    final record = await HireRecord.db.insertRow(
      session,
      HireRecord(
        consumer: consumer.value,
        agentId: agentId.value,
        price: price.stroops,
        manifestVersion: manifestVersion,
        expiredAt: expiredAt,
      ),
    );

    return Hire(
      id: HireId(record.id!),
      agentId: agentId,
      consumer: consumer,
      price: price,
      manifestVersion: manifestVersion,
    );
  }

  @override
  Future<HireRow?> findHire(int id) async {
    final record = await HireRecord.db.findById(session, id);
    return record == null ? null : _row(record);
  }

  @override
  Future<HireRow?> findHireByRequest(String consumer, String requestId) async {
    final record = await HireRecord.db.findFirstRow(
      session,
      where: (t) => t.consumer.equals(consumer) & t.requestId.equals(requestId),
    );
    return record == null ? null : _row(record);
  }

  @override
  Future<HireRow> insertHire(NewHire hire, {Transaction? transaction}) async {
    try {
      final record = await HireRecord.db.insertRow(
        session,
        HireRecord(
          consumer: hire.consumer,
          agentId: hire.agentId,
          price: hire.price,
          manifestVersion: hire.manifestVersion,
          expiredAt: hire.expiredAt,
          requestId: hire.requestId,
          input: hire.input,
        ),
        transaction: transaction,
      );
      return _row(record, transaction: transaction);
    } on DatabaseQueryException catch (e) {
      if (e.code == _uniqueViolation && e.constraintName == _requestIndex) {
        throw const HireRequestConflict();
      }
      rethrow;
    }
  }

  @override
  Future<JobBinding> bindJob(
    int hireId,
    int jobId, {
    required int expiredAt,
  }) async {
    final record = await HireRecord.db.findById(session, hireId);
    if (record == null) throw StateError('hire $hireId does not exist');
    if (record.jobId == jobId) return JobBinding.alreadyBound;
    if (record.jobId != null) return JobBinding.taken;
    try {
      final updated = await HireRecord.db.updateWhere(
        session,
        columnValues: (t) => [t.jobId(jobId), t.expiredAt(expiredAt)],
        where: (t) => t.id.equals(hireId) & t.jobId.equals(null),
      );
      if (updated.isNotEmpty) return JobBinding.bound;
    } on DatabaseQueryException catch (e) {
      if (e.code == _uniqueViolation && e.constraintName == _jobIdIndex) {
        return JobBinding.taken;
      }
      rethrow;
    }
    // A concurrent bind won the conditional update.
    final current = await HireRecord.db.findById(session, hireId);
    return current?.jobId == jobId ? JobBinding.alreadyBound : JobBinding.taken;
  }

  /// The wire view of [record]: no status until the job exists, `open`
  /// after, `funded` once a payment is recorded.
  Future<HireRow> _row(HireRecord record, {Transaction? transaction}) async {
    final payment = await HirePaymentRecord.db.findFirstRow(
      session,
      where: (t) => t.hireId.equals(record.id!),
      transaction: transaction,
    );
    return HireRow(
      id: record.id!,
      consumer: record.consumer,
      agentId: record.agentId,
      price: record.price,
      manifestVersion: record.manifestVersion,
      expiredAt: record.expiredAt,
      requestId: record.requestId,
      input: record.input,
      jobId: record.jobId,
      paymentTransaction: payment?.transactionHash,
      status: payment != null
          ? HireStatus.funded
          : record.jobId != null
          ? HireStatus.open
          : null,
    );
  }

  @override
  Future<Hire?> findById(HireId id) async {
    final hireRecord = await HireRecord.db.findById(session, id.value);
    if (hireRecord == null) return null;

    final paymentRecord = await HirePaymentRecord.db.findFirstRow(
      session,
      where: (t) => t.hireId.equals(id.value),
    );

    final open = Hire(
      id: HireId(hireRecord.id!),
      agentId: AgentId(hireRecord.agentId),
      consumer: StellarAddress.parse(hireRecord.consumer),
      price: UsdcAmount.stroops(hireRecord.price),
      manifestVersion: hireRecord.manifestVersion,
    );

    if (paymentRecord == null) {
      return open;
    }

    final payment = Payment(
      transaction: TransactionHash.parse(paymentRecord.transactionHash),
      hireId: open.id,
      payer: StellarAddress.parse(paymentRecord.payer),
      payee: StellarAddress.parse(paymentRecord.payee),
      amount: UsdcAmount.stroops(paymentRecord.amount),
    );

    final funded = open.fund(payment, agentWallet: payment.payee);
    final run = await HireRunRecord.db.findFirstRow(
      session,
      where: (t) => t.hireId.equals(id.value),
    );
    return run == null ? funded : _replayRun(funded, run);
  }

  /// [funded] with its stored run applied through the domain transitions.
  static Hire _replayRun(Hire funded, HireRunRecord run) =>
      switch (HireRunState.parse(run.state)) {
        HireRunState.queued => funded,
        HireRunState.running || HireRunState.succeeded => funded.startRun(),
        HireRunState.failed =>
          (run.startedAt == null ? funded : funded.startRun()).failRun(
            reason: run.failureReason ?? runFailedWithoutReason,
          ),
      };

  @override
  Future<int?> preparedExpiry(HireId id) async =>
      (await HireRecord.db.findById(session, id.value))?.expiredAt;

  @override
  Future<Hire> recordPayment(Hire funded, Payment payment, int jobId) async {
    final fundedHire = funded.status == HireStatus.funded
        ? funded
        : funded.fund(payment, agentWallet: payment.payee);

    try {
      await session.db.transaction((transaction) async {
        await HirePaymentRecord.db.insertRow(
          session,
          HirePaymentRecord(
            hireId: funded.id.value,
            transactionHash: payment.transaction.value,
            jobId: jobId,
            payer: payment.payer.value,
            payee: payment.payee.value,
            amount: payment.amount.stroops,
          ),
          transaction: transaction,
        );
        await ServerpodHireRunStore.enqueue(
          session,
          funded.id.value,
          _now().toUtc(),
          transaction: transaction,
        );
      });
      return fundedHire;
    } on DatabaseQueryException catch (e) {
      final index = hirePaymentIndexOf(
        code: e.code,
        constraintName: e.constraintName,
      );
      if (index == null) rethrow;
      if (index == HirePaymentIndex.hireId) {
        final existing = await HirePaymentRecord.db.findFirstRow(
          session,
          where: (t) => t.hireId.equals(funded.id.value),
        );
        if (existing?.transactionHash == payment.transaction.value) {
          return fundedHire;
        }
      }
      throw HirePaymentConflict(index);
    }
  }
}

/// The `hire_payment` index violated by a database error, or null when the
/// error is not a unique violation (SQLSTATE `23505`) of one of them. The
/// repository rethrows the error in that case.
@visibleForTesting
HirePaymentIndex? hirePaymentIndexOf({
  required String? code,
  required String? constraintName,
}) => code == _uniqueViolation ? _indexByName[constraintName] : null;

/// SQLSTATE of a unique violation.
const _uniqueViolation = '23505';

/// Unique indexes of `hire` (`hire.spy.yaml`).
const _requestIndex = 'hire_consumer_request_idx';
const _jobIdIndex = 'hire_job_id_idx';

/// The unique indexes of `hire_payment`, by the name the migration gives
/// them (`hire_payment.spy.yaml`). Any other violated constraint is not a
/// payment conflict and is rethrown.
const _indexByName = {
  'hire_id': HirePaymentIndex.hireId,
  'transaction_hash': HirePaymentIndex.transactionHash,
  'job_id': HirePaymentIndex.jobId,
};
