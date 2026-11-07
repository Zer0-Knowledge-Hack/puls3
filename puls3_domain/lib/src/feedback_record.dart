import 'entities.dart';
import 'feedback_provenance.dart';
import 'funding.dart';
import 'stellar_address.dart';
import 'values.dart';

/// The lowest score a puls3 feedback can carry (#11, `I16`).
const int lowestFeedbackScore = 1;

/// The highest score a puls3 feedback can carry (#11, `I16`).
const int highestFeedbackScore = 5;

/// A feedback record as the Reputation Registry (#14) stores it, before
/// puls3 decides whether it is a score. The registry accepts feedback from
/// any address and in any scale, so the raw record is what an auditor reads
/// on chain (#202).
final class FeedbackRecord {
  const FeedbackRecord({
    required this.agentId,
    required this.client,
    required this.index,
    required this.value,
    required this.valueDecimals,
    required this.isRevoked,
    this.tag2 = '',
  });

  /// A record the registry lists (`get_last_index` counts it) but cannot
  /// load (`read_feedback` answers `FeedbackNotFound`).
  const FeedbackRecord.unreadable({
    required this.agentId,
    required this.client,
    required this.index,
  }) : value = null,
       valueDecimals = null,
       isRevoked = null,
       tag2 = null;

  final AgentId agentId;
  final StellarAddress client;

  /// The registry key of the record for this client, from 1.
  final int index;

  /// The stored `value`; null when the record cannot be loaded.
  final BigInt? value;

  /// The stored `value_decimals`; null when the record cannot be loaded.
  final int? valueDecimals;

  /// The stored `is_revoked`; null when the record cannot be loaded.
  final bool? isRevoked;

  /// The stored `tag2`, where puls3 writes the [PaidJobReference] of the
  /// rating (#201); null when the record cannot be loaded.
  final String? tag2;

  /// The paid job this record points to, or null when [tag2] is not a
  /// reference.
  PaidJobReference? get jobReference {
    final tag = tag2;
    return tag == null ? null : PaidJobReference.tryParse(tag);
  }
}

/// Why a [FeedbackRecord] is not a puls3 score. These rules, and only these,
/// keep a record out of `reputationOf` (docs/domain/reputation.md). The first
/// four are about the score (#202); the others tie the rating to a paid,
/// completed escrow job of the same client and agent (#201).
enum FeedbackExclusion {
  /// The registry lists the record but cannot load it.
  unreadable,

  /// Its submitter revoked it.
  revoked,

  /// `value_decimals` is not 0: a fraction, not a whole score.
  notWholeScore,

  /// A whole value outside [lowestFeedbackScore]..[highestFeedbackScore].
  outOfScale,

  /// `tag2` holds no [PaidJobReference]: nothing ties the rating to a job.
  noJobReference,

  /// The reference names an escrow contract the reader does not trust.
  otherEscrow,

  /// The referenced job could not be read from the escrow (it does not
  /// exist, or its entry is archived).
  jobUnreadable,

  /// The job's client is not the record's client, or its agent is not the
  /// rated agent.
  jobMismatch,

  /// The job is not `Completed`: not paid and settled, or refunded.
  jobNotCompleted,

  /// An earlier record already counts for the same job: one rating per hire.
  jobAlreadyRated,
}

/// The score rules of #202, which need no job.
FeedbackExclusion? _scoreExclusionOf(FeedbackRecord record) {
  final value = record.value;
  if (value == null) return FeedbackExclusion.unreadable;
  if (record.isRevoked ?? false) return FeedbackExclusion.revoked;
  if (record.valueDecimals != 0) return FeedbackExclusion.notWholeScore;
  if (value < BigInt.from(lowestFeedbackScore) ||
      value > BigInt.from(highestFeedbackScore)) {
    return FeedbackExclusion.outOfScale;
  }
  return null;
}

/// Why [record], on its own, does not count toward reputation, or null when
/// it does. Checked in the order of [FeedbackExclusion], so a revoked record
/// is reported as revoked even when its value is also outside the scale.
///
/// The job rules use only [provenance]: the job must be on the trusted
/// escrow, readable, for the record's own client (the registry keys a record
/// by its authenticated submitter) and agent, and `Completed`. One rating
/// per job is a rule over several records: see [exclusionsOf].
FeedbackExclusion? exclusionOf(
  FeedbackRecord record,
  FeedbackProvenance provenance,
) {
  final score = _scoreExclusionOf(record);
  if (score != null) return score;
  final reference = record.jobReference;
  if (reference == null) return FeedbackExclusion.noJobReference;
  if (reference.escrow != provenance.escrow) {
    return FeedbackExclusion.otherEscrow;
  }
  final job = provenance.jobs[reference.jobId];
  if (job == null) return FeedbackExclusion.jobUnreadable;
  if (job.client != record.client || job.agentId != record.agentId) {
    return FeedbackExclusion.jobMismatch;
  }
  if (job.state != JobState.completed) {
    return FeedbackExclusion.jobNotCompleted;
  }
  return null;
}

/// The exclusion of each of [records], in the same order: [exclusionOf],
/// then one rating per job. The first record (in the given order) that
/// counts for a job takes it; a later one for the same job is
/// [FeedbackExclusion.jobAlreadyRated]. A revoked or otherwise excluded
/// record takes no job, so a client can revoke a rating and rate again.
List<FeedbackExclusion?> exclusionsOf(
  Iterable<FeedbackRecord> records,
  FeedbackProvenance provenance,
) {
  final rated = <int>{};
  final exclusions = <FeedbackExclusion?>[];
  for (final record in records) {
    var exclusion = exclusionOf(record, provenance);
    // A record with no exclusion has a reference to a job on the escrow.
    if (exclusion == null && !rated.add(record.jobReference!.jobId)) {
      exclusion = FeedbackExclusion.jobAlreadyRated;
    }
    exclusions.add(exclusion);
  }
  return exclusions;
}

/// The job ids a reader must read from [escrow] to decide [records]: the
/// referenced jobs of every record that passes the score rules and points to
/// [escrow], once each, in first-seen order.
List<int> referencedJobIds(
  Iterable<FeedbackRecord> records,
  StellarAddress escrow,
) {
  final ids = <int>{};
  for (final record in records) {
    if (_scoreExclusionOf(record) != null) continue;
    final reference = record.jobReference;
    if (reference != null && reference.escrow == escrow) {
      ids.add(reference.jobId);
    }
  }
  return ids.toList();
}

/// The feedback of [records] that counts, in the same order: every record
/// without an exclusion in [exclusionsOf] becomes one [Feedback], and
/// nothing else does. This is the input of `reputationOf` on the server and
/// in the verification tool, so both apply the same rule (#202, #201).
///
/// The registry stores no puls3 hire id and no comment: each [Feedback] has
/// a null `hireId` and an empty comment. Only `score` feeds `reputationOf`.
List<Feedback> countedFeedback(
  Iterable<FeedbackRecord> records,
  FeedbackProvenance provenance,
) {
  final list = records.toList();
  final exclusions = exclusionsOf(list, provenance);
  return [
    for (var i = 0; i < list.length; i++)
      if (exclusions[i] == null)
        Feedback(
          hireId: null,
          agentId: list[i].agentId,
          client: list[i].client,
          score: list[i].value!.toInt(),
        ),
  ];
}
