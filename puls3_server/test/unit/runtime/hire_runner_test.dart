import 'dart:async';

import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/ledger/ledger_errors.dart';
import 'package:puls3_server/src/runtime/agent_runner.dart';
import 'package:puls3_server/src/runtime/hire_run_store.dart';
import 'package:puls3_server/src/runtime/hire_runner.dart';
import 'package:puls3_server/src/runtime/run_manifest.dart';
import 'package:puls3_server/src/runtime/runtime_task.dart';
import 'package:test/test.dart';

import '../../support/in_memory_hire_run_store.dart';
import '../hire/hire_test_fakes.dart';

const _consumer = 'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H';
const _agentWallet = 'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY';
const _timeout = Duration(milliseconds: 50);
final _t0 = DateTime.utc(2026, 10, 8, 12);

const _manifest = RunManifest(
  provider: 'anthropic',
  modelId: 'claude-opus-5-5',
  systemPrompt: 'You triage one customer message.',
  inputMaxChars: 100,
  outputMaxChars: 100,
);

final class _Manifests implements RunManifestSource {
  _Manifests(this.byAgent);

  final Map<int, RunManifest> byAgent;
  Exception? failure;

  @override
  Future<RunManifest?> find(int agentId, int manifestVersion) async {
    if (failure != null) throw failure!;
    return manifestVersion == 1 ? byAgent[agentId] : null;
  }
}

final class _Model implements ModelRuntime {
  _Model(this.answer);

  Future<String> Function(RuntimeTask task) answer;
  final tasks = <RuntimeTask>[];

  @override
  Future<String> complete(RuntimeTask task, {Future<void>? abortTrigger}) {
    tasks.add(task);
    return answer(task);
  }
}

void main() {
  late FakeHireRepository hires;
  late InMemoryHireRunStore runs;
  late _Manifests manifests;
  late _Model model;
  late List<String> logs;
  late DateTime clock;

  HireRunner runner({Duration staleAfter = const Duration(minutes: 3)}) =>
      HireRunner(
        manifests: manifests,
        runner: AgentRunner(runtime: model, timeout: _timeout),
        staleAfter: staleAfter,
        now: () => clock,
        log: (level, message) => logs.add('${level.name}: $message'),
      );

  /// A funded hire for agent 13 with [input], queued like the repository
  /// queues it when the payment is recorded.
  int fundedHire({
    String input = 'My invoice is wrong',
    int version = 1,
    int expiredAt = 1800000000,
  }) {
    final id = hires.hires.length + 1;
    final open = Hire(
      id: HireId(id),
      agentId: AgentId(13),
      consumer: StellarAddress.parse(_consumer),
      price: UsdcAmount.stroops(1000000),
      manifestVersion: version,
    );
    final payment = Payment(
      transaction: TransactionHash.parse(
        '${'ab' * 31}${id.toString().padLeft(2, '0')}',
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
        manifestVersion: version,
        input: input,
        expiredAt: expiredAt,
      ),
      clock,
    );
    return id;
  }

  Future<RunPassSummary> pass() => runner().pass(runs: runs, hires: hires);

  setUp(() {
    hires = FakeHireRepository();
    runs = InMemoryHireRunStore();
    manifests = _Manifests({13: _manifest});
    model = _Model((_) async => 'Category: billing. Urgency: high.');
    logs = [];
    clock = _t0;
  });

  test('a funded hire runs its manifest and stores the result', () async {
    final id = fundedHire(input: 'My invoice is wrong');

    final summary = await pass();

    expect(summary.succeeded, 1);
    final run = await runs.find(id);
    expect(run!.state, HireRunState.succeeded);
    expect(run.result, 'Category: billing. Urgency: high.');
    final task = model.tasks.single;
    expect(task.modelId, 'claude-opus-5-5');
    expect(task.systemPrompt, 'You triage one customer message.');
    expect(task.input, 'My invoice is wrong');
    expect(task.maxOutputChars, 100);
  });

  test('changing the manifest changes the run, with no code change', () async {
    manifests.byAgent[13] = const RunManifest(
      provider: 'anthropic',
      modelId: 'claude-sonnet-5-5',
      systemPrompt: 'You translate the message into Spanish.',
      inputMaxChars: 100,
      outputMaxChars: 100,
    );
    fundedHire();

    await pass();

    expect(
      model.tasks.single.systemPrompt,
      'You translate the message into Spanish.',
    );
    expect(model.tasks.single.modelId, 'claude-sonnet-5-5');
  });

  test('a provider error fails the run with its safe code', () async {
    model.answer = (_) async => throw const RuntimeProviderFailed(
      status: 529,
      errorType: 'overloaded_error',
    );
    final id = fundedHire();

    final summary = await pass();

    expect(summary.failed, 1);
    final run = await runs.find(id);
    expect(run!.state, HireRunState.failed);
    expect(run.failureReason, 'provider_error:overloaded_error');
    expect(run.result, isNull);
  });

  test('a run past the timeout fails as timeout', () async {
    model.answer = (_) => Completer<String>().future;
    final id = fundedHire();

    await pass();

    final run = await runs.find(id);
    expect(run!.state, HireRunState.failed);
    expect(run.failureReason, 'timeout');
  });

  test(
    'input over the manifest limit fails without calling the model',
    () async {
      final id = fundedHire(input: 'x' * 101);

      await pass();

      expect(model.tasks, isEmpty);
      expect((await runs.find(id))!.failureReason, 'input_too_long');
    },
  );

  test(
    'an unknown manifest version fails the run, the model is not called',
    () async {
      final id = fundedHire(version: 2);

      await pass();

      expect(model.tasks, isEmpty);
      final run = await runs.find(id);
      expect(run!.state, HireRunState.failed);
      expect(run.failureReason, manifestUnavailable);
    },
  );

  test('an unreadable registry defers the run to a later pass', () async {
    manifests.failure = const LedgerUnavailable('rpc down');
    final id = fundedHire();

    final summary = await pass();

    expect(summary.deferred, 1);
    expect((await runs.find(id))!.state, HireRunState.queued);
    expect(model.tasks, isEmpty);

    manifests.failure = null;
    await pass();
    expect((await runs.find(id))!.state, HireRunState.succeeded);
  });

  test('a run already taken by another runner is not run again', () async {
    final id = fundedHire();
    await runs.markRunning(id, clock);

    final summary = await pass();

    expect(summary.total, 0);
    expect(model.tasks, isEmpty);
  });

  test(
    'a run another runner takes between list and claim is skipped',
    () async {
      final id = fundedHire();
      final racing = _RacingStore(runs, claimFirst: id, at: clock);

      final summary = await runner().pass(runs: racing, hires: hires);

      expect(summary.total, 0);
      expect(model.tasks, isEmpty);
      expect((await runs.find(id))!.state, HireRunState.running);
    },
  );

  test('a hire that is not funded is never run and leaves the queue', () async {
    final id = fundedHire();
    final next = fundedHire();
    final funded = hires.hires[id]!;
    hires.hires[id] = funded.reject();

    final summary = await pass();

    expect(model.tasks.single.input, 'My invoice is wrong');
    final run = await runs.find(id);
    expect(run!.state, HireRunState.failed);
    expect(run.failureReason, runNotRunnable);
    expect((await runs.find(next))!.state, HireRunState.succeeded);
    expect(summary.failed, 1);
    expect(logs.first, startsWith('error: Hire $id cannot run'));
  });

  test('a missing hire leaves the queue too', () async {
    final id = fundedHire();
    hires.hires.remove(id);

    await pass();

    expect(model.tasks, isEmpty);
    expect((await runs.find(id))!.failureReason, runNotRunnable);
  });

  test(
    'a run that cannot end before the job expires never calls the model',
    () async {
      final expiresSoon =
          clock.add(const Duration(milliseconds: 30)).millisecondsSinceEpoch ~/
          1000;
      final id = fundedHire(expiredAt: expiresSoon);

      await pass();

      expect(model.tasks, isEmpty);
      final run = await runs.find(id);
      expect(run!.state, HireRunState.failed);
      expect(run.failureReason, runJobExpired);
    },
  );

  test('an unexpected error fails the run and the batch goes on', () async {
    var calls = 0;
    model.answer = (task) async {
      if (calls++ == 0) throw StateError('TLS handshake failed');
      return 'ok: ${task.input}';
    };
    final first = fundedHire(input: 'a');
    final second = fundedHire(input: 'b');

    final summary = await pass();

    expect(summary.failed, 1);
    expect(summary.succeeded, 1);
    final failed = await runs.find(first);
    expect(failed!.state, HireRunState.failed);
    expect(failed.failureReason, runInternalError);
    expect((await runs.find(second))!.result, 'ok: b');
    expect(logs.join(' '), isNot(contains('TLS handshake failed')));
  });

  test(
    'an output for a run that already ended is not stored or counted',
    () async {
      late int id;
      model.answer = (_) async {
        // Another pass ends the run while the model is still answering.
        await runs.markFailed(id, runInterrupted, clock);
        return 'late output';
      };
      id = fundedHire();

      final summary = await pass();

      expect(summary.succeeded, 0);
      final run = await runs.find(id);
      expect(run!.state, HireRunState.failed);
      expect(run.failureReason, runInterrupted);
      expect(run.result, isNull);
    },
  );

  test('a run left running past staleAfter fails as interrupted', () async {
    final id = fundedHire();
    await runs.markRunning(id, _t0);
    clock = _t0.add(const Duration(minutes: 4));

    final summary = await pass();

    expect(summary.interrupted, 1);
    final run = await runs.find(id);
    expect(run!.state, HireRunState.failed);
    expect(run.failureReason, runInterrupted);
  });

  test('a recent running run is left alone', () async {
    final id = fundedHire();
    await runs.markRunning(id, _t0);
    clock = _t0.add(const Duration(minutes: 1));

    await pass();

    expect((await runs.find(id))!.state, HireRunState.running);
  });

  test('a batch runs every queued hire, one at a time', () async {
    var inFlight = 0;
    var maxInFlight = 0;
    model.answer = (task) async {
      inFlight++;
      maxInFlight = inFlight > maxInFlight ? inFlight : maxInFlight;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      inFlight--;
      return 'done: ${task.input}';
    };
    final ids = [fundedHire(input: 'a'), fundedHire(input: 'b')];

    final summary = await pass();

    expect(summary.succeeded, 2);
    expect(maxInFlight, 1);
    expect((await runs.find(ids[1]))!.result, 'done: b');
  });

  test('a pass with nothing queued does nothing and logs nothing', () async {
    final summary = await pass();
    expect(summary.total, 0);
    expect(logs, isEmpty);
  });
}

/// Lists like [inner], but another runner claims [claimFirst] right after
/// the list, so this runner's claim loses the race.
final class _RacingStore implements HireRunStore {
  _RacingStore(this.inner, {required this.claimFirst, required this.at});

  final InMemoryHireRunStore inner;
  final int claimFirst;
  final DateTime at;

  @override
  Future<List<QueuedRun>> listQueued({int limit = 10}) async {
    final queued = await inner.listQueued(limit: limit);
    await inner.markRunning(claimFirst, at);
    return queued;
  }

  @override
  Future<HireRun?> find(int hireId) => inner.find(hireId);

  @override
  Future<List<int>> listRunningStartedBefore(DateTime before) =>
      inner.listRunningStartedBefore(before);

  @override
  Future<bool> markRunning(int hireId, DateTime at) =>
      inner.markRunning(hireId, at);

  @override
  Future<bool> markSucceeded(int hireId, String result, DateTime at) =>
      inner.markSucceeded(hireId, result, at);

  @override
  Future<bool> markFailed(int hireId, String reason, DateTime at) =>
      inner.markFailed(hireId, reason, at);
}
