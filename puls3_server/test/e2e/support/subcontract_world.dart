import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;
import 'package:puls3_server/src/agent/agent_catalog_wiring.dart'
    show buildAgentSearchService, chainCatalog;
import 'package:puls3_server/src/agent/custodied_wallets.dart';
import 'package:puls3_server/src/agent/stellar_agent_wallet_custody.dart';
import 'package:puls3_server/src/agent/serverpod_agent_index_repository.dart';
import 'package:puls3_server/src/agent/serverpod_agent_wallet_store.dart';
import 'package:puls3_server/src/chain/agent_submit_sender.dart';
import 'package:puls3_server/src/chain/escrow_deadline.dart';
import 'package:puls3_server/src/chain/escrow_server_submit.dart';
import 'package:puls3_server/src/chain/serverpod_chain_submission_store.dart';
import 'package:puls3_server/src/hire/chain_accounts.dart';
import 'package:puls3_server/src/hire/escrow_relay_service.dart';
import 'package:puls3_server/src/hire/hire_agent_lookup.dart';
import 'package:puls3_server/src/hire/serverpod_child_job_store.dart';
import 'package:puls3_server/src/hire/serverpod_escrow_preparation_store.dart';
import 'package:puls3_server/src/hire/serverpod_hire_receipt_store.dart';
import 'package:puls3_server/src/hire/serverpod_hire_repository.dart';
import 'package:puls3_server/src/ledger/contract_reader.dart';
import 'package:puls3_server/src/ledger/ledger_errors.dart';
import 'package:puls3_server/src/ledger/envelope_codec.dart'
    show PreparedEnvelope;
import 'package:puls3_server/src/ledger/soroban_ledger.dart';
import 'package:puls3_server/src/ledger/soroban_rpc_client.dart';
import 'package:puls3_server/src/ledger/soroban_submission_ledger.dart';
import 'package:puls3_server/src/runtime/agent_runner.dart';
import 'package:puls3_server/src/runtime/child_agent_lookup.dart';
import 'package:puls3_server/src/runtime/conversation.dart';
import 'package:puls3_server/src/runtime/escrow_subcontract_port.dart';
import 'package:puls3_server/src/runtime/hire_runner.dart';
import 'package:puls3_server/src/runtime/provider_router.dart';
import 'package:puls3_server/src/runtime/run_manifest.dart';
import 'package:puls3_server/src/runtime/runtime_config.dart';
import 'package:puls3_server/src/runtime/serverpod_due_submit_source.dart';
import 'package:puls3_server/src/runtime/serverpod_hire_run_store.dart';
import 'package:puls3_server/src/runtime/subcontract_port.dart';
import 'package:puls3_server/src/runtime/subcontract_setup.dart';
import 'package:puls3_server/src/runtime/subcontract_wiring.dart';
import 'package:puls3_server/src/runtime/tool_loop.dart';
import 'package:serverpod/serverpod.dart' show Session;

import 'contract_event_log.dart';
import 'e2e_world.dart';
import 'local_sandbox.dart';

/// What the tests pass to `E2eWorld.start` so hires may carry a subcontract
/// reserve: the platform ceiling is the most `subcontractMaxChildrenCap`
/// children at [e2ePriceStroops] each. ADR-0011 D1 names a configured ceiling
/// per network but no value, so the sandbox derives one from the platform cap
/// instead of inventing a number.
Map<String, String> subcontractEnvironment() => {
  'PULS3_SUBCONTRACT_RESERVE_MAX_STROOPS':
      '${subcontractMaxChildrenCap * e2ePriceStroops}',
};

/// The reserve a consumer funds for [children] children at the sandbox price.
int reserveFor(int children) => children * e2ePriceStroops;

// ---------------------------------------------------------------------------
// The stand-in for the model.

/// One agent's behavior, keyed by the system prompt of its manifest.
abstract interface class Persona {
  /// A plain run of the agent (a hired child).
  Future<String> complete(RuntimeTask task);

  /// One turn of the agent's conversation (a parent with tools).
  Future<ModelTurn> converse(ConversationTask task);
}

/// A deterministic [ConversationRuntime]: it never calls a provider. Each
/// manifest of a suite carries a persona name as its system prompt, and the
/// model answers as that persona.
final class ScriptedModel implements ConversationRuntime {
  ScriptedModel(this.personas);

  final Map<String, Persona> personas;

  /// The calls the model answered, for tests that count them.
  final calls = <String>[];

  Persona _of(String systemPrompt) {
    for (final entry in personas.entries) {
      if (systemPrompt.startsWith(entry.key)) return entry.value;
    }
    throw StateError('no persona for system prompt "$systemPrompt"');
  }

  @override
  Future<String> complete(RuntimeTask task, {Future<void>? abortTrigger}) {
    calls.add('complete:${task.systemPrompt}');
    return _of(task.systemPrompt).complete(task);
  }

  @override
  Future<ModelTurn> converse(
    ConversationTask task, {
    Future<void>? abortTrigger,
  }) {
    calls.add('converse:${task.messages.length}');
    return _of(task.systemPrompt).converse(task);
  }
}

/// A hired child: answers with [output], or fails with [failure].
final class Worker implements Persona {
  Worker({this.output = 'work done', this.failure});

  final String output;
  final RuntimeFailure? failure;

  @override
  Future<String> complete(RuntimeTask task) async {
    final failure = this.failure;
    if (failure != null) throw failure;
    return output;
  }

  @override
  Future<ModelTurn> converse(ConversationTask task) =>
      throw StateError('a worker holds no conversation');
}

/// A parent that searches the marketplace for [skill], then subcontracts
/// [wanted] one after another, and answers with what each call returned.
///
/// [wanted] names agents (the registered names). The agent id is read from
/// the server's own search result, so the model never invents one.
final class Delegator implements Persona {
  Delegator({
    required this.skill,
    required this.wanted,
    this.task = 'do the part A cannot',
  });

  final String skill;
  final List<String> wanted;
  final String task;

  @override
  Future<String> complete(RuntimeTask task) =>
      throw StateError('a delegator runs the tool loop');

  @override
  Future<ModelTurn> converse(ConversationTask t) async {
    final messages = t.messages;
    final calls = {
      for (final m in messages)
        if (m is AssistantMessage)
          for (final call in m.toolCalls) call.id: call,
    };
    final subcontracted = [
      for (final m in messages)
        if (m is ToolResultMessage && calls[m.callId]?.name == 'subcontract') m,
    ];
    final search = messages
        .whereType<ToolResultMessage>()
        .where((m) => calls[m.callId]?.name == 'search_agents')
        .firstOrNull;
    if (search == null) {
      return ToolCallsTurn(
        calls: [
          ToolCall(
            id: 'search-1',
            name: 'search_agents',
            arguments: {
              'query': skill,
              'skills': [skill],
            },
          ),
        ],
      );
    }
    if (subcontracted.length < wanted.length) {
      final name = wanted[subcontracted.length];
      final candidates = (_unwrap(search.content)['candidates'] as List)
          .cast<Map<String, Object?>>();
      final pick = candidates.where((c) => c['name'] == name).firstOrNull;
      if (pick == null) {
        return const FinalText('no candidate named in the search');
      }
      return ToolCallsTurn(
        calls: [
          ToolCall(
            id: 'sub-${subcontracted.length + 1}',
            name: 'subcontract',
            arguments: {
              'agent_id': pick['agent_id'],
              'task': task,
              'justification': 'best ranked for the part A cannot do',
            },
          ),
        ],
      );
    }
    final parts = [
      for (final m in subcontracted)
        m.isError ? 'refused ${_error(m.content)}' : 'delivered ${m.content}',
    ];
    return FinalText('A report. ${parts.join(' | ')}');
  }

  /// The tool error's code, then its message (which names the reason).
  static String _error(String content) {
    final error = jsonDecode(content) as Map<String, Object?>;
    return '${error['error']} (${error['message']})';
  }

  static Map<String, Object?> _unwrap(String content) {
    final start = content.indexOf('\n') + 1;
    final end = content.lastIndexOf('\n</untrusted_data>');
    return jsonDecode(content.substring(start, end)) as Map<String, Object?>;
  }
}

// ---------------------------------------------------------------------------
// The manifests.

/// The manifests of a suite by registry id. An agent in [unreadable] has a
/// manifest lookup that fails like an unreadable registry, so its run stays
/// queued and never starts.
final class ScriptedManifests implements RunManifestSource {
  final byAgent = <int, RunManifest>{};
  final unreadable = <int>{};

  /// Everything a suite agent shares. The limits are the platform's own:
  /// `RuntimeConfig` and the runtime task limits, never a number of the test.
  static const provider = 'anthropic';

  void opensChildren(
    int registryId,
    String persona, {
    required int maxChildren,
  }) {
    byAgent[registryId] = RunManifest(
      provider: provider,
      modelId: 'e2e',
      systemPrompt: persona,
      inputMaxChars: 4000,
      outputMaxChars: 4000,
      subcontract: SubcontractOptIn(
        maxChildren: maxChildren,
        suggestedReserve: 0,
      ),
    );
  }

  void plain(int registryId, String persona) {
    byAgent[registryId] = RunManifest(
      provider: provider,
      modelId: 'e2e',
      systemPrompt: persona,
      inputMaxChars: 4000,
      outputMaxChars: 4000,
    );
  }

  @override
  Future<RunManifest?> find(int agentId, int manifestVersion) async {
    if (unreadable.contains(agentId)) {
      throw const LedgerUnavailable('manifest registry unreadable');
    }
    return byAgent[agentId];
  }
}

// ---------------------------------------------------------------------------
// The runtime of the suites: the production composition, driven by hand.

/// The agent runtime and its submit and deadline passes, composed as
/// `startAgentRuntime` composes them (`agent_runtime_wiring.dart`), with two
/// differences: the model is a [ScriptedModel], and the passes run when the
/// test calls [pass] instead of on a timer. `startAgentRuntime` has no seam
/// for a stand-in model, so its own composition is not exercised here.
final class SubcontractRuntime {
  SubcontractRuntime({
    required this.world,
    required this.model,
    required this.manifests,
    required this.relay,
    this.runHeadroom,
    Duration? modelTimeout,
  }) : _timeout = modelTimeout ?? RuntimeConfig.defaultTimeout,
       _rpc = SorobanRpcClient(
         httpClient: http.Client(),
         url: world.wiring.stellar.rpcUrl,
         timeout: world.wiring.stellar.rpcTimeout,
       );

  final E2eWorld world;
  final ScriptedModel model;
  final ScriptedManifests manifests;

  /// The account that sends `release` and `claim_refund`, as the relay key of
  /// production does. The test passwords hold none, so the run funds its own.
  final E2eAccount relay;

  /// Replaces `childRunHeadroom` of the port for the one suite that cannot
  /// wait it out; the production value applies when null.
  final Duration? runHeadroom;

  final Duration _timeout;
  final SorobanRpcClient _rpc;
  final _agents = <String>{};
  var _deadlineAfterId = 0;

  /// The log of the passes, for failure messages.
  final log = <String>[];

  /// Fails the unfinished runs rows earlier test runs left in the shared test
  /// database. Their agents' keys were sealed by a cipher that is gone, so
  /// their runs and verdicts could never end and would take the batch of every
  /// pass. A run of this suite is queued after this call.
  Future<void> discardStaleRuns() async {
    final runs = ServerpodHireRunStore(world.session);
    for (final entry in await runs.listAwaitingChild(limit: 1000)) {
      await runs.markFailed(entry.hireId, 'e2e_stale', DateTime.now());
    }
    for (final queued in await runs.listQueued(
      limit: 1000,
      now: DateTime.now(),
    )) {
      await runs.markFailed(queued.hireId, 'e2e_stale', DateTime.now());
    }
  }

  /// Every escrow event of this run's sandbox, oldest first.
  Future<List<ContractEventRecord>> escrowEvents() => world.events.read(
    world.wiring.stellar.escrow.value,
    startLedger: world.startLedger,
  );

  /// Runs [body] with the port a pass of this runtime would use.
  Future<T> withPort<T>(Future<T> Function(SubcontractPort port) body) async {
    final session = await world.pod.createSession();
    try {
      return await body(_services(session).setup.port);
    } finally {
      await session.close();
    }
  }

  /// The escrow's live approval window, in seconds.
  Future<int> approvalWindow() => contractApprovalWindow(
    ContractReader(_rpc, source: world.wiring.stellar.simulationSource),
    escrow: world.wiring.stellar.escrow,
  )();

  /// Signs [envelope] as [signer], sends it straight to the node and waits
  /// for it to land. For a call the server never makes, such as a child with
  /// its own sub-reserve (the server draws children at a reserve of 0).
  Future<void> sendDirect(E2eAccount signer, PreparedEnvelope envelope) async {
    final result = await _rpc.sendTransaction(
      signer.signPrepared(world.codec, envelope),
      envelope.hashHex,
    );
    if (result.status == SendTransactionStatus.error) {
      throw StateError('the node refused ${envelope.hashHex}');
    }
    await until('transaction ${envelope.hashHex} to land', () async {
      final tx = await _rpc.getTransaction(envelope.hashHex);
      final status = tx['status'];
      if (status == 'FAILED') {
        throw StateError('transaction ${envelope.hashHex} failed');
      }
      return status == 'SUCCESS' ? tx : null;
    });
  }

  /// Runs [body] with the escrow relay service of a pass.
  Future<T> withRelay<T>(
    Future<T> Function(EscrowRelayService relay) body,
  ) async {
    final session = await world.pod.createSession();
    try {
      return await body(_relayOn(session));
    } finally {
      await session.close();
    }
  }

  /// Lets [agent] sign its calls: only the wallets of this run's agents are
  /// served, so rows left by earlier runs never hold a pass.
  void serve(E2eAccount agent) => _agents.add(agent.address.value);

  Future<RunPassSummary> pass() async {
    final session = await world.pod.createSession();
    try {
      final services = _services(session);
      final timings = runtimeTimings(
        timeout: _timeout,
        batchSize: 10,
        maxTurns: defaultMaxLoopTurns,
      );
      final summary =
          await HireRunner(
            manifests: manifests,
            runner: AgentRunner(
              runtime: ProviderRouter({ScriptedManifests.provider: model}),
              timeout: _timeout,
            ),
            staleAfter: timings.staleAfter,
            log: _log,
            subcontracting: services.setup,
          ).pass(
            runs: ServerpodHireRunStore(session),
            hires: ServerpodHireRepository(session),
          );
      await services.reconcileChildren(_log);
      await _submitPass(session, services);
      try {
        await _deadlinePass(session);
      } on Object catch (e) {
        // The tracker logs a failed deadline pass and goes on.
        _log('deadline', 'pass failed: $e');
      }
      return summary;
    } finally {
      await session.close();
    }
  }

  /// Runs [pass] until [probe] answers, or fails with [what] on timeout.
  Future<T> passUntil<T>(
    String what,
    Future<T?> Function() probe, {
    Duration timeout = const Duration(minutes: 4),
  }) async {
    try {
      return await until(what, () async {
        await pass();
        return probe();
      }, timeout: timeout);
    } on Object {
      // ignore: avoid_print
      print('--- passes while waiting for $what\n${log.join('\n')}');
      rethrow;
    }
  }

  void _log(dynamic level, String message) => log.add('$level: $message');

  EscrowRelayService _relayOn(Session session) {
    final stellar = world.wiring.stellar;
    return EscrowRelayService(
      preparations: ServerpodEscrowPreparationStore(session),
      submissions: ServerpodChainSubmissionStore(session),
      hires: ServerpodHireRepository(session),
      accounts: RpcChainAccounts(_rpc),
      codec: world.codec,
      sender: SorobanSubmissionLedger(_rpc, escrow: stellar.escrow),
      agentWallets: SorobanLedger(_rpc, stellar),
      agents: hireAgentLookup(
        index: ServerpodAgentIndexRepository(
          session,
          network: stellar.networkPassphrase,
        ),
        fallback: chainCatalog(world.sandbox.environment),
      ),
      stellar: stellar,
      config: world.wiring.config,
    );
  }

  SubcontractServices _services(Session session) {
    final stellar = world.wiring.stellar;
    final env = world.sandbox.environment;
    final hires = ServerpodHireRepository(session);
    final submissions = ServerpodChainSubmissionStore(session);
    final ledger = SorobanLedger(_rpc, stellar);
    final accounts = RpcChainAccounts(_rpc);
    final agentOf = hireAgentLookup(
      index: ServerpodAgentIndexRepository(
        session,
        network: stellar.networkPassphrase,
      ),
      fallback: chainCatalog(env),
    );
    final signer = CustodiedEnvelopeSigner(
      wallets: ServerpodAgentWalletStore(session),
      cipher: world.custody,
      codec: world.codec,
    );
    final receipts = ServerpodHireReceiptStore(session);
    final approvalWindow = contractApprovalWindow(
      ContractReader(_rpc, source: stellar.simulationSource),
      escrow: stellar.escrow,
    );
    final childAgent = childAgentLookup(
      agentOf: agentOf,
      registry: ledger,
      custody: custodyOn(session),
      unpublished: publicationOn(session),
    );
    final escrowRelay = _relayOn(session);
    final services = buildSubcontractServices(
      hires: hires,
      receipts: receipts,
      runs: ServerpodHireRunStore(session),
      submissions: submissions,
      openings: ServerpodChildJobStore(session),
      jobs: ledger,
      relay: escrowRelay,
      accounts: accounts,
      codec: world.codec,
      config: world.wiring.config,
      childAgent: childAgent,
      approvalWindow: approvalWindow,
      sign: signer.sign,
      send: _rpc.sendTransaction,
      search: buildAgentSearchService(session, environment: env).search,
      escrow: stellar.escrow,
      inclusionFee: world.wiring.config.inclusionFeeStroops,
      validitySeconds: world.wiring.config.preparationValiditySeconds,
      maxTurns: defaultMaxLoopTurns,
      log: _log,
    );
    final headroom = runHeadroom;
    if (headroom == null) return services;
    return SubcontractServices(
      setup: SubcontractSetup(
        search: services.setup.search,
        port: EscrowSubcontractPort(
          hires: hires,
          receipts: receipts,
          submissions: submissions,
          jobs: ledger,
          relay: escrowRelay,
          codec: world.codec,
          config: world.wiring.config,
          childAgent: childAgent,
          approvalWindow: approvalWindow,
          sign: signer.sign,
          send: _rpc.sendTransaction,
          runHeadroom: headroom,
          log: _log,
        ),
        children: services.setup.children,
        maxTurns: defaultMaxLoopTurns,
      ),
      reconciler: services.reconciler,
      childrenOpen: services.childrenOpen,
    );
  }

  /// The custodied `submit` of every succeeded run, as `_SubmitWiring.pass`
  /// does, for the agents of this run only.
  Future<void> _submitPass(
    Session session,
    SubcontractServices services,
  ) async {
    final stellar = world.wiring.stellar;
    final signer = CustodiedEnvelopeSigner(
      wallets: ServerpodAgentWalletStore(session),
      cipher: world.custody,
      codec: world.codec,
    );
    final sender = AgentSubmitSender(
      submissions: ServerpodChainSubmissionStore(session),
      accounts: RpcChainAccounts(_rpc),
      codec: world.codec,
      sign: signer.sign,
      send: _rpc.sendTransaction,
      escrow: stellar.escrow,
      inclusionFee: world.wiring.config.inclusionFeeStroops,
      validitySeconds: world.wiring.config.preparationValiditySeconds,
      now: DateTime.now,
      log: _log,
      childrenOpen: services.childrenOpen,
    );
    final due = await ServerpodDueSubmitSource(session).list(limit: 100);
    for (final item in due) {
      if (_agents.contains(item.provider.value)) await sender.send(item);
    }
  }

  /// `release` and `claim_refund` of jobs past their deadline, from the relay
  /// account, as the tracker's deadline pass does.
  Future<void> _deadlinePass(Session session) async {
    final stellar = world.wiring.stellar;
    final reader = SorobanLedger(_rpc, stellar);
    _deadlineAfterId = await EscrowDeadlineRunner(
      afterId: _deadlineAfterId,
      jobs: reader,
      expiry: reader,
      hires: ServerpodHireRepository(session),
      ledgerTime: _rpc.latestLedgerCloseTime,
      log: _log,
      sender: RelayEscrowCallSender(
        submissions: ServerpodChainSubmissionStore(session),
        accounts: RpcChainAccounts(_rpc),
        codec: world.codec,
        sign: (prepared) => relay.signPrepared(world.codec, prepared),
        send: _rpc.sendTransaction,
        source: relay.address,
        escrow: stellar.escrow,
        inclusionFee: world.wiring.config.inclusionFeeStroops,
        validitySeconds: world.wiring.config.preparationValiditySeconds,
        now: DateTime.now,
        log: _log,
      ),
    ).pass();
  }
}

/// [bytes] as lowercase hex, the form a bytes32 event field prints in.
String bytesHex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
