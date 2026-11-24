import 'package:puls3_domain/puls3_domain.dart' show HireStatus;
import 'package:serverpod/serverpod.dart' show Transaction;

import '../generated/protocol.dart' show Hire;

/// A hire to persist. The relay always has an idempotency key and the
/// consumer's input. The subcontract fields (ADR-0011) default to a hire
/// that never subcontracts.
final class NewHire {
  const NewHire({
    required this.consumer,
    required this.agentId,
    required this.price,
    required this.manifestVersion,
    required this.expiredAt,
    required this.requestId,
    required this.input,
    this.subcontractReserve = 0,
    this.allowRelatedParty = true,
    this.parentHireId,
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

  /// USDC stroops the consumer funds beside [price] for child jobs
  /// (`fund_with_reserve`, ADR-0011 D1); 0 never subcontracts.
  final int subcontractReserve;

  /// Whether the agent may subcontract an agent of the same owner (D10).
  final bool allowRelatedParty;

  /// The hire whose reserve funds this child hire (D7).
  final int? parentHireId;
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
    this.escrow,
    required this.paymentTransaction,
    required this.status,
    this.subcontractReserve = 0,
    this.allowRelatedParty = true,
    this.parentHireId,
    this.payee,
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

  /// The StrKey of the escrow contract that holds [jobId], bound with it
  /// (#273). Null for a hire without a job, and for a hire that predates the
  /// column: it then means the escrow configured at that moment (#307).
  final String? escrow;

  /// The `fund` transaction hash, once the hire is funded.
  final String? paymentTransaction;

  /// The agent wallet that received the `fund`, once the hire is funded.
  final String? payee;

  /// The wire status (api.md, "Hire escrow states"): null until the job
  /// exists, then `open`, and `funded` once a payment is recorded.
  ///
  /// A funded hire then reads `submitted`, `completed`, `rejected` or
  /// `expired` from confirmed escrow submissions (`submit`, `complete` /
  /// `release`, `reject`, `claim_refund`). That status is derived on read
  /// from `chain_submission` instead of stored; the store has no write
  /// for it.
  final HireStatus? status;

  /// USDC stroops of subcontract reserve (ADR-0011 D1); 0 for a hire that
  /// never subcontracts, which `fund` pays as before.
  final int subcontractReserve;

  /// Whether related-party children are allowed (ADR-0011 D10).
  final bool allowRelatedParty;

  /// The parent hire of a child hire (ADR-0011 D7), or `null`.
  final int? parentHireId;

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
    subcontractReserve: subcontractReserve,
    allowRelatedParty: allowRelatedParty,
    parentHireId: parentHireId,
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

  /// Binds [jobId], the job's [expiredAt] and the StrKey of the [escrow] that
  /// holds it to hire [hireId] unless the hire has a job. One conditional
  /// write, so applying it twice, or from two trackers, binds once, and the
  /// first escrow stays. Without [escrow] the hire keeps none (#273).
  ///
  /// Throws [StateError] when the hire does not exist.
  Future<JobBinding> bindJob(
    int hireId,
    int jobId, {
    required int expiredAt,
    String? escrow,
  });

  /// Hires that already have an escrow job and an id above [afterId],
  /// oldest first (by id), at most [limit]. A hire without a job is not a
  /// candidate for a server-signed `release` or `claim_refund`.
  ///
  /// The deadline pass pages through every hire with [afterId], so hires
  /// past the first [limit] are swept too.
  ///
  /// Throws [ArgumentError] when [limit] is below 1.
  Future<List<HireRow>> listWithJob({int afterId = 0, int limit = 100});

  /// The hires of [consumer], newest first (by id), at most [limit].
  ///
  /// Throws [ArgumentError] when [limit] is below 1.
  Future<List<HireRow>> listByConsumer(String consumer, {int limit = 100});
}
