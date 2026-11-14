import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/agent/agent_endpoint.dart';
import 'package:puls3_server/src/agent/catalog_reader.dart';
import 'package:puls3_server/src/agent/custodied_wallets.dart';
import 'package:puls3_server/src/agent/hireable_catalog_reader.dart';
import 'package:puls3_server/src/agent/indexed_agent_catalog_service.dart';
import 'package:puls3_server/src/agent/secret_cipher.dart';
import 'package:puls3_server/src/agent/serverpod_agent_index_repository.dart';
import 'package:puls3_server/src/agent/serverpod_agent_wallet_store.dart';
import 'package:puls3_server/src/generated/protocol.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

const _custodied = 'GDWVBEPVODIA7D3A2II7LBR7FLD4TZDFOVWWVAXUAYPV4F4J5ZIIKWNF';
const _uncustodied = 'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY';

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

      test('hireable comes from the wallet custody rule', () async {
        final session = sessionBuilder.build();
        final repo = ServerpodAgentIndexRepository(
          session,
          network: 'it-hireable',
        );
        await repo.upsertAll([
          _agent(9401, 'it-hireable-custodied').copyWith(wallet: _custodied),
          _agent(9402, 'it-hireable-uncustodied').copyWith(
            wallet: _uncustodied,
          ),
          _agent(9403, 'it-hireable-no-wallet'),
        ]);
        await ServerpodAgentWalletStore(session).save(
          owner: StellarAddress.parse(_uncustodied),
          address: StellarAddress.parse(_custodied),
          idempotencyKey: 'it-hireable-wallet',
          secret: const EncryptedSecret(
            ciphertext: 'Y2lwaGVy',
            nonce: 'bm9uY2U=',
            mac: 'bWFj',
            keyVersion: 1,
          ),
          createdAt: DateTime.utc(2026, 11, 13),
        );
        final reader = HireableCatalogReader(
          inner: IndexedAgentCatalogService(index: repo),
          custody: custodyOn(session),
        );

        final agents = await reader.list();
        expect(
          {
            for (final agent in agents)
              if (agent.id.startsWith('it-hireable-')) agent.id: agent.hireable,
          },
          {
            'it-hireable-custodied': true,
            'it-hireable-uncustodied': false,
            'it-hireable-no-wallet': false,
          },
        );

        expect((await reader.get('it-hireable-custodied'))?.hireable, isTrue);
        expect(
          (await reader.get('it-hireable-uncustodied'))?.hireable,
          isFalse,
        );
      });
    });
  }, tags: 'integration');
}
