import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:puls3_server/src/runtime/adapters/workers_ai_runtime.dart';
import 'package:puls3_server/src/runtime/runtime_task.dart';
import 'package:test/test.dart';

const _token = 'cf-token-that-must-never-leak';
const _account = 'acc0123456789abcdef';
const _model = '@cf/meta/llama-3.3-70b-instruct-fp8-fast';

RuntimeTask _task({
  String provider = 'workers-ai',
  String modelId = _model,
  String systemPrompt = 'You triage one customer message.',
  String input = 'My invoice is wrong',
  int maxOutputChars = 4000,
}) => RuntimeTask(
  provider: provider,
  modelId: modelId,
  systemPrompt: systemPrompt,
  input: input,
  maxInputChars: 4000,
  maxOutputChars: maxOutputChars,
);

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, Object?> _ok(String text) => {
  'result': {'response': text},
  'success': true,
  'errors': <Object>[],
  'messages': <Object>[],
};

Map<String, Object?> _cfError(int code) => {
  'result': null,
  'success': false,
  'errors': [
    {'code': code, 'message': 'details from Cloudflare'},
  ],
  'messages': <Object>[],
};

WorkersAiRuntime _runtime(http.Client client) =>
    WorkersAiRuntime(httpClient: client, accountId: _account, apiToken: _token);

Matcher _failed(int? status, String? type, {required bool retryable}) =>
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

    Future<String> send(RuntimeTask task) => _runtime(
      MockClient((request) async {
        seen = request;
        body = jsonDecode(request.body) as Map<String, Object?>;
        return _json(_ok('ok'));
      }),
    ).complete(task);

    test(
      'posts to the Workers AI run URL of the model with a bearer token',
      () async {
        await send(_task());

        expect(seen.method, 'POST');
        expect(
          seen.url.toString(),
          'https://api.cloudflare.com/client/v4/accounts/$_account/ai/run/'
          '$_model',
        );
        expect(seen.headers['authorization'], 'Bearer $_token');
        expect(seen.headers['content-type'], startsWith('application/json'));
      },
    );

    test('system prompt and input come from the task, as messages', () async {
      await send(_task());

      expect(body['messages'], [
        {'role': 'system', 'content': 'You triage one customer message.'},
        {'role': 'user', 'content': 'My invoice is wrong'},
      ]);
    });

    test('a different manifest prompt or model changes the request', () async {
      await send(_task(systemPrompt: 'You translate into Spanish.'));
      expect(
        (body['messages'] as List).first,
        {'role': 'system', 'content': 'You translate into Spanish.'},
      );

      await send(_task(modelId: '@cf/meta/llama-4-scout-17b-16e-instruct'));
      expect(
        seen.url.path,
        endsWith('/ai/run/@cf/meta/llama-4-scout-17b-16e-instruct'),
      );
    });

    test('max_tokens is always set from the output limit, capped', () async {
      await send(_task(maxOutputChars: 1000));
      expect(body['max_tokens'], 1000);

      await send(_task(maxOutputChars: 16000));
      expect(body['max_tokens'], WorkersAiRuntime.maxTokensCeiling);
    });
  });

  group('response', () {
    test('returns result.response', () async {
      final runtime = _runtime(
        MockClient((_) async => _json(_ok('Category: billing.'))),
      );

      expect(await runtime.complete(_task()), 'Category: billing.');
    });

    test('success false is a failure with the Cloudflare code', () {
      final runtime = _runtime(MockClient((_) async => _json(_cfError(3040))));

      expect(
        runtime.complete(_task()),
        _failed(200, 'cloudflare_3040', retryable: false),
      );
    });

    test('a body without result.response is malformed', () async {
      for (final body in [
        'not json',
        '[]',
        jsonEncode({'success': true, 'result': {}}),
      ]) {
        final runtime = _runtime(
          MockClient((_) async => http.Response(body, 200)),
        );
        await expectLater(
          runtime.complete(_task()),
          _failed(200, 'malformed_response', retryable: false),
          reason: body,
        );
      }
    });
  });

  group('errors', () {
    test('HTTP errors keep the status and the Cloudflare code', () async {
      final cases = {
        400: (5006, false),
        401: (10000, false),
        429: (3036, true),
        500: (5000, true),
      };
      for (final MapEntry(key: status, value: (code, retryable))
          in cases.entries) {
        final runtime = _runtime(
          MockClient((_) async => _json(_cfError(code), status)),
        );
        await expectLater(
          runtime.complete(_task()),
          _failed(status, 'cloudflare_$code', retryable: retryable),
          reason: '$status',
        );
      }
    });

    test('a network failure is a retryable failure', () async {
      for (final error in [
        const SocketException('refused'),
        http.ClientException('closed'),
      ]) {
        final runtime = _runtime(MockClient((_) async => throw error));
        await expectLater(
          runtime.complete(_task()),
          _failed(null, null, retryable: true),
        );
      }
    });

    test('the abort trigger reaches the request and stops it', () async {
      final trigger = Completer<void>();
      Future<void>? seenTrigger;
      final runtime = _runtime(
        MockClient.streaming((request, _) async {
          seenTrigger = request is http.Abortable ? request.abortTrigger : null;
          await trigger.future;
          throw http.RequestAbortedException(request.url);
        }),
      );

      final call = runtime.complete(_task(), abortTrigger: trigger.future);
      await Future<void>.delayed(Duration.zero);
      expect(seenTrigger, same(trigger.future));
      trigger.complete();

      await expectLater(call, _failed(null, 'aborted', retryable: false));
    });

    test('another provider is refused without a request', () async {
      var called = false;
      final runtime = _runtime(
        MockClient((_) async {
          called = true;
          return _json(_ok('x'));
        }),
      );

      await expectLater(
        runtime.complete(_task(provider: 'anthropic')),
        throwsA(isA<RuntimeUnsupportedProvider>()),
      );
      expect(called, isFalse);
    });

    test('the API token never appears in a failure or toString', () async {
      for (final response in [
        _json(_cfError(10000), 401),
        http.Response('echo $_token', 500),
        _json(_cfError(3040)),
      ]) {
        final runtime = _runtime(MockClient((_) async => response));
        try {
          await runtime.complete(_task());
          fail('expected a failure');
        } on RuntimeFailure catch (e) {
          expect(e.toString(), isNot(contains(_token)));
          expect(e.code, isNot(contains(_token)));
        }
      }
      expect(
        _runtime(MockClient((_) async => _json({}))).toString(),
        isNot(contains(_token)),
      );
    });
  });
}
