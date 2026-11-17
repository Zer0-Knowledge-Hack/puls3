import 'dart:convert';
import 'dart:io';

import 'package:dart_mcp/client.dart';
import 'package:puls3_client/puls3_client.dart'
    show Hire, ServerpodClientNetworkException, ServerpodClientUnauthorized;
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

const _wallet = 'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY';

/// The session calls of a signed-in wallet. Every call is recorded, and
/// [error] is thrown by all of them.
final class _FakeSession implements HireApi, StudioApi {
  _FakeSession({this.error});

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
      input: 'Summarize this.',
      result: 'A summary.',
      jobId: 12,
      expiresAt: DateTime.utc(2026, 11, 20),
      approvalDeadline: DateTime.utc(2026, 11, 19),
    );
  }

  PreparedTransaction _prepared(String purpose) => PreparedTransaction(
    preparationId: 'prep-1',
    purpose: purpose,
    signer: _wallet,
    networkPassphrase: 'Test SDF Network ; September 2015',
    unsignedTransactionXdr: 'AAAAAgAAAAA=',
    expiresAt: DateTime.utc(2026, 11, 17, 4),
  );

  @override
  Future<PreparedTransaction> prepareComplete(int hireId) async {
    calls.add('prepareComplete $hireId');
    if (error != null) throw error!;
    return _prepared('complete');
  }

  @override
  Future<PreparedTransaction> prepareReject(int hireId, String reason) async {
    calls.add('prepareReject $hireId $reason');
    if (error != null) throw error!;
    return _prepared('reject');
  }

  // Not a tool of this server: an agent hiring another agent (#312) stays in
  // the app and the CLI.
  @override
  noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} is not used here');

  @override
  Future<TestRunResult> testRun(int draftId, String input) async {
    calls.add('testRun $draftId $input');
    if (error != null) throw error!;
    return TestRunResult(output: 'ran: $input', remainingDailyRuns: 19);
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
    _FakeSession? signedIn,
    String? wallet,
  }) async {
    final channels = StreamChannelController<String>();
    final server = Puls3McpServer(
      channels.local,
      sdk: Puls3Sdk.withApi(
        catalog: catalog,
        hire: signedIn,
        studio: signedIn,
      ),
      apiUrl: apiUrl,
      wallet: wallet,
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

  const sessionCalls = [
    ('hire_get', {'hireId': 3, 'wallet': _wallet}),
    ('hire_prepare_complete', {'hireId': 3}),
    ('hire_prepare_reject', {'hireId': 3, 'reason': 'wrong output'}),
    ('studio_test_run', {'draftId': 1, 'input': 'hello'}),
  ];

  group('without a session', () {
    for (final (name, args) in sessionCalls) {
      test('$name answers SessionUnavailable and calls nothing', () async {
        await start(_FakeCatalog());
        final result = await session.call(name, args);
        expect(result.isError, isTrue);
        expect(_text(result), 'error: SessionUnavailable: $sessionMissing');
        expect(catalog.calls, isEmpty);
      });
    }

    test('hire_get with no wallet still says the session is missing', () async {
      await start(_FakeCatalog());
      final result = await session.call('hire_get', {'hireId': 3});
      expect(_text(result), startsWith('error: SessionUnavailable:'));
    });

    test('the catalog still works', () async {
      await start(_FakeCatalog(agents: [_agent('agt-001', 7)]));
      final result = await session.call('catalog_list');
      expect(result.isError, isNot(true));
    });

    test('the message says where to get a session, with no issue link', () {
      expect(sessionMissing, contains('Copy session for CLI'));
      expect(sessionMissing, contains('PULS3_REFRESH_TOKEN'));
      expect(sessionMissing, isNot(contains('issues/')));
    });
  });

  group('with a session', () {
    late _FakeSession signedIn;

    Future<void> signIn({Object? error, String? wallet}) async {
      signedIn = _FakeSession(error: error);
      catalog = _FakeCatalog();
      session = await _Session.start(
        catalog,
        signedIn: signedIn,
        wallet: wallet,
      );
    }

    Map<String, Object?> json(CallToolResult result) {
      expect(result.isError, isNot(true), reason: _text(result));
      return jsonDecode(_text(result)) as Map<String, Object?>;
    }

    test('hire_get returns the hire of the wallet in the call', () async {
      await signIn();
      final hire = json(
        await session.call('hire_get', {'hireId': 3, 'wallet': ' $_wallet '}),
      );

      expect(signedIn.calls, ['get 3 $_wallet']);
      expect(hire, {
        'id': 3,
        'status': 'submitted',
        'agentId': 'agt-001',
        'agentName': 'Agent agt-001',
        'consumer': _wallet,
        'priceUsdcStroops': 5000000,
        'priceUsdc': '0.50',
        'jobId': 12,
        'expiresAt': '2026-11-20T00:00:00.000Z',
        'approvalDeadline': '2026-11-19T00:00:00.000Z',
        'input': 'Summarize this.',
        'result': 'A summary.',
        'rejectReason': null,
        'paymentExplorerUrl': null,
      });
    });

    test('hire_get falls back to the wallet of the server', () async {
      await signIn(wallet: _wallet);
      json(await session.call('hire_get', {'hireId': 3}));
      expect(signedIn.calls, ['get 3 $_wallet']);
    });

    test('hire_get with no wallet anywhere is refused', () async {
      await signIn();
      final result = await session.call('hire_get', {'hireId': 3});
      expect(result.isError, isTrue);
      expect(_text(result), contains('error: Usage:'));
      expect(_text(result), contains('PULS3_WALLET'));
      expect(signedIn.calls, isEmpty);
    });

    for (final (tool, args, call, purpose) in [
      (
        'hire_prepare_complete',
        <String, Object?>{'hireId': 3},
        'prepareComplete 3',
        'complete',
      ),
      (
        'hire_prepare_reject',
        <String, Object?>{'hireId': 3, 'reason': ' wrong output '},
        'prepareReject 3 wrong output',
        'reject',
      ),
    ]) {
      test('$tool returns the unsigned envelope and sends nothing', () async {
        await signIn();
        final prepared = json(await session.call(tool, args));

        // One prepare call, and nothing after it.
        expect(signedIn.calls, [call]);
        expect(prepared['purpose'], purpose);
        expect(prepared['preparationId'], 'prep-1');
        expect(prepared['signer'], _wallet);
        expect(prepared['unsignedTransactionXdr'], 'AAAAAgAAAAA=');
        expect(prepared['expiresAt'], '2026-11-17T04:00:00.000Z');
        expect(prepared['submitted'], isFalse);
        expect(prepared['next'], contains('Not signed and not sent'));
      });
    }

    test('hire_prepare_reject needs a reason', () async {
      await signIn();
      for (final args in [
        <String, Object?>{'hireId': 3, 'reason': '  '},
      ]) {
        final result = await session.call('hire_prepare_reject', args);
        expect(result.isError, isTrue);
        expect(_text(result), contains('error: Usage:'));
      }
      expect(signedIn.calls, isEmpty);
    });

    test('a hire id below 1 is refused before the server', () async {
      await signIn(wallet: _wallet);
      for (final tool in ['hire_get', 'hire_prepare_complete']) {
        final result = await session.call(tool, {'hireId': 0});
        expect(result.isError, isTrue, reason: tool);
        expect(_text(result), contains('error: Usage:'), reason: tool);
      }
      expect(signedIn.calls, isEmpty);
    });

    test('studio_test_run returns the output and the runs left', () async {
      await signIn();
      final run = json(
        await session.call('studio_test_run', {'draftId': 4, 'input': 'hi'}),
      );

      expect(signedIn.calls, ['testRun 4 hi']);
      expect(run, {'output': 'ran: hi', 'remainingDailyRuns': 19});
    });

    test('a session the server refuses is SessionExpired', () async {
      await signIn(error: ServerpodClientUnauthorized(), wallet: _wallet);
      for (final (name, args) in sessionCalls) {
        final result = await session.call(name, args);
        expect(result.isError, isTrue, reason: name);
        expect(
          _text(result),
          'error: SessionExpired: $sessionRefused',
          reason: name,
        );
      }
    });

    test('a typed server error keeps its code', () async {
      await signIn(
        error: Puls3ApiException(
          code: 'InvalidHireTransition',
          message: 'The hire is not submitted.',
        ),
      );
      final result = await session.call('hire_prepare_complete', {'hireId': 3});
      expect(
        _text(result),
        'error: InvalidHireTransition: The hire is not submitted.',
      );
    });

    test('an unreachable server is Unreachable, not Internal', () async {
      await signIn(error: const ServerpodClientNetworkException('offline'));
      final result = await session.call('studio_test_run', {
        'draftId': 1,
        'input': 'hello',
      });
      expect(_text(result), startsWith('error: Unreachable:'));
    });

    test('a session file that cannot be written is SessionFile', () async {
      await signIn(
        error: const FileSystemException('Cannot write', '/tmp/session.json'),
      );
      final result = await session.call('hire_prepare_complete', {'hireId': 3});
      expect(
        _text(result),
        'error: SessionFile: Cannot write: /tmp/session.json',
      );
    });

    test('no answer carries a refresh token', () async {
      // The shape of a refresh token (`sajrt:…`), as an error might quote it.
      const token = 'sajrt:aWQ=:Zml4ZWQ=:cm90YXRpbmc=';
      await signIn(error: StateError('refresh failed for $token'));
      for (final (name, args) in sessionCalls) {
        final result = await session.call(name, args);
        expect(result.isError, isTrue, reason: name);
        expect(_text(result), isNot(contains('sajrt:')), reason: name);
        expect(_text(result), startsWith('error: Internal:'), reason: name);
      }
    });

    test('studio_test_run without a draft id or an input is refused', () async {
      await signIn();
      for (final args in [
        <String, Object?>{'input': 'hello'},
        {'draftId': 1},
        <String, Object?>{},
      ]) {
        final result = await session.call('studio_test_run', args);
        expect(result.isError, isTrue, reason: '$args');
      }
      expect(signedIn.calls, isEmpty);
    });
  });

  test('redactedTokens hides refresh and bearer tokens', () {
    expect(
      redactedTokens('failed for sajrt:aWQ=:Zml4ZWQ=:cm90YXRpbmc= at x'),
      'failed for sajrt:[redacted] at x',
    );
    expect(
      redactedTokens('authorization: Bearer eyJhbGciOi.J9.abc-_'),
      'authorization: Bearer [redacted]',
    );
    expect(redactedTokens('nothing secret'), 'nothing secret');
    // Never started in this test: tearDown needs a session.
    return start(_FakeCatalog());
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
