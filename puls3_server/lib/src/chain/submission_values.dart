/// Wire values of a `ChainSubmission`, as `docs/architecture/api.md` names
/// them. The table stores these strings; Dart code uses the enums.
library;

/// What a submitted transaction does. [wireName] is the camelCase value of
/// `ChainSubmission.purpose`.
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
  claimRefund;

  String get wireName => name;

  /// Signed by the server, never prepared for a wallet, so it has no
  /// preparation id.
  bool get isServerSigned =>
      this == submit || this == release || this == claimRefund;

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

  static const all = {
    transactionFailed,
    submissionRejected,
    preparationExpired,
    jobMismatch,
    jobEvidenceUnavailable,
    escrowCallFailed,
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
