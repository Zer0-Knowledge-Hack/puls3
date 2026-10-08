/// One prompt-only task for a model, built from a deployed agent manifest
/// (ADR-0004): the manifest's `model`, `system_prompt`, and `input` /
/// `output` limits, plus the hire's input.
final class RuntimeTask {
  RuntimeTask({
    required this.provider,
    required this.modelId,
    required this.systemPrompt,
    required this.input,
    required this.maxInputChars,
    required this.maxOutputChars,
  }) {
    if (maxInputChars < 1) {
      throw ArgumentError.value(maxInputChars, 'maxInputChars', 'below 1');
    }
    if (maxOutputChars < 1) {
      throw ArgumentError.value(maxOutputChars, 'maxOutputChars', 'below 1');
    }
  }

  /// The manifest's `model.provider`, for example `anthropic`.
  final String provider;

  /// The manifest's `model.id`.
  final String modelId;
  final String systemPrompt;
  final String input;

  /// The manifest's `input.max_chars`.
  final int maxInputChars;

  /// The manifest's `output.max_chars`.
  final int maxOutputChars;
}

/// Calls one LLM provider. Each provider is an adapter in
/// `lib/src/runtime/adapters/`; nothing outside it knows the provider's API.
abstract interface class ModelRuntime {
  /// The model's text output for [task], or a [RuntimeFailure].
  ///
  /// When [abortTrigger] completes, the adapter must cancel the provider call
  /// (not just stop waiting for it), so an abandoned run is not billed to the
  /// end.
  Future<String> complete(RuntimeTask task, {Future<void>? abortTrigger});
}

/// Why a run produced no result.
///
/// [code] is safe to store as the hire's `failureReason` and to show to the
/// client: it never holds provider messages, prompts, inputs or keys.
sealed class RuntimeFailure implements Exception {
  const RuntimeFailure();

  String get code;

  @override
  String toString() => '$runtimeType($code)';
}

/// The model did not answer within the runtime timeout.
final class RuntimeTimedOut extends RuntimeFailure {
  const RuntimeTimedOut(this.timeout);

  final Duration timeout;

  @override
  String get code => 'timeout';
}

/// The provider failed or answered something the adapter cannot use.
final class RuntimeProviderFailed extends RuntimeFailure {
  const RuntimeProviderFailed({required this.status, required this.errorType});

  /// The HTTP status, or `null` when no response arrived.
  final int? status;

  /// The provider's error type (for example `rate_limit_error`), an adapter
  /// label such as `malformed_response`, or `null` when unknown.
  final String? errorType;

  /// Whether the same task may succeed on a retry: no response, rate limits
  /// and server-side errors. A call the runner aborted is not retried.
  bool get retryable {
    if (errorType == 'aborted') return false;
    final status = this.status;
    return status == null || status == 429 || status >= 500;
  }

  @override
  String get code =>
      'provider_error:${errorType ?? (status == null ? 'unavailable' : 'http_$status')}';
}

/// The model declined the task.
final class RuntimeRefused extends RuntimeFailure {
  const RuntimeRefused(this.category);

  /// The provider's refusal category, when it gives one.
  final String? category;

  @override
  String get code => 'refused';
}

/// The model stopped at its token limit, so the output is incomplete.
final class RuntimeOutputTruncated extends RuntimeFailure {
  const RuntimeOutputTruncated();

  @override
  String get code => 'output_truncated';
}

/// The hire input is longer than the manifest's `input.max_chars`.
final class RuntimeInputTooLong extends RuntimeFailure {
  const RuntimeInputTooLong(this.length, this.max);

  final int length;
  final int max;

  @override
  String get code => 'input_too_long';
}

/// The output is longer than the manifest's `output.max_chars`.
final class RuntimeOutputTooLong extends RuntimeFailure {
  const RuntimeOutputTooLong(this.length, this.max);

  final int length;
  final int max;

  @override
  String get code => 'output_too_long';
}

/// The model answered with no text.
final class RuntimeEmptyOutput extends RuntimeFailure {
  const RuntimeEmptyOutput();

  @override
  String get code => 'empty_output';
}

/// No adapter serves the manifest's `model.provider`.
final class RuntimeUnsupportedProvider extends RuntimeFailure {
  const RuntimeUnsupportedProvider(this.provider);

  final String provider;

  @override
  String get code => 'unsupported_provider';
}
