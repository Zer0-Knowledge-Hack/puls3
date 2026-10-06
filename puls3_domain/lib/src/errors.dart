import 'hire_status.dart';

/// Every error the domain raises. Each subclass names the rule that was
/// broken, so callers react to the type instead of parsing a message.
sealed class DomainError implements Exception {
  const DomainError();

  String get message;

  @override
  String toString() => '$runtimeType: $message';
}

enum StellarAddressProblem {
  wrongLength,
  invalidCharacters,
  wrongPrefix,
  badChecksum,
}

final class InvalidStellarAddress extends DomainError {
  const InvalidStellarAddress(this.problem);

  final StellarAddressProblem problem;

  @override
  String get message => 'not a valid G… or C… address (${problem.name})';
}

final class InvalidAmount extends DomainError {
  const InvalidAmount(this.stroops);

  final int stroops;

  @override
  String get message => '$stroops stroops is outside 0..9007199254740991';
}

final class InvalidAgentId extends DomainError {
  const InvalidAgentId(this.value);

  final int value;

  @override
  String get message => '$value is outside the u32 range';
}

final class InvalidHireId extends DomainError {
  const InvalidHireId(this.value);

  final int value;

  @override
  String get message => '$value is outside 1..9007199254740991';
}

final class InvalidTransactionHash extends DomainError {
  const InvalidTransactionHash();

  @override
  String get message => 'expected 64 lowercase hexadecimal characters';
}

enum SkillProblem { idNotKebabCase, nameLength }

final class InvalidSkill extends DomainError {
  const InvalidSkill(this.problem);

  final SkillProblem problem;

  @override
  String get message => switch (problem) {
    SkillProblem.idNotKebabCase => 'skill id must be kebab-case',
    SkillProblem.nameLength => 'skill name must be 1 to 48 characters',
  };
}

enum AgentProblem {
  nameLength,
  descriptionLength,
  skillCount,
  duplicateSkillId,
  priceNotPositive,
}

final class InvalidAgent extends DomainError {
  const InvalidAgent(this.problem);

  final AgentProblem problem;

  @override
  String get message => switch (problem) {
    AgentProblem.nameLength => 'agent name must be 3 to 48 characters',
    AgentProblem.descriptionLength =>
      'agent description must be 10 to 280 characters',
    AgentProblem.skillCount => 'an agent has 1 to 5 skills',
    AgentProblem.duplicateSkillId => 'skill ids must be unique',
    AgentProblem.priceNotPositive => 'agent price must be greater than zero',
  };
}

enum HireProblem {
  priceNotPositive,
  manifestVersionBelowOne,
  failureReasonEmpty,
}

final class InvalidHire extends DomainError {
  const InvalidHire(this.problem);

  final HireProblem problem;

  @override
  String get message => switch (problem) {
    HireProblem.priceNotPositive => 'hire price must be greater than zero',
    HireProblem.manifestVersionBelowOne =>
      'manifest version must be at least 1',
    HireProblem.failureReasonEmpty => 'a failed run needs a reason',
  };
}

/// An event that the hire lifecycle does not allow in the current state.
final class InvalidHireTransition extends DomainError {
  const InvalidHireTransition(this.from, this.event);

  final HireStatus from;
  final HireEvent event;

  @override
  String get message => 'a ${from.name} hire cannot ${event.name}';
}

/// The payment does not pay this hire in full (ADR-0003).
final class PaymentDoesNotSettleHire extends DomainError {
  const PaymentDoesNotSettleHire();

  @override
  String get message =>
      'payment is not for this hire, not to the agent wallet, or not the exact price';
}

/// The payment was made by an address other than the hire's consumer. The
/// consumer is the one who hires, pays and rates (ADR-0002 `client_address`).
final class PaymentNotFromConsumer extends DomainError {
  const PaymentNotFromConsumer();

  @override
  String get message => 'a hire must be paid by its own consumer';
}

/// A runtime progress update that the hire's state does not allow. Runtime
/// progress moves only while the hire is `funded`: `queued` → `running`, and
/// `queued` or `running` → `failed`.
final class InvalidRuntimeTransition extends DomainError {
  const InvalidRuntimeTransition(this.status, this.runtimeStatus);

  final HireStatus status;
  final RuntimeStatus? runtimeStatus;

  @override
  String get message =>
      'cannot update the run of a ${status.name} hire '
      '(run: ${runtimeStatus?.name ?? 'none'})';
}

/// Feedback can only be recorded on a `completed` hire (ADR-0005 D5, D6).
final class HireNotCompleted extends DomainError {
  const HireNotCompleted(this.status);

  final HireStatus status;

  @override
  String get message => 'a ${status.name} hire cannot be rated';
}

/// The hire already has a feedback reference.
final class HireAlreadyRated extends DomainError {
  const HireAlreadyRated();

  @override
  String get message => 'a hire is rated at most once';
}

/// The feedback is not for this hire, this agent, or from this consumer.
final class FeedbackDoesNotMatchHire extends DomainError {
  const FeedbackDoesNotMatchHire();

  @override
  String get message =>
      'feedback must be for this hire and agent, from its consumer';
}

final class InvalidPayment extends DomainError {
  const InvalidPayment();

  @override
  String get message => 'payment amount must be greater than zero';
}

enum FeedbackProblem { scoreOutOfRange, commentTooLong }

final class InvalidFeedback extends DomainError {
  const InvalidFeedback(this.problem);

  final FeedbackProblem problem;

  @override
  String get message => switch (problem) {
    FeedbackProblem.scoreOutOfRange => 'score must be from 1 to 5',
    FeedbackProblem.commentTooLong => 'comment must be at most 500 characters',
  };
}
