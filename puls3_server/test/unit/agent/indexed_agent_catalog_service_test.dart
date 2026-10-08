import 'package:puls3_server/src/agent/agent_index_repository.dart';
import 'package:puls3_server/src/agent/catalog_reader.dart';
import 'package:puls3_server/src/agent/indexed_agent_catalog_service.dart';
import 'package:puls3_server/src/generated/protocol.dart';
import 'package:test/test.dart';

AgentSummary _agent(String id, int registryId) => AgentSummary(
  id: id,
  registryId: registryId,
  name: 'Agent $registryId',
  description: 'Does the job number $registryId well.',
  skills: const ['testing'],
  priceUsdcStroops: registryId * 1000000,
);

final class _FakeIndex implements AgentIndexRepository {
  _FakeIndex(this.rows);

  final Map<String, AgentSummary> rows;
  int listCalls = 0;

  @override
  Future<List<AgentSummary>> list() async {
    listCalls++;
    return rows.values.toList();
  }

  @override
  Future<AgentSummary?> findByAgentId(String agentId) async => rows[agentId];

  @override
  Future<Set<int>> registryIds() async =>
      {for (final row in rows.values) row.registryId};

  @override
  Future<void> upsertAll(List<AgentSummary> agents) async {}

  @override
  Future<int?> lastProcessedLedger() async => null;

  @override
  Future<void> setLastProcessedLedger(int ledger) async {}
}

final class _FakeFallback implements CatalogReader {
  _FakeFallback(this.agents);

  final List<AgentSummary> agents;
  int listCalls = 0;

  @override
  Future<List<AgentSummary>> list() async {
    listCalls++;
    return agents;
  }

  @override
  Future<AgentSummary?> get(String id) async {
    for (final agent in agents) {
      if (agent.id == id) return agent;
    }
    return null;
  }
}

void main() {
  test('list serves the index and never the fallback when it has rows',
      () async {
    final index = _FakeIndex({'agt-001': _agent('agt-001', 0)});
    final fallback = _FakeFallback([_agent('agt-002', 1)]);
    final service = IndexedAgentCatalogService(
      index: index,
      fallback: fallback,
    );

    final agents = await service.list();

    expect(agents.single.id, 'agt-001');
    expect(fallback.listCalls, 0);
  });

  test('list falls back to the chain when the index is empty', () async {
    final fallback = _FakeFallback([_agent('agt-002', 1)]);
    final service = IndexedAgentCatalogService(
      index: _FakeIndex({}),
      fallback: fallback,
    );

    final agents = await service.list();

    expect(agents.single.id, 'agt-002');
    expect(fallback.listCalls, 1);
  });

  test('get serves the index, then the fallback', () async {
    final service = IndexedAgentCatalogService(
      index: _FakeIndex({'agt-001': _agent('agt-001', 0)}),
      fallback: _FakeFallback([_agent('agt-002', 1)]),
    );

    expect((await service.get('agt-001'))?.id, 'agt-001');
    expect((await service.get('agt-002'))?.id, 'agt-002');
    expect(await service.get('agt-999'), isNull);
  });

  test('an empty index with no fallback is an empty list', () async {
    final service = IndexedAgentCatalogService(index: _FakeIndex({}));

    expect(await service.list(), isEmpty);
    expect(await service.get('agt-001'), isNull);
  });
}
