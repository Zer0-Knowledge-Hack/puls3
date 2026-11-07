import 'entities.dart';
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
  });

  /// A record the registry lists (`get_last_index` counts it) but cannot
  /// load (`read_feedback` answers `FeedbackNotFound`).
  const FeedbackRecord.unreadable({
    required this.agentId,
    required this.client,
    required this.index,
  }) : value = null,
       valueDecimals = null,
       isRevoked = null;

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
}

/// Why a [FeedbackRecord] is not a puls3 score. These four rules, and only
/// these, keep a record out of `reputationOf` (docs/domain/reputation.md).
enum FeedbackExclusion {
  /// The registry lists the record but cannot load it.
  unreadable,

  /// Its submitter revoked it.
  revoked,

  /// `value_decimals` is not 0: a fraction, not a whole score.
  notWholeScore,

  /// A whole value outside [lowestFeedbackScore]..[highestFeedbackScore].
  outOfScale,
}

/// Why [record] does not count toward reputation, or null when it does.
/// Checked in this order, so a revoked record is reported as revoked even
/// when its value is also outside the scale.
FeedbackExclusion? exclusionOf(FeedbackRecord record) {
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

/// The feedback of [records] that counts, in the same order: every record
/// without an [exclusionOf] becomes one [Feedback], and nothing else does.
/// This is the input of `reputationOf` on the server and in the
/// verification tool, so both apply the same rule (#202).
///
/// The registry stores no hire and no comment: each [Feedback] has a null
/// `hireId` and an empty comment. Only `score` feeds `reputationOf`.
List<Feedback> countedFeedback(Iterable<FeedbackRecord> records) => [
  for (final record in records)
    if (exclusionOf(record) == null)
      Feedback(
        hireId: null,
        agentId: record.agentId,
        client: record.client,
        score: record.value!.toInt(),
      ),
];
