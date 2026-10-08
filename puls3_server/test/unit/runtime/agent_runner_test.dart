import 'dart:async';

import 'package:puls3_server/src/runtime/agent_runner.dart';
import 'package:puls3_server/src/runtime/runtime_task.dart';
import 'package:test/test.dart';

const _timeout = Duration(milliseconds: 50);

RuntimeTask _task({
  String input = 'Summarize: the release adds escrow payments.',
  int maxInputChars = 100,
  int maxOutputChars = 50,
}) => RuntimeTask(
  provider: 'anthropic',
  modelId: 'claude-opus-5-5',
  systemPrompt: 'You summarize release notes in one sentence.',
  input: input,
  maxInputChars: maxInputChars,
  maxOutputChars: maxOutputChars,
);

/// A [ModelRuntime] that answers with [answer] and records each task.
final class _FakeRuntime implements ModelRuntime {
  _FakeRuntime(this.answer);

  final Future<String> Function(RuntimeTask task) answer;
  final calls = <RuntimeTask>[];
  final abortTriggers = <Future<void>?>[];

  @override
  Future<String> complete(RuntimeTask task, {Future<void>? abortTrigger}) {
    calls.add(task);
    abortTriggers.add(abortTrigger);
    return answer(task);
  }
}

Matcher _failsWith(String code) =>
    throwsA(isA<RuntimeFailure>().having((e) => e.code, 'code', code));

void main() {
  test('returns the model output for a task within its limits', () async {
    final runtime = _FakeRuntime((_) async => 'Escrow payments are here.');
    final runner = AgentRunner(runtime: runtime, timeout: _timeout);

    expect(await runner.run(_task()), 'Escrow payments are here.');
    expect(runtime.calls, hasLength(1));
  });

  test('a provider failure reaches the caller unchanged', () async {
    const failure = RuntimeProviderFailed(
      status: 429,
      errorType: 'rate_limit_error',
    );
    final runner = AgentRunner(
      runtime: _FakeRuntime((_) async => throw failure),
      timeout: _timeout,
    );

    expect(() => runner.run(_task()), throwsA(same(failure)));
  });

  test('a model that does not answer in time is a timeout', () async {
    final never = Completer<String>();
    final runner = AgentRunner(
      runtime: _FakeRuntime((_) => never.future),
      timeout: _timeout,
    );

    await expectLater(runner.run(_task()), _failsWith('timeout'));
  });

  test('a timeout aborts the provider call instead of abandoning it', () async {
    final never = Completer<String>();
    final runtime = _FakeRuntime((_) => never.future);
    final runner = AgentRunner(runtime: runtime, timeout: _timeout);

    await expectLater(runner.run(_task()), _failsWith('timeout'));

    final trigger = runtime.abortTriggers.single;
    expect(trigger, isNotNull);
    var aborted = false;
    await trigger!.then((_) => aborted = true);
    expect(aborted, isTrue);
  });

  test(
    'an aborted call that fails afterwards is not an unhandled error',
    () async {
      late final _FakeRuntime failing;
      failing = _FakeRuntime((_) async {
        // Fails only once the runner has aborted it, like a real HTTP client.
        await failing.abortTriggers.single;
        throw const RuntimeProviderFailed(status: null, errorType: 'aborted');
      });
      final runner = AgentRunner(runtime: failing, timeout: _timeout);

      await expectLater(runner.run(_task()), _failsWith('timeout'));
      // Let the aborted call settle; an unhandled error would fail this test.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(failing.calls, hasLength(1));
    },
  );

  test('a call that finishes in time is never aborted', () async {
    final runtime = _FakeRuntime((_) async => 'ok');
    final runner = AgentRunner(runtime: runtime, timeout: _timeout);

    expect(await runner.run(_task()), 'ok');
    var aborted = false;
    unawaited(runtime.abortTriggers.single!.then((_) => aborted = true));
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(aborted, isFalse);
  });

  test('the timeout comes from the runner, so it is configurable', () async {
    final runner = AgentRunner(
      runtime: _FakeRuntime(
        (_) => Future.delayed(
          const Duration(milliseconds: 30),
          () => 'late but fine',
        ),
      ),
      timeout: const Duration(seconds: 1),
    );

    expect(await runner.run(_task()), 'late but fine');
  });

  test('input over the manifest limit fails without calling the model', () {
    final runtime = _FakeRuntime((_) async => 'unused');
    final runner = AgentRunner(runtime: runtime, timeout: _timeout);

    expect(
      () => runner.run(_task(input: 'x' * 101)),
      _failsWith('input_too_long'),
    );
    expect(runtime.calls, isEmpty);
  });

  test('input exactly at the limit is accepted', () async {
    final runner = AgentRunner(
      runtime: _FakeRuntime((_) async => 'ok'),
      timeout: _timeout,
    );

    expect(await runner.run(_task(input: 'x' * 100)), 'ok');
  });

  test('output over the manifest limit fails', () async {
    final runner = AgentRunner(
      runtime: _FakeRuntime((_) async => 'y' * 51),
      timeout: _timeout,
    );

    await expectLater(runner.run(_task()), _failsWith('output_too_long'));
  });

  test('blank output fails', () async {
    final runner = AgentRunner(
      runtime: _FakeRuntime((_) async => '  \n '),
      timeout: _timeout,
    );

    await expectLater(runner.run(_task()), _failsWith('empty_output'));
  });

  group('RuntimeTask', () {
    test('rejects limits below one', () {
      expect(() => _task(maxInputChars: 0), throwsArgumentError);
      expect(() => _task(maxOutputChars: 0), throwsArgumentError);
    });
  });

  group('failure codes are safe to show and store', () {
    test('each failure has a stable code', () {
      expect(const RuntimeTimedOut(_timeout).code, 'timeout');
      expect(
        const RuntimeProviderFailed(
          status: 529,
          errorType: 'overloaded_error',
        ).code,
        'provider_error:overloaded_error',
      );
      expect(
        const RuntimeProviderFailed(status: null, errorType: null).code,
        'provider_error:unavailable',
      );
      expect(const RuntimeRefused('cyber').code, 'refused');
      expect(const RuntimeOutputTruncated().code, 'output_truncated');
      expect(const RuntimeInputTooLong(5, 4).code, 'input_too_long');
      expect(const RuntimeOutputTooLong(5, 4).code, 'output_too_long');
      expect(const RuntimeEmptyOutput().code, 'empty_output');
      expect(
        const RuntimeUnsupportedProvider('x').code,
        'unsupported_provider',
      );
    });

    test('only rate limits, overload, server errors and network failures '
        'are retryable', () {
      bool retryable(int? status, String? type) =>
          RuntimeProviderFailed(status: status, errorType: type).retryable;

      expect(retryable(429, 'rate_limit_error'), isTrue);
      expect(retryable(500, 'api_error'), isTrue);
      expect(retryable(529, 'overloaded_error'), isTrue);
      expect(retryable(null, null), isTrue);
      expect(retryable(400, 'invalid_request_error'), isFalse);
      expect(retryable(401, 'authentication_error'), isFalse);
      expect(retryable(404, 'not_found_error'), isFalse);
      expect(retryable(null, 'aborted'), isFalse);
    });
  });
}
