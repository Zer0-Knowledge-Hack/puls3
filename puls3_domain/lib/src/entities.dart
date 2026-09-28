import 'errors.dart';
import 'hire_status.dart';
import 'stellar_address.dart';
import 'values.dart';

/// One thing an agent is good at. Same shape as an A2A skill (ADR-0004).
final class Skill {
  Skill._(this.id, this.name, this.description, this.tags);

  factory Skill({
    required String id,
    required String name,
    String description = '',
    List<String> tags = const [],
  }) {
    if (!_kebabCase.hasMatch(id)) {
      throw const InvalidSkill(SkillProblem.idNotKebabCase);
    }
    if (name.isEmpty || name.length > 48) {
      throw const InvalidSkill(SkillProblem.nameLength);
    }
    return Skill._(id, name, description, List.unmodifiable(tags));
  }

  final String id;
  final String name;
  final String description;
  final List<String> tags;
}

final _kebabCase = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');

/// An AI agent published in puls3.
final class Agent {
  Agent._(
    this.id,
    this.owner,
    this.wallet,
    this.name,
    this.description,
    this.skills,
    this.price,
  );

  factory Agent({
    required AgentId id,
    required StellarAddress owner,
    required StellarAddress wallet,
    required String name,
    required String description,
    required List<Skill> skills,
    required UsdcAmount price,
  }) {
    if (name.length < 3 || name.length > 48) {
      throw const InvalidAgent(AgentProblem.nameLength);
    }
    if (description.length < 10 || description.length > 280) {
      throw const InvalidAgent(AgentProblem.descriptionLength);
    }
    if (skills.isEmpty || skills.length > 5) {
      throw const InvalidAgent(AgentProblem.skillCount);
    }
    final ids = <String>{};
    for (final skill in skills) {
      if (!ids.add(skill.id)) {
        throw const InvalidAgent(AgentProblem.duplicateSkillId);
      }
    }
    if (!price.isPositive) {
      throw const InvalidAgent(AgentProblem.priceNotPositive);
    }
    return Agent._(
      id,
      owner,
      wallet,
      name,
      description,
      List.unmodifiable(skills),
      price,
    );
  }

  final AgentId id;

  /// The address that registered the agent on-chain and controls it.
  final StellarAddress owner;

  /// The address that receives the agent's payments.
  final StellarAddress wallet;
  final String name;
  final String description;
  final List<Skill> skills;

  /// Price per task.
  final UsdcAmount price;
}

/// One task a consumer asks an agent to do.
///
/// A hire is immutable: every transition returns a new `Hire` or throws a
/// typed error. The lifecycle is documented in docs/domain/hire-lifecycle.md.
final class Hire {
  const Hire._({
    required this.id,
    required this.agentId,
    required this.consumer,
    required this.price,
    required this.manifestVersion,
    required this.status,
    this.paymentTransaction,
    this.failureReason,
  });

  /// A new hire. It always starts in [HireStatus.requested].
  factory Hire({
    required HireId id,
    required AgentId agentId,
    required StellarAddress consumer,
    required UsdcAmount price,
    required int manifestVersion,
  }) {
    if (!price.isPositive) {
      throw const InvalidHire(HireProblem.priceNotPositive);
    }
    if (manifestVersion < 1) {
      throw const InvalidHire(HireProblem.manifestVersionBelowOne);
    }
    return Hire._(
      id: id,
      agentId: agentId,
      consumer: consumer,
      price: price,
      manifestVersion: manifestVersion,
      status: HireStatus.requested,
    );
  }

  final HireId id;
  final AgentId agentId;
  final StellarAddress consumer;

  /// The agent's price when the hire was created.
  final UsdcAmount price;

  /// The manifest version this hire runs (ADR-0004).
  final int manifestVersion;

  final HireStatus status;

  /// The transaction that paid this hire. Set by [pay], kept afterwards.
  final TransactionHash? paymentTransaction;

  /// Why the hire failed. Set by [fail].
  final String? failureReason;

  /// `requested` → `paid`, only with a payment that settles this hire.
  Hire pay(Payment payment, {required StellarAddress agentWallet}) {
    _require(HireStatus.requested, HireEvent.pay);
    if (!payment.settles(this, agentWallet: agentWallet)) {
      throw const PaymentDoesNotSettleHire();
    }
    return _to(HireStatus.paid, paymentTransaction: payment.transaction);
  }

  /// `requested` → `cancelled`.
  Hire cancel() {
    _require(HireStatus.requested, HireEvent.cancel);
    return _to(HireStatus.cancelled);
  }

  /// `paid` → `inProgress`.
  Hire start() {
    _require(HireStatus.paid, HireEvent.start);
    return _to(HireStatus.inProgress);
  }

  /// `inProgress` → `delivered`.
  Hire deliver() {
    _require(HireStatus.inProgress, HireEvent.deliver);
    return _to(HireStatus.delivered);
  }

  /// `paid` or `inProgress` → `failed`, with a non-empty [reason].
  Hire fail({required String reason}) {
    if (status != HireStatus.paid && status != HireStatus.inProgress) {
      throw InvalidHireTransition(status, HireEvent.fail);
    }
    if (reason.isEmpty) {
      throw const InvalidHire(HireProblem.failureReasonEmpty);
    }
    return _to(HireStatus.failed, failureReason: reason);
  }

  /// `delivered` → `rated`, with feedback for this hire and agent, left by
  /// this hire's consumer.
  Hire rate(Feedback feedback) {
    _require(HireStatus.delivered, HireEvent.rate);
    if (feedback.hireId != id ||
        feedback.agentId != agentId ||
        feedback.client != consumer) {
      throw const FeedbackDoesNotMatchHire();
    }
    return _to(HireStatus.rated);
  }

  void _require(HireStatus expected, HireEvent event) {
    if (status != expected) throw InvalidHireTransition(status, event);
  }

  Hire _to(
    HireStatus next, {
    TransactionHash? paymentTransaction,
    String? failureReason,
  }) => Hire._(
    id: id,
    agentId: agentId,
    consumer: consumer,
    price: price,
    manifestVersion: manifestVersion,
    status: next,
    paymentTransaction: paymentTransaction ?? this.paymentTransaction,
    failureReason: failureReason ?? this.failureReason,
  );
}

/// The USDC transfer on Stellar that pays for a hire.
final class Payment {
  Payment({
    required this.transaction,
    required this.hireId,
    required this.payer,
    required this.payee,
    required this.amount,
  }) {
    if (!amount.isPositive) throw const InvalidPayment();
  }

  final TransactionHash transaction;
  final HireId hireId;
  final StellarAddress payer;
  final StellarAddress payee;
  final UsdcAmount amount;

  /// Whether this payment pays [hire] in full: it is for that hire, it went to
  /// [agentWallet], and the amount equals the hire price exactly (ADR-0003).
  bool settles(Hire hire, {required StellarAddress agentWallet}) =>
      hireId == hire.id && payee == agentWallet && amount == hire.price;
}

/// The score and optional comment a consumer leaves about a paid hire.
final class Feedback {
  Feedback({
    required this.hireId,
    required this.agentId,
    required this.client,
    required this.score,
    this.comment = '',
  }) {
    if (score < 1 || score > 5) {
      throw const InvalidFeedback(FeedbackProblem.scoreOutOfRange);
    }
    if (comment.length > 500) {
      throw const InvalidFeedback(FeedbackProblem.commentTooLong);
    }
  }

  final HireId hireId;
  final AgentId agentId;
  final StellarAddress client;

  /// From 1 to 5.
  final int score;
  final String comment;
}
