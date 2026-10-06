import 'package:puls3_domain/puls3_domain.dart';
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';

/// PostgreSQL-backed implementation of [HireRepository] using Serverpod ORM.
///
/// A unique violation (SQLSTATE 23505) surfaces as a [DatabaseQueryException]
/// whose `constraintName` is the violated index; [recordPayment] maps the
/// three `hire_payment` indexes to [HirePaymentConflict].
class ServerpodHireRepository implements HireRepository {
  ServerpodHireRepository(this.session);

  final Session session;

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
  Future<Hire?> findById(HireId id) async {
    final hireRecord = await HireRecord.db.findById(session, id.value);
    if (hireRecord == null) return null;

    final paymentRecord = await HirePaymentRecord.db.findFirstRow(
      session,
      where: (t) => t.hireId.equals(id.value),
    );

    final requested = Hire(
      id: HireId(hireRecord.id!),
      agentId: AgentId(hireRecord.agentId),
      consumer: StellarAddress.parse(hireRecord.consumer),
      price: UsdcAmount.stroops(hireRecord.price),
      manifestVersion: hireRecord.manifestVersion,
    );

    if (paymentRecord == null) {
      return requested;
    }

    final payment = Payment(
      transaction: TransactionHash.parse(paymentRecord.transactionHash),
      hireId: requested.id,
      payer: StellarAddress.parse(paymentRecord.payer),
      payee: StellarAddress.parse(paymentRecord.payee),
      amount: UsdcAmount.stroops(paymentRecord.amount),
    );

    return requested.pay(payment, agentWallet: payment.payee);
  }

  @override
  Future<int?> preparedExpiry(HireId id) async =>
      (await HireRecord.db.findById(session, id.value))?.expiredAt;

  @override
  Future<Hire> recordPayment(Hire paid, Payment payment, int jobId) async {
    final paidHire = paid.status == HireStatus.paid
        ? paid
        : paid.pay(payment, agentWallet: payment.payee);

    try {
      await HirePaymentRecord.db.insertRow(
        session,
        HirePaymentRecord(
          hireId: paid.id.value,
          transactionHash: payment.transaction.value,
          jobId: jobId,
          payer: payment.payer.value,
          payee: payment.payee.value,
          amount: payment.amount.stroops,
        ),
      );
      return paidHire;
    } on DatabaseQueryException catch (e) {
      if (e.code != _uniqueViolation) rethrow;
      final index = _indexByName[e.constraintName];
      if (index == null) rethrow;
      if (index == HirePaymentIndex.hireId) {
        final existing = await HirePaymentRecord.db.findFirstRow(
          session,
          where: (t) => t.hireId.equals(paid.id.value),
        );
        if (existing?.transactionHash == payment.transaction.value) {
          return paidHire;
        }
      }
      throw HirePaymentConflict(index);
    }
  }
}

/// SQLSTATE of a unique violation.
const _uniqueViolation = '23505';

/// The unique indexes of `hire_payment`, by the name the migration gives
/// them (`hire_payment.spy.yaml`). Any other violated constraint is not a
/// payment conflict and is rethrown.
const _indexByName = {
  'hire_id': HirePaymentIndex.hireId,
  'transaction_hash': HirePaymentIndex.transactionHash,
  'job_id': HirePaymentIndex.jobId,
};
