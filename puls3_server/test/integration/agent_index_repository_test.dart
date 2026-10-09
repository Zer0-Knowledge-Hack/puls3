import 'package:puls3_server/src/agent/serverpod_agent_index_repository.dart';
import 'package:puls3_server/src/generated/protocol.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

AgentSummary _agent({
  required int registryId,
  required String id,
  String name = 'Agent',
}) => AgentSummary(
  id: id,
  registryId: registryId,
  name: name,
  description: 'Does the job number $registryId well.',
  skills: const ['testing'],
  priceUsdcStroops: registryId * 1000000,
);

void main() {
  group('ServerpodAgentIndexRepository integration', () {
    withServerpod('index persistence', (sessionBuilder, _) {
      test('upsertAll is idempotent per registry id', () async {
        final session = sessionBuilder.build();
        final repo = ServerpodAgentIndexRepository(session, network: 'it-1');

        await repo.upsertAll([_agent(registryId: 9001, id: 'it-upsert')]);
        await repo.upsertAll([_agent(registryId: 9001, id: 'it-upsert')]);

        final count = await AgentRecord.db.count(
          session,
          where: (t) => t.registryId.equals(9001),
        );
        expect(count, 1);

        final stored = await repo.findByAgentId('it-upsert');
        expect(stored, isNotNull);
        expect(stored!.registryId, 9001);
      });

      test('an update replaces the row for the same registry id', () async {
        final session = sessionBuilder.build();
        final repo = ServerpodAgentIndexRepository(session, network: 'it-2');

        await repo.upsertAll([
          _agent(registryId: 9101, id: 'it-update', name: 'First'),
        ]);
        await repo.upsertAll([
          _agent(registryId: 9101, id: 'it-update', name: 'Second'),
        ]);

        final stored = await repo.findByAgentId('it-update');
        expect(stored!.name, 'Second');
      });

      test('findByAgentId keeps the newest registration', () async {
        final session = sessionBuilder.build();
        final repo = ServerpodAgentIndexRepository(session, network: 'it-3');

        await repo.upsertAll([
          _agent(registryId: 9201, id: 'it-dup', name: 'First'),
          _agent(registryId: 9202, id: 'it-dup', name: 'Second'),
        ]);

        final stored = await repo.findByAgentId('it-dup');
        expect(stored!.registryId, 9202);
        expect(stored.name, 'Second');
      });

      test('the resume cursor round-trips per network', () async {
        final session = sessionBuilder.build();
        final repo = ServerpodAgentIndexRepository(session, network: 'it-4');

        expect(await repo.lastProcessedLedger(), isNull);
        await repo.setLastProcessedLedger(1234);
        expect(await repo.lastProcessedLedger(), 1234);
        await repo.setLastProcessedLedger(5678);
        expect(await repo.lastProcessedLedger(), 5678);

        final other = ServerpodAgentIndexRepository(session, network: 'it-5');
        expect(await other.lastProcessedLedger(), isNull);
      });
    });
  }, tags: 'integration');
}
