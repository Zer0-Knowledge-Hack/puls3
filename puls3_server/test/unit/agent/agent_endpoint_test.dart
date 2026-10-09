import 'package:puls3_server/src/agent/agent_catalog_wiring.dart';
import 'package:puls3_server/src/agent/agent_endpoint.dart';
import 'package:puls3_server/src/agent/catalog_reader.dart';
import 'package:puls3_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

/// The injected reader never touches the session, so a bare stand-in is
/// enough for those tests.
final class _UnusedSession implements Session {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('The agent endpoint must not use the session');
}

AgentSummary _agent({String id = 'agt-001'}) => AgentSummary(
  id: id,
  registryId: 7,
  name: 'Ledger Scout',
  description: 'Reads the ledger and reports what changed.',
  skills: const ['ledger-analysis'],
  priceUsdcStroops: 5000000,
  wallet: 'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY',
  model: 'claude-sonnet',
);

final class _FakeCatalog implements CatalogReader {
  _FakeCatalog(this.agents, {this.failure});

  final List<AgentSummary> agents;
  final Object? failure;

  @override
  Future<List<AgentSummary>> list() async {
    if (failure != null) throw failure!;
    return agents;
  }

  @override
  Future<AgentSummary?> get(String id) async {
    if (failure != null) throw failure!;
    for (final agent in agents) {
      if (agent.id == id) return agent;
    }
    return null;
  }
}

void main() {
  final session = _UnusedSession();
  final endpoint = AgentEndpoint();

  tearDown(() {
    AgentEndpoint.service = null;
    AgentEndpoint.defaultServiceBuilder = buildAgentCatalogReader;
  });

  test('list serves the injected reader', () async {
    AgentEndpoint.service = _FakeCatalog([_agent()]);

    final agents = await endpoint.list(session);

    expect(agents.single.id, 'agt-001');
    expect(agents.single.name, 'Ledger Scout');
  });

  test('get returns a known agent and null for an unknown id', () async {
    AgentEndpoint.service = _FakeCatalog([_agent()]);

    expect((await endpoint.get(session, 'agt-001'))?.priceUsdcStroops, 5000000);
    expect(await endpoint.get(session, 'agt-999'), isNull);
  });

  test('list and get propagate an unavailability error', () {
    AgentEndpoint.service = _FakeCatalog(
      const [],
      failure: AgentCatalogUnavailable(
        message: 'The agent catalog cannot be read from the chain right now.',
      ),
    );

    expect(endpoint.list(session), throwsA(isA<AgentCatalogUnavailable>()));
    expect(
      endpoint.get(session, 'agt-001'),
      throwsA(isA<AgentCatalogUnavailable>()),
    );
  });

  test('the default builder receives the session', () async {
    late Session seen;
    AgentEndpoint.service = null;
    AgentEndpoint.defaultServiceBuilder = (s) {
      seen = s;
      return _FakeCatalog([_agent()]);
    };

    final agents = await endpoint.list(session);

    expect(seen, same(session));
    expect(agents.single.id, 'agt-001');
  });

  test('AgentSummary exposes exactly the catalog fields and no rating', () {
    final json = _agent().toJson();

    expect(
      json.keys.toSet()..remove('__className__'),
      {
        'id',
        'registryId',
        'name',
        'description',
        'skills',
        'priceUsdcStroops',
        'wallet',
        'model',
      },
    );
    expect(
      json.keys.where((k) => k.contains(RegExp('rating|reputation'))),
      isEmpty,
    );
  });
}
