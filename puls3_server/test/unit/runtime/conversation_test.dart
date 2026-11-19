import 'package:puls3_server/src/runtime/conversation.dart';
import 'package:test/test.dart';

ConversationTask _task(List<ConversationMessage> messages) => ConversationTask(
  provider: 'anthropic',
  modelId: 'claude-opus-5-5',
  systemPrompt: 'You plan.',
  messages: messages,
  tools: const [],
  maxInputChars: 100,
  maxOutputChars: 100,
);

void main() {
  test('the conversation length counts every message in runes, not the '
      'system prompt or the provider content', () {
    final task = _task([
      UserMessage('héllo 👋'), // 7 runes
      AssistantMessage(
        text: 'ok', // 2
        toolCalls: [
          ToolCall(id: 'c1', name: 'find', arguments: const {'q': 'x'}),
        ], // 'find' 4 + '{"q":"x"}' 9
        providerContent: const [
          {'type': 'thinking', 'thinking': 'a very long hidden block'},
        ],
      ),
      ToolResultMessage(callId: 'c1', content: 'found'), // 5
    ]);

    expect(task.conversationLength, 7 + 2 + 4 + 9 + 5);
  });

  test('a conversation needs at least one message', () {
    expect(() => _task(const []), throwsArgumentError);
  });

  test('an assistant message needs text or tool calls', () {
    expect(() => AssistantMessage(text: ''), throwsArgumentError);
  });

  test('a tool calls turn needs at least one call and replays as an '
      'assistant message', () {
    expect(() => ToolCallsTurn(calls: const []), throwsArgumentError);

    final call = ToolCall(id: 'c1', name: 'find', arguments: const {});
    final turn = ToolCallsTurn(
      calls: [call],
      text: 'Looking.',
      providerContent: const ['raw'],
    );
    final message = turn.toMessage();
    expect(message.text, 'Looking.');
    expect(message.toolCalls, [same(call)]);
    expect(message.providerContent, ['raw']);
  });

  test('tool call arguments cannot be changed after the call', () {
    final args = <String, Object?>{'q': 'x'};
    final call = ToolCall(id: 'c1', name: 'find', arguments: args);
    args['q'] = 'y';
    expect(call.arguments, {'q': 'x'});
    expect(() => call.arguments['q'] = 'z', throwsUnsupportedError);
  });
}
