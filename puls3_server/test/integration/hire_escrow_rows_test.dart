import 'package:puls3_server/src/generated/protocol.dart';
import 'package:puls3_server/src/hire/serverpod_hire_escrow_rows.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

const _alice = 'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H';
const _escrow = 'CBRD7A7MXINM7LREKCL3RMKRQ5UMLGKNHAEYY4JT7MVBBB7R5QV4TPE2';
const _other = 'CD5QZOKGRBV35C5SDT6PG7S72XGG4BHQAC2L56YLNBJDUL4LDMTXFIJJ';

void main() {
  withServerpod('ServerpodHireEscrowRows (#307)', (sessionBuilder, _) {
    Future<HireRecord> insert({int? jobId, String? escrow}) =>
        HireRecord.db.insertRow(
          sessionBuilder.build(),
          HireRecord(
            consumer: _alice,
            agentId: 7,
            price: 5000000,
            manifestVersion: 1,
            expiredAt: 1795000000,
            jobId: jobId,
            escrow: escrow,
          ),
        );

    test('lists only hires with a job and no escrow, oldest first', () async {
      final first = await insert(jobId: 9101);
      await insert();
      await insert(jobId: 9102, escrow: _other);
      final last = await insert(jobId: 9103);

      final found = await ServerpodHireEscrowRows(
        sessionBuilder.build(),
      ).withoutEscrow();

      expect(found.map((h) => h.hireId), [first.id, last.id]);
      expect(found.first.jobId, 9101);
      expect(found.first.consumer, _alice);
      expect(found.first.agentId, 7);
    });

    test('writes only an empty escrow, never over one', () async {
      final empty = await insert(jobId: 9201);
      final own = await insert(jobId: 9202, escrow: _other);
      final rows = ServerpodHireEscrowRows(sessionBuilder.build());

      expect(await rows.setEscrowIfEmpty(empty.id!, _escrow), isTrue);
      expect(await rows.setEscrowIfEmpty(own.id!, _escrow), isFalse);
      expect(await rows.setEscrowIfEmpty(empty.id!, _other), isFalse);

      final session = sessionBuilder.build();
      final emptyNow = await HireRecord.db.findById(session, empty.id!);
      final ownNow = await HireRecord.db.findById(session, own.id!);
      expect(emptyNow!.escrow, _escrow);
      expect(ownNow!.escrow, _other);
    });

    test('reads only the confirmed create_job envelope of the hire', () async {
      final session = sessionBuilder.build();
      Future<void> submission(
        int hireId,
        String purpose,
        String state,
        String envelope,
        String tx,
      ) => ChainSubmission.db.insertRow(
        session,
        ChainSubmission(
          preparationId: 'prep-$tx',
          purpose: purpose,
          transaction: tx,
          state: state,
          updatedAt: DateTime.utc(2026, 11, 24),
          hireId: hireId,
          signedEnvelopeXdr: envelope,
        ),
      );
      String tx(String c) => c * 64;
      await submission(9301, 'createJob', 'failed', 'FAILED', tx('a'));
      await submission(9301, 'createJob', 'confirmed', 'CREATED', tx('b'));
      await submission(9301, 'fund', 'confirmed', 'FUNDED', tx('c'));
      await submission(9302, 'createJob', 'submitted', 'PENDING', tx('d'));
      final rows = ServerpodHireEscrowRows(session);

      expect(await rows.confirmedCreateJobEnvelope(9301), 'CREATED');
      expect(await rows.confirmedCreateJobEnvelope(9302), isNull);
      expect(await rows.confirmedCreateJobEnvelope(9399), isNull);
    });
  });
}
