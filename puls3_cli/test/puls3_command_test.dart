import 'dart:convert';
import 'dart:io';

import 'package:puls3_cli/puls3_cli.dart';
import 'package:puls3_client/puls3_client.dart'
    show ServerpodClientNetworkException;
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

/// One run of `puls3` against a fake catalog.
final class _Run {
  _Run(this.code, this.out, this.err, this.connectedTo);

  final int code;
  final String out;
  final String err;

  /// The URLs the command opened, as the real client would receive them.
  final List<String> connectedTo;
}

Future<_Run> _puls3(
  List<String> arguments, {
  _FakeCatalog? catalog,
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
      return Puls3Sdk.withApi(catalog: catalog ?? _FakeCatalog());
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
      ['hire', 'get', '1'],
      ['catalog', 'delete'],
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
