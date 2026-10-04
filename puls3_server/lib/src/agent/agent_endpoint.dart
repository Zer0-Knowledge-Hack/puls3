import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../ledger/soroban_ledger.dart';
import '../ledger/soroban_rpc_client.dart';
import '../ledger/stellar_config.dart';
import 'agent_catalog_service.dart';

/// How long one Soroban RPC call may take before the chain counts as down.
const _rpcTimeout = Duration(seconds: 8);

/// Serves the agent catalog read from the on-chain identity registry.
///
/// It only delegates to [AgentCatalogService], which owns caching and the
/// outage policy. When the chain cannot be read and nothing is cached, `list`
/// and `get` throw [AgentCatalogUnavailable] instead of answering with an
/// empty catalog or `null`.
class AgentEndpoint extends Endpoint {
  static AgentCatalogService? _service;

  /// The service in use. The first call builds the default one from the
  /// `PULS3_STELLAR_*` environment and keeps it for the life of the process.
  static AgentCatalogService get _instance => _service ??= _defaultService();

  /// Replaces the service, for tests. `null` restores the lazy default.
  @visibleForTesting
  static set service(AgentCatalogService? service) => _service = service;

  /// Every agent registered on chain with valid metadata, oldest first.
  Future<List<AgentSummary>> list(Session session) => _instance.list();

  /// The agent with the metadata id [id], or `null` when there is none.
  Future<AgentSummary?> get(Session session, String id) => _instance.get(id);

  static AgentCatalogService _defaultService() {
    final config = StellarConfig.fromEnvironment(Platform.environment);
    final rpc = SorobanRpcClient(
      httpClient: http.Client(),
      url: config.rpcUrl,
      timeout: _rpcTimeout,
    );
    return AgentCatalogService(SorobanLedger(rpc, config));
  }
}
