import 'package:puls3_server/src/runtime/conversation.dart';
import 'package:puls3_server/src/runtime/provider_router.dart';
import 'package:test/test.dart';

ConversationTask _task(String provider) => ConversationTask(
  provider: provider,
  modelId: 'm',
  systemPrompt: 'p',
  messages: [UserMessage('i')],
  tools: const [],
  maxInputChars: 10,
  maxOutputChars: 10,
);

final class _Talker implements ConversationRuntime {
  _Talker(this.name);

  final String name;
  Future<void>? lastTrigger;

  @override
  Future<ModelTurn> converse(
    ConversationTask task, {
    Future<void>? abortTrigger,
  }) async {
    lastTrigger = abortTrigger;
    return FinalText('$name:${task.provider}');
  }

  @override
  Future<String> complete(RuntimeTask task, {Future<void>? abortTrigger}) =>
      throw UnimplementedError();
}

final class _TextOnly implements ModelRuntime {
  @override
  Future<String> complete(RuntimeTask task, {Future<void>? abortTrigger}) =>
      throw UnimplementedError();
}

void main() {
  final byok = _Talker('byok');
  final router = ProviderRouter({'anthropic': byok, 'workers-ai': _TextOnly()});

  test('sends each conversation to its provider runtime with the abort '
      'trigger', () async {
    final trigger = Future<void>.value();
    final turn = await router.converse(
      _task('anthropic'),
      abortTrigger: trigger,
    );
    expect(
      turn,
      isA<FinalText>().having((t) => t.text, 'text', 'byok:anthropic'),
    );
    expect(byok.lastTrigger, same(trigger));
  });

  test('a provider without credentials is unsupported', () {
    expect(
      router.converse(_task('openai')),
      throwsA(isA<RuntimeUnsupportedProvider>()),
    );
  });

  test('a runtime that cannot converse is tools_unsupported', () {
    expect(
      router.converse(_task('workers-ai')),
      throwsA(
        isA<RuntimeToolsUnsupported>().having(
          (e) => e.code,
          'code',
          'tools_unsupported',
        ),
      ),
    );
  });
}
