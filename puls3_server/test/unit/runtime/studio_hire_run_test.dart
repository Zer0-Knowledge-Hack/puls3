// A hire of a Studio-deployed agent runs the version the builder published,
// on the builder's own provider credential (#220). The team runner (and with
// it the team Workers AI token) and the seeded demo manifests are traps here:
// any call to them fails the test.
import 'dart:convert';

import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/runtime/agent_runner.dart';
import 'package:puls3_server/src/runtime/hire_run_store.dart';
import 'package:puls3_server/src/runtime/hire_runner.dart';
import 'package:puls3_server/src/runtime/run_execution.dart';
import 'package:puls3_server/src/runtime/run_manifest.dart';
import 'package:puls3_server/src/runtime/runtime_task.dart';
import 'package:puls3_server/src/runtime/studio_run_manifest_source.dart';
import 'package:puls3_server/src/studio/builder_credential.dart';
import 'package:puls3_server/src/studio/studio_agent_version.dart';
import 'package:puls3_server/src/studio/studio_model_policy.dart';
import 'package:test/test.dart';

import '../../support/in_memory_hire_run_store.dart';
import '../hire/hire_test_fakes.dart';

const _builder = 'GBRPYHIL2CI3FNQ4BXLFMNDLFJUNPU2HY3ZMFSHONUCEOASW7QC7OX2H';
const _consumer = 'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H';
const _agentWallet = 'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY';
const _studioAgent = 42;
const _seededAgent = 13;
const _workersModel = '@cf/meta/llama-3.3-70b-instruct-fp8-fast';
const _builderToken = 'builder-cloudflare-token';
const _builderAccount = 'builderaccount0001';
final _t0 = DateTime.utc(2026, 11, 6, 12);

/// The manifest a seeded demo agent runs. A Studio hire must never get it.
const _seedManifest = RunManifest(
  provider: 'workers-ai',
  modelId: _workersModel,
  systemPrompt: 'SEED PROMPT: you are a demo agent.',
  inputMaxChars: 1000,
  outputMaxChars: 1000,
);

/// What a published Studio version stores in `AgentVersion.manifestJson`.
String _published(String systemPrompt, {String provider = 'workers-ai'}) =>
    jsonEncode(
      AgentManifestDraft(
        name: 'Copy Forge',
        description: 'Rewrites a paragraph in a calmer voice.',
        skills: [Skill(id: 'rewrite', name: 'Rewrite')],
        model: ModelId(
          provider: provider,
          id: provider == 'workers-ai' ? _workersModel : 'claude-haiku-5-5',
        ),
        systemPrompt: systemPrompt,
        inputType: InputType.text,
        inputMaxChars: 1000,
        outputType: OutputType.text,
        outputMaxChars: 1000,
        price: UsdcAmount.stroops(5000000),
      ).toJson(),
    );

/// The seeded demo manifests, keyed by registry id. Records every lookup.
final class _SeededManifests implements RunManifestSource {
  final lookups = <int>[];

  @override
  Future<RunManifest?> find(int agentId, int manifestVersion) async {
    lookups.add(agentId);
    return _seedManifest;
  }
}

/// The team model runtime, which holds the team Workers AI token.
final class _TeamModel implements ModelRuntime {
  final tasks = <RuntimeTask>[];

  @override
  Future<String> complete(
    RuntimeTask task, {
    Future<void>? abortTrigger,
  }) async {
    tasks.add(task);
    return 'answered on the team token';
  }
}

void main() {
  late FakeHireRepository hires;
  late InMemoryHireRunStore runs;
  late MemoryAgentVersionStore versions;
  late MemoryBuilderCredentialStore credentials;
  late _SeededManifests seeded;
  late _TeamModel team;
  late List<(RuntimeTask, BuilderProviderCredential)> builderCalls;
  late DateTime clock;

  HireRunner runner() {
    final teamRunner = AgentRunner(
      runtime: team,
      timeout: const Duration(seconds: 1),
    );
    return HireRunner(
      // The source the server wires in startAgentRuntime.
      manifests: StudioRunManifestSource(
        lookup: (agentId, version) async {
          final row = await versions.find(agentId, version);
          if (row == null) return null;
          return (manifestJson: row.manifestJson, owner: row.owner);
        },
        fallback: seeded,
      ),
      runner: teamRunner,
      staleAfter: const Duration(minutes: 3),
      now: () => clock,
      execute: runExecutor(
        team: teamRunner,
        credentials: credentials.find,
        builder: (task, credential) async {
          builderCalls.add((task, credential));
          return 'answered on the builder account';
        },
      ),
    );
  }

  Future<void> publish(int version, String systemPrompt) => versions.save(
    AgentVersion(
      registryAgentId: _studioAgent,
      version: version,
      owner: _builder,
      manifestJson: _published(systemPrompt),
      updatedAt: _t0,
    ),
  );

  Future<void> saveBuilderCredential({String? accountId = _builderAccount}) =>
      credentials.save(
        owner: _builder,
        credential: BuilderProviderCredential(
          provider: 'workers-ai',
          secret: _builderToken,
          accountId: accountId,
        ),
      );

  /// A funded hire of [agentId] pinned to [version], queued for the runner.
  int fundedHire({required int agentId, int version = 1}) {
    final id = hires.hires.length + 1;
    final open = Hire(
      id: HireId(id),
      agentId: AgentId(agentId),
      consumer: StellarAddress.parse(_consumer),
      price: UsdcAmount.stroops(5000000),
      manifestVersion: version,
    );
    final payment = Payment(
      transaction: TransactionHash.parse(
        '${'cd' * 31}${id.toString().padLeft(2, '0')}',
      ),
      hireId: open.id,
      payer: open.consumer,
      payee: StellarAddress.parse(_agentWallet),
      amount: open.price,
    );
    hires.hires[id] = open.fund(payment, agentWallet: payment.payee);
    runs.enqueue(
      QueuedRun(
        hireId: id,
        agentId: agentId,
        manifestVersion: version,
        input: 'Make this calmer: WHY IS IT LATE',
        expiredAt: 1800000000,
      ),
      _t0,
    );
    return id;
  }

  Future<RunPassSummary> pass() => runner().pass(runs: runs, hires: hires);

  setUp(() {
    hires = FakeHireRepository();
    runs = InMemoryHireRunStore();
    versions = MemoryAgentVersionStore();
    credentials = MemoryBuilderCredentialStore();
    seeded = _SeededManifests();
    team = _TeamModel();
    builderCalls = [];
    clock = _t0;
  });

  test('a Studio hire runs the published version on the builder credential, '
      'never on the team token or a seed manifest', () async {
    await publish(1, 'You rewrite one paragraph in a calmer voice.');
    await saveBuilderCredential();
    final id = fundedHire(agentId: _studioAgent);

    final summary = await pass();

    expect(summary.succeeded, 1);
    final run = await runs.find(id);
    expect(run!.state, HireRunState.succeeded);
    expect(run.result, 'answered on the builder account');

    final (task, credential) = builderCalls.single;
    expect(task.systemPrompt, 'You rewrite one paragraph in a calmer voice.');
    expect(task.modelId, _workersModel);
    expect(task.input, 'Make this calmer: WHY IS IT LATE');
    expect(credential.secret, _builderToken);
    expect(credential.accountId, _builderAccount);

    expect(team.tasks, isEmpty, reason: 'the team token was used');
    expect(seeded.lookups, isEmpty, reason: 'a seed manifest was looked up');
  });

  test('each hire runs the version it pinned: a new version does not change '
      'an earlier hire', () async {
    await publish(1, 'You answer as version one of this agent.');
    await publish(2, 'You answer as version two of this agent.');
    await saveBuilderCredential();
    final before = fundedHire(agentId: _studioAgent, version: 1);
    final after = fundedHire(agentId: _studioAgent, version: 2);

    await pass();

    expect((await runs.find(before))!.state, HireRunState.succeeded);
    expect((await runs.find(after))!.state, HireRunState.succeeded);
    expect(
      builderCalls.map((call) => call.$1.systemPrompt),
      [
        'You answer as version one of this agent.',
        'You answer as version two of this agent.',
      ],
    );
    expect(team.tasks, isEmpty);
  });

  /// Runs passes past every retry backoff until the run of [id] is no
  /// longer queued, and returns its final state.
  Future<HireRun> runUntilSettled(int id) async {
    for (var i = 0; i <= retryBackoff.length; i++) {
      await pass();
      final run = (await runs.find(id))!;
      if (run.state != HireRunState.queued) return run;
      clock = clock.add(const Duration(minutes: 10));
    }
    return (await runs.find(id))!;
  }

  test('without a builder credential the run is retried and then fails; the '
      'team token is never a fallback', () async {
    await publish(1, 'You rewrite one paragraph in a calmer voice.');
    final id = fundedHire(agentId: _studioAgent);

    final first = await pass();

    expect(first.retried, 1);
    expect((await runs.find(id))!.state, HireRunState.queued);
    expect(runs.lastErrors[id], 'unsupported_provider');

    final run = await runUntilSettled(id);

    expect(run.state, HireRunState.failed);
    expect(run.failureReason, 'unsupported_provider');
    expect(builderCalls, isEmpty);
    expect(team.tasks, isEmpty, reason: 'the team token was used');
    expect(seeded.lookups, isEmpty, reason: 'a seed manifest was looked up');
  });

  test(
    'a credential saved after the first attempt is used on the retry',
    () async {
      await publish(1, 'You rewrite one paragraph in a calmer voice.');
      final id = fundedHire(agentId: _studioAgent);
      await pass();
      expect((await runs.find(id))!.state, HireRunState.queued);

      await saveBuilderCredential();
      final run = await runUntilSettled(id);

      expect(run.state, HireRunState.succeeded);
      expect(run.result, 'answered on the builder account');
      expect(builderCalls.single.$2.secret, _builderToken);
      expect(team.tasks, isEmpty);
    },
  );

  test('a Workers AI credential without its account id is not used', () async {
    await publish(1, 'You rewrite one paragraph in a calmer voice.');
    await saveBuilderCredential(accountId: null);
    final id = fundedHire(agentId: _studioAgent);

    final run = await runUntilSettled(id);

    expect(run.failureReason, 'unsupported_provider');
    expect(builderCalls, isEmpty);
    expect(team.tasks, isEmpty);
  });

  test("another builder's credential is not used", () async {
    await publish(1, 'You rewrite one paragraph in a calmer voice.');
    await credentials.save(
      owner: _consumer,
      credential: const BuilderProviderCredential(
        provider: 'workers-ai',
        secret: 'someone-else-token',
        accountId: _builderAccount,
      ),
    );
    final id = fundedHire(agentId: _studioAgent);

    final run = await runUntilSettled(id);

    expect(run.failureReason, 'unsupported_provider');
    expect(builderCalls, isEmpty);
    expect(team.tasks, isEmpty);
  });

  test(
    'a seeded demo agent still runs its seed manifest on the team runner',
    () async {
      await saveBuilderCredential();
      final id = fundedHire(agentId: _seededAgent);

      await pass();

      expect((await runs.find(id))!.result, 'answered on the team token');
      expect(team.tasks.single.systemPrompt, _seedManifest.systemPrompt);
      expect(seeded.lookups, [_seededAgent]);
      expect(builderCalls, isEmpty);
    },
  );

  test(
    'the published model policy accepts the manifest these tests publish',
    () {
      // Guards the fixture: an invalid snapshot would fall back to the seed
      // manifest and hide the behaviour under test.
      expect(
        () => AgentManifestDraft.fromJson(
          jsonDecode(_published('You rewrite one paragraph calmly.')),
        ).validate(studioServerModelPolicy, ManifestVersion.first),
        returnsNormally,
      );
    },
  );
}
