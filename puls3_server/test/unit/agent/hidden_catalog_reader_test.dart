import 'package:puls3_server/src/agent/catalog_reader.dart';
import 'package:puls3_server/src/agent/hidden_agents.dart';
import 'package:puls3_server/src/agent/hidden_catalog_reader.dart';
import 'package:puls3_server/src/generated/protocol.dart';
import 'package:test/test.dart';

AgentSummary _agent(String id, int registryId) => AgentSummary(
  id: id,
  registryId: registryId,
  name: 'Agent $registryId',
  description: 'A helpful test agent for verification.',
  skills: const ['coding'],
  priceUsdcStroops: 5000000,
);

final class _FakeCatalog implements CatalogReader {
  _FakeCatalog(this.agents);

  final List<AgentSummary> agents;

  @override
  Future<List<AgentSummary>> list() async => agents;

  @override
  Future<AgentSummary?> get(String id) async {
    for (final agent in agents) {
      if (agent.id == id) return agent;
    }
    return null;
  }
}

void main() {
  final catalog = _FakeCatalog([
    _agent('agt-007', 7),
    _agent('ssda', 15),
    _agent('rigoberto', 16),
  ]);

  HiddenCatalogReader readerHiding(String value) => HiddenCatalogReader(
    inner: catalog,
    hidden: HiddenAgents.fromEnvironment({'PULS3_HIDDEN_AGENT_IDS': value}),
  );

  test('list drops hidden agents and keeps the order of the rest', () async {
    final agents = await readerHiding('15,16').list();

    expect([for (final a in agents) a.registryId], [7]);
  });

  test('get is null for a hidden agent', () async {
    expect(await readerHiding('15').get('ssda'), isNull);
  });

  test('get returns a visible agent unchanged', () async {
    expect(await readerHiding('15').get('agt-007'), catalog.agents.first);
  });

  test('get is null for an unknown agent', () async {
    expect(await readerHiding('15').get('nobody'), isNull);
  });

  test('with the variable unset, list and get are the inner ones', () async {
    final reader = HiddenCatalogReader(
      inner: catalog,
      hidden: HiddenAgents.fromEnvironment(const {}),
    );

    expect(await reader.list(), catalog.agents);
    expect(await reader.get('ssda'), catalog.agents[1]);
  });
}
