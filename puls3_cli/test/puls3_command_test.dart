import 'dart:convert';
import 'dart:io';

import 'package:puls3_cli/puls3_cli.dart';
import 'package:puls3_client/puls3_client.dart'
    show Hire, ServerpodClientNetworkException;
import 'package:puls3_sdk/puls3_sdk.dart';
import 'package:puls3_sdk/src/puls3_sdk.dart' show normalizeApiUrl;
import 'package:test/test.dart';

AgentSummary _agent(String id, int registryId, {int price = 5000000}) =>
    AgentSummary(
      id: id,
      registryId: registryId,
      name: 'Agent $id',
      description: 'Summarizes text.',
      skills: const ['summarize', 'translate'],
      priceUsdcStroops: price,
      wallet: null,
      model: 'llama-3.1-8b',
      rating: 4.5,
      paidHireCount: 3,
    );

final class _FakeCatalog implements CatalogApi {
  _FakeCatalog({this.agents = const [], this.error});

  final List<AgentSummary> agents;
  final Object? error;

  @override
  Future<List<AgentSummary>> list() async {
    if (error != null) throw error!;
    return agents;
  }

  @override
  Future<AgentSummary?> get(String id) async {
    if (error != null) throw error!;
    for (final agent in agents) {
      if (agent.id == id) return agent;
    }
    return null;
  }
}

const _wallet = 'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H';

PreparedTransaction _prepared(String purpose) => PreparedTransaction(
  preparationId: 'prep-1',
  purpose: purpose,
  signer: _wallet,
  networkPassphrase: 'Test SDF Network ; September 2015',
  unsignedTransactionXdr: 'AAAAunsigned',
  expiresAt: DateTime.utc(2026, 11, 11, 12),
);

/// The session-bound hire calls, recorded. It never signs or submits.
final class _FakeHire implements HireApi {
  _FakeHire({this.error});

  final Object? error;
  final calls = <String>[];

  @override
  Future<HireDetail> get(int hireId, String consumer) async {
    calls.add('get $hireId $consumer');
    if (error != null) throw error!;
    return HireDetail(
      hire: Hire(
        id: hireId,
        agentId: 7,
        consumer: consumer,
        price: 5000000,
        manifestVersion: 1,
        status: 'submitted',
      ),
      agent: _agent('agt-001', 7),
      input: 'summarise this',
      result: 'a summary',
      jobId: 34,
      approvalDeadline: DateTime.utc(2026, 11, 12),
    );
  }

  @override
  Future<PreparedTransaction> prepareComplete(int hireId) async {
    calls.add('complete $hireId');
    if (error != null) throw error!;
    return _prepared('complete');
  }

  @override
  Future<PreparedTransaction> prepareReject(int hireId, String reason) async {
    calls.add('reject $hireId $reason');
    if (error != null) throw error!;
    return _prepared('reject');
  }
}

final class _FakeStudio implements StudioApi {
  _FakeStudio({this.error});

  final Object? error;
  final calls = <String>[];

  @override
  Future<TestRunResult> testRun(int draftId, String input) async {
    calls.add('$draftId $input');
    if (error != null) throw error!;
    return TestRunResult(output: 'model says: $input', remainingDailyRuns: 1);
  }
}

/// One run of `puls3` against a fake catalog.
final class _Run {
  _Run(this.code, this.out, this.err, this.connectedTo);

  final int code;
  final String out;
  final String err;

  /// The URLs the command opened, as the real client would receive them.
  final List<String> connectedTo;
}

/// Runs `puls3` on fakes. [hire] and [studio] stand for a session: without
/// them the SDK has none, as the binary has until #259.
Future<_Run> _puls3(
  List<String> arguments, {
  _FakeCatalog? catalog,
  _FakeHire? hire,
  _FakeStudio? studio,
  Map<String, String> environment = const {},
}) async {
  final out = StringBuffer();
  final err = StringBuffer();
  final connectedTo = <String>[];
  final code = await runPuls3(
    arguments,
    connect: (url) {
      // Same check as Puls3Sdk.connect, without a network client.
      connectedTo.add(normalizeApiUrl(url));
      return Puls3Sdk.withApi(
        catalog: catalog ?? _FakeCatalog(),
        hire: hire,
        studio: studio,
      );
    },
    environment: environment,
    out: out,
    err: err,
  );
  return _Run(code, '$out', '$err', connectedTo);
}

const _api = ['--api', 'https://api.puls3.test'];

void main() {
  group('catalog list', () {
    test('prints one line per agent on stdout', () async {
      final run = await _puls3(
        [..._api, 'catalog', 'list'],
        catalog: _FakeCatalog(
          agents: [_agent('agt-001', 1), _agent('agt-002', 2, price: 1)],
        ),
      );
      expect(run.code, ExitCodes.ok);
      expect(run.err, isEmpty);
      final lines = const LineSplitter().convert(run.out);
      expect(lines.first, '2 agents');
      expect(lines[1], contains('agt-001'));
      expect(lines[1], contains('#1'));
      expect(lines[1], contains('0.50 USDC'));
      expect(lines[1], contains('Agent agt-001'));
      expect(lines[2], contains('0.0000001 USDC'));
      expect(run.connectedTo, ['https://api.puls3.test/']);
    });

    test('--json prints the agents as a JSON array', () async {
      final run = await _puls3(
        [..._api, '--json', 'catalog', 'list'],
        catalog: _FakeCatalog(agents: [_agent('agt-001', 1)]),
      );
      expect(run.code, ExitCodes.ok);
      final decoded = jsonDecode(run.out) as List<Object?>;
      expect(decoded, [
        {
          'id': 'agt-001',
          'registryId': 1,
          'name': 'Agent agt-001',
          'description': 'Summarizes text.',
          'skills': ['summarize', 'translate'],
          'priceUsdcStroops': 5000000,
          'wallet': null,
          'model': 'llama-3.1-8b',
          'rating': 4.5,
          'paidHireCount': 3,
        },
      ]);
    });

    test('an empty catalog says so', () async {
      final run = await _puls3([..._api, 'catalog', 'list']);
      expect(run.code, ExitCodes.ok);
      expect(run.out.trim(), '0 agents');
    });

    test('an extra argument is a usage error', () async {
      final run = await _puls3([..._api, 'catalog', 'list', 'agt-001']);
      expect(run.code, ExitCodes.usage);
      expect(run.out, isEmpty);
      expect(run.connectedTo, isEmpty);
    });
  });

  group('catalog get', () {
    test('prints the agent', () async {
      final run = await _puls3(
        [..._api, 'catalog', 'get', 'agt-001'],
        catalog: _FakeCatalog(agents: [_agent('agt-001', 7)]),
      );
      expect(run.code, ExitCodes.ok);
      expect(run.err, isEmpty);
      expect(run.out, startsWith('agt-001  Agent agt-001\n'));
      expect(run.out, contains('registry id  7\n'));
      expect(run.out, contains('rating       4.5 (3 paid hires)\n'));
      expect(run.out, contains('skills       summarize, translate\n'));
      expect(run.out, contains('wallet       -\n'));
      expect(run.out.trimRight(), endsWith('Summarizes text.'));
    });

    test('--json prints one object', () async {
      final run = await _puls3(
        [..._api, '--json', 'catalog', 'get', 'agt-001'],
        catalog: _FakeCatalog(agents: [_agent('agt-001', 7)]),
      );
      expect(run.code, ExitCodes.ok);
      expect((jsonDecode(run.out) as Map)['registryId'], 7);
    });

    test('an unknown id exits 3 with NotFound on stderr only', () async {
      final run = await _puls3([..._api, 'catalog', 'get', 'agt-999']);
      expect(run.code, ExitCodes.notFound);
      expect(run.out, isEmpty);
      expect(run.err.trim(), 'error: NotFound: no agent with id agt-999');
    });

    for (final rest in [
      <String>[],
      ['agt-001', 'agt-002'],
      ['  '],
    ]) {
      test('$rest is a usage error without calling the server', () async {
        final run = await _puls3([..._api, 'catalog', 'get', ...rest]);
        expect(run.code, ExitCodes.usage);
        expect(run.out, isEmpty);
        expect(run.err, startsWith('error: Usage: '));
        expect(run.connectedTo, isEmpty);
      });
    }
  });

  group('server errors', () {
    test('a Puls3ApiException exits 1 with its code on stderr', () async {
      final run = await _puls3(
        [..._api, 'catalog', 'list'],
        catalog: _FakeCatalog(
          error: Puls3ApiException(code: 'RateLimited', message: 'slow down'),
        ),
      );
      expect(run.code, ExitCodes.serverError);
      expect(run.out, isEmpty);
      expect(run.err.trim(), 'error: RateLimited: slow down');
    });

    test('a catalog outage exits 69, never an empty list', () async {
      final run = await _puls3(
        [..._api, 'catalog', 'list'],
        catalog: _FakeCatalog(
          error: AgentCatalogUnavailable(message: 'registry unreachable'),
        ),
      );
      expect(run.code, ExitCodes.unavailable);
      expect(run.out, isEmpty);
      expect(
        run.err.trim(),
        'error: AgentCatalogUnavailable: registry unreachable',
      );
    });

    test('an unreachable server exits 69 and names the URL', () async {
      final run = await _puls3(
        [..._api, 'catalog', 'get', 'agt-001'],
        catalog: _FakeCatalog(
          error: const ServerpodClientNetworkException('connection refused'),
        ),
      );
      expect(run.code, ExitCodes.unavailable);
      expect(run.out, isEmpty);
      expect(
        run.err.trim(),
        'error: Unreachable: https://api.puls3.test: connection refused',
      );
    });

    test('a TLS handshake failure exits 69 without a stack trace', () async {
      final run = await _puls3(
        [..._api, 'catalog', 'list'],
        catalog: _FakeCatalog(
          error: const HandshakeException(
            'Handshake error in client',
            OSError('CERTIFICATE_VERIFY_FAILED: self signed certificate'),
          ),
        ),
      );
      expect(run.code, ExitCodes.unavailable);
      expect(run.out, isEmpty);
      expect(
        run.err.trim(),
        'error: Unreachable: https://api.puls3.test: Handshake error in '
        'client: CERTIFICATE_VERIFY_FAILED: self signed certificate',
      );
    });

    test('a socket error exits 69', () async {
      final run = await _puls3(
        [..._api, 'catalog', 'list'],
        catalog: _FakeCatalog(
          error: const SocketException('Failed host lookup: api.puls3.test'),
        ),
      );
      expect(run.code, ExitCodes.unavailable);
      expect(
        run.err.trim(),
        'error: Unreachable: https://api.puls3.test: Failed host lookup: '
        'api.puls3.test',
      );
    });
  });

  group('API URL', () {
    test('falls back to PULS3_API_URL', () async {
      final run = await _puls3(
        ['catalog', 'list'],
        environment: {apiUrlVariable: ' http://localhost:8080 '},
      );
      expect(run.code, ExitCodes.ok);
      expect(run.connectedTo, ['http://localhost:8080/']);
    });

    test('--api wins over PULS3_API_URL', () async {
      final run = await _puls3(
        [..._api, 'catalog', 'list'],
        environment: {apiUrlVariable: 'http://localhost:8080'},
      );
      expect(run.connectedTo, ['https://api.puls3.test/']);
    });

    test('no URL is a usage error that names the variable', () async {
      final run = await _puls3(['catalog', 'list']);
      expect(run.code, ExitCodes.usage);
      expect(run.err, contains(apiUrlVariable));
      expect(run.connectedTo, isEmpty);
    });

    test('a relative or non-http URL is a usage error', () async {
      for (final url in ['api.puls3.test', 'ftp://api.puls3.test']) {
        final run = await _puls3(['--api', url, 'catalog', 'list']);
        expect(run.code, ExitCodes.usage, reason: url);
        expect(run.err, contains('absolute http or https'), reason: url);
      }
    });
  });

  group('usage', () {
    for (final arguments in [
      ['--help'],
      ['catalog', '--help'],
      ['catalog', 'get', '-h'],
    ]) {
      test('$arguments prints the usage on stdout and exits 0', () async {
        final run = await _puls3(arguments);
        expect(run.code, ExitCodes.ok);
        expect(run.err, isEmpty);
        expect(run.out, contains('catalog get <id>'));
        expect(run.out, contains('never signs'));
        expect(run.connectedTo, isEmpty);
      });
    }

    for (final arguments in [
      <String>[],
      ['catalog'],
      ['hire', 'list'],
      ['catalog', 'delete'],
      ['foo'],
      ['--nope', 'catalog', 'list'],
    ]) {
      test('$arguments is a usage error on stderr', () async {
        final run = await _puls3([..._api, ...arguments]);
        expect(run.code, ExitCodes.usage);
        expect(run.out, isEmpty);
        expect(run.err, startsWith('error: Usage: '));
        expect(run.err, contains('Usage: puls3'));
        expect(run.connectedTo, isEmpty);
      });
    }
  });

  group('hire get', () {
    test('prints the hire of the session wallet', () async {
      final hire = _FakeHire();
      final run = await _puls3([
        ..._api,
        'hire',
        'get',
        '12',
        '--wallet',
        _wallet,
      ], hire: hire, studio: _FakeStudio());
      expect(run.code, ExitCodes.ok);
      expect(run.err, isEmpty);
      expect(hire.calls, ['get 12 $_wallet']);
      final lines = const LineSplitter().convert(run.out);
      expect(lines.first, 'hire 12  submitted');
      expect(run.out, contains('agt-001  Agent agt-001'));
      expect(run.out, contains('0.50 USDC'));
      expect(run.out, contains('job id       34'));
      expect(run.out, contains('approve by   2026-11-12T00:00:00.000Z'));
      expect(run.out, contains('a summary'));
    });

    test('takes the wallet from PULS3_WALLET', () async {
      final hire = _FakeHire();
      final run = await _puls3(
        [..._api, 'hire', 'get', '12'],
        hire: hire,
        studio: _FakeStudio(),
        environment: {walletVariable: _wallet},
      );
      expect(run.code, ExitCodes.ok);
      expect(hire.calls, ['get 12 $_wallet']);
    });

    test('--json prints fixed fields', () async {
      final run = await _puls3([
        ..._api,
        '--json',
        'hire',
        'get',
        '12',
        '--wallet',
        _wallet,
      ], hire: _FakeHire(), studio: _FakeStudio());
      final decoded = jsonDecode(run.out) as Map<String, Object?>;
      expect(decoded['id'], 12);
      expect(decoded['status'], 'submitted');
      expect(decoded['agentId'], 'agt-001');
      expect(decoded['consumer'], _wallet);
      expect(decoded['priceUsdcStroops'], 5000000);
      expect(decoded['jobId'], 34);
      expect(decoded['approvalDeadline'], '2026-11-12T00:00:00.000Z');
      expect(decoded['result'], 'a summary');
    });

    for (final arguments in [
      ['hire', 'get'],
      ['hire', 'get', '0'],
      ['hire', 'get', 'abc'],
      ['hire', 'get', '1', '2'],
      ['hire', 'get', '1'], // no wallet
    ]) {
      test('$arguments is a usage error without calling the server', () async {
        final hire = _FakeHire();
        final run = await _puls3([
          ..._api,
          ...arguments,
        ], hire: hire, studio: _FakeStudio());
        expect(run.code, ExitCodes.usage);
        expect(run.out, isEmpty);
        expect(hire.calls, isEmpty);
        expect(run.connectedTo, isEmpty);
      });
    }
  });

  group('hire prepare-complete and prepare-reject', () {
    test('prepare-complete prints the unsigned envelope and nothing else '
        'happens', () async {
      final hire = _FakeHire();
      final run = await _puls3([
        ..._api,
        'hire',
        'prepare-complete',
        '12',
      ], hire: hire, studio: _FakeStudio());
      expect(run.code, ExitCodes.ok);
      expect(run.err, isEmpty);
      // One prepare call: the CLI has no way to sign or submit.
      expect(hire.calls, ['complete 12']);
      expect(run.out, contains('purpose      complete'));
      expect(run.out, contains('signer       $_wallet'));
      expect(run.out, contains('not signed, not submitted'));
      expect(const LineSplitter().convert(run.out).last, 'AAAAunsigned');
    });

    test('prepare-reject passes the reason', () async {
      final hire = _FakeHire();
      final run = await _puls3([
        ..._api,
        'hire',
        'prepare-reject',
        '12',
        '--reason',
        'wrong language',
      ], hire: hire, studio: _FakeStudio());
      expect(run.code, ExitCodes.ok);
      expect(hire.calls, ['reject 12 wrong language']);
      expect(run.out, contains('purpose      reject'));
    });

    test('--json prints the envelope fields', () async {
      final run = await _puls3([
        ..._api,
        '--json',
        'hire',
        'prepare-complete',
        '12',
      ], hire: _FakeHire(), studio: _FakeStudio());
      expect(jsonDecode(run.out), {
        'preparationId': 'prep-1',
        'purpose': 'complete',
        'signer': _wallet,
        'networkPassphrase': 'Test SDF Network ; September 2015',
        'unsignedTransactionXdr': 'AAAAunsigned',
        'expiresAt': '2026-11-11T12:00:00.000Z',
      });
    });

    test('prepare-reject without --reason is a usage error', () async {
      final hire = _FakeHire();
      final run = await _puls3([
        ..._api,
        'hire',
        'prepare-reject',
        '12',
      ], hire: hire, studio: _FakeStudio());
      expect(run.code, ExitCodes.usage);
      expect(hire.calls, isEmpty);
    });

    test('a server error code goes to stderr with exit 1', () async {
      final run = await _puls3(
        [..._api, 'hire', 'prepare-complete', '12'],
        hire: _FakeHire(
          error: Puls3ApiException(
            code: 'InvalidHireTransition',
            message: 'the hire is funded',
          ),
        ),
        studio: _FakeStudio(),
      );
      expect(run.code, ExitCodes.serverError);
      expect(run.out, isEmpty);
      expect(
        run.err.trim(),
        'error: InvalidHireTransition: the hire is funded',
      );
    });
  });

  group('studio test-run', () {
    test('prints the model output and the runs left', () async {
      final studio = _FakeStudio();
      final run = await _puls3([
        ..._api,
        'studio',
        'test-run',
        '--draft',
        '3',
        '--input',
        'hello',
      ], hire: _FakeHire(), studio: studio);
      expect(run.code, ExitCodes.ok);
      expect(studio.calls, ['3 hello']);
      final lines = const LineSplitter().convert(run.out);
      expect(lines.first, 'model says: hello');
      expect(lines.last, '1 test run left today');
    });

    test('a missing provider credential is the server code', () async {
      final run = await _puls3(
        [..._api, 'studio', 'test-run', '--draft', '3', '--input', 'hi'],
        hire: _FakeHire(),
        studio: _FakeStudio(
          error: Puls3ApiException(
            code: 'RuntimeUnavailable',
            message: 'no provider credential',
          ),
        ),
      );
      expect(run.code, ExitCodes.serverError);
      expect(run.out, isEmpty);
      expect(run.err, startsWith('error: RuntimeUnavailable: '));
    });

    for (final arguments in [
      ['studio', 'test-run', '--input', 'hi'],
      ['studio', 'test-run', '--draft', 'x', '--input', 'hi'],
      ['studio', 'test-run', '--draft', '3'],
      ['studio', 'test-run', '--draft', '3', '--input', '  '],
      ['studio', 'test-run', '--draft', '3', '--input', 'hi', 'extra'],
    ]) {
      test('$arguments is a usage error without calling the server', () async {
        final studio = _FakeStudio();
        final run = await _puls3([
          ..._api,
          ...arguments,
        ], hire: _FakeHire(), studio: studio);
        expect(run.code, ExitCodes.usage);
        expect(studio.calls, isEmpty);
      });
    }
  });

  group('session', () {
    for (final arguments in [
      ['hire', 'get', '12', '--wallet', _wallet],
      ['hire', 'prepare-complete', '12'],
      ['hire', 'prepare-reject', '12', '--reason', 'no'],
      ['studio', 'test-run', '--draft', '3', '--input', 'hi'],
    ]) {
      test('$arguments without a session exits 77 and sends nothing', () async {
        final run = await _puls3([..._api, ...arguments]);
        expect(run.code, ExitCodes.noSession);
        expect(run.out, isEmpty);
        expect(run.err, startsWith('error: SessionRequired: '));
        expect(run.err, contains('#259'));
      });
    }

    test('a refused session exits 77', () async {
      final run = await _puls3(
        [..._api, 'hire', 'prepare-complete', '12'],
        hire: _FakeHire(error: ServerpodClientUnauthorized()),
        studio: _FakeStudio(),
      );
      expect(run.code, ExitCodes.noSession);
      expect(run.out, isEmpty);
      expect(run.err, startsWith('error: Unauthorized: '));
    });

    test('the catalog needs no session', () async {
      final run = await _puls3([..._api, 'catalog', 'list']);
      expect(run.code, ExitCodes.ok);
    });
  });

  group('formatUsdc, from puls3_sdk, as the CLI prints prices', () {
    test('keeps two decimals and drops trailing zeros past them', () {
      expect(formatUsdc(0), '0.00');
      expect(formatUsdc(5000000), '0.50');
      expect(formatUsdc(10000000), '1.00');
      expect(formatUsdc(12345678), '1.2345678');
      expect(formatUsdc(1), '0.0000001');
      expect(formatUsdc(-2500000), '-0.25');
    });
  });

  test('the package imports neither the server nor Flutter', () {
    final sources = [
      ...Directory('lib').listSync(recursive: true),
      ...Directory('bin').listSync(recursive: true),
    ].whereType<File>().where((f) => f.path.endsWith('.dart'));
    for (final file in sources) {
      final text = file.readAsStringSync();
      expect(text, isNot(contains('package:puls3_server')), reason: file.path);
      expect(text, isNot(contains('package:flutter')), reason: file.path);
    }
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, isNot(contains('puls3_server')));
    expect(pubspec, isNot(contains('flutter')));
  });
}
