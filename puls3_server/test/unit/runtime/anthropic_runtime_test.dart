import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:puls3_server/src/runtime/adapters/anthropic_runtime.dart';
import 'package:puls3_server/src/runtime/runtime_task.dart';
import 'package:test/test.dart';

const _apiKey = 'test-key-that-must-never-leak';

RuntimeTask _task({
  String provider = 'anthropic',
  String modelId = 'claude-opus-5-5',
  String systemPrompt = 'You summarize release notes in one sentence.',
  String input = 'The release adds escrow payments.',
}) => RuntimeTask(
  provider: provider,
  modelId: modelId,
  systemPrompt: systemPrompt,
  input: input,
  maxInputChars: 4000,
  maxOutputChars: 8000,
);

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, Object?> _message(
  List<Map<String, Object?>> content, {
  String stopReason = 'end_turn',
  Map<String, Object?>? stopDetails,
}) => {
  'id': 'msg_01',
  'type': 'message',
  'role': 'assistant',
  'content': content,
  'stop_reason': stopReason,
  'stop_details': stopDetails,
  'usage': {'input_tokens': 10, 'output_tokens': 5},
};

Map<String, Object?> _error(String type) => {
  'type': 'error',
  'error': {'type': type, 'message': 'details from the provider'},
};

AnthropicRuntime _runtime(http.Client client) =>
    AnthropicRuntime(httpClient: client, apiKey: _apiKey);

Matcher _providerFailed(int? status, String? type, {required bool retryable}) =>
    throwsA(
      isA<RuntimeProviderFailed>()
          .having((e) => e.status, 'status', status)
          .having((e) => e.errorType, 'errorType', type)
          .having((e) => e.retryable, 'retryable', retryable),
    );

void main() {
  group('request', () {
    late http.Request seen;
    late Map<String, Object?> body;

    Future<void> send(RuntimeTask task) async {
      final runtime = _runtime(
        MockClient((request) async {
          seen = request;
          body = jsonDecode(request.body) as Map<String, Object?>;
          return _json(
            _message([
              {'type': 'text', 'text': 'ok'},
            ]),
          );
        }),
      );
      await runtime.complete(task);
    }

    test(
      'posts to the Messages API with the key and version headers',
      () async {
        await send(_task());

        expect(seen.method, 'POST');
        expect(seen.url, Uri.parse('https://api.anthropic.com/v1/messages'));
        expect(seen.headers['x-api-key'], _apiKey);
        expect(seen.headers['anthropic-version'], '2023-06-01');
        expect(seen.headers['content-type'], startsWith('application/json'));
      },
    );

    test('model, system prompt and input come from the task', () async {
      await send(_task());

      expect(body['model'], 'claude-opus-5-5');
      expect(body['system'], 'You summarize release notes in one sentence.');
      expect(body['messages'], [
        {'role': 'user', 'content': 'The release adds escrow payments.'},
      ]);
      expect(body['max_tokens'], 8000 + AnthropicRuntime.thinkingHeadroom);
      expect(body.containsKey('temperature'), isFalse);
      expect(body.containsKey('thinking'), isFalse);
    });

    test('a different manifest prompt changes the request, with no code '
        'change', () async {
      await send(_task(systemPrompt: 'You translate the input into Spanish.'));
      expect(body['system'], 'You translate the input into Spanish.');

      await send(_task(modelId: 'claude-sonnet-5-5'));
      expect(body['model'], 'claude-sonnet-5-5');
    });

    test(
      'asks for server-side fallbacks on models that support them',
      () async {
        for (final model in [
          'claude-opus-5-5',
          'claude-sonnet-5-5',
          'claude-opus-5',
          'claude-fable-5-1',
        ]) {
          await send(_task(modelId: model));
          expect(body['fallbacks'], 'default', reason: model);
          expect(
            seen.headers['anthropic-beta'],
            'server-side-fallback-2026-07-01',
            reason: model,
          );
        }
      },
    );

    test('sends no fallbacks for other models', () async {
      await send(_task(modelId: 'claude-haiku-4-5'));

      expect(body.containsKey('fallbacks'), isFalse);
      expect(seen.headers.containsKey('anthropic-beta'), isFalse);
    });
  });

  group('max_tokens follows the manifest output limit', () {
    RuntimeTask withOutput(int maxOutputChars) => RuntimeTask(
      provider: 'anthropic',
      modelId: 'claude-opus-5-5',
      systemPrompt: 'p',
      input: 'i',
      maxInputChars: 10,
      maxOutputChars: maxOutputChars,
    );

    test('output limit plus thinking headroom', () {
      expect(AnthropicRuntime.maxTokensFor(withOutput(500)), 4500);
      expect(AnthropicRuntime.maxTokensFor(withOutput(8000)), 12000);
    });

    test('never above the ceiling', () {
      expect(AnthropicRuntime.maxTokensFor(withOutput(12000)), 16000);
      expect(AnthropicRuntime.maxTokensFor(withOutput(50000)), 16000);
    });
  });

  group('abort', () {
    test(
      'the request carries the abort trigger and stops when it fires',
      () async {
        final trigger = Completer<void>();
        Future<void>? seenTrigger;
        final runtime = _runtime(
          MockClient.streaming((request, _) async {
            seenTrigger = request is http.Abortable
                ? request.abortTrigger
                : null;
            // A real client aborts the request when the trigger completes.
            await trigger.future;
            throw http.RequestAbortedException(request.url);
          }),
        );

        final call = runtime.complete(_task(), abortTrigger: trigger.future);
        await Future<void>.delayed(Duration.zero);
        expect(seenTrigger, same(trigger.future));
        trigger.complete();

        await expectLater(
          call,
          throwsA(
            isA<RuntimeProviderFailed>()
                .having((e) => e.errorType, 'errorType', 'aborted')
                .having((e) => e.retryable, 'retryable', isFalse),
          ),
        );
      },
    );
  });

  group('response', () {
    test('joins the text blocks and ignores thinking blocks', () async {
      final runtime = _runtime(
        MockClient(
          (_) async => _json(
            _message([
              {'type': 'thinking', 'thinking': '', 'signature': 'sig'},
              {'type': 'text', 'text': 'Escrow payments '},
              {'type': 'text', 'text': 'are here.'},
            ]),
          ),
        ),
      );

      expect(await runtime.complete(_task()), 'Escrow payments are here.');
    });

    test('a refusal is a RuntimeRefused with its category', () async {
      final runtime = _runtime(
        MockClient(
          (_) async => _json(
            _message(
              [],
              stopReason: 'refusal',
              stopDetails: {'type': 'refusal', 'category': 'cyber'},
            ),
          ),
        ),
      );

      await expectLater(
        runtime.complete(_task()),
        throwsA(
          isA<RuntimeRefused>().having((e) => e.category, 'category', 'cyber'),
        ),
      );
    });

    test('output cut by max_tokens is a RuntimeOutputTruncated', () async {
      final runtime = _runtime(
        MockClient(
          (_) async => _json(
            _message([
              {'type': 'text', 'text': 'half an ans'},
            ], stopReason: 'max_tokens'),
          ),
        ),
      );

      await expectLater(
        runtime.complete(_task()),
        throwsA(isA<RuntimeOutputTruncated>()),
      );
    });

    test('an unexpected stop reason is a non-retryable provider failure', () {
      final runtime = _runtime(
        MockClient(
          (_) async => _json(_message([], stopReason: 'tool_use')),
        ),
      );

      expect(
        runtime.complete(_task()),
        _providerFailed(200, 'unexpected_stop_reason', retryable: false),
      );
    });

    test('a body that is not a message is a provider failure', () {
      for (final body in ['not json', '[]', '{"content": "text"}']) {
        final runtime = _runtime(
          MockClient((_) async => http.Response(body, 200)),
        );
        expect(
          runtime.complete(_task()),
          _providerFailed(200, 'malformed_response', retryable: false),
          reason: body,
        );
      }
    });
  });

  group('errors', () {
    test('API errors keep the status and the error type', () async {
      final cases = {
        400: ('invalid_request_error', false),
        401: ('authentication_error', false),
        404: ('not_found_error', false),
        429: ('rate_limit_error', true),
        500: ('api_error', true),
        529: ('overloaded_error', true),
      };
      for (final MapEntry(key: status, value: (type, retryable))
          in cases.entries) {
        final runtime = _runtime(
          MockClient((_) async => _json(_error(type), status)),
        );
        await expectLater(
          runtime.complete(_task()),
          _providerFailed(status, type, retryable: retryable),
          reason: '$status',
        );
      }
    });

    test('an error body that is not JSON still keeps the status', () {
      final runtime = _runtime(
        MockClient((_) async => http.Response('<html>bad gateway</html>', 502)),
      );

      expect(
        runtime.complete(_task()),
        _providerFailed(502, null, retryable: true),
      );
    });

    test('a network failure is a retryable provider failure', () async {
      for (final error in [
        const SocketException('connection refused'),
        http.ClientException('connection closed'),
      ]) {
        final runtime = _runtime(MockClient((_) async => throw error));
        await expectLater(
          runtime.complete(_task()),
          _providerFailed(null, null, retryable: true),
        );
      }
    });

    test('another provider is refused without a request', () async {
      var called = false;
      final runtime = _runtime(
        MockClient((_) async {
          called = true;
          return _json({});
        }),
      );

      await expectLater(
        runtime.complete(_task(provider: 'openai')),
        throwsA(isA<RuntimeUnsupportedProvider>()),
      );
      expect(called, isFalse);
    });

    test('the API key never appears in a failure', () async {
      final responses = <http.Response>[
        _json(_error('authentication_error'), 401),
        http.Response('echo $_apiKey', 500),
        _json(_message([], stopReason: 'refusal')),
      ];
      for (final response in responses) {
        final runtime = _runtime(MockClient((_) async => response));
        try {
          await runtime.complete(_task());
          fail('expected a failure');
        } on RuntimeFailure catch (e) {
          expect(e.toString(), isNot(contains(_apiKey)));
          expect(e.code, isNot(contains(_apiKey)));
        }
      }
    });
  });

  test('the adapter never prints its key', () {
    final runtime = _runtime(MockClient((_) async => _json({})));
    expect(runtime.toString(), isNot(contains(_apiKey)));
  });
}
