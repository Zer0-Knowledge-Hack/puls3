import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart';

import 'contract_reader.dart';
import 'ledger_errors.dart';
import 'sc_val_json.dart';
import 'xdr_invoke_encoder.dart' show ScArg;

/// The state of an escrow job, in the order of the contract's `JobState`.
enum EscrowJobState { open, funded, submitted, completed, rejected, expired }

/// The domain's name for this escrow state.
extension EscrowJobStateDomain on EscrowJobState {
  JobState get domain => switch (this) {
    EscrowJobState.open => JobState.open,
    EscrowJobState.funded => JobState.funded,
    EscrowJobState.submitted => JobState.submitted,
    EscrowJobState.completed => JobState.completed,
    EscrowJobState.rejected => JobState.rejected,
    EscrowJobState.expired => JobState.expired,
  };
}

/// Reads escrow jobs. Implemented by [ContractEscrowJobReader] (which
/// `SorobanLedger` uses).
abstract interface class EscrowJobReader {
  /// Escrow `get_job`, or `null` when the job does not exist.
  Future<EscrowJob?> escrowJob(int jobId);
}

/// Escrow `JobNotFound`: no job has this id.
const escrowJobNotFound = 1;

/// [EscrowJobReader] over a [ContractReader] for the escrow at [escrow]:
/// the one `get_job` read.
///
/// An archived job is a [LedgerUnavailable] with `archived` set, any other
/// failure a [LedgerException].
///
/// A simulation answers `restorePreamble` when any entry of its footprint is
/// archived, so an archived escrow instance or code looks exactly like an
/// archived job (#273). When `get_job` says archived, `job_count`, which
/// touches the instance and the code but no job, tells them apart: if it is
/// archived too, the escrow itself needs a restore and the read is a
/// [LedgerUnavailable] without `archived`, a failure for the caller and never
/// "this job is gone". Concurrent checks share one read.
final class ContractEscrowJobReader implements EscrowJobReader {
  ContractEscrowJobReader(this._reader, {required this.escrow});

  final ContractReader _reader;
  final StellarAddress escrow;

  Future<bool>? _probe;

  @override
  Future<EscrowJob?> escrowJob(int jobId) async {
    final Object? value;
    try {
      value = await _reader.read(
        escrow,
        'get_job',
        [ScArg.u64(jobId)],
        absentErrors: const {escrowJobNotFound},
      );
    } on LedgerUnavailable catch (e) {
      if (e.archived && await _escrowArchived()) {
        throw const LedgerUnavailable(
          'The escrow contract instance or code is archived and needs a '
          'restore',
        );
      }
      rethrow;
    }
    return value == null ? null : readOptional(value, decodeEscrowJob);
  }

  Future<bool> _escrowArchived() =>
      _probe ??= _probeEscrow().whenComplete(() => _probe = null);

  /// Whether `job_count` needs a restore. Any other failure of the check is
  /// the caller's failure: not knowing is never read as "the job is gone".
  Future<bool> _probeEscrow() async {
    try {
      await _reader.read(escrow, 'job_count', const []);
      return false;
    } on LedgerUnavailable catch (e) {
      if (e.archived) return true;
      rethrow;
    }
  }
}

/// Reads the escrow's own expiry view. Implemented by `SorobanLedger`.
abstract interface class EscrowExpiryReader {
  /// Escrow `is_expired`. True for `Expired`, and for `Open` or `Funded`
  /// jobs at or after `expired_at`. A `Submitted` job is never expired.
  Future<bool> isExpired(int jobId);
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
