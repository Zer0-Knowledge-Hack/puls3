/// Agent runtime settings.
///
/// | Source | Field |
/// |---|---|
/// | Serverpod password `anthropicApiKey` (secret; never logged) | [anthropicApiKey] |
/// | `PULS3_RUNTIME_TIMEOUT_SECONDS` environment variable | [timeout] |
///
/// The Anthropic key is optional: it only serves manifests whose provider is
/// `anthropic` (BYOK). Workers AI, the free provider, is configured by
/// `startAgentRuntime` from `PULS3_WORKERS_AI_ACCOUNT_ID` and the
/// `workersAiApiToken` password. Whether the runtime runs at all is
/// `PULS3_RUNTIME_ENABLED` (`RuntimeLoopConfig`).
///
/// The key is a secret, so it never comes from `.env`, which the app compiles
/// into its build (docs/infra/secrets.md). The composition root reads it from
/// Serverpod's passwords: `passwords.yaml` locally,
/// `scloud password set anthropicApiKey` on Serverpod Cloud.
final class RuntimeConfig {
  const RuntimeConfig({required this.anthropicApiKey, required this.timeout});

  /// Builds the configuration from [env] (normally `Platform.environment`)
  /// and the Serverpod password [anthropicApiKey].
  ///
  /// A null or empty key leaves the `anthropic` provider off. An unset or
  /// empty timeout
  /// uses [defaultTimeout]; a timeout that is not a positive whole number of
  /// seconds throws [FormatException].
  factory RuntimeConfig.fromEnvironment(
    Map<String, String> env, {
    required String? anthropicApiKey,
  }) {
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
      anthropicApiKey: anthropicApiKey == null || anthropicApiKey.isEmpty
          ? null
          : anthropicApiKey,
      timeout: timeout,
    );
  }

  /// Used when `PULS3_RUNTIME_TIMEOUT_SECONDS` is unset. The real value is
  /// deferred (ADR-0005 D3) and must end before the job's `expired_at`.
  static const defaultTimeout = Duration(seconds: 120);

  final String? anthropicApiKey;
  final Duration timeout;

  /// Whether the `anthropic` provider has a key. It says nothing about the
  /// other providers or whether the runtime runs.
  bool get hasAnthropicKey => anthropicApiKey != null;

  @override
  String toString() =>
      'RuntimeConfig(anthropic key ${hasAnthropicKey ? 'set' : 'unset'}, '
      'timeout: ${timeout.inSeconds}s)';
}
