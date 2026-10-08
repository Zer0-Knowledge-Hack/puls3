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
import 'agent_runner.dart';
import 'demo_manifests.dart';
import 'hire_runner.dart';
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

/// Name of the Serverpod password that holds the Anthropic API key.
const anthropicApiKeyPassword = 'anthropicApiKey';

/// Starts the agent runtime when [env] enables it (see [RuntimeLoopConfig])
/// and the `anthropicApiKey` password is set, and returns its loop, or
/// returns `null`. Stopping the loop also closes its HTTP client.
///
/// Each pass opens its own session and runs at most one batch, one hire at a
/// time.
TrackerLoop? startAgentRuntime(Serverpod pod, Map<String, String> env) {
  final loopConfig = RuntimeLoopConfig.fromEnvironment(env);
  if (!loopConfig.enabled) return null;
  const ChainLog log = _consoleLog;
  final config = RuntimeConfig.fromEnvironment(
    env,
    anthropicApiKey: pod.getPassword(anthropicApiKeyPassword),
  );
  final apiKey = config.anthropicApiKey;
  if (apiKey == null) {
    log(
      ChainLogLevel.error,
      'PULS3_RUNTIME_ENABLED is true but the "$anthropicApiKeyPassword" '
      'password is not set; the agent runtime is not started',
    );
    return null;
  }

  final stellar = StellarConfig.fromEnvironment(env);
  final httpClient = http.Client();
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
      runtime: AnthropicRuntime(httpClient: httpClient, apiKey: apiKey),
      timeout: config.timeout,
    ),
    // A run still `running` a minute past the timeout was interrupted.
    staleAfter: config.timeout + const Duration(minutes: 1),
    log: log,
    batchSize: _batchSize,
  );
  final loop = TrackerLoop(
    interval: loopConfig.interval,
    passTimeout: config.timeout * _batchSize + const Duration(minutes: 1),
    log: log,
    runPass: () async {
      final session = await pod.createSession();
      try {
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
    '$config',
  );
  return loop;
}

void _consoleLog(ChainLogLevel level, String message) {
  final line = '[agent-runtime] ${level.name}: $message';
  if (level == ChainLogLevel.info) {
    stdout.writeln(line);
  } else {
    stderr.writeln(line);
  }
}
