/// Wire values of a `ChainSubmission`, as `docs/architecture/api.md` names
/// them. The table stores these strings; Dart code uses the enums.
library;

/// The escrow function a `fund` submission calls when the hire carries a
/// subcontract reserve (ADR-0011 D1). It stays a [SubmissionPurpose.fund]:
/// funding is one escrow step whatever the reserve, so the tracker, the
/// funding check and the hire status treat both calls alike.
const fundWithReserveFunction = 'fund_with_reserve';

/// What a submitted transaction does. [wireName] is the camelCase value of
/// `ChainSubmission.purpose`; [contractFunction] is the snake_case Soroban
/// function the transaction calls. New values go last: stored rows and
/// tests read them by name, never by index, but the order is pinned.
enum SubmissionPurpose {
  createJob,
  fund,
  complete,
  reject,
  registerFull,
  setAgentWallet,
  giveFeedback,
  submit,
  release,
  claimRefund,

  /// A child job drawn from the parent's reserve, signed by the parent's
  /// provider through custody (ADR-0011 D2).
  createChildJob;

  String get wireName => name;

  /// The contract function this purpose calls. Explicit, never derived from
  /// [wireName]: the stored camelCase value and the Soroban name are two
  /// contracts. A `fund` with a reserve calls [fundWithReserveFunction].
  String get contractFunction => switch (this) {
    createJob => 'create_job',
    fund => 'fund',
    complete => 'complete',
    reject => 'reject',
    registerFull => 'register_full',
    setAgentWallet => 'set_agent_wallet',
    giveFeedback => 'give_feedback',
    submit => 'submit',
    release => 'release',
    claimRefund => 'claim_refund',
    createChildJob => 'create_child_job',
  };

  /// Signed by the server, never prepared for a wallet, so it has no
  /// preparation id.
  bool get isServerSigned =>
      this == submit ||
      this == release ||
      this == claimRefund ||
      this == createChildJob;

  /// The purpose whose [wireName] is exactly [wire], or `null`.
  static SubmissionPurpose? tryParse(String wire) => _byWire(values, wire);

  /// Like [tryParse], but throws [FormatException] for an unknown name.
  static SubmissionPurpose parse(String wire) =>
      tryParse(wire) ??
      (throw FormatException('Unknown submission purpose', wire));
}

/// Where a submission is. [wireName] is the lowercase value of
/// `ChainSubmission.state`.
enum SubmissionState {
  submitted,
  confirmed,
  failed;

  String get wireName => name;

  /// `confirmed` and `failed` never change again.
  bool get isFinal => this != submitted;

  /// The state whose [wireName] is exactly [wire], or `null`.
  static SubmissionState? tryParse(String wire) => _byWire(values, wire);

  /// Like [tryParse], but throws [FormatException] for an unknown name.
  static SubmissionState parse(String wire) =>
      tryParse(wire) ??
      (throw FormatException('Unknown submission state', wire));
}

/// Asynchronous outcome codes a failed submission reports in
/// `ChainSubmission.errorCode`. They come from the same catalog as
/// `Puls3ApiException.code`.
abstract final class SubmissionOutcomeCode {
  static const transactionFailed = 'TransactionFailed';
  static const submissionRejected = 'SubmissionRejected';
  static const preparationExpired = 'PreparationExpired';
  static const jobMismatch = 'JobMismatch';
  static const jobEvidenceUnavailable = 'JobEvidenceUnavailable';
  static const escrowCallFailed = 'EscrowCallFailed';

  /// A simulation failure that counts toward the bounded attempts but is
  /// not permanent (for example `InvalidState` from a lagging node).
  static const simulationFailed = 'SimulationFailed';

  /// A simulation rejected with a contract code that can never change for
  /// this job (expired / too late); the hire is closed immediately.
  static const submitSimulationRejected = 'SubmitSimulationRejected';

  /// The transaction can no longer be looked up and nothing else proves
  /// whether it landed. The hire stays blocked until someone resolves it.
  static const outcomeUnknown = 'OutcomeUnknown';

  static const all = {
    transactionFailed,
    submissionRejected,
    preparationExpired,
    jobMismatch,
    jobEvidenceUnavailable,
    escrowCallFailed,
    simulationFailed,
    submitSimulationRejected,
    outcomeUnknown,
  };

  /// Whether [code] is exactly one of [all].
  static bool isKnown(String code) => all.contains(code);
}

T? _byWire<T extends Enum>(List<T> values, String wire) {
  for (final value in values) {
    if (value.name == wire) return value;
  }
  return null;
}
