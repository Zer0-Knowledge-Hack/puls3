import 'dart:convert';
import 'dart:io';

import 'package:dart_mcp/client.dart';
import 'package:puls3_client/puls3_client.dart'
    show ServerpodClientNetworkException;
import 'package:puls3_mcp/puls3_mcp.dart';
import 'package:puls3_sdk/puls3_sdk.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

AgentSummary _agent(String id, int registryId, {int price = 5000000}) =>
    AgentSummary(
      id: id,
      registryId: registryId,
      name: 'Agent $id',
      description: 'Summarizes text.',
      skills: const ['summarize'],
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
  final calls = <String>[];

  @override
  Future<List<AgentSummary>> list() async {
    calls.add('list');
    if (error != null) throw error!;
    return agents;
  }

  @override
  Future<AgentSummary?> get(String id) async {
    calls.add('get $id');
    if (error != null) throw error!;
    for (final agent in agents) {
      if (agent.id == id) return agent;
    }
    return null;
  }
}

/// An MCP client connected in memory to a [Puls3McpServer] over [catalog].
final class _Session {
  _Session._(this.client, this.server);

  final ServerConnection client;
  final Puls3McpServer server;

  static Future<_Session> start(
    _FakeCatalog catalog, {
    String apiUrl = 'https://api.puls3.test/',
  }) async {
    final channels = StreamChannelController<String>();
    final server = Puls3McpServer(
      channels.local,
      sdk: Puls3Sdk.withApi(catalog: catalog),
      apiUrl: apiUrl,
    );
    final client = MCPClient(
      Implementation(name: 'test client', version: '0.0.1'),
    ).connectServer(channels.foreign);
    final init = await client.initialize(
      InitializeRequest(
        protocolVersion: ProtocolVersion.latestSupported,
        capabilities: ClientCapabilities(),
        clientInfo: Implementation(name: 'test client', version: '0.0.1'),
      ),
    );
    expect(init.capabilities.tools, isNotNull);
    client.notifyInitialized();
    return _Session._(client, server);
  }

  Future<CallToolResult> call(String name, [Map<String, Object?>? args]) =>
      client.callTool(CallToolRequest(name: name, arguments: args));

  Future<void> close() => client.shutdown();
}

String _text(CallToolResult result) =>
    result.content.map((c) => (c as TextContent).text).join('\n');

void main() {
  late _FakeCatalog catalog;
  late _Session session;

  Future<void> start(_FakeCatalog fake, {String? apiUrl}) async {
    catalog = fake;
    session = apiUrl == null
        ? await _Session.start(fake)
        : await _Session.start(fake, apiUrl: apiUrl);
  }

  tearDown(() => session.close());

  test('lists the six tools and no others', () async {
    await start(_FakeCatalog());
    final tools = await session.client.listTools(ListToolsRequest());
    expect([for (final tool in tools.tools) tool.name], toolNames);
    expect(toolNames, [
      'catalog_list',
      'catalog_get',
      'hire_get',
      'hire_prepare_complete',
      'hire_prepare_reject',
      'studio_test_run',
    ]);
  });

  group('catalog_list', () {
    test('returns the agents of the SDK as JSON', () async {
      await start(
        _FakeCatalog(agents: [_agent('agt-001', 7), _agent('agt-002', 8)]),
      );
      final result = await session.call('catalog_list');
      expect(result.isError, isNot(true));
      final agents = jsonDecode(_text(result)) as List<Object?>;
      expect(agents, hasLength(2));
      expect(agents.first, {
        'id': 'agt-001',
        'registryId': 7,
        'name': 'Agent agt-001',
        'description': 'Summarizes text.',
        'skills': ['summarize'],
        'priceUsdcStroops': 5000000,
        'priceUsdc': '0.50',
        'wallet': null,
        'model': 'llama-3.1-8b',
        'rating': 4.5,
        'paidHireCount': 3,
      });
      expect(catalog.calls, ['list']);
    });

    test('a catalog outage is an error, never an empty list', () async {
      await start(
        _FakeCatalog(
          error: AgentCatalogUnavailable(message: 'registry unreachable'),
        ),
      );
      final result = await session.call('catalog_list');
      expect(result.isError, isTrue);
      expect(
        _text(result),
        'error: AgentCatalogUnavailable: registry unreachable',
      );
    });

    test(
      'an unreachable server names the URL, without a stack trace',
      () async {
        await start(
          _FakeCatalog(
            error: const ServerpodClientNetworkException('connection refused'),
          ),
        );
        final result = await session.call('catalog_list');
        expect(result.isError, isTrue);
        expect(
          _text(result),
          'error: Unreachable: https://api.puls3.test/: connection refused',
        );
      },
    );

    test('any other failure is Internal, without a stack trace', () async {
      await start(_FakeCatalog(error: StateError('client is closed')));
      final result = await session.call('catalog_list');
      expect(result.isError, isTrue);
      expect(
        _text(result),
        'error: Internal: unexpected StateError; see the server log',
      );
    });

    test('the URL in an error never carries user info', () async {
      await start(
        _FakeCatalog(
          error: const ServerpodClientNetworkException('connection refused'),
        ),
        apiUrl: 'https://user:s3cret@api.puls3.test/',
      );
      final result = await session.call('catalog_list');
      expect(
        _text(result),
        'error: Unreachable: https://api.puls3.test/: connection refused',
      );
    });

    test('a server error keeps its code', () async {
      await start(
        _FakeCatalog(
          error: Puls3ApiException(code: 'RateLimited', message: 'slow down'),
        ),
      );
      final result = await session.call('catalog_list');
      expect(_text(result), 'error: RateLimited: slow down');
    });
  });

  group('catalog_get', () {
    test('returns one agent', () async {
      await start(_FakeCatalog(agents: [_agent('agt-007', 13)]));
      final result = await session.call('catalog_get', {'id': ' agt-007 '});
      expect(result.isError, isNot(true));
      expect((jsonDecode(_text(result)) as Map)['registryId'], 13);
      expect(catalog.calls, ['get agt-007']);
    });

    test('an unknown id is NotFound', () async {
      await start(_FakeCatalog());
      final result = await session.call('catalog_get', {'id': 'agt-999'});
      expect(result.isError, isTrue);
      expect(_text(result), 'error: NotFound: no agent with id agt-999');
    });

    test(
      'a missing or blank id is refused without calling the server',
      () async {
        await start(_FakeCatalog());
        for (final args in [
          <String, Object?>{},
          {'id': '  '},
        ]) {
          final result = await session.call('catalog_get', args);
          expect(result.isError, isTrue, reason: '$args');
        }
        expect(catalog.calls, isEmpty);
      },
    );
  });

  group('session tools fail closed until #259', () {
    for (final (name, args) in [
      ('hire_get', {'hireId': 3}),
      ('hire_prepare_complete', {'hireId': 3}),
      ('hire_prepare_reject', {'hireId': 3, 'reason': 'wrong output'}),
      ('studio_test_run', {'draftId': 1, 'input': 'hello'}),
    ]) {
      test('$name answers SessionUnavailable and calls nothing', () async {
        await start(_FakeCatalog());
        final result = await session.call(name, args);
        expect(result.isError, isTrue);
        expect(_text(result), 'error: SessionUnavailable: $sessionPending');
        expect(catalog.calls, isEmpty);
      });
    }

    test('studio_test_run without a draft id or an input is refused', () async {
      await start(_FakeCatalog());
      for (final args in [
        <String, Object?>{'input': 'hello'},
        {'draftId': 1},
        <String, Object?>{},
      ]) {
        final result = await session.call('studio_test_run', args);
        expect(result.isError, isTrue, reason: '$args');
        expect(_text(result), isNot(contains('SessionUnavailable')));
      }
    });
  });

  test('a tool name outside the list is refused', () async {
    await start(_FakeCatalog());
    for (final name in ['hire_fund', 'hire_submit', 'sign', 'catalog_delete']) {
      final result = await session.call(name, {});
      expect(result.isError, isTrue, reason: name);
    }
    expect(catalog.calls, isEmpty);
  });

  group('package rules', () {
    // Never tear down a session that was never started.
    setUp(() => start(_FakeCatalog()));

    Iterable<File> sources() => [
      ...Directory('lib').listSync(recursive: true),
      ...Directory('bin').listSync(recursive: true),
    ].whereType<File>().where((f) => f.path.endsWith('.dart'));

    String withoutComments(String text) => text
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');

    test('no tool signs, funds or submits a transaction', () {
      // A call whose name says submit, sign or fund, for example
      // `submitEscrowCall(`, `signTransaction(` or `prepareFund(`.
      final forbidden = RegExp(
        r'\b\w*(submit|sign|fund)\w*\s*\(',
        caseSensitive: false,
      );
      for (final file in sources()) {
        final code = withoutComments(file.readAsStringSync());
        expect(forbidden.hasMatch(code), isFalse, reason: file.path);
      }
    });

    test('imports neither the server, the CLI nor Flutter', () {
      for (final file in sources()) {
        final text = file.readAsStringSync();
        for (final package in ['puls3_server', 'puls3_cli', 'flutter']) {
          expect(text, isNot(contains('package:$package')), reason: file.path);
        }
      }
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('puls3_sdk'));
      // As a dependency key (`puls3_client` is allowed, `puls3_cli` is not).
      for (final package in ['puls3_server', 'puls3_cli', 'flutter']) {
        expect(
          RegExp('^\\s+$package:', multiLine: true).hasMatch(pubspec),
          isFalse,
          reason: package,
        );
      }
    });
  });
}
