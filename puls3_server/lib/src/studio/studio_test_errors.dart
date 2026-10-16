/// The builder used today's test runs. [resetsAt] is the next UTC midnight.
final class StudioTestQuotaExceeded implements Exception {
  const StudioTestQuotaExceeded(this.resetsAt);

  final DateTime resetsAt;

  @override
  String toString() => 'StudioTestQuotaExceeded';
}

/// The draft cannot be run: no builder credential for its provider, or the
/// provider is not wired. The message never includes a prompt or a secret.
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
