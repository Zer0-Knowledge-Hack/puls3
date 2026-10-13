import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:serverpod/serverpod.dart';

import '../chain/chain_log.dart';
import '../chain/tracker_loop.dart';
import '../ledger/soroban_ledger.dart';
import '../ledger/soroban_registry_event_reader.dart';
import '../ledger/soroban_rpc_client.dart';
import '../ledger/stellar_config.dart';
import 'catalog_indexer.dart';
import 'serverpod_agent_index_repository.dart';

const _rpcTimeout = Duration(seconds: 8);

/// Longest a pass may run before the loop gives up on it, so a hung pass
/// cannot wedge the indexer.
const _passTimeout = Duration(minutes: 5);

/// Whether and how often the catalog indexer runs.
///
/// | Variable | Field | Default |
/// |---|---|---|
/// | `PULS3_INDEXER_ENABLED` | [enabled] (only `true` enables it) | `false` |
/// | `PULS3_INDEXER_INTERVAL_SECONDS` | [interval] | `30` |
///
/// It is off by default, like the chain tracker, so tests, CI and existing
/// deployments do not read the chain unless asked to.
final class CatalogIndexerLoopConfig {
  const CatalogIndexerLoopConfig({
    required this.enabled,
    required this.interval,
  });

  /// Reads [env] (normally `Platform.environment`). Throws [ArgumentError]
  /// when the interval is set but is not a positive whole number of seconds.
  factory CatalogIndexerLoopConfig.fromEnvironment(Map<String, String> env) {
    const intervalName = 'PULS3_INDEXER_INTERVAL_SECONDS';
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
    return CatalogIndexerLoopConfig(
      enabled: env['PULS3_INDEXER_ENABLED'] == 'true',
      interval: Duration(seconds: seconds),
    );
  }

  final bool enabled;

  /// Time between the starts of two passes.
  final Duration interval;
}

const _defaultIntervalSeconds = 30;

/// Starts the catalog indexer when [env] enables it and returns its loop, or
/// `null`. Stopping the loop also closes its HTTP client.
///
/// Each pass opens its own session, so a pass never holds a connection
/// between ticks. The registry reader and the event reader are stateless and
/// shared; the repository is built per pass from its session.
TrackerLoop? startCatalogIndexer(Serverpod pod, Map<String, String> env) {
  final config = CatalogIndexerLoopConfig.fromEnvironment(env);
  if (!config.enabled) return null;
  final stellar = StellarConfig.fromEnvironment(env);
  final httpClient = http.Client();
  final rpc = SorobanRpcClient(
    httpClient: httpClient,
    url: stellar.rpcUrl,
    timeout: _rpcTimeout,
  );
  const ChainLog log = _consoleLog;
  final registry = SorobanLedger(rpc, stellar);
  final events = SorobanRegistryEventReader(rpc, stellar);
  final loop = TrackerLoop(
    interval: config.interval,
    passTimeout: _passTimeout,
    log: log,
    runPass: () async {
      final session = await pod.createSession();
      try {
        final indexer = CatalogIndexer(
          registry: registry,
          events: events,
          repository: ServerpodAgentIndexRepository(
            session,
            network: stellar.networkPassphrase,
          ),
          log: log,
        );
        final summary = await indexer.pass();
        log(ChainLogLevel.info, 'Catalog index pass: $summary');
      } finally {
        await session.close();
      }
    },
    onStop: () async => httpClient.close(),
  )..start();
  log(
    ChainLogLevel.info,
    'Catalog indexer started, every ${config.interval.inSeconds}s',
  );
  return loop;
}

void _consoleLog(ChainLogLevel level, String message) {
  final line = '[catalog-indexer] ${level.name}: $message';
  if (level == ChainLogLevel.info) {
    stdout.writeln(line);
  } else {
    stderr.writeln(line);
  }
}
