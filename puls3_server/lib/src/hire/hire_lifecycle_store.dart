import 'package:puls3_domain/puls3_domain.dart' show HireStatus;
import 'package:serverpod/serverpod.dart' show Transaction;

import '../generated/protocol.dart' show Hire;

/// A hire to persist. Every field is required: the relay always has an
/// idempotency key and the consumer's input.
final class NewHire {
  const NewHire({
    required this.consumer,
    required this.agentId,
    required this.price,
    required this.manifestVersion,
    required this.expiredAt,
    required this.requestId,
    required this.input,
  });

  /// StrKey of the session wallet.
  final String consumer;
  final int agentId;

  /// USDC stroops.
  final int price;
  final int manifestVersion;

  /// Unix seconds: the `expired_at` the first `create_job` is prepared with.
  final int expiredAt;

  /// Client idempotency key, unique per [consumer].
  final String? requestId;
  final String input;
}

/// A persisted hire as the relay reads it.
final class HireRow {
  const HireRow({
    required this.id,
    required this.consumer,
    required this.agentId,
    required this.price,
    required this.manifestVersion,
    required this.expiredAt,
    required this.requestId,
    required this.input,
    required this.jobId,
    required this.paymentTransaction,
    required this.status,
  });

  final int id;
  final String consumer;
  final int agentId;
  final int price;
  final int manifestVersion;
  final int expiredAt;

  /// Null for a hire that predates the idempotency key.
  final String? requestId;

  /// Null for a hire that predates the input column.
  final String? input;

  /// The escrow job id, bound once the `create_job` is confirmed.
  final int? jobId;

  /// The `fund` transaction hash, once the hire is funded.
  final String? paymentTransaction;

  /// The wire status (api.md, "Hire escrow states"): null until the job
  /// exists, then `open`, and `funded` once a payment is recorded.
  final HireStatus? status;

  /// The client-visible hire: no runtime or feedback fields, which this
  /// store does not track yet.
  Hire toProtocol() => Hire(
    id: id,
    agentId: agentId,
    consumer: consumer,
    price: price,
    manifestVersion: manifestVersion,
    status: status?.name,
    paymentTransaction: paymentTransaction,
  );
}

/// An insert reused a `(consumer, requestId)` pair.
final class HireRequestConflict implements Exception {
  const HireRequestConflict();

  @override
  String toString() => 'HireRequestConflict';
}

/// The outcome of [HireLifecycleStore.bindJob].
enum JobBinding {
  /// The hire now holds the job id.
  bound,

  /// The hire already held this very job id: the effect was applied before.
  alreadyBound,

  /// Another hire holds the job id, or this hire holds another one.
  taken,
}

/// Hire data the escrow relay needs beyond the domain `HireRepository`
/// (design D10): the idempotency key, the input and the escrow job id.
abstract interface class HireLifecycleStore {
  /// The hire with [id], or `null`.
  Future<HireRow?> findHire(int id);

  /// The hire [consumer] created with [requestId], or `null`.
  Future<HireRow?> findHireByRequest(String consumer, String requestId);

  /// Stores [hire] with no job id and returns it. Joins [transaction] when
  /// given.
  ///
  /// Throws [HireRequestConflict] when the consumer already used the
  /// request id; a database store then aborts [transaction], which the
  /// caller must roll back.
  Future<HireRow> insertHire(NewHire hire, {Transaction? transaction});

  /// Binds [jobId] and the job's [expiredAt] to hire [hireId] unless the
  /// hire has a job. One conditional write, so applying it twice, or from
  /// two trackers, binds once.
  ///
  /// Throws [StateError] when the hire does not exist.
  Future<JobBinding> bindJob(int hireId, int jobId, {required int expiredAt});
}
