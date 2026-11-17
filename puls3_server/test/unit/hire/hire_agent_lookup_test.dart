import 'package:puls3_server/src/agent/agent_index_repository.dart';
import 'package:puls3_server/src/agent/catalog_reader.dart';
import 'package:puls3_server/src/generated/protocol.dart';
import 'package:puls3_server/src/hire/hire_agent_lookup.dart';
import 'package:test/test.dart';

AgentSummary _agent(int registryId, String id) => AgentSummary(
  id: id,
  registryId: registryId,
  name: 'Agent $id',
  description: 'Does the job well.',
  skills: const ['testing'],
  priceUsdcStroops: 5000000,
);

/// An index that answers [findByRegistryId] from [rows] and counts reads.
final class _Index implements AgentIndexRepository {
  _Index(this.rows);

  final Map<int, AgentSummary> rows;
  var lookups = 0;

  @override
  Future<AgentSummary?> findByRegistryId(int registryId) async {
    lookups++;
    return rows[registryId];
  }

  @override
  Future<bool> isEmpty() async => rows.isEmpty;

  @override
  Future<List<AgentSummary>> list() => throw StateError('not used');

  @override
  Future<AgentSummary?> findByAgentId(String agentId) =>
      throw StateError('not used');

  @override
  Future<Set<int>> registryIds() => throw StateError('not used');

  @override
  Future<void> upsertAll(List<AgentSummary> agents) async {}

  @override
  Future<int?> lastProcessedLedger() async => null;

  @override
  Future<void> setLastProcessedLedger(int ledger) async {}
}

/// The on-chain catalog: counts how often the whole list is read.
final class _Chain implements CatalogReader {
  _Chain(this.agents);

  final List<AgentSummary> agents;
  var lists = 0;

  @override
  Future<List<AgentSummary>> list() async {
    lists++;
    return agents;
  }

  @override
  Future<AgentSummary?> get(String id) => throw StateError('not used');
}

void main() {
  group('hireAgentLookup (#206, I-2)', () {
    test('reads one agent from the index and never the whole catalog', () async {
      final index = _Index({7: _agent(7, 'agt-001')});
      final chain = _Chain([_agent(7, 'agt-001')]);

      final agent = await hireAgentLookup(index: index, fallback: chain)(7);

      expect(agent!.id, 'agt-001');
      expect(index.lookups, 1);
      expect(chain.lists, 0);
    });

    test('an id a populated index does not have is unknown', () async {
      // Unknown or superseded: the chain is not read for it either.
      final chain = _Chain([_agent(9, 'agt-009')]);
      final agent = await hireAgentLookup(
        index: _Index({7: _agent(7, 'agt-001')}),
        fallback: chain,
      )(9);

      expect(agent, isNull);
      expect(chain.lists, 0);
    });

    test('before the first indexer pass it falls back to the chain', () async {
      final chain = _Chain([_agent(7, 'agt-001'), _agent(8, 'agt-002')]);

      final lookup = hireAgentLookup(index: _Index({}), fallback: chain);

      expect((await lookup(8))!.id, 'agt-002');
      expect(await lookup(99), isNull);
      expect(chain.lists, 2);
    });
  });
}
