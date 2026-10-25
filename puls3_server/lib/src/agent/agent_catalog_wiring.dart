import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:serverpod/serverpod.dart';

import '../chain/chain_log.dart';
import '../feedback/reputation_wiring.dart';
import '../ledger/contract_reader.dart';
import '../ledger/soroban_ledger.dart';
import '../ledger/soroban_rpc_client.dart';
import '../ledger/stellar_config.dart';
import 'agent_catalog_service.dart';
import 'catalog_reader.dart';
import 'indexed_agent_catalog_service.dart';
import 'reputation_catalog_reader.dart';
import 'serverpod_agent_index_repository.dart';

/// The HTTP client shared by every catalog read. Created once and reused for
/// the life of the process, so requests do not open a socket each time.
http.Client? _sharedHttpClient;

/// The on-chain fallback, built once per process. It owns the 60 s cache, the
/// shared in-flight refresh and the serve-last-list-on-outage behavior, so
/// rebuilding it on every request would lose all three.
CatalogReader? _chainCatalog;

/// The reputation read and its 60 s cache, built once per process: a cache
/// built per request would never be hit. Its registry is the one of the first
/// request's configuration: `PULS3_STELLAR_REPUTATION_REGISTRY`, or unwired
/// (every agent without feedback) while that is unset.
ReputationCache? _reputationCache;

/// How many times the on-chain fallback was built. Tests assert it stays 1.
@visibleForTesting
int chainCatalogBuilds = 0;

/// How many times the reputation cache was built. Tests assert it stays 1.
@visibleForTesting
int reputationCacheBuilds = 0;

/// Clears the cached fallback, the reputation cache and the build counters,
/// for tests.
@visibleForTesting
void resetChainCatalog() {
  _chainCatalog = null;
  chainCatalogBuilds = 0;
  _reputationCache = null;
  reputationCacheBuilds = 0;
}

ReputationCache _reputation(StellarConfig config) {
  final cached = _reputationCache;
  if (cached != null) return cached;
  reputationCacheBuilds++;
  final rpc = SorobanRpcClient(
    httpClient: _sharedHttpClient ??= http.Client(),
    url: config.rpcUrl,
    timeout: config.rpcTimeout,
  );
  return _reputationCache = ReputationCache(
    registry: reputationRegistryFor(
      config,
      ContractReader(rpc, source: config.simulationSource),
    ),
  );
}

/// The process-wide on-chain catalog fallback, created on first use.
CatalogReader chainCatalog(Map<String, String> environment) {
  final cached = _chainCatalog;
  if (cached != null) return cached;
  chainCatalogBuilds++;
  return _chainCatalog = _buildChainCatalog(
    StellarConfig.fromEnvironment(environment),
    _sharedHttpClient ??= http.Client(),
  );
}

AgentCatalogService _buildChainCatalog(
  StellarConfig config,
  http.Client client,
) => AgentCatalogService(
  SorobanLedger(
    SorobanRpcClient(
      httpClient: client,
      url: config.rpcUrl,
      timeout: config.rpcTimeout,
    ),
    config,
  ),
  log: catalogConsoleLog,
);

/// Writes a catalog message to the process output: info to stdout, the rest to
/// stderr, like the other wiring logs.
void catalogConsoleLog(ChainLogLevel level, String message) {
  final line = '[agent-catalog] ${level.name}: $message';
  if (level == ChainLogLevel.info) {
    stdout.writeln(line);
  } else {
    stderr.writeln(line);
  }
}

/// Builds the catalog reader for one request: the Postgres index, falling back
/// to the on-chain catalog while the index is empty, with each agent's
/// reputation added by the #11 function.
///
/// Every Soroban import lives here, not in the endpoint, so the endpoint
/// depends only on [CatalogReader]. The fallback is a process-wide singleton;
/// a test that passes [environment] or [httpClient] gets a fresh, isolated one.
CatalogReader buildAgentCatalogReader(
  Session session, {
  Map<String, String>? environment,
  http.Client? httpClient,
}) {
  final config = StellarConfig.fromEnvironment(
    environment ?? Platform.environment,
  );
  final fallback = (environment == null && httpClient == null)
      ? chainCatalog(Platform.environment)
      : _buildChainCatalog(
          config,
          httpClient ?? (_sharedHttpClient ??= http.Client()),
        );
  return ReputationCatalogReader(
    inner: IndexedAgentCatalogService(
      index: ServerpodAgentIndexRepository(
        session,
        network: config.networkPassphrase,
      ),
      fallback: fallback,
    ),
    cache: _reputation(config),
  );
}
