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
    if (name.isEmpty || name.runes.length > 48) {
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
    if (name.runes.length < 3 || name.runes.length > 48) {
      throw const InvalidAgent(AgentProblem.nameLength);
    }
    if (description.runes.length < 10 || description.runes.length > 280) {
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

/// One task a consumer asks an agent to do: an ERC-8183 escrow job.
///
/// A hire is immutable: every transition returns a new `Hire` or throws a
/// typed error. Each transition mirrors a confirmed escrow transition (ADR-0005
/// D6); time rules such as `expired_at` and the approval window are enforced
/// by the escrow, not here. The lifecycle is documented in
/// docs/domain/hire-lifecycle.md.
final class Hire {
  const Hire._({
    required this.id,
    required this.agentId,
    required this.consumer,
    required this.price,
    required this.manifestVersion,
    required this.status,
    this.paymentTransaction,
    this.runtimeStatus,
    this.failureReason,
    this.rejectedFrom,
    this.feedbackReference,
  });

  /// A hire whose escrow job was created. It always starts in
  /// [HireStatus.open].
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
      status: HireStatus.open,
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

  /// The `fund` transaction. Set by [fund], kept afterwards.
  final TransactionHash? paymentTransaction;

  /// The agent runtime's progress. Set to `queued` by [fund]; it moves only
  /// while the hire is `funded`.
  final RuntimeStatus? runtimeStatus;

  /// Why the run failed. Set by [failRun].
  final String? failureReason;

  /// The state the hire was rejected from. Set by [reject]. A reject from
  /// `open` is a cancel before paying; only rejects from `submitted` count
  /// against the client (ADR-0005 D8).
  final HireStatus? rejectedFrom;

  /// The confirmed ERC-8004 feedback transaction. Set by [recordFeedback].
  final TransactionHash? feedbackReference;

  /// `open` → `funded`, only with a payment that settles this hire and was
  /// made by its consumer, so the one who hires, pays and rates is the same.
  /// Queues the run.
  Hire fund(Payment payment, {required StellarAddress agentWallet}) {
    _require({HireStatus.open}, HireEvent.fund);
    if (!payment.settles(this, agentWallet: agentWallet)) {
      throw const PaymentDoesNotSettleHire();
    }
    if (payment.payer != consumer) {
      throw const PaymentNotFromConsumer();
    }
    return _to(
      HireStatus.funded,
      paymentTransaction: payment.transaction,
      runtimeStatus: RuntimeStatus.queued,
    );
  }

  /// `funded` → `submitted`: the agent delivered.
  Hire submit() {
    _require({HireStatus.funded}, HireEvent.submit);
    return _to(HireStatus.submitted);
  }

  /// `submitted` → `completed`: the evaluator accepted, or the approval window
  /// passed and the job was released.
  Hire complete() {
    _require({HireStatus.submitted}, HireEvent.complete);
    return _to(HireStatus.completed);
  }

  /// `open`, `funded` or `submitted` → `rejected`, recording the state it
  /// came from.
  Hire reject() {
    _require({
      HireStatus.open,
      HireStatus.funded,
      HireStatus.submitted,
    }, HireEvent.reject);
    return _to(HireStatus.rejected, rejectedFrom: status);
  }

  /// `open` (unfunded job past `expired_at`, derived) or `funded`
  /// (`claim_refund`) → `expired`. A `submitted` hire cannot expire: it is
  /// released first (ADR-0005 D4).
  Hire expire() {
    _require({HireStatus.open, HireStatus.funded}, HireEvent.expire);
    return _to(HireStatus.expired);
  }

  /// Runtime `queued` → `running`. The hire stays `funded`.
  Hire startRun() {
    if (status != HireStatus.funded || runtimeStatus != RuntimeStatus.queued) {
      throw InvalidRuntimeTransition(status, runtimeStatus);
    }
    return _to(status, runtimeStatus: RuntimeStatus.running);
  }

  /// Runtime `queued` or `running` → `failed`, with a non-empty [reason]. The
  /// hire stays `funded` until the client rejects it or the job expires.
  Hire failRun({required String reason}) {
    if (status != HireStatus.funded || runtimeStatus == RuntimeStatus.failed) {
      throw InvalidRuntimeTransition(status, runtimeStatus);
    }
    if (reason.trim().isEmpty) {
      throw const InvalidHire(HireProblem.failureReasonEmpty);
    }
    return _to(
      status,
      runtimeStatus: RuntimeStatus.failed,
      failureReason: reason,
    );
  }

  /// Records confirmed [feedback] for this hire and agent, left by this hire's
  /// consumer, once. The status does not change.
  Hire recordFeedback(Feedback feedback, {required TransactionHash reference}) {
    if (status != HireStatus.completed) throw HireNotCompleted(status);
    if (feedbackReference != null) throw const HireAlreadyRated();
    if (feedback.hireId != id ||
        feedback.agentId != agentId ||
        feedback.client != consumer) {
      throw const FeedbackDoesNotMatchHire();
    }
    return _to(status, feedbackReference: reference);
  }

  void _require(Set<HireStatus> allowed, HireEvent event) {
    if (!allowed.contains(status)) throw InvalidHireTransition(status, event);
  }

  Hire _to(
    HireStatus next, {
    TransactionHash? paymentTransaction,
    RuntimeStatus? runtimeStatus,
    String? failureReason,
    HireStatus? rejectedFrom,
    TransactionHash? feedbackReference,
  }) => Hire._(
    id: id,
    agentId: agentId,
    consumer: consumer,
    price: price,
    manifestVersion: manifestVersion,
    status: next,
    paymentTransaction: paymentTransaction ?? this.paymentTransaction,
    runtimeStatus: runtimeStatus ?? this.runtimeStatus,
    failureReason: failureReason ?? this.failureReason,
    rejectedFrom: rejectedFrom ?? this.rejectedFrom,
    feedbackReference: feedbackReference ?? this.feedbackReference,
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
