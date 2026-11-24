/// The escrow events the relay tracker needs, read from a `getTransaction`
/// result (`xdrFormat: "json"`).
///
/// The escrow publishes each event with the snake_case event name and the
/// job id as topics, and the other fields as a symbol-keyed map
/// (`contracts/contracts/escrow/src/lib.rs`, `JobCreated` and `JobFunded`).
/// The subcontract events of ADR-0011 D6 use the parent or the closing job
/// as that topic.
library;

import 'package:puls3_domain/puls3_domain.dart';

import 'contract_events.dart';
import 'ledger_errors.dart';
import 'sc_val_json.dart';

/// The escrow `JobCreated` event: a new `Open` job.
final class JobCreatedEvent {
  const JobCreatedEvent({
    required this.jobId,
    required this.client,
    required this.provider,
    required this.evaluator,
    required this.agentId,
    required this.token,
    required this.budget,
    required this.expiredAt,
  });

  final int jobId;
  final StellarAddress client;
  final StellarAddress provider;
  final StellarAddress evaluator;
  final AgentId agentId;
  final StellarAddress token;

  /// In the token's smallest unit (stroops for USDC).
  final BigInt budget;

  /// Unix seconds.
  final int expiredAt;
}

/// The escrow `JobFunded` event: the client paid the budget into the escrow.
final class JobFundedEvent {
  const JobFundedEvent({
    required this.jobId,
    required this.client,
    required this.amount,
    required this.feeBps,
  });

  final int jobId;
  final StellarAddress client;

  /// In the token's smallest unit (stroops for USDC).
  final BigInt amount;

  /// The fee snapshotted at `fund`.
  final int feeBps;
}

/// Every `job_created` event that [escrow] emitted in a successful [tx], in
/// order. Events of other contracts and malformed events are skipped, so the
/// list is empty when none is valid.
List<JobCreatedEvent> allJobCreated(
  Map<String, Object?> tx, {
  required StellarAddress escrow,
}) => _all(tx, escrow, 'job_created', (jobId, fields) {
  return JobCreatedEvent(
    jobId: jobId,
    client: readAddress(fields('client')),
    provider: readAddress(fields('provider')),
    evaluator: readAddress(fields('evaluator')),
    agentId: AgentId(readU32(fields('agent_id'))),
    token: readAddress(fields('token')),
    budget: readI128(fields('budget')),
    expiredAt: readU64(fields('expired_at')),
  );
});

/// Every `job_funded` event that [escrow] emitted in a successful [tx], in
/// order. Events of other contracts and malformed events are skipped, so the
/// list is empty when none is valid.
List<JobFundedEvent> allJobFunded(
  Map<String, Object?> tx, {
  required StellarAddress escrow,
}) => _all(tx, escrow, 'job_funded', (jobId, fields) {
  return JobFundedEvent(
    jobId: jobId,
    client: readAddress(fields('client')),
    amount: readI128(fields('amount')),
    feeBps: readU32(fields('fee_bps')),
  );
});

/// The escrow `JobCompleted` event: job [jobId] paid [payout] to its
/// provider and [fee] to the treasury, through `complete` or (with
/// [autoReleased]) the permissionless `release`.
final class JobCompletedEvent {
  const JobCompletedEvent({
    required this.jobId,
    required this.evaluator,
    required this.payout,
    required this.fee,
    required this.autoReleased,
  });

  final int jobId;
  final StellarAddress evaluator;

  /// In the token's smallest unit (stroops for USDC).
  final BigInt payout;
  final BigInt fee;
  final bool autoReleased;
}

/// Every `job_completed` event that [escrow] emitted in a successful [tx],
/// in order. Events of other contracts and malformed events are skipped.
List<JobCompletedEvent> allJobCompleted(
  Map<String, Object?> tx, {
  required StellarAddress escrow,
}) => _all(
  tx,
  escrow,
  'job_completed',
  (jobId, fields) => JobCompletedEvent(
    jobId: jobId,
    evaluator: readAddress(fields('evaluator')),
    payout: readI128(fields('payout')),
    fee: readI128(fields('fee')),
    autoReleased: readBool(fields('auto_released')),
  ),
);

/// The escrow `ReserveFunded` event: `fund_with_reserve` put a non-zero
/// subcontract reserve on job [jobId] (ADR-0011 D6).
final class ReserveFundedEvent {
  const ReserveFundedEvent({
    required this.jobId,
    required this.client,
    required this.reserve,
  });

  final int jobId;
  final StellarAddress client;

  /// In the token's smallest unit (stroops for USDC).
  final BigInt reserve;
}

/// The escrow `ChildJobCreated` event: a child job drawn from the reserve of
/// [parentJobId] (ADR-0011 D2). The child also emits `JobCreated` and
/// `JobFunded`.
final class ChildJobCreatedEvent {
  const ChildJobCreatedEvent({
    required this.parentJobId,
    required this.childJobId,
    required this.provider,
    required this.agentId,
    required this.budget,
    required this.reserve,
    required this.depth,
    required this.parentReserveLeft,
  });

  final int parentJobId;
  final int childJobId;
  final StellarAddress provider;
  final AgentId agentId;

  /// In the token's smallest unit (stroops for USDC).
  final BigInt budget;

  /// The child's own sub-reserve.
  final BigInt reserve;
  final int depth;

  /// The parent's unspent reserve after the draw.
  final BigInt parentReserveLeft;
}

/// The escrow `ReserveReturned` event: a refunded child sent [amount] back
/// up its tree (ADR-0011 D3). With [toClient] false it went to the reserve
/// of [parentJobId]; with [toClient] true to the client of that root job.
final class ReserveReturnedEvent {
  const ReserveReturnedEvent({
    required this.parentJobId,
    required this.childJobId,
    required this.amount,
    required this.toClient,
  });

  final int parentJobId;
  final int childJobId;
  final BigInt amount;
  final bool toClient;
}

/// The escrow `ReserveRefunded` event: job [jobId] closed and its unspent
/// reserve went back to [client] (ADR-0011 D4), as a claimable balance when
/// [deferred].
final class ReserveRefundedEvent {
  const ReserveRefundedEvent({
    required this.jobId,
    required this.client,
    required this.amount,
    required this.deferred,
  });

  final int jobId;
  final StellarAddress client;
  final BigInt amount;
  final bool deferred;
}

/// Every valid `reserve_funded` event of [escrow] in a successful [tx].
List<ReserveFundedEvent> allReserveFunded(
  Map<String, Object?> tx, {
  required StellarAddress escrow,
}) => _all(
  tx,
  escrow,
  'reserve_funded',
  (jobId, fields) => ReserveFundedEvent(
    jobId: jobId,
    client: readAddress(fields('client')),
    reserve: readI128(fields('reserve')),
  ),
);

/// Every valid `child_job_created` event of [escrow] in a successful [tx].
List<ChildJobCreatedEvent> allChildJobCreated(
  Map<String, Object?> tx, {
  required StellarAddress escrow,
}) => _all(
  tx,
  escrow,
  'child_job_created',
  (parentJobId, fields) => ChildJobCreatedEvent(
    parentJobId: parentJobId,
    childJobId: readU64(fields('child_job_id')),
    provider: readAddress(fields('provider')),
    agentId: AgentId(readU32(fields('agent_id'))),
    budget: readI128(fields('budget')),
    reserve: readI128(fields('reserve')),
    depth: readU32(fields('depth')),
    parentReserveLeft: readI128(fields('parent_reserve_left')),
  ),
);

/// Every valid `reserve_returned` event of [escrow] in a successful [tx].
List<ReserveReturnedEvent> allReserveReturned(
  Map<String, Object?> tx, {
  required StellarAddress escrow,
}) => _all(
  tx,
  escrow,
  'reserve_returned',
  (parentJobId, fields) => ReserveReturnedEvent(
    parentJobId: parentJobId,
    childJobId: readU64(fields('child_job_id')),
    amount: readI128(fields('amount')),
    toClient: readBool(fields('to_client')),
  ),
);

/// Every valid `reserve_refunded` event of [escrow] in a successful [tx].
List<ReserveRefundedEvent> allReserveRefunded(
  Map<String, Object?> tx, {
  required StellarAddress escrow,
}) => _all(
  tx,
  escrow,
  'reserve_refunded',
  (jobId, fields) => ReserveRefundedEvent(
    jobId: jobId,
    client: readAddress(fields('client')),
    amount: readI128(fields('amount')),
    deferred: readBool(fields('deferred')),
  ),
);

List<T> _all<T>(
  Map<String, Object?> tx,
  StellarAddress escrow,
  String name,
  T Function(int jobId, Object? Function(String field) fields) build,
) {
  if (tx['status'] != 'SUCCESS') return const [];
  final events = <T>[];
  for (final event in contractEvents(tx)) {
    final body = contractEventBody(event, escrow.value);
    if (body == null || body.topics.length != 2) continue;
    try {
      if (readSymbol(body.topics[0]) != name) continue;
      final jobId = readU64(body.topics[1]);
      final data = readMap(body.data);
      Object? field(String key) => data.containsKey(key)
          ? data[key]
          : throw LedgerUnavailable('$name has no "$key" field');
      events.add(build(jobId, field));
    } on LedgerUnavailable {
      continue;
    } on InvalidAgentId {
      continue;
    }
  }
  return events;
}
