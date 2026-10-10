import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:serverpod/serverpod.dart';

import '../chain/chain_log.dart';
import '../chain/tracker_loop.dart';
import '../hire/serverpod_hire_repository.dart';
import '../ledger/soroban_ledger.dart';
import '../ledger/soroban_rpc_client.dart';
import '../ledger/stellar_config.dart';
import 'adapters/anthropic_runtime.dart';
import 'adapters/workers_ai_runtime.dart';
import 'agent_runner.dart';
import 'demo_manifests.dart';
import 'hire_runner.dart';
import 'provider_router.dart';
import 'run_manifest.dart';
import 'runtime_config.dart';
import 'serverpod_hire_run_store.dart';

/// Whether and how often the agent runtime looks for queued runs.
///
/// | Variable | Field | Default |
/// |---|---|---|
/// | `PULS3_RUNTIME_ENABLED` | [enabled] (only `true` enables it) | `false` |
/// | `PULS3_RUNTIME_INTERVAL_SECONDS` | [interval] | `5` |
///
/// Off by default, like the chain tracker, so tests, CI and existing
/// deployments never call a paid model unless asked to.
final class RuntimeLoopConfig {
  const RuntimeLoopConfig({required this.enabled, required this.interval});

  /// Reads [env] (normally `Platform.environment`). Throws [ArgumentError]
  /// when the interval is set but is not a positive whole number of seconds.
  factory RuntimeLoopConfig.fromEnvironment(Map<String, String> env) {
    const intervalName = 'PULS3_RUNTIME_INTERVAL_SECONDS';
    final rawInterval = env[intervalName];
    var seconds = _defaultIntervalSeconds;
    if (rawInterval != null && rawInterval.isNotEmpty) {
      final parsed = int.tryParse(rawInterval);
      if (parsed == null || parsed < 1) {
        throw ArgumentError.value(
          rawInterval,
          intervalName,
          'must be a positive whole number of seconds',
        );
      }
      seconds = parsed;
    }
    return RuntimeLoopConfig(
      enabled: env['PULS3_RUNTIME_ENABLED'] == 'true',
      interval: Duration(seconds: seconds),
    );
  }

  final bool enabled;

  /// Time between the starts of two passes.
  final Duration interval;
}

const _defaultIntervalSeconds = 5;
const _rpcTimeout = Duration(seconds: 8);
const _batchSize = 10;

/// Name of the Serverpod password that holds the Anthropic API key (BYOK).
const anthropicApiKeyPassword = 'anthropicApiKey';

/// Name of the Serverpod password that holds the Cloudflare API token for
/// Workers AI, the free provider.
const workersAiTokenPassword = 'workersAiApiToken';

/// The public Cloudflare account id that Workers AI runs under.
const workersAiAccountVariable = 'PULS3_WORKERS_AI_ACCOUNT_ID';

/// Starts the agent runtime when [env] enables it (see [RuntimeLoopConfig])
/// and at least one provider has credentials, and returns its loop, or
/// returns `null`. Stopping the loop also closes its HTTP client.
///
/// - `workers-ai`: the `PULS3_WORKERS_AI_ACCOUNT_ID` variable and the
///   `workersAiApiToken` password.
/// - `anthropic`: the `anthropicApiKey` password.
///
/// A manifest whose provider has no credentials fails its run as
/// `unsupported_provider`.
///
/// Each pass opens its own session and runs at most one batch, one hire at a
/// time.
TrackerLoop? startAgentRuntime(Serverpod pod, Map<String, String> env) {
  const ChainLog log = _consoleLog;
  final settings = runtimeSettingsOrNull(
    env,
    anthropicApiKey: pod.getPassword(anthropicApiKeyPassword),
    log: log,
  );
  if (settings == null) return null;
  final (loopConfig, config) = settings;
  final httpClient = http.Client();
  final runtimes = <String, ModelRuntime>{};
  final accountId = env[workersAiAccountVariable];
  final workersAiToken = pod.getPassword(workersAiTokenPassword);
  if (accountId != null &&
      accountId.isNotEmpty &&
      workersAiToken != null &&
      workersAiToken.isNotEmpty) {
    runtimes[WorkersAiRuntime.provider] = WorkersAiRuntime(
      httpClient: httpClient,
      accountId: accountId,
      apiToken: workersAiToken,
    );
  }
  final apiKey = config.anthropicApiKey;
  if (apiKey != null) {
    runtimes[AnthropicRuntime.provider] = AnthropicRuntime(
      httpClient: httpClient,
      apiKey: apiKey,
    );
  }
  for (final warning in providerSetupWarnings(
    workersAiAccountSet: accountId != null && accountId.isNotEmpty,
    workersAiTokenSet: workersAiToken != null && workersAiToken.isNotEmpty,
    configured: runtimes.keys.toSet(),
    manifests: demoManifests,
  )) {
    log(ChainLogLevel.warning, warning);
  }
  if (runtimes.isEmpty) {
    httpClient.close();
    log(
      ChainLogLevel.error,
      'PULS3_RUNTIME_ENABLED is true but no model provider has credentials '
      '($workersAiAccountVariable with the "$workersAiTokenPassword" '
      'password, or the "$anthropicApiKeyPassword" password); the agent '
      'runtime is not started',
    );
    return null;
  }
  final router = ProviderRouter(runtimes);

  final stellar = StellarConfig.fromEnvironment(env);
  final registry = SorobanLedger(
    SorobanRpcClient(
      httpClient: httpClient,
      url: stellar.rpcUrl,
      timeout: _rpcTimeout,
    ),
    stellar,
  );
  final runner = HireRunner(
    manifests: SeededRunManifestSource(
      registry: registry,
      manifests: demoManifests,
    ),
    runner: AgentRunner(
      runtime: router,
      timeout: config.timeout,
    ),
    // A run still `running` a minute past the timeout was interrupted.
    staleAfter: config.timeout + const Duration(minutes: 1),
    log: log,
    batchSize: _batchSize,
  );
  var backfilled = false;
  final loop = TrackerLoop(
    interval: loopConfig.interval,
    passTimeout: config.timeout * _batchSize + const Duration(minutes: 1),
    log: log,
    runPass: () async {
      final session = await pod.createSession();
      try {
        if (!backfilled) {
          // Hires paid before hire_run existed get their run once.
          final queued = await ServerpodHireRunStore(
            session,
          ).enqueueMissing(DateTime.now());
          if (queued > 0) log(ChainLogLevel.info, 'Queued $queued missed runs');
          backfilled = true;
        }
        final summary = await runner.pass(
          runs: ServerpodHireRunStore(session),
          hires: ServerpodHireRepository(session),
        );
        if (summary.total > 0) log(ChainLogLevel.info, 'Pass: $summary');
      } finally {
        await session.close();
      }
    },
    onStop: () async => httpClient.close(),
  )..start();
  log(
    ChainLogLevel.info,
    'Agent runtime started, every ${loopConfig.interval.inSeconds}s, '
    'providers ${router.providers.join(', ')}, '
    'timeout ${config.timeout.inSeconds}s',
  );
  return loop;
}

/// What is wrong with the provider credentials at startup, as log lines
/// that name variables and passwords but never their values:
///
/// - Workers AI with only one of its account id and token, which would
///   otherwise be dropped without a word;
/// - every provider a seeded manifest uses that has no credentials, whose
///   runs then fail as `unsupported_provider`.
List<String> providerSetupWarnings({
  required bool workersAiAccountSet,
  required bool workersAiTokenSet,
  required Set<String> configured,
  required Map<String, Map<int, RunManifest>> manifests,
}) {
  final warnings = <String>[];
  if (workersAiAccountSet != workersAiTokenSet) {
    final (present, missing) = workersAiAccountSet
        ? (workersAiAccountVariable, 'the "$workersAiTokenPassword" password')
        : ('the "$workersAiTokenPassword" password', workersAiAccountVariable);
    warnings.add(
      'Workers AI is only partly configured: $present is set but $missing '
      'is not, so the workers-ai provider is off',
    );
  }
  final agentsByProvider = <String, Set<String>>{};
  for (final MapEntry(key: agent, value: versions) in manifests.entries) {
    for (final manifest in versions.values) {
      agentsByProvider.putIfAbsent(manifest.provider, () => {}).add(agent);
    }
  }
  final missing = agentsByProvider.keys.toSet().difference(configured).toList()
    ..sort();
  for (final provider in missing) {
    final agents = agentsByProvider[provider]!.toList()..sort();
    warnings.add(
      'Provider "$provider" has no credentials; runs of ${agents.join(', ')} '
      'fail as unsupported_provider',
    );
  }
  return warnings;
}

/// The loop and runtime settings from [env], or `null` when the runtime is
/// disabled or a setting is invalid. An invalid `PULS3_RUNTIME_*` value is
/// logged and leaves the runtime off; it never stops the server.
(RuntimeLoopConfig, RuntimeConfig)? runtimeSettingsOrNull(
  Map<String, String> env, {
  required String? anthropicApiKey,
  required ChainLog log,
}) {
  try {
    final loop = RuntimeLoopConfig.fromEnvironment(env);
    if (!loop.enabled) return null;
    return (
      loop,
      RuntimeConfig.fromEnvironment(env, anthropicApiKey: anthropicApiKey),
    );
  } on ArgumentError catch (e) {
    log(ChainLogLevel.error, 'Agent runtime not started: ${e.message}');
  } on FormatException catch (e) {
    log(ChainLogLevel.error, 'Agent runtime not started: ${e.message}');
  }
  return null;
}

void _consoleLog(ChainLogLevel level, String message) {
  final line = '[agent-runtime] ${level.name}: $message';
  if (level == ChainLogLevel.info) {
    stdout.writeln(line);
  } else {
    stderr.writeln(line);
  }
}
