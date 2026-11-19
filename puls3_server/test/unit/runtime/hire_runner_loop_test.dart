// Run phases (ADR-0011 D8, T5.3): a hire whose manifest opted in to
// subcontract runs the tool loop, pauses as `awaitingChild` with its loop
// state persisted, and resumes on a later pass once the child finished.
import 'dart:convert';

import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/runtime/agent_runner.dart';
import 'package:puls3_server/src/runtime/conversation.dart';
import 'package:puls3_server/src/runtime/hire_run_store.dart';
import 'package:puls3_server/src/runtime/hire_runner.dart';
import 'package:puls3_server/src/runtime/run_execution.dart';
import 'package:puls3_server/src/runtime/run_manifest.dart';
import 'package:puls3_server/src/runtime/subcontract_port.dart';
import 'package:puls3_server/src/runtime/subcontract_setup.dart';
import 'package:puls3_server/src/runtime/subcontract_tools.dart';
import 'package:puls3_server/src/runtime/tool_loop.dart';
import 'package:puls3_server/src/runtime/tool_loop_codec.dart';
import 'package:puls3_server/src/studio/builder_credential.dart';
import 'package:test/test.dart';

import '../../support/in_memory_hire_run_store.dart';
import '../hire/hire_test_fakes.dart';

const _consumer = 'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H';
const _agentWallet = 'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY';
const _builder = 'GBRPYHIL2CI3FNQ4BXLFMNDLFJUNPU2HY3ZMFSHONUCEOASW7QC7OX2H';
const _childHireId = 77;
const _timeout = Duration(seconds: 120);
final _t0 = DateTime.utc(2026, 11, 18, 12);

final _optIn = SubcontractOptIn(maxChildren: 2, suggestedReserve: 1000);

RunManifest _manifest({SubcontractOptIn? subcontract}) => RunManifest(
  provider: 'anthropic',
  modelId: 'claude-opus-5-5',
  systemPrompt: 'You write reports.',
  inputMaxChars: 200,
  outputMaxChars: 500,
  subcontract: subcontract,
);

final class _Manifests implements RunManifestSource {
  _Manifests(this.manifest);

  RunManifest manifest;

  @override
  Future<RunManifest?> find(int agentId, int manifestVersion) async => manifest;
}

/// A [ConversationRuntime] that plays [turns] in order. A [RuntimeFailure]
/// in [turns] is thrown instead.
final class _Scripted implements ConversationRuntime {
  _Scripted(this.turns);

  static const plain = 'plain answer';

  final List<Object> turns;
  final tasks = <ConversationTask>[];
  final completes = <RuntimeTask>[];

  @override
  Future<ModelTurn> converse(
    ConversationTask task, {
    Future<void>? abortTrigger,
  }) async {
    tasks.add(task);
    final next = turns[tasks.length - 1];
    if (next is RuntimeFailure) throw next;
    return next as ModelTurn;
  }

  @override
  Future<String> complete(
    RuntimeTask task, {
    Future<void>? abortTrigger,
  }) async {
    completes.add(task);
    return plain;
  }
}

final class _Port implements SubcontractPort {
  final requests = <ChildRequest>[];

  @override
  Future<int> requestChild(ChildRequest request) async {
    requests.add(request);
    return _childHireId;
  }
}

final class _Children implements ChildResultSource {
  ChildToolResult? result;
  final asked = <int>[];

  @override
  Future<ChildToolResult?> resultOf(int childHireId) async {
    asked.add(childHireId);
    return result;
  }
}

AgentCandidate _candidate() => const AgentCandidate(
  id: 'agt-7',
  registryId: 7,
  name: 'Researcher',
  skills: ['research'],
  priceStroops: 400,
  rating: 4.5,
  paidHireCount: 3,
  skillMatch: 1,
  score: 0.9,
  rank: 1,
  isRelatedParty: false,
  ownershipKnown: true,
);

Future<List<AgentCandidate>> _search({
  required int hireId,
  required int remainingReserveStroops,
  required String query,
  List<String> skills = const [],
}) async => [_candidate()];

final _searchTurn = ToolCallsTurn(
  calls: [
    ToolCall(
      id: 'call_s',
      name: searchAgentsToolName,
      arguments: {'query': 'r'},
    ),
  ],
  providerContent: [
    {'type': 'tool_use', 'id': 'call_s'},
  ],
);

final _subcontractTurn = ToolCallsTurn(
  calls: [
    ToolCall(
      id: 'call_c',
      name: subcontractToolName,
      arguments: {
        'agent_id': 7,
        'task': 'Find sources.',
        'justification': 'Top ranked.',
      },
    ),
  ],
  providerContent: [
    {'type': 'thinking', 'signature': 'keep-me'},
    {'type': 'tool_use', 'id': 'call_c'},
  ],
);

const _overloaded = RuntimeProviderFailed(
  status: 529,
  errorType: 'overloaded_error',
);

void main() {
  late FakeHireRepository hires;
  late InMemoryHireRunStore runs;
  late _Manifests manifests;
  late _Scripted model;
  late _Port port;
  late _Children children;
  late DateTime clock;

  HireRunner runner({bool subcontracting = true, RunnerLease? lease}) =>
      HireRunner(
        manifests: manifests,
        runner: AgentRunner(runtime: model, timeout: _timeout),
        staleAfter: _timeout + const Duration(minutes: 1),
        now: () => clock,
        subcontracting: subcontracting
            ? SubcontractSetup(
                search: _search,
                port: port,
                children: children,
                lease: lease,
              )
            : null,
      );

  int fundedHire({int expiredAt = 1800000000}) {
    final id = hires.hires.length + 1;
    final open = Hire(
      id: HireId(id),
      agentId: AgentId(13),
      consumer: StellarAddress.parse(_consumer),
      price: UsdcAmount.stroops(1000000),
      manifestVersion: 1,
    );
    final payment = Payment(
      transaction: TransactionHash.parse(
        '${'ef' * 31}${id.toString().padLeft(2, '0')}',
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
        agentId: 13,
        manifestVersion: 1,
        input: 'Write the report.',
        expiredAt: expiredAt,
        reserveStroops: 1000,
      ),
      clock,
    );
    return id;
  }

  Future<RunPassSummary> pass({bool subcontracting = true}) =>
      runner(subcontracting: subcontracting).pass(runs: runs, hires: hires);

  /// Runs a fresh opted-in hire up to its pause on the child.
  Future<int> pausedHire(List<Object> laterTurns) async {
    model = _Scripted([_searchTurn, _subcontractTurn, ...laterTurns]);
    final id = fundedHire();
    final summary = await pass();
    expect(summary.awaiting, 1);
    expect((await runs.find(id))!.state, HireRunState.awaitingChild);
    return id;
  }

  setUp(() {
    hires = FakeHireRepository();
    runs = InMemoryHireRunStore();
    manifests = _Manifests(_manifest(subcontract: _optIn));
    model = _Scripted(const []);
    port = _Port();
    children = _Children();
    clock = _t0;
  });

  group('without the opt-in, the run is one plain segment', () {
    test('a manifest without subcontract never sees tools', () async {
      manifests.manifest = _manifest();
      final id = fundedHire();

      final summary = await pass();

      expect(summary.succeeded, 1);
      expect(model.completes, hasLength(1));
      expect(model.tasks, isEmpty);
      final run = (await runs.find(id))!;
      expect(run.result, _Scripted.plain);
      expect(run.loopState, isNull);
    });

    test('an opted-in manifest runs plain while subcontracting is not wired '
        '(production until T6)', () async {
      final id = fundedHire();

      final summary = await pass(subcontracting: false);

      expect(summary.succeeded, 1);
      expect(model.completes, hasLength(1));
      expect(model.tasks, isEmpty);
      expect((await runs.find(id))!.result, _Scripted.plain);
    });
  });

  test('an opted-in run that subcontracts persists awaitingChild with its '
      'loop state, pending call, child hire and request', () async {
    final id = await pausedHire(const []);

    final run = (await runs.find(id))!;
    expect(run.pendingToolCallId, 'call_c');
    expect(run.childHireId, _childHireId);
    expect(run.finishedAt, isNull);
    final state = decodeToolLoopState(run.loopState!);
    expect(state.turnsUsed, 2);
    expect(state.childrenUsed, 1);
    expect(state.remainingReserveStroops, 600);
    expect(state.searches.single.single.registryId, 7);
    final paused = state.transcript.last as AssistantMessage;
    expect(jsonEncode(paused.providerContent), contains('keep-me'));
    final request = decodeChildRequest(run.childRequest!);
    expect(request.agentRegistryId, 7);
    expect(request.priceStroops, 400);
    expect(request.justification, 'Top ranked.');
    expect(
      request.relatedPartyJustification,
      RelatedPartyJustification.independent,
    );
    expect(port.requests, hasLength(1));
    expect(hires.hires[id]!.status, HireStatus.funded, reason: 'D7');
  });

  test('a delivered child resumes the run, which then succeeds', () async {
    final id = await pausedHire([const FinalText('Report with B.')]);
    children.result = const ChildDelivered('B found three sources.');
    clock = _t0.add(const Duration(minutes: 30));

    final summary = await pass();

    expect(summary.succeeded, 1);
    expect(children.asked, [_childHireId]);
    final run = (await runs.find(id))!;
    expect(run.state, HireRunState.succeeded);
    expect(run.result, 'Report with B.');
    final resumed = model.tasks.last;
    final result = resumed.messages.last as ToolResultMessage;
    expect(result.callId, 'call_c');
    expect(result.isError, isFalse);
    expect(result.content, contains('B found three sources.'));
    final replayed = resumed.messages[resumed.messages.length - 2];
    expect(
      jsonEncode((replayed as AssistantMessage).providerContent),
      contains('keep-me'),
      reason: 'the stored provider content is replayed verbatim',
    );
    expect(port.requests, hasLength(1));
  });

  test('a failed child is a tool error and the loop carries on', () async {
    final id = await pausedHire([const FinalText('Report without B.')]);
    children.result = const ChildFailed('expired');

    final summary = await pass();

    expect(summary.succeeded, 1);
    final result = model.tasks.last.messages.last as ToolResultMessage;
    expect(result.isError, isTrue);
    expect(result.content, contains('child_failed'));
    expect((await runs.find(id))!.result, 'Report without B.');
  });

  test('a child still working leaves the run awaiting, with no model call '
      'and nothing logged as work', () async {
    final id = await pausedHire(const []);
    final calls = model.tasks.length;

    final summary = await pass();

    expect(summary.total, 0);
    expect(model.tasks, hasLength(calls));
    expect((await runs.find(id))!.state, HireRunState.awaitingChild);
  });

  test('the stale sweep never fails an awaiting run as interrupted', () async {
    final id = await pausedHire(const []);
    clock = _t0.add(const Duration(hours: 6));

    final summary = await pass();

    expect(summary.interrupted, 0);
    expect((await runs.find(id))!.state, HireRunState.awaitingChild);
  });

  test('an awaiting run whose job can no longer be submitted fails as '
      'job_expired without asking for the child', () async {
    model = _Scripted([_searchTurn, _subcontractTurn]);
    final expiredAt = _t0.add(const Duration(hours: 1));
    final id = fundedHire(expiredAt: expiredAt.millisecondsSinceEpoch ~/ 1000);
    await pass();
    clock = expiredAt;

    final summary = await pass();

    expect(summary.failed, 1);
    expect(children.asked, isEmpty);
    final run = (await runs.find(id))!;
    expect(run.state, HireRunState.failed);
    expect(run.failureReason, runJobExpired);
  });

  test('a retryable failure after the resume continues from the stored '
      'transcript on the next attempt, not from the start', () async {
    final id = await pausedHire([_overloaded, const FinalText('Recovered.')]);
    children.result = const ChildDelivered('B output.');

    final first = await pass();

    expect(first.retried, 1);
    var run = (await runs.find(id))!;
    expect(run.state, HireRunState.queued);
    expect(runs.attemptsOf(id), 1);
    final stored = decodeToolLoopState(run.loopState!);
    expect(stored.turnsUsed, 2, reason: 'the failed segment is not counted');
    expect(
      (stored.transcript.last as ToolResultMessage).content,
      contains('B output.'),
    );

    clock = clock.add(retryBackoff[0]);
    final second = await pass();

    expect(second.succeeded, 1);
    run = (await runs.find(id))!;
    expect(run.result, 'Recovered.');
    final failedTry = model.tasks[2];
    final retry = model.tasks[3];
    expect(
      retry.messages.length,
      failedTry.messages.length,
      reason: 'the same conversation is sent again',
    );
    expect(retry.messages.whereType<UserMessage>(), hasLength(1));
    expect(port.requests, hasLength(1), reason: 'no child is paid twice');
    expect(children.asked, hasLength(1));
  });

  test(
    'a retryable failure before any pause also keeps the transcript',
    () async {
      model = _Scripted([_searchTurn, _overloaded, const FinalText('Done.')]);
      final id = fundedHire();

      expect((await pass()).retried, 1);
      final stored = decodeToolLoopState((await runs.find(id))!.loopState!);
      expect(stored.turnsUsed, 1);
      expect(stored.searches, hasLength(1));

      clock = clock.add(retryBackoff[0]);
      expect((await pass()).succeeded, 1);
      expect(model.tasks[2].messages.length, model.tasks[1].messages.length);
      expect((await runs.find(id))!.result, 'Done.');
    },
  );

  test('a Studio (owned) manifest runs the loop on the builder credential, '
      'never on the team runner', () async {
    manifests.manifest = OwnedRunManifest(
      owner: _builder,
      provider: 'anthropic',
      modelId: 'claude-haiku-5-5',
      systemPrompt: 'You write reports.',
      inputMaxChars: 200,
      outputMaxChars: 500,
      subcontract: _optIn,
    );
    final builderModel = _Scripted([_searchTurn, _subcontractTurn]);
    final credentials = <(String, String)>[];
    final used = <BuilderProviderCredential>[];
    final lease = runnerLease(
      team: AgentRunner(runtime: model, timeout: _timeout),
      credentials: ({required owner, required provider}) async {
        credentials.add((owner, provider));
        return const BuilderProviderCredential(
          provider: 'anthropic',
          secret: 'builder-key',
        );
      },
      builder: (credential, body) {
        used.add(credential);
        return body(AgentRunner(runtime: builderModel, timeout: _timeout));
      },
    );
    final id = fundedHire();

    final summary = await runner(lease: lease).pass(runs: runs, hires: hires);

    expect(summary.awaiting, 1);
    expect(credentials, [(_builder, 'anthropic')]);
    expect(used.single.secret, 'builder-key');
    expect(builderModel.tasks, hasLength(2));
    expect(builderModel.tasks.first.tools, isNotEmpty);
    expect(model.tasks, isEmpty);
    expect(model.completes, isEmpty);
    expect((await runs.find(id))!.state, HireRunState.awaitingChild);
  });

  test('an owned manifest without a builder credential fails its loop run '
      'as unsupported_provider', () async {
    manifests.manifest = OwnedRunManifest(
      owner: _builder,
      provider: 'anthropic',
      modelId: 'claude-haiku-5-5',
      systemPrompt: 'You write reports.',
      inputMaxChars: 200,
      outputMaxChars: 500,
      subcontract: _optIn,
    );
    final lease = runnerLease(
      team: AgentRunner(runtime: model, timeout: _timeout),
      credentials: ({required owner, required provider}) async => null,
    );
    final id = fundedHire();

    final summary = await runner(lease: lease).pass(runs: runs, hires: hires);

    expect(summary.retried, 1, reason: 'a missing credential is retryable');
    expect(runs.lastErrors[id], 'unsupported_provider');
    expect(model.tasks, isEmpty);
  });
}
