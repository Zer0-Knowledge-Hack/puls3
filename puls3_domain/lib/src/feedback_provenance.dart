import 'errors.dart';
import 'funding.dart';
import 'stellar_address.dart';
import 'values.dart';

/// The prefix of a version 1 paid-job reference (#201).
const paidJobReferencePrefix = 'puls3:job:v1:';

/// A job id in a reference: a positive decimal with no sign and no leading
/// zero, short enough to be exact in every Dart runtime, the web included.
final _jobIdDigits = RegExp(r'^[1-9][0-9]{0,14}$');

/// The escrow job a rating was given for, as puls3 writes it on chain in the
/// feedback's `tag2` (and `feedback_uri`):
/// `puls3:job:v1:<escrow contract>:<job id>`.
///
/// The reference is only a pointer. It proves nothing by itself: a reader
/// checks it against the escrow's own state ([exclusionOf]).
final class PaidJobReference {
  PaidJobReference({required this.escrow, required this.jobId}) {
    if (escrow.kind != StellarAddressKind.contract) {
      throw ArgumentError.value(escrow.value, 'escrow', 'is not a contract');
    }
    if (!_jobIdDigits.hasMatch('$jobId')) {
      throw RangeError.value(jobId, 'jobId', 'is not a valid job id');
    }
  }

  /// The reference in [text], or null when [text] is not one. Strict: any
  /// other version, separator, address kind or number form is not a
  /// reference, so a malformed tag can never match a job.
  static PaidJobReference? tryParse(String text) {
    if (!text.startsWith(paidJobReferencePrefix)) return null;
    final parts = text.substring(paidJobReferencePrefix.length).split(':');
    if (parts.length != 2) return null;
    final StellarAddress escrow;
    try {
      escrow = StellarAddress.parse(parts.first);
    } on InvalidStellarAddress {
      return null;
    }
    if (escrow.kind != StellarAddressKind.contract) return null;
    if (!_jobIdDigits.hasMatch(parts.last)) return null;
    return PaidJobReference(escrow: escrow, jobId: int.parse(parts.last));
  }

  /// The escrow contract that holds the job.
  final StellarAddress escrow;

  /// The escrow's job id (from 1).
  final int jobId;

  /// The reference as it is written on chain.
  String get text => '$paidJobReferencePrefix${escrow.value}:$jobId';

  @override
  bool operator ==(Object other) =>
      other is PaidJobReference &&
      other.escrow == escrow &&
      other.jobId == jobId;

  @override
  int get hashCode => Object.hash(escrow, jobId);

  @override
  String toString() => text;
}

/// The facts of an escrow job a reader needs to check a rating: who the
/// client was, which agent was hired, and the job state (`get_job`).
final class ReferencedJob {
  const ReferencedJob({
    required this.client,
    required this.agentId,
    required this.state,
  });

  final StellarAddress client;
  final AgentId agentId;
  final JobState state;
}

/// What a reader knows about paid jobs when it decides which ratings count.
///
/// [escrow] is the escrow contract the reader trusts. It comes from the
/// reader's configuration, never from a record, so a reference to another
/// contract (one that could answer anything) never counts.
///
/// [jobs] holds the jobs read from [escrow] by id. A referenced job that is
/// not in it could not be read (it does not exist, or is archived).
final class FeedbackProvenance {
  const FeedbackProvenance({required this.escrow, this.jobs = const {}});

  final StellarAddress escrow;
  final Map<int, ReferencedJob> jobs;
}

/// The text `feedback_hash` commits to: the job reference, the agent, the
/// client and the score, one per line. The server hashes it (SHA-256 of its
/// UTF-8 bytes) when it builds `give_feedback`, so anyone holding the event
/// can recompute it. It binds the rating to its job; it does not prove the
/// payment, which only the escrow state does.
String feedbackCommitment({
  required PaidJobReference job,
  required AgentId agent,
  required StellarAddress client,
  required int score,
}) =>
    'puls3:feedback:v1\n'
    '${job.text}\n'
    'agent:${agent.value}\n'
    'client:${client.value}\n'
    'score:$score';
