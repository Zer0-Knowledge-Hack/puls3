import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:serverpod/serverpod.dart';

import '../ledger/soroban_ledger.dart';
import '../ledger/soroban_rpc_client.dart';
import '../ledger/stellar_config.dart';
import 'agent_catalog_service.dart';
import 'catalog_reader.dart';
import 'indexed_agent_catalog_service.dart';
import 'serverpod_agent_index_repository.dart';

/// How long one Soroban RPC call may take before the chain counts as down.
const _rpcTimeout = Duration(seconds: 8);

/// The HTTP client shared by every catalog read. Created once and reused for
/// the life of the process, so requests do not open a socket each time.
http.Client? _sharedHttpClient;

/// The on-chain fallback, built once per process. It owns the 60 s cache, the
/// shared in-flight refresh and the serve-last-list-on-outage behavior, so
/// rebuilding it on every request would lose all three.
CatalogReader? _chainCatalog;

/// How many times the on-chain fallback was built. Tests assert it stays 1.
@visibleForTesting
int chainCatalogBuilds = 0;

/// Clears the cached fallback and the build counter, for tests.
@visibleForTesting
void resetChainCatalog() {
  _chainCatalog = null;
  chainCatalogBuilds = 0;
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

AgentCatalogService _buildChainCatalog(StellarConfig config, http.Client client) =>
    AgentCatalogService(
      SorobanLedger(
        SorobanRpcClient(
          httpClient: client,
          url: config.rpcUrl,
          timeout: _rpcTimeout,
        ),
        config,
      ),
    );

/// Builds the catalog reader for one request: the Postgres index, falling back
/// to the on-chain catalog while the index is empty.
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
  return IndexedAgentCatalogService(
    index: ServerpodAgentIndexRepository(
      session,
      network: config.networkPassphrase,
    ),
    fallback: fallback,
  );
}
