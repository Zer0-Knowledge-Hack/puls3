/// The escrow events the relay tracker needs, read from a `getTransaction`
/// result (`xdrFormat: "json"`).
///
/// The escrow publishes each event with the snake_case event name and the
/// job id as topics, and the other fields as a symbol-keyed map
/// (`contracts/contracts/escrow/src/lib.rs`, `JobCreated` and `JobFunded`).
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

/// The first `job_created` event that [escrow] emitted in a successful [tx],
/// or `null`. Events of other contracts and malformed events are skipped.
JobCreatedEvent? firstJobCreated(
  Map<String, Object?> tx, {
  required StellarAddress escrow,
}) => _first(tx, escrow, 'job_created', (jobId, fields) {
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

/// The first `job_funded` event that [escrow] emitted in a successful [tx],
/// or `null`. Events of other contracts and malformed events are skipped.
JobFundedEvent? firstJobFunded(
  Map<String, Object?> tx, {
  required StellarAddress escrow,
}) => _first(tx, escrow, 'job_funded', (jobId, fields) {
  return JobFundedEvent(
    jobId: jobId,
    client: readAddress(fields('client')),
    amount: readI128(fields('amount')),
    feeBps: readU32(fields('fee_bps')),
  );
});

T? _first<T>(
  Map<String, Object?> tx,
  StellarAddress escrow,
  String name,
  T Function(int jobId, Object? Function(String field) fields) build,
) {
  if (tx['status'] != 'SUCCESS') return null;
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
      return build(jobId, field);
    } on LedgerUnavailable {
      continue;
    } on InvalidAgentId {
      continue;
    }
  }
  return null;
}
