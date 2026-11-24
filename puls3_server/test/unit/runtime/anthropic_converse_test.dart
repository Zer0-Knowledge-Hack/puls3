import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:puls3_server/src/runtime/adapters/anthropic_runtime.dart';
import 'package:puls3_server/src/runtime/conversation.dart';
import 'package:test/test.dart';

const _apiKey = 'test-key-that-must-never-leak';

const _search = ToolSpec(
  name: 'search_agents',
  description: 'Finds agents that can do a task.',
  parameters: {
    'type': 'object',
    'properties': {
      'query': {'type': 'string'},
    },
    'required': ['query'],
  },
);

ConversationTask _task({
  List<ConversationMessage>? messages,
  List<ToolSpec> tools = const [_search],
  String provider = 'anthropic',
}) => ConversationTask(
  provider: provider,
  modelId: 'claude-opus-5-5',
  systemPrompt: 'You plan a release.',
  messages: messages ?? [UserMessage('Write the release notes.')],
  tools: tools,
  maxInputChars: 4000,
  maxOutputChars: 8000,
);

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, Object?> _message(
  List<Object?> content, {
  String stopReason = 'end_turn',
}) => {
  'id': 'msg_01',
  'type': 'message',
  'role': 'assistant',
  'content': content,
  'stop_reason': stopReason,
  'stop_details': null,
};

AnthropicRuntime _runtime(http.Client client) =>
    AnthropicRuntime(httpClient: client, apiKey: _apiKey);

Future<ModelTurn> _answer(Object body) =>
    _runtime(MockClient((_) async => _json(body))).converse(_task());

Matcher _failed(String type) => throwsA(
  isA<RuntimeProviderFailed>()
      .having((e) => e.status, 'status', 200)
      .having((e) => e.errorType, 'errorType', type)
      .having((e) => e.retryable, 'retryable', false),
);

void main() {
  group('request', () {
    late http.Request seen;
    late Map<String, Object?> body;

    Future<void> send(ConversationTask task) async {
      await _runtime(
        MockClient((request) async {
          seen = request;
          body = jsonDecode(request.body) as Map<String, Object?>;
          return _json(
            _message([
              {'type': 'text', 'text': 'ok'},
            ]),
          );
        }),
      ).converse(task);
    }

    test('posts to the Messages API with the tools as input schemas', () async {
      await send(_task());

      expect(seen.url, Uri.parse('https://api.anthropic.com/v1/messages'));
      expect(seen.headers['x-api-key'], _apiKey);
      expect(body['model'], 'claude-opus-5-5');
      expect(body['system'], 'You plan a release.');
      expect(body['max_tokens'], 8000 + AnthropicRuntime.thinkingHeadroom);
      expect(body['tools'], [
        {
          'name': 'search_agents',
          'description': 'Finds agents that can do a task.',
          'input_schema': _search.parameters,
        },
      ]);
      expect(body['messages'], [
        {'role': 'user', 'content': 'Write the release notes.'},
      ]);
      expect(body.containsKey('tool_choice'), isFalse);
    });

    test('sends no tools field when no tool is offered', () async {
      await send(_task(tools: const []));
      expect(body.containsKey('tools'), isFalse);
    });

    test('replays assistant tool calls as content blocks and groups the '
        'tool results in one user message', () async {
      await send(
        _task(
          messages: [
            UserMessage('Write the release notes.'),
            AssistantMessage(
              text: 'Searching.',
              toolCalls: [
                ToolCall(
                  id: 'toolu_1',
                  name: 'search_agents',
                  arguments: const {'query': 'writer'},
                ),
                ToolCall(
                  id: 'toolu_2',
                  name: 'search_agents',
                  arguments: const {'query': 'editor'},
                ),
              ],
            ),
            ToolResultMessage(callId: 'toolu_1', content: 'agent A'),
            ToolResultMessage(
              callId: 'toolu_2',
              content: 'no agent',
              isError: true,
            ),
          ],
        ),
      );

      expect(body['messages'], [
        {'role': 'user', 'content': 'Write the release notes.'},
        {
          'role': 'assistant',
          'content': [
            {'type': 'text', 'text': 'Searching.'},
            {
              'type': 'tool_use',
              'id': 'toolu_1',
              'name': 'search_agents',
              'input': {'query': 'writer'},
            },
            {
              'type': 'tool_use',
              'id': 'toolu_2',
              'name': 'search_agents',
              'input': {'query': 'editor'},
            },
          ],
        },
        {
          'role': 'user',
          'content': [
            {
              'type': 'tool_result',
              'tool_use_id': 'toolu_1',
              'content': 'agent A',
              'is_error': false,
            },
            {
              'type': 'tool_result',
              'tool_use_id': 'toolu_2',
              'content': 'no agent',
              'is_error': true,
            },
          ],
        },
      ]);
    });

    test('replays the provider content verbatim, so thinking blocks come '
        'back unchanged', () async {
      final raw = [
        {'type': 'thinking', 'thinking': '', 'signature': 'sig'},
        {
          'type': 'tool_use',
          'id': 'toolu_1',
          'name': 'search_agents',
          'input': {'query': 'writer'},
        },
      ];
      await send(
        _task(
          messages: [
            UserMessage('Write the release notes.'),
            AssistantMessage(
              toolCalls: [
                ToolCall(
                  id: 'toolu_1',
                  name: 'search_agents',
                  arguments: const {'query': 'writer'},
                ),
              ],
              providerContent: raw,
            ),
            ToolResultMessage(callId: 'toolu_1', content: 'agent A'),
          ],
        ),
      );

      final messages = body['messages']! as List;
      expect(messages[1], {'role': 'assistant', 'content': raw});
    });

    test('a task for another provider is refused with no call', () async {
      var called = false;
      final runtime = _runtime(
        MockClient((_) async {
          called = true;
          return _json(_message(const []));
        }),
      );
      await expectLater(
        runtime.converse(_task(provider: 'workers-ai')),
        throwsA(isA<RuntimeUnsupportedProvider>()),
      );
      expect(called, isFalse);
    });
  });

  group('response', () {
    test('end_turn is the final text', () async {
      final turn = await _answer(
        _message([
          {'type': 'text', 'text': 'Notes: '},
          {'type': 'text', 'text': 'done.'},
        ]),
      );
      expect(
        turn,
        isA<FinalText>().having((t) => t.text, 'text', 'Notes: done.'),
      );
    });

    test('tool_use is the list of tool calls with the raw content', () async {
      final content = [
        {'type': 'thinking', 'thinking': '', 'signature': 'sig'},
        {'type': 'text', 'text': 'Let me search.'},
        {
          'type': 'tool_use',
          'id': 'toolu_1',
          'name': 'search_agents',
          'input': {'query': 'writer'},
        },
      ];
      final turn = await _answer(_message(content, stopReason: 'tool_use'));

      expect(turn, isA<ToolCallsTurn>());
      turn as ToolCallsTurn;
      expect(turn.text, 'Let me search.');
      expect(turn.providerContent, content);
      final call = turn.calls.single;
      expect(call.id, 'toolu_1');
      expect(call.name, 'search_agents');
      expect(call.arguments, {'query': 'writer'});
    });

    test('a tool_use stop with no tool_use block is malformed', () async {
      expect(
        _answer(
          _message([
            {'type': 'text', 'text': 'hm'},
          ], stopReason: 'tool_use'),
        ),
        _failed('malformed_tool_call'),
      );
    });

    for (final (label, block) in [
      ('a missing id', {'type': 'tool_use', 'name': 'x', 'input': {}}),
      ('an empty id', {'type': 'tool_use', 'id': '', 'name': 'x', 'input': {}}),
      ('a missing name', {'type': 'tool_use', 'id': 't', 'input': {}}),
      (
        'a non-object input',
        {'type': 'tool_use', 'id': 't', 'name': 'x', 'input': 'q'},
      ),
    ]) {
      test('a tool call with $label is malformed', () {
        expect(
          _answer(_message([block], stopReason: 'tool_use')),
          _failed('malformed_tool_call'),
        );
      });
    }

    test('refusals and truncation map as in complete', () async {
      await expectLater(
        _answer(_message(const [], stopReason: 'refusal')),
        throwsA(isA<RuntimeRefused>()),
      );
      await expectLater(
        _answer(_message(const [], stopReason: 'max_tokens')),
        throwsA(isA<RuntimeOutputTruncated>()),
      );
    });

    test('an HTTP error keeps the provider error type', () {
      expect(
        _runtime(
          MockClient(
            (_) async => _json({
              'type': 'error',
              'error': {'type': 'overloaded_error', 'message': 'busy'},
            }, 529),
          ),
        ).converse(_task()),
        throwsA(
          isA<RuntimeProviderFailed>()
              .having((e) => e.status, 'status', 529)
              .having((e) => e.errorType, 'errorType', 'overloaded_error'),
        ),
      );
    });

    test('an abort cancels the request', () async {
      final abort = Completer<void>();
      final runtime = _runtime(
        MockClient.streaming((request, _) async {
          await (request as http.Abortable).abortTrigger;
          throw http.RequestAbortedException(request.url);
        }),
      );
      final call = runtime.converse(_task(), abortTrigger: abort.future);
      abort.complete();
      await expectLater(call, _failedAborted);
    });
  });
}

final _failedAborted = throwsA(
  isA<RuntimeProviderFailed>()
      .having((e) => e.errorType, 'errorType', 'aborted')
      .having((e) => e.retryable, 'retryable', false),
);
