import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:serverpod/serverpod.dart';

import '../agent/agent_catalog_service.dart';
import '../chain/serverpod_chain_submission_store.dart';
import '../chain/submission_ledger.dart';
import '../generated/protocol.dart' show AgentSummary;
import '../ledger/envelope_codec.dart';
import '../ledger/soroban_ledger.dart';
import '../ledger/soroban_rpc_client.dart';
import '../ledger/soroban_submission_ledger.dart';
import '../ledger/stellar_config.dart';
import '../ledger/stellar_envelope_codec.dart';
import '../runtime/serverpod_hire_run_store.dart';
import 'chain_accounts.dart';
import 'escrow_relay_service.dart';
import 'hire_query_service.dart';
import 'hire_relay_config.dart';
import 'hire_service.dart';
import 'serverpod_escrow_preparation_store.dart';
import 'serverpod_hire_repository.dart';

/// How long one Soroban RPC call may take before the chain counts as down.
const _rpcTimeout = Duration(seconds: 8);

/// The services one `HireEndpoint` request works with.
final class HireServices {
  const HireServices({required this.hires, required this.relay, this.query});

  final HireService hires;
  final EscrowRelayService relay;

  /// Reads a hire for `getHire`. Null only in tests that do not read hires.
  final HireQueryService? query;
}

/// Builds the [HireServices] of one request on its database [Session].
typedef HireServicesBuilder = HireServices Function(Session session);

/// The parts of the hire services that belong to the process, not to a
/// request: the RPC client, the agent catalog cache and the codec.
///
/// Nothing here reads the `PULS3_ESCROW_*`, `PULS3_PLATFORM_FEE_BPS` or
/// `PULS3_HIRE_*` settings. [HireRelayConfig] reads them when an operation
/// needs one, so a missing key fails that operation with
/// `HireConfigurationMissing` and never stops the server or another endpoint.
final class HireWiring {
  HireWiring._({
    required this.stellar,
    required this.ledger,
    required this.catalog,
    required this.codec,
    required this.accounts,
    required this.sender,
    required this.config,
  });

  /// Builds the wiring from [environment] (the process environment when
  /// omitted) and [httpClient] (a new client when omitted).
  factory HireWiring.fromEnvironment({
    Map<String, String>? environment,
    http.Client? httpClient,
  }) {
    final env = environment ?? Platform.environment;
    final stellar = StellarConfig.fromEnvironment(env);
    final rpc = SorobanRpcClient(
      httpClient: httpClient ?? http.Client(),
      url: stellar.rpcUrl,
      timeout: _rpcTimeout,
    );
    final ledger = SorobanLedger(rpc, stellar);
    return HireWiring._(
      stellar: stellar,
      ledger: ledger,
      catalog: AgentCatalogService(ledger),
      codec: StellarEnvelopeCodec.forPassphrase(stellar.networkPassphrase),
      accounts: RpcChainAccounts(rpc),
      sender: SorobanSubmissionLedger(rpc, escrow: stellar.escrow),
      config: HireRelayConfig(env),
    );
  }

  final StellarConfig stellar;
  final SorobanLedger ledger;
  final AgentCatalogService catalog;
  final EnvelopeCodec codec;
  final ChainAccounts accounts;
  final SubmissionLedger sender;
  final HireRelayConfig config;

  /// The services of one request, with stores on [session].
  HireServices servicesOn(Session session) {
    final repository = ServerpodHireRepository(session);
    final preparations = ServerpodEscrowPreparationStore(session);
    final submissions = ServerpodChainSubmissionStore(session);
    Future<AgentSummary?> agentOf(int registryId) async =>
        (await catalog.list())
            .where((agent) => agent.registryId == registryId)
            .firstOrNull;
    final relay = EscrowRelayService(
      preparations: preparations,
      submissions: submissions,
      hires: repository,
      accounts: accounts,
      codec: codec,
      sender: sender,
      agentWallets: ledger,
      agents: agentOf,
      stellar: stellar,
      config: config,
    );
    return HireServices(
      hires: HireService(
        hires: repository,
        preparations: preparations,
        relay: relay,
        registry: ledger,
        catalog: catalog,
        config: config,
      ),
      relay: relay,
      query: HireQueryService(
        hires: repository,
        runs: ServerpodHireRunStore(session),
        submissions: submissions,
        agents: agentOf,
      ),
    );
  }
}
