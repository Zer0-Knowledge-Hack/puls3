import 'entities.dart';
import 'errors.dart';
import 'stellar_address.dart';

/// The reputation prior: the score a new agent starts at. It is the mean the
/// Bayesian average is pulled toward (docs/domain/reputation.md, #11).
const double reputationPriorMean = 4.0;

/// How many ratings the prior is worth. A larger weight pulls an agent with
/// few ratings harder toward [reputationPriorMean].
const double reputationPriorWeight = 5.0;

/// The reputation of an agent from its [feedback]: the Bayesian average of the
/// scores (each 1–5), pulled toward [reputationPriorMean] by
/// [reputationPriorWeight] so an agent with few ratings is not over- or
/// under-ranked. Rounded to two decimals.
///
/// With no feedback it is [reputationPriorMean], so a new agent is never ranked
/// above one with a history. The formula and its worked examples live in
/// docs/domain/reputation.md (#11).
double reputationOf(Iterable<Feedback> feedback) {
  var sum = 0;
  var count = 0;
  for (final item in feedback) {
    sum += item.score;
    count += 1;
  }
  final average =
      (reputationPriorWeight * reputationPriorMean + sum) /
      (reputationPriorWeight + count);
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
