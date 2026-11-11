/// The builder used today's test runs. [resetsAt] is the next UTC midnight.
final class StudioTestQuotaExceeded implements Exception {
  const StudioTestQuotaExceeded(this.resetsAt);

  final DateTime resetsAt;

  @override
  String toString() => 'StudioTestQuotaExceeded';
}

/// The draft cannot be run: no builder credential for its provider. The
/// message never includes a prompt or a secret.
final class StudioCredentialMissing implements Exception {
  const StudioCredentialMissing();

  @override
  String toString() => 'StudioCredentialMissing';
}

/// The credential the builder tried to save is not usable: an empty secret
/// or Workers AI without an account id.
final class StudioCredentialInvalid implements Exception {
  const StudioCredentialInvalid();

  @override
  String toString() => 'StudioCredentialInvalid';
}

/// The provider in a credential is not one this server serves. This is a
/// model-choice error, not a bad token.
final class StudioProviderUnsupported implements Exception {
  const StudioProviderUnsupported();

  @override
  String toString() => 'StudioProviderUnsupported';
}

/// The Studio runtime, or its credential store, is unavailable: for example
/// the server has no custody key. It is not the builder's fault.
final class StudioRuntimeUnavailable implements Exception {
  const StudioRuntimeUnavailable();

  @override
  String toString() => 'StudioRuntimeUnavailable';
}

/// The sample input is longer than the draft accepts.
final class StudioInputTooLong implements Exception {
  const StudioInputTooLong();

  @override
  String toString() => 'StudioInputTooLong';
}

/// The model was called and failed. [code] is a safe runtime code, never a
/// prompt, an input or a provider body.
final class StudioRunFailed implements Exception {
  const StudioRunFailed(this.code);

  final String code;

  @override
  String toString() => 'StudioRunFailed';
}
