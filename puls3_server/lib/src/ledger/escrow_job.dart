import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart';

import 'ledger_errors.dart';
import 'sc_val_json.dart';

/// The state of an escrow job, in the order of the contract's `JobState`.
enum EscrowJobState { open, funded, submitted, completed, rejected, expired }

/// Reads escrow jobs. Implemented by `SorobanLedger`.
abstract interface class EscrowJobReader {
  /// Escrow `get_job`, or `null` when the job does not exist.
  Future<EscrowJob?> escrowJob(int jobId);
}

/// An escrow `Job` as the contract stores it. It lives in the server package:
/// the domain does not model escrow jobs.
final class EscrowJob {
  const EscrowJob({
    required this.client,
    required this.provider,
    required this.evaluator,
    required this.agentId,
    required this.token,
    required this.budget,
    required this.feeBps,
    required this.expiredAt,
    required this.description,
    required this.state,
    required this.submittedAt,
    required this.approvalDeadline,
    required this.deliverable,
  });

  final StellarAddress client;
  final StellarAddress provider;
  final StellarAddress evaluator;
  final AgentId agentId;
  final StellarAddress token;

  /// In the token's smallest unit (stroops for USDC).
  final BigInt budget;

  /// Taken at `fund`; 0 before that.
  final int feeBps;

  /// Unix seconds.
  final int expiredAt;
  final String description;
  final EscrowJobState state;

  /// Unix seconds; 0 until the provider submits.
  final int submittedAt;

  /// Unix seconds; 0 until the provider submits.
  final int approvalDeadline;

  /// The 32-byte deliverable hash in lowercase hex, or `null` before submit.
  final String? deliverable;
}

/// Decodes the `map` ScVal that the escrow `get_job` returns.
///
/// Throws [LedgerUnavailable] when a field is missing, has another type, or
/// the state index is not one the contract defines.
EscrowJob decodeEscrowJob(Object? value) {
  final fields = readMap(value);

  Object? field(String name) {
    if (!fields.containsKey(name)) {
      throw LedgerUnavailable('The escrow job has no "$name" field');
    }
    return fields[name];
  }

  final stateIndex = readU32(field('state'));
  if (stateIndex >= EscrowJobState.values.length) {
    throw LedgerUnavailable('The escrow job has an unknown state $stateIndex');
  }
  final AgentId agentId;
  try {
    agentId = AgentId(readU32(field('agent_id')));
  } on InvalidAgentId {
    throw const LedgerUnavailable('The escrow job has an invalid agent id');
  }
  return EscrowJob(
    client: readAddress(field('client')),
    provider: readAddress(field('provider')),
    evaluator: readAddress(field('evaluator')),
    agentId: agentId,
    token: readAddress(field('token')),
    budget: readI128(field('budget')),
    feeBps: readU32(field('fee_bps')),
    expiredAt: readU64(field('expired_at')),
    description: readString(field('description')),
    state: EscrowJobState.values[stateIndex],
    submittedAt: readU64(field('submitted_at')),
    approvalDeadline: readU64(field('approval_deadline')),
    deliverable: readOptional(field('deliverable'), _hexOfBytes),
  );
}

String _hexOfBytes(Object? value) {
  final Uint8List bytes = readBytes(value);
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
