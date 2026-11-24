import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:serverpod/serverpod.dart';

import '../agent/aes_gcm_secret_cipher.dart';
import '../agent/agent_catalog_wiring.dart'
    show buildAgentSearchService, chainCatalog;
import '../agent/agent_wallet_custody.dart';
import '../agent/custodied_wallets.dart';
import '../agent/hidden_agents.dart';
import '../agent/serverpod_agent_index_repository.dart';
import '../agent/serverpod_agent_wallet_store.dart';
import '../agent/stellar_agent_wallet_custody.dart';
import '../agent/wallet_custody_config.dart';
import '../chain/agent_submit_sender.dart';
import '../chain/chain_log.dart';
import '../chain/escrow_deadline.dart';
import '../chain/serverpod_chain_submission_store.dart';
import '../chain/tracker_loop.dart';
import '../generated/protocol.dart' show HireConfigurationMissing;
import '../hire/chain_accounts.dart';
import '../hire/escrow_relay_service.dart';
import '../hire/hire_agent_lookup.dart';
import '../hire/hire_relay_config.dart';
import '../hire/serverpod_child_job_store.dart';
import '../hire/serverpod_escrow_preparation_store.dart';
import '../hire/serverpod_hire_receipt_store.dart';
import '../hire/serverpod_hire_repository.dart';
import '../ledger/contract_reader.dart';
import '../ledger/soroban_ledger.dart';
import '../ledger/soroban_rpc_client.dart';
import '../ledger/soroban_submission_ledger.dart';
import '../ledger/stellar_config.dart';
import '../ledger/stellar_envelope_codec.dart';
import '../studio/builder_credential.dart' show BuilderProviderCredential;
import '../studio/serverpod_studio_agent_version_store.dart';
import '../studio/studio_endpoint.dart';
import '../studio/studio_test_errors.dart';
import 'adapters/anthropic_runtime.dart';
import 'adapters/workers_ai_runtime.dart';
import 'agent_runner.dart';
import 'child_agent_lookup.dart';
import 'demo_manifests.dart';
import 'hire_runner.dart';
import 'missed_run_backfill.dart';
import 'provider_router.dart';
import 'run_execution.dart';
import 'run_manifest.dart';
import 'runtime_config.dart';
import 'serverpod_due_submit_source.dart';
import 'serverpod_hire_run_store.dart';
import 'studio_run_manifest_source.dart';
import 'subcontract_setup.dart' show RunnerLease, SubcontractSetup;
import 'subcontract_wiring.dart';
import 'tool_loop.dart' show defaultMaxLoopTurns;

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
  final rawAccountId = env[workersAiAccountVariable];
  final accountId = workersAiAccountId(rawAccountId);
  final workersAiToken = pod.getPassword(workersAiTokenPassword);
  if (accountId != null &&
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
    workersAiAccountSet: accountId != null,
    workersAiAccountMalformed:
        accountId == null && (rawAccountId?.trim().isNotEmpty ?? false),
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
  final rpc = SorobanRpcClient(
    httpClient: httpClient,
    url: stellar.rpcUrl,
    timeout: stellar.rpcTimeout,
  );
  final registry = SorobanLedger(rpc, stellar);
  final agentRunner = AgentRunner(
    runtime: router,
    timeout: config.timeout,
  );
  // A fresh session per lookup: the run itself can take minutes.
  Future<BuilderProviderCredential?> builderCredentials({
    required String owner,
    required String provider,
  }) async {
    final session = await pod.createSession();
    try {
      return await StudioEndpoint.credentialsOn(
        session,
      ).find(owner: owner, provider: provider);
    } on StudioRuntimeUnavailable {
      // No custody key: a paid provider's credential cannot be read, so the
      // run fails as a missing credential. It never falls back to the team
      // token. A free `workers-ai` manifest never gets here.
      return null;
    } finally {
      await session.close();
    }
  }

  final timings = runtimeTimings(
    timeout: config.timeout,
    batchSize: _batchSize,
    maxTurns: defaultMaxLoopTurns,
  );
  // One runner per pass: the subcontract setup holds the stores of that
  // pass's database session. Without a setup a run is one plain segment.
  HireRunner runnerWith(SubcontractSetup? subcontracting) => HireRunner(
    manifests: StudioRunManifestSource(
      lookup: (agentId, version) async {
        final session = await pod.createSession();
        try {
          final row = await ServerpodStudioAgentVersionStore(
            session,
          ).find(agentId, version);
          if (row == null) return null;
          return (manifestJson: row.manifestJson, owner: row.owner);
        } finally {
          await session.close();
        }
      },
      fallback: SeededRunManifestSource(
        registry: registry,
        manifests: demoManifests,
      ),
    ),
    runner: agentRunner,
    execute: runExecutor(team: agentRunner, credentials: builderCredentials),
    subcontracting: subcontracting,
    // A run still `running` past a whole segment of model calls was
    // interrupted.
    staleAfter: timings.staleAfter,
    log: log,
    batchSize: _batchSize,
  );
  final backfill = MissedRunBackfill(log: log);
  final submit = _submitWiringOrNull(env, rpc, stellar, log);
  // Subcontracting needs a custodied key to sign as agent A, so it is off
  // wherever `submit` is.
  final subcontract = submit == null
      ? null
      : _subcontractWiringOrNull(
          pod: pod,
          env: env,
          rpc: rpc,
          stellar: stellar,
          submit: submit,
          lease: runnerLease(
            team: agentRunner,
            credentials: builderCredentials,
          ),
          log: log,
        );
  final loop = TrackerLoop(
    interval: loopConfig.interval,
    passTimeout: timings.passTimeout,
    log: log,
    runPass: () async {
      final session = await pod.createSession();
      try {
        // Hires paid before hire_run existed get their run once.
        await backfill.run(
          () => ServerpodHireRunStore(session).enqueueMissing(DateTime.now()),
        );
        final services = subcontract?.on(session);
        final summary = await runnerWith(services?.setup).pass(
          runs: ServerpodHireRunStore(session),
          hires: ServerpodHireRepository(session),
        );
        if (summary.total > 0) log(ChainLogLevel.info, 'Pass: $summary');
        await services?.reconcileChildren(log);
        if (submit != null) {
          final sent = await submit.pass(
            session,
            childrenOpen: services?.childrenOpen,
          );
          if (sent > 0) {
            log(ChainLogLevel.info, 'Submit pass sent $sent envelope(s)');
          }
        }
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
    'timeout ${config.timeout.inSeconds}s'
    '${submit == null ? '; submit off' : ''}'
    '${subcontract == null ? '; subcontracting off' : '; subcontracting on'}',
  );
  return loop;
}

/// Custodied `submit` after a successful run, or null when the cipher or
/// hire relay fees are missing so the runtime can still call the model.
_SubmitWiring? _submitWiringOrNull(
  Map<String, String> env,
  SorobanRpcClient rpc,
  StellarConfig stellar,
  ChainLog log,
) {
  try {
    final custody = WalletCustodyConfig.fromEnvironment(env);
    final fees = HireRelayConfig(env);
    return _SubmitWiring(
      cipher: AesGcmSecretCipher(
        keys: {custody.keyVersion: custody.secretKey},
        writeKeyVersion: custody.keyVersion,
      ),
      codec: StellarEnvelopeCodec.forPassphrase(stellar.networkPassphrase),
      rpc: rpc,
      stellar: stellar,
      inclusionFee: fees.inclusionFeeStroops,
      validitySeconds: fees.preparationValiditySeconds,
      log: log,
    );
  } on AgentWalletCustodyUnavailable catch (e) {
    log(ChainLogLevel.info, 'Agent submit is off: $e');
  } on HireConfigurationMissing catch (e) {
    log(
      ChainLogLevel.info,
      'Agent submit is off: ${e.setting} is not set',
    );
  } on ArgumentError catch (e) {
    log(ChainLogLevel.warning, 'Agent submit is off: ${e.message}');
  }
  return null;
}

final class _SubmitWiring {
  _SubmitWiring({
    required this.cipher,
    required this.codec,
    required this.rpc,
    required this.stellar,
    required this.inclusionFee,
    required this.validitySeconds,
    required this.log,
  });

  final AesGcmSecretCipher cipher;
  final StellarEnvelopeCodec codec;
  final SorobanRpcClient rpc;
  final StellarConfig stellar;
  final int inclusionFee;
  final int validitySeconds;
  final ChainLog log;

  /// The signer of agent-signed envelopes over [session], which holds the
  /// custodied keys.
  CustodiedEnvelopeSigner signerOn(Session session) => CustodiedEnvelopeSigner(
    wallets: ServerpodAgentWalletStore(session),
    cipher: cipher,
    codec: codec,
  );

  Future<int> pass(
    Session session, {
    Future<bool> Function(int hireId)? childrenOpen,
  }) async {
    final signer = signerOn(session);
    final sender = AgentSubmitSender(
      submissions: ServerpodChainSubmissionStore(session),
      accounts: RpcChainAccounts(rpc),
      codec: codec,
      sign: signer.sign,
      send: rpc.sendTransaction,
      escrow: stellar.escrow,
      inclusionFee: inclusionFee,
      validitySeconds: validitySeconds,
      now: DateTime.now,
      log: log,
      childrenOpen: childrenOpen,
    );
    final due = await ServerpodDueSubmitSource(session).list();
    for (final item in due) {
      await sender.send(item);
    }
    return due.length;
  }
}

/// The subcontract executor of production (ADR-0011), or null when its
/// settings are missing so the runtime still runs plain hires. What
/// `HireRelayConfig` needs for a child job
/// (`PULS3_HIRE_JOB_DURATION_SECONDS`) is read here, so a missing value
/// turns subcontracting off at startup instead of failing a parent run
/// later.
///
/// There is no other switch: a hire carries a subcontract reserve only when
/// `PULS3_SUBCONTRACT_RESERVE_MAX_STROOPS` is set, and a run is offered the
/// tools only when its manifest opted in.
_SubcontractWiring? _subcontractWiringOrNull({
  required Serverpod pod,
  required Map<String, String> env,
  required SorobanRpcClient rpc,
  required StellarConfig stellar,
  required _SubmitWiring submit,
  required RunnerLease lease,
  required ChainLog log,
}) {
  try {
    final config = HireRelayConfig(env);
    // Fails now, not in the middle of a parent run.
    config.jobDurationSeconds;
    return _SubcontractWiring(
      pod: pod,
      env: env,
      rpc: rpc,
      stellar: stellar,
      submit: submit,
      config: config,
      hidden: HiddenAgents.fromEnvironment(env),
      lease: lease,
      log: log,
    );
  } on HireConfigurationMissing catch (e) {
    log(ChainLogLevel.info, 'Subcontracting is off: ${e.setting} is not set');
  } on ArgumentError catch (e) {
    log(ChainLogLevel.warning, 'Subcontracting is off: ${e.message}');
  }
  return null;
}

final class _SubcontractWiring {
  _SubcontractWiring({
    required this.pod,
    required this.env,
    required this.rpc,
    required this.stellar,
    required this.submit,
    required this.config,
    required this.hidden,
    required this.lease,
    required this.log,
  });

  final Serverpod pod;
  final Map<String, String> env;
  final SorobanRpcClient rpc;
  final StellarConfig stellar;
  final _SubmitWiring submit;
  final HireRelayConfig config;
  final HiddenAgents hidden;
  final RunnerLease lease;
  final ChainLog log;

  /// The services of one pass, with stores on [session].
  SubcontractServices on(Session session) {
    final hires = ServerpodHireRepository(session);
    final submissions = ServerpodChainSubmissionStore(session);
    final ledger = SorobanLedger(rpc, stellar);
    final accounts = RpcChainAccounts(rpc);
    // The same one-agent lookup as a consumer's hire (#206, I-2).
    final agentOf = hireAgentLookup(
      index: ServerpodAgentIndexRepository(
        session,
        network: stellar.networkPassphrase,
      ),
      fallback: chainCatalog(env),
    );
    final signer = submit.signerOn(session);
    return buildSubcontractServices(
      hires: hires,
      receipts: ServerpodHireReceiptStore(session),
      runs: ServerpodHireRunStore(session),
      submissions: submissions,
      openings: ServerpodChildJobStore(session),
      jobs: ledger,
      relay: EscrowRelayService(
        preparations: ServerpodEscrowPreparationStore(session),
        submissions: submissions,
        hires: hires,
        accounts: accounts,
        codec: submit.codec,
        sender: SorobanSubmissionLedger(rpc, escrow: stellar.escrow),
        agentWallets: ledger,
        agents: agentOf,
        stellar: stellar,
        config: config,
      ),
      accounts: accounts,
      codec: submit.codec,
      config: config,
      childAgent: childAgentLookup(
        agentOf: agentOf,
        registry: ledger,
        custody: custodyOn(session),
        unpublished: publicationOn(session),
        hidden: hidden,
      ),
      approvalWindow: contractApprovalWindow(
        ContractReader(rpc, source: stellar.simulationSource),
        escrow: stellar.escrow,
      ),
      sign: signer.sign,
      send: rpc.sendTransaction,
      search: buildAgentSearchService(session).search,
      escrow: stellar.escrow,
      inclusionFee: submit.inclusionFee,
      validitySeconds: submit.validitySeconds,
      maxTurns: defaultMaxLoopTurns,
      lease: lease,
      log: log,
    );
  }
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
  bool workersAiAccountMalformed = false,
}) {
  final warnings = <String>[];
  if (workersAiAccountMalformed) {
    warnings.add(
      '$workersAiAccountVariable is not a Cloudflare account id (letters and '
      'digits only), so the workers-ai provider is off',
    );
  } else if (workersAiAccountSet != workersAiTokenSet) {
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

/// `PULS3_WORKERS_AI_ACCOUNT_ID` trimmed, or `null` when it is unset, blank
/// or not a Cloudflare account id. The id is a path segment of every
/// Workers AI call, so only letters and digits are accepted: a `.`, `..`,
/// `/` or blank value would change the URL's path.
String? workersAiAccountId(String? raw) {
  final value = raw?.trim();
  if (value == null || !_accountIdPattern.hasMatch(value)) return null;
  return value;
}

final _accountIdPattern = RegExp(r'^[A-Za-z0-9]+$');

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
