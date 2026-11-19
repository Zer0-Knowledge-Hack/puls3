import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:puls3_server/src/runtime/runtime_task.dart';
import 'package:puls3_server/src/studio/team_task_runner.dart';
import 'package:test/test.dart';

void main() {
  const account = 'account1234';
  const env = {'PULS3_WORKERS_AI_ACCOUNT_ID': account};

  test('without the account id there is no team runner', () {
    expect(teamTestRunnerFromEnvironment({}, workersAiToken: 'token'), isNull);
    expect(
      teamTestRunnerFromEnvironment(
        {'PULS3_WORKERS_AI_ACCOUNT_ID': 'not-an-account'},
        workersAiToken: 'token',
      ),
      isNull,
    );
  });

  test('without the token there is no team runner', () {
    expect(teamTestRunnerFromEnvironment(env, workersAiToken: null), isNull);
    expect(teamTestRunnerFromEnvironment(env, workersAiToken: '  '), isNull);
  });

  test('the team runner sends the platform account and token', () async {
    late http.Request sent;
    final client = MockClient((request) async {
      sent = request;
      return http.Response(
        jsonEncode({
          'success': true,
          'result': {'response': 'five bullets'},
        }),
        200,
      );
    });
    final runner = teamTestRunnerFromEnvironment(
      env,
      workersAiToken: 'team-token',
      httpClient: client,
    )!;

    final output = await runner(
      RuntimeTask(
        provider: 'workers-ai',
        modelId: '@cf/meta/llama-3.3-70b-instruct-fp8-fast',
        systemPrompt: 'You are Brief Bot.',
        input: 'A long note.',
        maxInputChars: 100,
        maxOutputChars: 2000,
      ),
    );

    expect(output, 'five bullets');
    expect(
      sent.url.path,
      '/client/v4/accounts/$account/ai/run/'
      '@cf/meta/llama-3.3-70b-instruct-fp8-fast',
    );
    expect(sent.headers['authorization'], 'Bearer team-token');
    expect(jsonDecode(sent.body)['messages'], [
      {'role': 'system', 'content': 'You are Brief Bot.'},
      {'role': 'user', 'content': 'A long note.'},
    ]);
  });
}
