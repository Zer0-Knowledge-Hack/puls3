import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:puls3_server/src/runtime/adapters/workers_ai_runtime.dart';
import 'package:puls3_server/src/runtime/conversation.dart';
import 'package:test/test.dart';

const _model = '@cf/meta/llama-3.3-70b-instruct-fp8-fast';

ConversationTask _task({
  required List<ConversationMessage> messages,
  List<ToolSpec> tools = const [],
}) => ConversationTask(
  provider: 'workers-ai',
  modelId: _model,
  systemPrompt: 'You triage one customer message.',
  messages: messages,
  tools: tools,
  maxInputChars: 4000,
  maxOutputChars: 4000,
);

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  late int calls;
  late Map<String, Object?> body;

  WorkersAiRuntime runtime() => WorkersAiRuntime(
    httpClient: MockClient((request) async {
      calls++;
      body = jsonDecode(request.body) as Map<String, Object?>;
      return _json({
        'result': {'response': 'Billing.'},
        'success': true,
        'errors': <Object>[],
      });
    }),
    accountId: 'acc',
    apiToken: 'token',
  );

  setUp(() => calls = 0);

  test('a conversation without tools is sent as chat messages and answers '
      'with the final text', () async {
    final turn = await runtime().converse(
      _task(
        messages: [
          UserMessage('My invoice is wrong'),
          AssistantMessage(text: 'Which invoice?'),
          UserMessage('The May one'),
        ],
      ),
    );

    expect(turn, isA<FinalText>().having((t) => t.text, 'text', 'Billing.'));
    expect(body['messages'], [
      {'role': 'system', 'content': 'You triage one customer message.'},
      {'role': 'user', 'content': 'My invoice is wrong'},
      {'role': 'assistant', 'content': 'Which invoice?'},
      {'role': 'user', 'content': 'The May one'},
    ]);
    expect(body['max_tokens'], 4000);
    expect(body.containsKey('tools'), isFalse);
  });

  final unsupported = throwsA(
    isA<RuntimeToolsUnsupported>().having(
      (e) => e.code,
      'code',
      'tools_unsupported',
    ),
  );

  test('offering tools is unsupported, with no call', () async {
    await expectLater(
      runtime().converse(
        _task(
          messages: [UserMessage('hi')],
          tools: const [
            ToolSpec(name: 'search_agents', description: 'd', parameters: {}),
          ],
        ),
      ),
      unsupported,
    );
    expect(calls, 0);
  });

  test('replaying tool calls or tool results is unsupported, with no '
      'call', () async {
    await expectLater(
      runtime().converse(
        _task(
          messages: [
            UserMessage('hi'),
            AssistantMessage(
              toolCalls: [ToolCall(id: 'c', name: 'x', arguments: const {})],
            ),
            ToolResultMessage(callId: 'c', content: 'r'),
          ],
        ),
      ),
      unsupported,
    );
    expect(calls, 0);
  });
}
