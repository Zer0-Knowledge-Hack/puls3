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

/// An inner reader with a fixed catalog, so the decorator is tested alone.
final class _FixedCatalog implements CatalogReader {
  _FixedCatalog(this.agents);

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
  final catalog = _FixedCatalog([
    _agent('agt-001', 7),
    _agent('agt-015', 15),
    _agent('agt-016', 16),
  ]);

  group('HiddenCatalogReader', () {
    test('an unset list returns the inner catalog untouched', () async {
      final reader = HiddenCatalogReader(
        inner: catalog,
        hidden: HiddenAgents.none,
      );

      expect(await reader.list(), await catalog.list());
      expect(await reader.get('agt-015'), isNotNull);
    });

    test('list drops the hidden agents', () async {
      final reader = HiddenCatalogReader(
        inner: catalog,
        hidden: HiddenAgents.fromEnvironment(const {
          'PULS3_HIDDEN_AGENT_IDS': '15,16',
        }),
      );

      final agents = await reader.list();

      expect(agents.map((a) => a.registryId), [7]);
    });

    test('get answers null for a hidden agent, as if it did not exist', () async {
      final reader = HiddenCatalogReader(
        inner: catalog,
        hidden: HiddenAgents.fromEnvironment(const {
          'PULS3_HIDDEN_AGENT_IDS': '15',
        }),
      );

      expect(await reader.get('agt-015'), isNull);
      expect(await reader.get('agt-001'), isNotNull);
      expect(await reader.get('agt-999'), isNull);
    });
  });
}
