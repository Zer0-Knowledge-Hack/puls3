import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:puls3_cli/puls3_cli.dart';
import 'package:test/test.dart';

/// A valid draft manifest, as the Studio exports it, with [overrides] applied
/// to the top-level keys.
Map<String, Object?> _manifest({
  String provider = 'workers-ai',
  String modelId = '@cf/meta/llama-3.3-70b-instruct-fp8-fast',
  int inputMaxChars = 8000,
  int outputMaxChars = 6000,
  Map<String, Object?> overrides = const {},
}) => {
  'name': 'Soroban Pre-Audit',
  'description': 'Reviews a Soroban contract before an audit.',
  'skills': [
    {
      'id': 'soroban-security-review',
      'name': 'Soroban security review',
      'description': 'Finds security issues.',
      'tags': ['soroban'],
    },
    {
      'id': 'auth-check',
      'name': 'Authorization check',
      'description': 'Checks require_auth.',
      'tags': <String>[],
    },
  ],
  'model': {'provider': provider, 'id': modelId},
  'system_prompt': 'You are a Soroban security reviewer. Find the bugs.',
  'input': {'type': 'text', 'max_chars': inputMaxChars},
  'output': {'type': 'markdown', 'max_chars': outputMaxChars},
  'price': {'asset': 'USDC', 'amount': 5000000},
  ...overrides,
};

const _cloudflare = {
  'CLOUDFLARE_ACCOUNT_ID': 'acct123',
  'CLOUDFLARE_API_TOKEN': 'cf-secret-token',
};
const _anthropic = {'ANTHROPIC_API_KEY': 'sk-ant-secret'};

http.Response _workersAiOk(String text) => http.Response(
  jsonEncode({
    'success': true,
    'result': {'response': text},
    'errors': <Object>[],
  }),
  200,
  headers: {'content-type': 'application/json'},
);

http.Response _anthropicOk(String text, {String stop = 'end_turn'}) =>
    http.Response(
      jsonEncode({
        'content': [
          {'type': 'text', 'text': text},
        ],
        'stop_reason': stop,
      }),
      200,
      headers: {'content-type': 'application/json'},
    );

final class _Run {
  _Run(this.code, this.out, this.err, this.requests);

  final int code;
  final String out;
  final String err;

  /// The requests the fake transport received.
  final List<http.Request> requests;

  Map<String, Object?> get body =>
      jsonDecode(requests.single.body) as Map<String, Object?>;
}

/// Runs `puls3` with a fake file system, stdin and model transport. The puls3
/// server is never connected to.
Future<_Run> _puls3(
  List<String> arguments, {
  Map<String, String> files = const {},
  String stdin = '',
  Map<String, String> environment = const {},
  http.Response Function(http.Request)? respond,
  Object? transportError,
}) async {
  final out = StringBuffer();
  final err = StringBuffer();
  final requests = <http.Request>[];
  final code = await runPuls3(
    arguments,
    connect: (url) => fail('run must not open the puls3 server: $url'),
    environment: environment,
    out: out,
    err: err,
    httpClient: MockClient((request) async {
      requests.add(request);
      if (transportError != null) throw transportError;
      return (respond ?? (_) => _workersAiOk('ok'))(request);
    }),
    readFile: (path) async {
      final text = files[path];
      if (text == null) {
        throw FileSystemException('Cannot open file', path);
      }
      return text;
    },
    readStdin: () async => stdin,
  );
  return _Run(code, '$out', '$err', requests);
}

Map<String, String> _withManifest([Map<String, Object?>? manifest]) => {
  'agent.json': jsonEncode(manifest ?? _manifest()),
};

void main() {
  group('run: manifest', () {
    test('a manifest file that does not exist exits 66', () async {
      final run = await _puls3([
        'run',
        '--manifest',
        'nope.json',
        '--input',
        'x',
      ]);

      expect(run.code, ExitCodes.noInput);
      expect(run.err, startsWith('error: ManifestUnreadable: '));
      expect(run.err, contains('nope.json'));
      expect(run.out, isEmpty);
      expect(run.requests, isEmpty);
    });

    test('a manifest that is not JSON exits 65', () async {
      final run = await _puls3(
        ['run', '--manifest', 'agent.json', '--input', 'x'],
        files: {'agent.json': '{not json'},
      );

      expect(run.code, ExitCodes.invalidData);
      expect(run.err, startsWith('error: InvalidManifest: '));
      expect(run.requests, isEmpty);
    });

    test('an invalid manifest lists every broken rule and exits 65', () async {
      final manifest = _manifest()
        ..remove('name')
        ..['system_prompt'] = 'short';
      final run = await _puls3([
        'run',
        '--manifest',
        'agent.json',
        '--input',
        'x',
      ], files: _withManifest(manifest));

      expect(run.code, ExitCodes.invalidData);
      expect(
        run.err,
        startsWith('error: InvalidManifest: invalid agent manifest: '),
      );
      expect(run.err, contains('name is required'));
      expect(run.err, contains('system prompt'));
      expect(run.requests, isEmpty);
    });

    test(
      'a Workers AI model outside the policy is refused like on deploy',
      () async {
        final run = await _puls3(
          ['run', '--manifest', 'agent.json', '--input', 'x'],
          files: _withManifest(_manifest(modelId: '@cf/some/other-model')),
          environment: _cloudflare,
        );

        expect(run.code, ExitCodes.invalidData);
        expect(run.err, startsWith('error: InvalidManifest: '));
        expect(run.requests, isEmpty);
      },
    );

    test('a deployed manifest with schema and version also runs', () async {
      final manifest = _manifest(
        overrides: {'schema': 'puls3.agent-manifest/v1', 'version': 3},
      );
      final run = await _puls3(
        ['run', '--manifest', 'agent.json', '--input', 'x'],
        files: _withManifest(manifest),
        environment: _cloudflare,
      );

      expect(run.code, ExitCodes.ok, reason: run.err);
    });

    test('the manifest can be given as the only positional argument', () async {
      final run = await _puls3(
        ['run', 'agent.json', '--input', 'x'],
        files: _withManifest(),
        environment: _cloudflare,
      );

      expect(run.code, ExitCodes.ok, reason: run.err);
    });

    test('the example manifest in example/ is valid', () async {
      final out = StringBuffer();
      final err = StringBuffer();
      final code = await runPuls3(
        ['run', '--manifest', 'example/soroban_pre_audit.json', '--input', 'x'],
        connect: (url) => fail('no server'),
        environment: _cloudflare,
        out: out,
        err: err,
        httpClient: MockClient((_) async => _workersAiOk('# No findings')),
      );

      expect(code, ExitCodes.ok, reason: '$err');
      expect('$out', '# No findings\n');
    });
  });

  group('run: input', () {
    test('no input is a usage error', () async {
      final run = await _puls3(
        ['run', '--manifest', 'agent.json'],
        files: _withManifest(),
        environment: _cloudflare,
      );

      expect(run.code, ExitCodes.usage);
      expect(run.err, startsWith('error: Usage: '));
      expect(run.requests, isEmpty);
    });

    test('--input and --input-file together are a usage error', () async {
      final run = await _puls3(
        [
          'run',
          '--manifest',
          'agent.json',
          '--input',
          'x',
          '--input-file',
          'in.txt',
        ],
        files: _withManifest(),
        environment: _cloudflare,
      );

      expect(run.code, ExitCodes.usage);
      expect(run.requests, isEmpty);
    });

    test('no manifest is a usage error', () async {
      final run = await _puls3(['run', '--input', 'x']);

      expect(run.code, ExitCodes.usage);
      expect(run.err, startsWith('error: Usage: '));
    });

    test('--input-file reads the input from a file', () async {
      final run = await _puls3(
        ['run', '--manifest', 'agent.json', '--input-file', 'in.txt'],
        files: {..._withManifest(), 'in.txt': 'fn transfer() {}'},
        environment: _cloudflare,
      );

      expect(run.code, ExitCodes.ok, reason: run.err);
      final messages = run.body['messages'] as List;
      expect(messages.last, {'role': 'user', 'content': 'fn transfer() {}'});
    });

    test('an input file that does not exist exits 66', () async {
      final run = await _puls3(
        ['run', '--manifest', 'agent.json', '--input-file', 'missing.txt'],
        files: _withManifest(),
        environment: _cloudflare,
      );

      expect(run.code, ExitCodes.noInput);
      expect(run.err, startsWith('error: InputUnreadable: '));
      expect(run.requests, isEmpty);
    });

    test('`-` reads the input from stdin', () async {
      for (final flag in ['--input', '--input-file']) {
        final run = await _puls3(
          ['run', '--manifest', 'agent.json', flag, '-'],
          files: _withManifest(),
          stdin: 'from stdin',
          environment: _cloudflare,
        );

        expect(run.code, ExitCodes.ok, reason: run.err);
        final messages = run.body['messages'] as List;
        expect(messages.last, {'role': 'user', 'content': 'from stdin'});
      }
    });

    test('input over input.max_chars exits 65 before any model call', () async {
      final run = await _puls3(
        ['run', '--manifest', 'agent.json', '--input', '😀' * 11],
        files: _withManifest(_manifest(inputMaxChars: 10)),
        environment: _cloudflare,
      );

      expect(run.code, ExitCodes.invalidData);
      expect(
        run.err,
        'error: InputTooLong: the input is 11 characters; '
        'the manifest allows 10\n',
      );
      expect(run.requests, isEmpty);
    });

    test('input at input.max_chars, counted in runes, runs', () async {
      final run = await _puls3(
        ['run', '--manifest', 'agent.json', '--input', '😀' * 10],
        files: _withManifest(_manifest(inputMaxChars: 10)),
        environment: _cloudflare,
      );

      expect(run.code, ExitCodes.ok, reason: run.err);
    });
  });

  group('run: credentials', () {
    test('workers-ai without Cloudflare credentials exits 78', () async {
      final run = await _puls3([
        'run',
        '--manifest',
        'agent.json',
        '--input',
        'x',
      ], files: _withManifest());

      expect(run.code, ExitCodes.missingCredential);
      expect(run.err, startsWith('error: MissingCredential: '));
      expect(run.err, contains('CLOUDFLARE_ACCOUNT_ID'));
      expect(run.err, contains('CLOUDFLARE_API_TOKEN'));
      expect(run.out, isEmpty);
      expect(run.requests, isEmpty);
    });

    test(
      'workers-ai with only the account id names the missing token',
      () async {
        final run = await _puls3(
          ['run', '--manifest', 'agent.json', '--input', 'x'],
          files: _withManifest(),
          environment: {
            'CLOUDFLARE_ACCOUNT_ID': 'acct123',
            'CLOUDFLARE_API_TOKEN': ' ',
          },
        );

        expect(run.code, ExitCodes.missingCredential);
        expect(run.err, contains('CLOUDFLARE_API_TOKEN'));
        expect(run.err, isNot(contains('acct123')));
      },
    );

    test('anthropic without ANTHROPIC_API_KEY exits 78', () async {
      final run = await _puls3(
        ['run', '--manifest', 'agent.json', '--input', 'x'],
        files: _withManifest(
          _manifest(provider: 'anthropic', modelId: 'claude-sonnet-5-5'),
        ),
        environment: _cloudflare,
      );

      expect(run.code, ExitCodes.missingCredential);
      expect(run.err, contains('ANTHROPIC_API_KEY'));
      expect(run.requests, isEmpty);
    });
  });

  group('run: request', () {
    test('workers-ai posts the system prompt, input and max_tokens', () async {
      final run = await _puls3(
        ['run', '--manifest', 'agent.json', '--input', 'fn a() {}'],
        files: _withManifest(),
        environment: _cloudflare,
      );

      expect(run.code, ExitCodes.ok, reason: run.err);
      final request = run.requests.single;
      expect(request.method, 'POST');
      expect(
        request.url.toString(),
        'https://api.cloudflare.com/client/v4/accounts/acct123/ai/run/'
        '@cf/meta/llama-3.3-70b-instruct-fp8-fast',
      );
      expect(request.headers['authorization'], 'Bearer cf-secret-token');
      expect(run.body, {
        'messages': [
          {
            'role': 'system',
            'content': 'You are a Soroban security reviewer. Find the bugs.',
          },
          {'role': 'user', 'content': 'fn a() {}'},
        ],
        'max_tokens': 4096,
      });
    });

    test(
      'workers-ai max_tokens is output.max_chars below the ceiling',
      () async {
        final run = await _puls3(
          ['run', '--manifest', 'agent.json', '--input', 'x'],
          files: _withManifest(_manifest(outputMaxChars: 500)),
          environment: _cloudflare,
        );

        expect(run.body['max_tokens'], 500);
      },
    );

    test('anthropic posts to the Messages API with the key header', () async {
      final run = await _puls3(
        ['run', '--manifest', 'agent.json', '--input', 'fn a() {}'],
        files: _withManifest(
          _manifest(
            provider: 'anthropic',
            modelId: 'claude-haiku-4-5',
            outputMaxChars: 2000,
          ),
        ),
        environment: _anthropic,
        respond: (_) => _anthropicOk('All good.'),
      );

      expect(run.code, ExitCodes.ok, reason: run.err);
      final request = run.requests.single;
      expect(request.url.toString(), 'https://api.anthropic.com/v1/messages');
      expect(request.headers['x-api-key'], 'sk-ant-secret');
      expect(request.headers['anthropic-version'], '2023-06-01');
      expect(run.body, {
        'model': 'claude-haiku-4-5',
        'max_tokens': 6000,
        'system': 'You are a Soroban security reviewer. Find the bugs.',
        'messages': [
          {'role': 'user', 'content': 'fn a() {}'},
        ],
      });
      expect(run.out, 'All good.\n');
    });
  });

  group('run: output', () {
    test('prints the model output to stdout', () async {
      final run = await _puls3(
        ['run', '--manifest', 'agent.json', '--input', 'x'],
        files: _withManifest(),
        environment: _cloudflare,
        respond: (_) => _workersAiOk('## Findings\n\nNone.'),
      );

      expect(run.code, ExitCodes.ok);
      expect(run.out, '## Findings\n\nNone.\n');
      expect(run.err, isEmpty);
    });

    test('--json prints output, model, lengths and elapsed time', () async {
      final run = await _puls3(
        ['run', '--manifest', 'agent.json', '--input', 'abc', '--json'],
        files: _withManifest(),
        environment: _cloudflare,
        respond: (_) => _workersAiOk('😀 ok'),
      );

      expect(run.code, ExitCodes.ok, reason: run.err);
      final json = jsonDecode(run.out) as Map<String, Object?>;
      expect(json.keys, [
        'output',
        'model',
        'inputChars',
        'outputChars',
        'elapsedMs',
      ]);
      expect(json['output'], '😀 ok');
      expect(
        json['model'],
        'workers-ai/@cf/meta/llama-3.3-70b-instruct-fp8-fast',
      );
      expect(json['inputChars'], 3);
      expect(json['outputChars'], 4);
      expect(json['elapsedMs'], isA<int>());
    });

    test('the global --json flag works too', () async {
      final run = await _puls3(
        ['--json', 'run', '--manifest', 'agent.json', '--input', 'x'],
        files: _withManifest(),
        environment: _cloudflare,
      );

      expect(jsonDecode(run.out), containsPair('output', 'ok'));
    });

    test('output over output.max_chars exits 1 and prints nothing', () async {
      final run = await _puls3(
        ['run', '--manifest', 'agent.json', '--input', 'x'],
        files: _withManifest(_manifest(outputMaxChars: 3)),
        environment: _cloudflare,
        respond: (_) => _workersAiOk('four'),
      );

      expect(run.code, ExitCodes.serverError);
      expect(
        run.err,
        'error: OutputTooLong: the output is 4 characters; '
        'the manifest allows 3\n',
      );
      expect(run.out, isEmpty);
    });

    test('a blank output exits 1', () async {
      final run = await _puls3(
        ['run', '--manifest', 'agent.json', '--input', 'x'],
        files: _withManifest(),
        environment: _cloudflare,
        respond: (_) => _workersAiOk('  \n'),
      );

      expect(run.code, ExitCodes.serverError);
      expect(run.err, startsWith('error: EmptyOutput: '));
    });
  });

  group('run: provider failures', () {
    test('an HTTP error exits 1 without the body or the credential', () async {
      final run = await _puls3(
        ['run', '--manifest', 'agent.json', '--input', 'x'],
        files: _withManifest(),
        environment: _cloudflare,
        respond: (_) => http.Response(
          jsonEncode({
            'success': false,
            'errors': [
              {
                'code': 10000,
                'message': 'Authentication error cf-secret-token',
              },
            ],
          }),
          401,
        ),
      );

      expect(run.code, ExitCodes.serverError);
      expect(
        run.err,
        'error: ProviderError: workers-ai answered HTTP 401 (cloudflare_10000)\n',
      );
      expect(run.err, isNot(contains('cf-secret-token')));
    });

    test('an anthropic refusal exits 1', () async {
      final run = await _puls3(
        ['run', '--manifest', 'agent.json', '--input', 'x'],
        files: _withManifest(
          _manifest(provider: 'anthropic', modelId: 'claude-haiku-4-5'),
        ),
        environment: _anthropic,
        respond: (_) => _anthropicOk('', stop: 'refusal'),
      );

      expect(run.code, ExitCodes.serverError);
      expect(run.err, startsWith('error: Refused: '));
    });

    test('an anthropic max_tokens stop exits 1 as truncated', () async {
      final run = await _puls3(
        ['run', '--manifest', 'agent.json', '--input', 'x'],
        files: _withManifest(
          _manifest(provider: 'anthropic', modelId: 'claude-haiku-4-5'),
        ),
        environment: _anthropic,
        respond: (_) => _anthropicOk('partial', stop: 'max_tokens'),
      );

      expect(run.code, ExitCodes.serverError);
      expect(run.err, startsWith('error: OutputTruncated: '));
    });

    test('a malformed 200 answer exits 1', () async {
      final run = await _puls3(
        ['run', '--manifest', 'agent.json', '--input', 'x'],
        files: _withManifest(),
        environment: _cloudflare,
        respond: (_) => http.Response('<html>', 200),
      );

      expect(run.code, ExitCodes.serverError);
      expect(
        run.err,
        'error: ProviderError: workers-ai answered HTTP 200 (malformed_response)\n',
      );
    });

    test('an unreachable provider exits 69', () async {
      final run = await _puls3(
        ['run', '--manifest', 'agent.json', '--input', 'x'],
        files: _withManifest(),
        environment: _cloudflare,
        transportError: const SocketException('Failed host lookup'),
      );

      expect(run.code, ExitCodes.unavailable);
      expect(run.err, startsWith('error: Unreachable: workers-ai'));
    });
  });
}
