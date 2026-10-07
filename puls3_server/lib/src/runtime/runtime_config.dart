/// Agent runtime settings, read from environment variables:
///
/// | Variable | Field |
/// |---|---|
/// | `PULS3_ANTHROPIC_API_KEY` | [anthropicApiKey] (secret; never logged) |
/// | `PULS3_RUNTIME_TIMEOUT_SECONDS` | [timeout] |
final class RuntimeConfig {
  const RuntimeConfig({required this.anthropicApiKey, required this.timeout});

  /// Builds the configuration from [env] (normally `Platform.environment`).
  ///
  /// An unset or empty key disables the runtime. An unset or empty timeout
  /// uses [defaultTimeout]; a timeout that is not a positive whole number of
  /// seconds throws [FormatException].
  factory RuntimeConfig.fromEnvironment(Map<String, String> env) {
    String? read(String name) {
      final value = env[name];
      return value == null || value.isEmpty ? null : value;
    }

    final seconds = read('PULS3_RUNTIME_TIMEOUT_SECONDS');
    final Duration timeout;
    if (seconds == null) {
      timeout = defaultTimeout;
    } else {
      final parsed = int.tryParse(seconds);
      if (parsed == null || parsed < 1) {
        throw FormatException(
          'PULS3_RUNTIME_TIMEOUT_SECONDS must be a positive whole number',
          seconds,
        );
      }
      timeout = Duration(seconds: parsed);
    }
    return RuntimeConfig(
      anthropicApiKey: read('PULS3_ANTHROPIC_API_KEY'),
      timeout: timeout,
    );
  }

  /// Used when `PULS3_RUNTIME_TIMEOUT_SECONDS` is unset. The real value is
  /// deferred (ADR-0005 D3) and must end before the job's `expired_at`.
  static const defaultTimeout = Duration(seconds: 120);

  final String? anthropicApiKey;
  final Duration timeout;

  /// Whether a provider key is configured.
  bool get isEnabled => anthropicApiKey != null;

  @override
  String toString() =>
      'RuntimeConfig(${isEnabled ? 'enabled' : 'disabled'}, '
      'timeout: ${timeout.inSeconds}s)';
}
