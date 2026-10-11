import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/generated/protocol.dart'
    show HirePaymentRecord;
import 'package:puls3_server/src/hire/hire_lifecycle_store.dart';
import 'package:puls3_server/src/hire/serverpod_hire_repository.dart';
import 'package:puls3_server/src/runtime/hire_run_store.dart';
import 'package:puls3_server/src/runtime/serverpod_hire_run_store.dart';
import 'package:serverpod/serverpod.dart' show DatabaseQueryException, Session;
import 'package:test/test.dart';

import '../support/hire_run_store_contract.dart';
import 'test_tools/serverpod_test_tools.dart';

const _alice = 'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H';
const _provider = 'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY';

/// A funded hire through the real repository: insert, bind the job, record
/// the payment (which queues the run). Returns the hire id.
Future<int> _fundedHire(
  Session session, {
  required int seq,
  int agentId = 13,
  int manifestVersion = 1,
  String input = 'Summarize this',
}) async {
  final repo = ServerpodHireRepository(session);
  final row = await repo.insertHire(
    NewHire(
      consumer: _alice,
      agentId: agentId,
      price: 1000000,
      manifestVersion: manifestVersion,
      expiredAt: 1800000000,
      requestId: 'run-$seq',
      input: input,
    ),
  );
  await repo.bindJob(row.id, 1000 + seq, expiredAt: 1800000000);
  final open = (await repo.findById(HireId(row.id)))!;
  final payment = Payment(
    transaction: TransactionHash.parse(seq.toRadixString(16).padLeft(64, '0')),
    hireId: open.id,
    payer: StellarAddress.parse(_alice),
    payee: StellarAddress.parse(_provider),
    amount: UsdcAmount.stroops(1000000),
  );
  await repo.recordPayment(open, payment, 1000 + seq);
  return row.id;
}

void main() {
  withServerpod('Given the Serverpod HireRunStore', (sessionBuilder, _) {
    var seq = 0;

    hireRunStoreContract(() async {
      final session = sessionBuilder.build();
      return HireRunStoreFixture(
        store: ServerpodHireRunStore(session),
        queue:
            ({
              required int agentId,
              required int manifestVersion,
              required String input,
            }) => _fundedHire(
              session,
              seq: ++seq,
              agentId: agentId,
              manifestVersion: manifestVersion,
              input: input,
            ),
      );
    });

    test('recording a payment queues exactly one run', () async {
      final session = sessionBuilder.build();
      final id = await _fundedHire(session, seq: ++seq);
      final runs = ServerpodHireRunStore(session);

      final run = await runs.find(id);
      expect(run!.state, HireRunState.queued);

      // The tracker applies the funding effect again after a crash.
      final repo = ServerpodHireRepository(session);
      final funded = (await repo.findById(HireId(id)))!;
      final again = Payment(
        transaction: funded.paymentTransaction!,
        hireId: funded.id,
        payer: StellarAddress.parse(_alice),
        payee: StellarAddress.parse(_provider),
        amount: UsdcAmount.stroops(1000000),
      );
      await repo.recordPayment(funded, again, 1000 + seq);
      expect(
        (await runs.listQueued(limit: 100)).where((q) => q.hireId == id),
        hasLength(1),
      );
    });

    test(
      'enqueueMissing queues a run for a paid hire that has none, once',
      () async {
        final session = sessionBuilder.build();
        final repo = ServerpodHireRepository(session);
        final runs = ServerpodHireRunStore(session);
        final withRun = await _fundedHire(session, seq: ++seq);
        // A hire paid before hire_run existed: a payment row and no run.
        final row = await repo.insertHire(
          NewHire(
            consumer: _alice,
            agentId: 13,
            price: 1000000,
            manifestVersion: 1,
            expiredAt: 1800000000,
            requestId: 'legacy-$seq',
            input: 'old hire',
          ),
        );
        await HirePaymentRecord.db.insertRow(
          session,
          HirePaymentRecord(
            hireId: row.id,
            transactionHash: 'f${(++seq).toRadixString(16).padLeft(63, '0')}',
            jobId: 5000 + seq,
            payer: _alice,
            payee: _provider,
            amount: 1000000,
          ),
        );
        final now = DateTime.utc(2026, 10, 8, 12);

        expect(await runs.enqueueMissing(now), 1);
        expect((await runs.find(row.id))!.state, HireRunState.queued);
        expect((await runs.find(withRun))!.state, HireRunState.queued);
        expect(await runs.enqueueMissing(now), 0);
      },
    );

    test(
      'a second run for a hire is the 23505 of hire_run_hire_idx, the only '
      'error enqueueMissing skips',
      () async {
        final session = sessionBuilder.build();
        final hireId = await _fundedHire(session, seq: ++seq);

        await expectLater(
          ServerpodHireRunStore.enqueue(
            session,
            hireId,
            DateTime.utc(2026, 10, 10),
          ),
          throwsA(
            isA<DatabaseQueryException>().having(
              (e) => isDuplicateRun(
                code: e.code,
                constraintName: e.constraintName,
              ),
              'isDuplicateRun',
              isTrue,
            ),
          ),
        );
      },
    );

    test('findById replays the run through the domain', () async {
      final session = sessionBuilder.build();
      final repo = ServerpodHireRepository(session);
      final runs = ServerpodHireRunStore(session);
      final queued = await _fundedHire(session, seq: ++seq);
      final running = await _fundedHire(session, seq: ++seq);
      final failed = await _fundedHire(session, seq: ++seq);
      final now = DateTime.utc(2026, 10, 8, 12);
      await runs.markRunning(running, now);
      await runs.markRunning(failed, now);
      await runs.markFailed(failed, 'timeout', now);

      final q = (await repo.findById(HireId(queued)))!;
      final r = (await repo.findById(HireId(running)))!;
      final f = (await repo.findById(HireId(failed)))!;

      expect(q.status, HireStatus.funded);
      expect(q.runtimeStatus, RuntimeStatus.queued);
      expect(r.runtimeStatus, RuntimeStatus.running);
      expect(f.runtimeStatus, RuntimeStatus.failed);
      expect(f.failureReason, 'timeout');
    });
  });
}
