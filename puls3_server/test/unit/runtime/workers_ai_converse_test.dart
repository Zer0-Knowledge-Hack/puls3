import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:puls3_server/src/runtime/adapters/workers_ai_runtime.dart';
import 'package:puls3_server/src/runtime/conversation.dart';
import 'package:test/test.dart';

const _model = '@cf/meta/llama-3.3-70b-instruct-fp8-fast';

const _toolModel = '@cf/mistralai/mistral-small-3.1-24b-instruct';

const _searchTool = ToolSpec(
  name: 'search_agents',
  description: 'Find agents.',
  parameters: {
    'type': 'object',
    'properties': {
      'query': {'type': 'string'},
    },
    'required': ['query'],
  },
);

ConversationTask _task({
  required List<ConversationMessage> messages,
  List<ToolSpec> tools = const [],
  String model = _model,
}) => ConversationTask(
  provider: 'workers-ai',
  modelId: model,
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

  group('a Workers AI tool model', () {
    late Uri url;
    late Map<String, String> headers;
    late Object replyBody;
    late int replyStatus;

    WorkersAiRuntime toolRuntime() => WorkersAiRuntime(
      httpClient: MockClient((request) async {
        calls++;
        url = request.url;
        headers = request.headers;
        body = jsonDecode(request.body) as Map<String, Object?>;
        return http.Response(
          jsonEncode(replyBody),
          replyStatus,
          headers: {'content-type': 'application/json'},
        );
      }),
      accountId: 'acc',
      apiToken: 'token',
    );

    Map<String, Object?> completion(
      Map<String, Object?> message, {
      String finish = 'stop',
    }) => {
      'choices': [
        {'index': 0, 'message': message, 'finish_reason': finish},
      ],
    };

    setUp(() {
      replyStatus = 200;
      replyBody = completion({'role': 'assistant', 'content': 'Done.'});
    });

    test('is listed as a tool model, and llama 3.3 is not', () {
      expect(workersAiToolModels, contains(_toolModel));
      expect(workersAiToolModels, isNot(contains(_model)));
    });

    test('offering tools posts an OpenAI-compatible chat completion and a '
        'tool call comes back with its id and decoded arguments', () async {
      replyBody = completion({
        'role': 'assistant',
        'content': '',
        'tool_calls': [
          {
            'id': 'call_1',
            'type': 'function',
            'function': {
              'name': 'search_agents',
              'arguments': '{"query":"translate to Spanish"}',
            },
          },
        ],
      }, finish: 'tool_calls');

      final turn = await toolRuntime().converse(
        _task(
          model: _toolModel,
          messages: [UserMessage('Summarize in Spanish')],
          tools: const [_searchTool],
        ),
      );

      expect(calls, 1);
      expect(
        url.toString(),
        'https://api.cloudflare.com/client/v4/accounts/acc/ai/v1/chat/completions',
      );
      expect(headers['authorization'], 'Bearer token');
      expect(body['model'], _toolModel);
      expect(body['max_tokens'], 4000);
      expect(body['messages'], [
        {'role': 'system', 'content': 'You triage one customer message.'},
        {'role': 'user', 'content': 'Summarize in Spanish'},
      ]);
      expect(body['tools'], [
        {
          'type': 'function',
          'function': {
            'name': 'search_agents',
            'description': 'Find agents.',
            'parameters': _searchTool.parameters,
          },
        },
      ]);
      expect(turn, isA<ToolCallsTurn>());
      final call = (turn as ToolCallsTurn).calls.single;
      expect(call.id, 'call_1');
      expect(call.name, 'search_agents');
      expect(call.arguments, {'query': 'translate to Spanish'});
    });

    test('tool calls and results are replayed as assistant tool_calls and '
        'tool messages, and a final answer is FinalText', () async {
      replyBody = completion({'role': 'assistant', 'content': 'Hola.'});

      final turn = await toolRuntime().converse(
        _task(
          model: _toolModel,
          tools: const [_searchTool],
          messages: [
            UserMessage('Summarize in Spanish'),
            AssistantMessage(
              text: 'Searching.',
              toolCalls: [
                ToolCall(
                  id: 'call_1',
                  name: 'search_agents',
                  arguments: const {'query': 'spanish'},
                ),
              ],
            ),
            ToolResultMessage(callId: 'call_1', content: '{"candidates":[]}'),
          ],
        ),
      );

      expect(turn, isA<FinalText>().having((t) => t.text, 'text', 'Hola.'));
      expect((body['messages'] as List).skip(2), [
        {
          'role': 'assistant',
          'content': 'Searching.',
          'tool_calls': [
            {
              'id': 'call_1',
              'type': 'function',
              'function': {
                'name': 'search_agents',
                'arguments': '{"query":"spanish"}',
              },
            },
          ],
        },
        {
          'role': 'tool',
          'tool_call_id': 'call_1',
          'content': '{"candidates":[]}',
        },
      ]);
    });

    test('arguments sent as an object are accepted too', () async {
      replyBody = completion({
        'role': 'assistant',
        'content': null,
        'tool_calls': [
          {
            'id': 'call_2',
            'type': 'function',
            'function': {
              'name': 'search_agents',
              'arguments': {'query': 'x'},
            },
          },
        ],
      }, finish: 'tool_calls');

      final turn = await toolRuntime().converse(
        _task(
          model: _toolModel,
          messages: [UserMessage('hi')],
          tools: const [_searchTool],
        ),
      );

      final turnCalls = (turn as ToolCallsTurn).calls;
      expect(turnCalls.single.arguments, {'query': 'x'});
      expect(turn.text, '');
    });

    for (final (label, function) in [
      ('blank', {'name': 'search_agents', 'arguments': ''}),
      ('null', {'name': 'search_agents', 'arguments': null}),
      ('missing', {'name': 'search_agents'}),
    ]) {
      test('$label arguments are read as no arguments, not as a malformed '
          'call', () async {
        replyBody = completion({
          'role': 'assistant',
          'content': null,
          'tool_calls': [
            {'id': 'call_3', 'type': 'function', 'function': function},
          ],
        }, finish: 'tool_calls');

        final turn = await toolRuntime().converse(
          _task(
            model: _toolModel,
            messages: [UserMessage('hi')],
            tools: const [_searchTool],
          ),
        );

        final call = (turn as ToolCallsTurn).calls.single;
        expect(call.id, 'call_3');
        expect(call.name, 'search_agents');
        expect(call.arguments, isEmpty);
      });
    }

    final malformedCall = throwsA(
      isA<RuntimeProviderFailed>().having(
        (e) => e.errorType,
        'errorType',
        'malformed_tool_call',
      ),
    );

    for (final (label, call) in [
      (
        'without an id',
        {
          'type': 'function',
          'function': {'name': 'search_agents', 'arguments': '{}'},
        },
      ),
      (
        'without a name',
        {
          'id': 'c',
          'type': 'function',
          'function': {'arguments': '{}'},
        },
      ),
      (
        'whose arguments are not a JSON object',
        {
          'id': 'c',
          'type': 'function',
          'function': {'name': 'search_agents', 'arguments': '"just text"'},
        },
      ),
      (
        'whose arguments are not JSON',
        {
          'id': 'c',
          'type': 'function',
          'function': {'name': 'search_agents', 'arguments': '{query:'},
        },
      ),
    ]) {
      test('a tool call $label fails as malformed_tool_call', () async {
        replyBody = completion({
          'role': 'assistant',
          'content': '',
          'tool_calls': [call],
        }, finish: 'tool_calls');

        await expectLater(
          toolRuntime().converse(
            _task(
              model: _toolModel,
              messages: [UserMessage('hi')],
              tools: const [_searchTool],
            ),
          ),
          malformedCall,
        );
      });
    }

    test('an answer cut at max_tokens fails as output_truncated', () async {
      replyBody = completion({
        'role': 'assistant',
        'content': 'Half an ans',
      }, finish: 'length');

      await expectLater(
        toolRuntime().converse(
          _task(
            model: _toolModel,
            messages: [UserMessage('hi')],
            tools: const [_searchTool],
          ),
        ),
        throwsA(isA<RuntimeOutputTruncated>()),
      );
    });

    test('a body without a message, or a final answer without text, fails '
        'as malformed_response', () async {
      for (final reply in [
        <String, Object?>{'choices': <Object>[]},
        {'result': 'x'},
        completion({'role': 'assistant', 'content': null}),
      ]) {
        replyBody = reply;
        await expectLater(
          toolRuntime().converse(
            _task(
              model: _toolModel,
              messages: [UserMessage('hi')],
              tools: const [_searchTool],
            ),
          ),
          throwsA(
            isA<RuntimeProviderFailed>().having(
              (e) => e.errorType,
              'errorType',
              'malformed_response',
            ),
          ),
        );
      }
    });

    test('an error status fails with the Cloudflare error code', () async {
      replyStatus = 429;
      replyBody = {
        'success': false,
        'errors': [
          {'code': 3040, 'message': 'Capacity temporarily exceeded'},
        ],
      };

      await expectLater(
        toolRuntime().converse(
          _task(
            model: _toolModel,
            messages: [UserMessage('hi')],
            tools: const [_searchTool],
          ),
        ),
        throwsA(
          isA<RuntimeProviderFailed>()
              .having((e) => e.status, 'status', 429)
              .having((e) => e.errorType, 'errorType', 'cloudflare_3040'),
        ),
      );
    });

    test('a tool model without tools still uses the plain Workers AI '
        'run', () async {
      replyBody = {
        'result': {'response': 'Billing.'},
        'success': true,
        'errors': <Object>[],
      };

      final turn = await toolRuntime().converse(
        _task(model: _toolModel, messages: [UserMessage('hi')]),
      );

      expect(turn, isA<FinalText>().having((t) => t.text, 'text', 'Billing.'));
      expect(
        url.path,
        endsWith('/ai/run/@cf/mistralai/mistral-small-3.1-24b-instruct'),
      );
      expect(body.containsKey('tools'), isFalse);
    });
  });
}
