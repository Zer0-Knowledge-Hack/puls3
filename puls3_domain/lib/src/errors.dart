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

enum HireProblem { priceNotPositive, manifestVersionBelowOne }

final class InvalidHire extends DomainError {
  const InvalidHire(this.problem);

  final HireProblem problem;

  @override
  String get message => switch (problem) {
    HireProblem.priceNotPositive => 'hire price must be greater than zero',
    HireProblem.manifestVersionBelowOne =>
      'manifest version must be at least 1',
  };
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
