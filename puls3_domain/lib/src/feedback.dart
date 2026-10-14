import 'entities.dart';
import 'errors.dart';
import 'hire_status.dart';
import 'ports.dart';
import 'reputation.dart';
import 'stellar_address.dart';
import 'values.dart';

/// The agent's owner could not be read, so the self-rating rule cannot be
/// checked. Feedback fails closed instead of skipping the rule.
final class AgentOwnerUnavailable implements Exception {
  const AgentOwnerUnavailable(this.agent);

  final AgentId agent;

  @override
  String toString() => 'AgentOwnerUnavailable: no owner for agent $agent';
}

/// The on-chain ERC-8004 Reputation Registry (#14). The domain owns the port;
/// the Soroban adapter is out of scope here.
abstract interface class ReputationRegistry {
  /// Records [feedback] and returns the transaction that confirmed it.
  Future<TransactionHash> giveFeedback(Feedback feedback);

  /// Every feedback recorded for [agent], the input of [reputationOf].
  Future<List<Feedback>> feedbacksOf(AgentId agent);
}

/// The hire rules of feedback, over plain facts so the domain [Hire] and the
/// server's stored hire share one rule source. [matchesHire] says the
/// feedback is for this hire and agent and from its consumer.
///
/// The order is fixed: completed, not already rated, matches the hire.
void checkHireRateable({
  required HireStatus status,
  required bool rated,
  required bool matchesHire,
}) {
  if (status != HireStatus.completed) throw HireNotCompleted(status);
  if (rated) throw const HireAlreadyRated();
  if (!matchesHire) throw const FeedbackDoesNotMatchHire();
}

/// [checkHireRateable] then the owner rule: the agent's [owner] cannot rate
/// its own agent (#11, [rejectSelfRating]).
void checkFeedbackAllowed({
  required HireStatus status,
  required bool rated,
  required bool matchesHire,
  required Feedback feedback,
  required StellarAddress owner,
}) {
  checkHireRateable(status: status, rated: rated, matchesHire: matchesHire);
  rejectSelfRating(feedback, owner: owner);
}

/// Lets the consumer of a completed [Hire] rate it once. The registry is
/// called only when every rule holds; the returned hire carries the registry's
/// reference and keeps status `completed` (ADR-0005 D6).
final class SubmitFeedback {
  const SubmitFeedback({
    required this.registry,
    required this.owners,
  });

  final ReputationRegistry registry;
  final AgentOwnerReader owners;

  Future<Hire> call(Hire hire, Feedback feedback) async {
    final matchesHire =
        feedback.hireId == hire.id &&
        feedback.agentId == hire.agentId &&
        feedback.client == hire.consumer;
    final rated = hire.feedbackReference != null;
    // The hire rules run before the owner is read, so a hire that cannot be
    // rated is reported as such even when the owner is unavailable.
    checkHireRateable(
      status: hire.status,
      rated: rated,
      matchesHire: matchesHire,
    );
    final owner =
        await owners.ownerOf(hire.agentId) ??
        (throw AgentOwnerUnavailable(hire.agentId));
    checkFeedbackAllowed(
      status: hire.status,
      rated: rated,
      matchesHire: matchesHire,
      feedback: feedback,
      owner: owner,
    );
    final reference = await registry.giveFeedback(feedback);
    return hire.recordFeedback(feedback, reference: reference);
  }
}
