import 'package:puls3_server/src/runtime/hire_run_store.dart';
import 'package:test/test.dart';

/// A store under test plus a way to queue runs in it.
final class HireRunStoreFixture {
  HireRunStoreFixture({required this.store, required this.queue});

  final HireRunStore store;

  /// Queues a run for a new funded hire and returns its hire id.
  final Future<int> Function({
    required int agentId,
    required int manifestVersion,
    required String input,
  })
  queue;
}

final _t0 = DateTime.utc(2026, 10, 8, 12);

/// The behavior every [HireRunStore] shares: conditional transitions, so a
/// run moves once even when two runners race.
void hireRunStoreContract(Future<HireRunStoreFixture> Function() create) {
  late HireRunStoreFixture fixture;
  HireRunStore store() => fixture.store;

  Future<int> queueOne({String input = 'Summarize this'}) =>
      fixture.queue(agentId: 13, manifestVersion: 1, input: input);

  setUp(() async => fixture = await create());

  test('a queued run lists with the hire data the runner needs', () async {
    final hireId = await queueOne(input: 'Draft the release notes');

    final queued = await store().listQueued();
    expect(queued, hasLength(1));
    expect(queued.single.hireId, hireId);
    expect(queued.single.agentId, 13);
    expect(queued.single.manifestVersion, 1);
    expect(queued.single.input, 'Draft the release notes');
    expect((await store().find(hireId))!.state, HireRunState.queued);
  });

  test('listQueued is oldest first and honors the limit', () async {
    final first = await queueOne();
    final second = await queueOne();
    await queueOne();

    final queued = await store().listQueued(limit: 2);
    expect([for (final q in queued) q.hireId], [first, second]);
  });

  test('a run is taken once: the second markRunning loses', () async {
    final hireId = await queueOne();

    expect(await store().markRunning(hireId, _t0), isTrue);
    expect(await store().markRunning(hireId, _t0), isFalse);
    final run = await store().find(hireId);
    expect(run!.state, HireRunState.running);
    expect(run.startedAt!.isAtSameMomentAs(_t0), isTrue);
    expect(await store().listQueued(), isEmpty);
  });

  test('succeeded stores the result once, only from running', () async {
    final hireId = await queueOne();
    expect(
      await store().markSucceeded(hireId, 'out', _t0),
      isFalse,
      reason: 'a queued run cannot succeed',
    );
    await store().markRunning(hireId, _t0);

    expect(await store().markSucceeded(hireId, 'the result', _t0), isTrue);
    expect(await store().markSucceeded(hireId, 'again', _t0), isFalse);
    final run = await store().find(hireId);
    expect(run!.state, HireRunState.succeeded);
    expect(run.result, 'the result');
    expect(run.finishedAt, isNotNull);
  });

  test('failed stores the reason, from queued or running only', () async {
    final queued = await queueOne();
    final running = await queueOne();
    final done = await queueOne();
    await store().markRunning(running, _t0);
    await store().markRunning(done, _t0);
    await store().markSucceeded(done, 'ok', _t0);

    expect(
      await store().markFailed(queued, 'manifest_unavailable', _t0),
      isTrue,
    );
    expect(await store().markFailed(running, 'timeout', _t0), isTrue);
    expect(await store().markFailed(done, 'timeout', _t0), isFalse);
    expect(await store().markFailed(running, 'again', _t0), isFalse);

    expect((await store().find(queued))!.failureReason, 'manifest_unavailable');
    expect((await store().find(running))!.failureReason, 'timeout');
    expect((await store().find(done))!.state, HireRunState.succeeded);
  });

  test('listRunningStartedBefore finds only old running runs', () async {
    final old = await queueOne();
    final recent = await queueOne();
    await queueOne();
    await store().markRunning(old, _t0);
    await store().markRunning(recent, _t0.add(const Duration(minutes: 10)));

    final stale = await store().listRunningStartedBefore(
      _t0.add(const Duration(minutes: 5)),
    );
    expect(stale, [old]);
  });

  test('markRetry puts a running run back in the queue, once', () async {
    final hireId = await queueOne();
    expect(
      await store().markRetry(
        hireId,
        'provider_error:http_503',
        notBefore: _t0,
        at: _t0,
      ),
      isFalse,
      reason: 'a queued run cannot be retried',
    );
    await store().markRunning(hireId, _t0);
    final later = _t0.add(const Duration(seconds: 30));

    expect(
      await store().markRetry(
        hireId,
        'provider_error:http_503',
        notBefore: later,
        at: _t0,
      ),
      isTrue,
    );
    expect(
      await store().markRetry(hireId, 'again', notBefore: later, at: _t0),
      isFalse,
    );
    final run = await store().find(hireId);
    expect(run!.state, HireRunState.queued);
    expect(run.failureReason, isNull);
  });

  test(
    'a retried run is listed with its attempts after its backoff only',
    () async {
      final hireId = await queueOne();
      await store().markRunning(hireId, _t0);
      final later = _t0.add(const Duration(seconds: 30));
      await store().markRetry(hireId, 'x', notBefore: later, at: _t0);

      expect(await store().listQueued(now: _t0), isEmpty);
      final due = await store().listQueued(now: later);
      expect(due.single.hireId, hireId);
      expect(due.single.attempts, 1);
      expect(
        (await store().listQueued()).single.hireId,
        hireId,
        reason: 'without now, every queued run is listed',
      );
    },
  );

  test('an unknown hire has no run and no transition', () async {
    expect(await store().find(999999), isNull);
    expect(await store().markRunning(999999, _t0), isFalse);
    expect(await store().markFailed(999999, 'timeout', _t0), isFalse);
  });
}
