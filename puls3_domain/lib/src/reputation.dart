import 'entities.dart';
import 'errors.dart';
import 'stellar_address.dart';

/// The reputation prior: the score a new agent starts at. It is the mean the
/// Bayesian average is pulled toward (docs/domain/reputation.md, #11).
const double reputationPriorMean = 4.0;

/// How many ratings the prior is worth. A larger weight pulls an agent with
/// few ratings harder toward [reputationPriorMean].
const double reputationPriorWeight = 5.0;

/// The reputation of an agent from its [feedback]: the Bayesian average of
/// its clients' scores (each 1–5), pulled toward [reputationPriorMean] by
/// [reputationPriorWeight] so an agent with few ratings is not over- or
/// under-ranked. Rounded to two decimals.
///
/// **One client is one rating** (ADR-0012, #324): a client who rated the
/// agent several times counts once, with the mean of their scores. A paid
/// hire from an owner's second wallet costs the owner almost nothing, since
/// the agent's earnings come back to them, so repeated hires from one wallet
/// must not add up. Each further rating then needs another client.
///
/// With no feedback it is [reputationPriorMean], so a new agent is never ranked
/// above one with a history. The formula and its worked examples live in
/// docs/domain/reputation.md (#11).
double reputationOf(Iterable<Feedback> feedback) {
  final byClient = <StellarAddress, ({int sum, int count})>{};
  for (final item in feedback) {
    final seen = byClient[item.client] ?? (sum: 0, count: 0);
    byClient[item.client] = (sum: seen.sum + item.score, count: seen.count + 1);
  }
  // Summed in a fixed order (by client address), so the result never depends
  // on the order the feedback arrived in, not even in the last digit.
  final clients = byClient.keys.toList()
    ..sort((a, b) => a.value.compareTo(b.value));
  var sum = 0.0;
  for (final client in clients) {
    final scores = byClient[client]!;
    sum += scores.sum / scores.count;
  }
  final average =
      (reputationPriorWeight * reputationPriorMean + sum) /
      (reputationPriorWeight + byClient.length);
  return (average * 100).round() / 100;
}

/// Whether [feedback] is a self-rating: its client is the agent's [owner].
bool isSelfRating(Feedback feedback, {required StellarAddress owner}) =>
    feedback.client == owner;

/// Rejects a self-rating: an agent owner cannot rate its own agent (#11).
void rejectSelfRating(Feedback feedback, {required StellarAddress owner}) {
  if (isSelfRating(feedback, owner: owner)) {
    throw const FeedbackFromAgentOwner();
  }
}
