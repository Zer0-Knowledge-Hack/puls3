import 'package:puls3_server/src/agent/agent_owners.dart';
import 'package:puls3_server/src/generated/protocol.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

const _builder = 'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H';
const _studioOwner = 'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY';
const _walletA = 'GDWVBEPVODIA7D3A2II7LBR7FLD4TZDFOVWWVAXUAYPV4F4J5ZIIKWNF';

void main() {
  withServerpod('database owners lookup', (sessionBuilder, _) {
    test('joins custody and Studio deploy owners by registry id', () async {
      final session = sessionBuilder.build();
      await AgentWallet.db.insertRow(
        session,
        AgentWallet(
          owner: _builder,
          address: _walletA,
          idempotencyKey: 'it-owners-1',
          ciphertext: 'Y2lwaGVy',
          nonce: 'bm9uY2U=',
          mac: 'bWFj',
          keyVersion: 1,
          agentId: 7101,
          createdAt: DateTime.utc(2026, 11, 18),
        ),
      );
      await StudioDeployRecord.db.insertRow(
        session,
        StudioDeployRecord(
          draftId: 7101,
          owner: _studioOwner,
          state: 'active',
          agentWallet: _walletA,
          registrationUri: 'ipfs://owners',
          registryAgentId: 7101,
          updatedAt: DateTime.utc(2026, 11, 18),
        ),
      );

      final owners = await databaseOwnersLookup(session)({7101, 7102});

      expect(owners, {
        7101: {_builder, _studioOwner},
      });
      expect(await databaseOwnersLookup(session)(const {}), isEmpty);
    });
  });
}
