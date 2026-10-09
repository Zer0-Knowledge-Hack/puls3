import 'package:puls3_server/src/agent/agent_endpoint.dart';
import 'package:puls3_server/src/agent/catalog_reader.dart';
import 'package:puls3_server/src/agent/indexed_agent_catalog_service.dart';
import 'package:puls3_server/src/agent/serverpod_agent_index_repository.dart';
import 'package:puls3_server/src/generated/protocol.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

/// A fallback that always fails, standing in for a chain that is down.
final class _DownCatalog implements CatalogReader {
  @override
  Future<List<AgentSummary>> list() async =>
      throw AgentCatalogUnavailable(message: 'chain down');

  @override
  Future<AgentSummary?> get(String id) async =>
      throw AgentCatalogUnavailable(message: 'chain down');
}

AgentSummary _agent(int registryId, String id) => AgentSummary(
  id: id,
  registryId: registryId,
  name: 'Indexed $id',
  description: 'Does the job number $registryId well.',
  skills: const ['testing'],
  priceUsdcStroops: 1000000,
);

void main() {
  group('AgentEndpoint index integration', () {
    withServerpod('serves the catalog from the index', (sessionBuilder, endpoints) {
      test('list and get do not touch the chain when indexed', () async {
        final session = sessionBuilder.build();
        final repo = ServerpodAgentIndexRepository(
          session,
          network: 'it-endpoint',
        );
        await repo.upsertAll([_agent(9301, 'it-endpoint-agent')]);

        AgentEndpoint.service = IndexedAgentCatalogService(
          index: repo,
          fallback: _DownCatalog(),
        );
        addTearDown(() => AgentEndpoint.service = null);

        final agents = await endpoints.agent.list(sessionBuilder);
        expect(agents.map((a) => a.id), contains('it-endpoint-agent'));

        final found = await endpoints.agent.get(
          sessionBuilder,
          'it-endpoint-agent',
        );
        expect(found?.registryId, 9301);
      });
    });
  }, tags: 'integration');
}
