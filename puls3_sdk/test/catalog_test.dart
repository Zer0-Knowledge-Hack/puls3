import 'package:puls3_sdk/puls3_sdk.dart';
import 'package:puls3_sdk/src/puls3_sdk.dart' show normalizeApiUrl;
import 'package:test/test.dart';

AgentSummary _agent(String id, int registryId) => AgentSummary(
  id: id,
  registryId: registryId,
  name: 'Agent $id',
  description: 'Summarizes text.',
  skills: const ['summarize'],
  priceUsdcStroops: 5000000,
  wallet: null,
  model: null,
);

final class _FakeCatalog implements CatalogApi {
  _FakeCatalog({this.agents = const [], this.error});

  final List<AgentSummary> agents;
  final Object? error;
  final gets = <String>[];
  var lists = 0;

  @override
  Future<List<AgentSummary>> list() async {
    lists++;
    if (error != null) throw error!;
    return agents;
  }

  @override
  Future<AgentSummary?> get(String id) async {
    gets.add(id);
    if (error != null) throw error!;
    for (final agent in agents) {
      if (agent.id == id) return agent;
    }
    return null;
  }
}

void main() {
  group('listAgents', () {
    test('returns the catalog as the server sends it', () async {
      final catalog = _FakeCatalog(
        agents: [_agent('agt-001', 1), _agent('agt-002', 2)],
      );
      final agents = await Puls3Sdk.withApi(catalog: catalog).listAgents();
      expect(agents.map((a) => a.id), ['agt-001', 'agt-002']);
      expect(catalog.lists, 1);
    });

    test('an outage is AgentCatalogUnavailable, not an empty list', () async {
      final outage = AgentCatalogUnavailable(message: 'registry unreachable');
      final sdk = Puls3Sdk.withApi(catalog: _FakeCatalog(error: outage));
      await expectLater(sdk.listAgents(), throwsA(same(outage)));
    });

    test('a server error code passes through unchanged', () async {
      final error = Puls3ApiException(code: 'Unauthenticated', message: 'x');
      final sdk = Puls3Sdk.withApi(catalog: _FakeCatalog(error: error));
      await expectLater(sdk.listAgents(), throwsA(same(error)));
    });
  });

  group('getAgent', () {
    test('returns the agent for its metadata id', () async {
      final sdk = Puls3Sdk.withApi(
        catalog: _FakeCatalog(agents: [_agent('agt-001', 1)]),
      );
      final agent = await sdk.getAgent('agt-001');
      expect(agent?.registryId, 1);
    });

    test('an unknown id is null', () async {
      final sdk = Puls3Sdk.withApi(catalog: _FakeCatalog());
      expect(await sdk.getAgent('agt-999'), isNull);
    });

    test('a blank id is refused without calling the server', () {
      final catalog = _FakeCatalog();
      final sdk = Puls3Sdk.withApi(catalog: catalog);
      expect(() => sdk.getAgent('  '), throwsArgumentError);
      expect(catalog.gets, isEmpty);
    });
  });

  group('connect', () {
    test('adds the trailing slash the client expects', () {
      expect(
        normalizeApiUrl(Uri.parse('https://api.puls3.test')),
        'https://api.puls3.test/',
      );
      expect(
        normalizeApiUrl(Uri.parse('http://localhost:8080/')),
        'http://localhost:8080/',
      );
    });

    test('refuses a relative or non-http URL', () {
      for (final url in ['api.puls3.test', 'ftp://api.puls3.test', '/v1']) {
        expect(
          () => Puls3Sdk.connect(Uri.parse(url)),
          throwsArgumentError,
          reason: url,
        );
      }
    });
  });
}
