import 'dart:async';

import 'package:puls3_server/src/runtime/agent_runner.dart';
import 'package:puls3_server/src/runtime/conversation.dart';
import 'package:test/test.dart';

const _timeout = Duration(milliseconds: 50);

ConversationTask _task({
  String input = 'Plan the release.',
  int maxInputChars = 100,
  int maxOutputChars = 50,
}) => ConversationTask(
  provider: 'anthropic',
  modelId: 'claude-opus-5-5',
  systemPrompt: 'You plan releases.',
  messages: [UserMessage(input)],
  tools: const [
    ToolSpec(name: 'search_agents', description: 'd', parameters: {}),
  ],
  maxInputChars: maxInputChars,
  maxOutputChars: maxOutputChars,
);

/// A [ConversationRuntime] that answers with [answer] and records each task.
final class _FakeTalker implements ConversationRuntime {
  _FakeTalker(this.answer);

  final Future<ModelTurn> Function(ConversationTask task) answer;
  final calls = <ConversationTask>[];
  final abortTriggers = <Future<void>?>[];

  @override
  Future<ModelTurn> converse(
    ConversationTask task, {
    Future<void>? abortTrigger,
  }) {
    calls.add(task);
    abortTriggers.add(abortTrigger);
    return answer(task);
  }

  @override
  Future<String> complete(RuntimeTask task, {Future<void>? abortTrigger}) =>
      throw UnimplementedError();
}

/// A [ModelRuntime] with no conversation support.
final class _TextOnly implements ModelRuntime {
  @override
  Future<String> complete(RuntimeTask task, {Future<void>? abortTrigger}) =>
      throw UnimplementedError();
}

Matcher _failsWith(String code) =>
    throwsA(isA<RuntimeFailure>().having((e) => e.code, 'code', code));

ToolCallsTurn _calls(Map<String, Object?> arguments) => ToolCallsTurn(
  calls: [ToolCall(id: 'c1', name: 'search_agents', arguments: arguments)],
);

void main() {
  test('returns the final text or the tool calls of one turn', () async {
    final talker = _FakeTalker((_) async => const FinalText('Done.'));
    final runner = AgentRunner(runtime: talker, timeout: _timeout);

    final turn = await runner.converseOnce(_task());
    expect(turn, isA<FinalText>().having((t) => t.text, 'text', 'Done.'));

    final calls = _calls(const {'query': 'writer'});
    final tools = AgentRunner(
      runtime: _FakeTalker((_) async => calls),
      timeout: _timeout,
    );
    expect(await tools.converseOnce(_task()), same(calls));
  });

  test(
    'a turn that does not answer in time is a timeout and is aborted',
    () async {
      final never = Completer<ModelTurn>();
      final talker = _FakeTalker((_) => never.future);
      final runner = AgentRunner(runtime: talker, timeout: _timeout);

      await expectLater(runner.converseOnce(_task()), _failsWith('timeout'));
      var aborted = false;
      await talker.abortTriggers.single!.then((_) => aborted = true);
      expect(aborted, isTrue);
    },
  );

  test('a conversation over the input limit fails without a call', () async {
    final talker = _FakeTalker((_) async => const FinalText('unused'));
    final runner = AgentRunner(runtime: talker, timeout: _timeout);

    await expectLater(
      runner.converseOnce(_task(input: '\u{1F680}' * 101)),
      _failsWith('input_too_long'),
    );
    expect(talker.calls, isEmpty);
    expect(
      await runner.converseOnce(_task(input: '\u{1F680}' * 100)),
      isA<FinalText>(),
    );
  });

  test('final text keeps the output rules of run', () async {
    Future<void> expectCode(String text, String code) => expectLater(
      AgentRunner(
        runtime: _FakeTalker((_) async => FinalText(text)),
        timeout: _timeout,
      ).converseOnce(_task()),
      _failsWith(code),
    );

    await expectCode(' \n ', 'empty_output');
    await expectCode('y' * 51, 'output_too_long');
  });

  test('tool calls count toward the output limit', () async {
    // 'search_agents' is 13 runes, the encoded arguments 37.
    final atLimit = _calls({'query': 'x' * 25});
    final over = _calls({'query': 'x' * 26});

    final ok = AgentRunner(
      runtime: _FakeTalker((_) async => atLimit),
      timeout: _timeout,
    );
    expect(await ok.converseOnce(_task()), same(atLimit));

    final tooLong = AgentRunner(
      runtime: _FakeTalker((_) async => over),
      timeout: _timeout,
    );
    await expectLater(
      tooLong.converseOnce(_task()),
      _failsWith('output_too_long'),
    );
  });

  test('a runtime without conversation support is tools_unsupported', () {
    final runner = AgentRunner(runtime: _TextOnly(), timeout: _timeout);
    expect(runner.converseOnce(_task()), _failsWith('tools_unsupported'));
  });
}
