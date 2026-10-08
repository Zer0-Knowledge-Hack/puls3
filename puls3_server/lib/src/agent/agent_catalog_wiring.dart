import 'dart:io';

import 'package:http/http.dart' as http;
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

/// Builds the catalog reader for one request: the Postgres index, falling
/// back to the on-chain catalog while the index is still empty.
///
/// Every Soroban import lives here, not in the endpoint, so the endpoint
/// depends only on [CatalogReader].
CatalogReader buildAgentCatalogReader(
  Session session, {
  Map<String, String>? environment,
  http.Client? httpClient,
}) {
  final config = StellarConfig.fromEnvironment(
    environment ?? Platform.environment,
  );
  final client = httpClient ?? (_sharedHttpClient ??= http.Client());
  final ledger = SorobanLedger(
    SorobanRpcClient(
      httpClient: client,
      url: config.rpcUrl,
      timeout: _rpcTimeout,
    ),
    config,
  );
  return IndexedAgentCatalogService(
    index: ServerpodAgentIndexRepository(
      session,
      network: config.networkPassphrase,
    ),
    fallback: AgentCatalogService(ledger),
  );
}
