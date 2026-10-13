import 'dart:convert';
import 'dart:io';

import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/hire/serverpod_hire_repository.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

const _alice = 'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H';
const _provider = 'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY';
const _tx1 = '43cd3e847c1a8d11d13f9611b7a2d677d2919323c6f2a74c76b9e289f6652437';
const _tx2 = '652a575b5d85814c19a4fed0f7d21f40acb35a399c4008d450877ee83e8b31ab';

void main() {
  group('ServerpodHireRepository integration', () {
    withServerpod('database persistence', (sessionBuilder, _) {
      test('create and findById returns open hire', () async {
        final session = sessionBuilder.build();
        final repo = ServerpodHireRepository(session);

        final hire = await repo.create(
          agentId: AgentId(7),
          consumer: StellarAddress.parse(_alice),
          price: UsdcAmount.stroops(5000000),
          manifestVersion: 1,
          expiredAt: 1700000000,
        );

        expect(hire.id.value, isPositive);
        expect(hire.status, HireStatus.open);
        expect(hire.agentId.value, 7);
        expect(hire.consumer.value, _alice);
        expect(hire.price.stroops, 5000000);
        expect(hire.manifestVersion, 1);
        expect(hire.paymentTransaction, isNull);

        final found = await repo.findById(hire.id);
        expect(found, isNotNull);
        expect(found!.id, hire.id);
        expect(found.status, HireStatus.open);
        expect(found.agentId, hire.agentId);
        expect(found.consumer, hire.consumer);
        expect(found.price, hire.price);
        expect(found.manifestVersion, hire.manifestVersion);
        expect(found.paymentTransaction, isNull);

        final missing = await repo.findById(HireId(999999999));
        expect(missing, isNull);
      });

      test('recordPayment rehydrates funded hire', () async {
        final session = sessionBuilder.build();
        final repo = ServerpodHireRepository(session);

        final hire = await repo.create(
          agentId: AgentId(7),
          consumer: StellarAddress.parse(_alice),
          price: UsdcAmount.stroops(5000000),
          manifestVersion: 1,
          expiredAt: 1700000000,
        );

        final payment = Payment(
          transaction: TransactionHash.parse(_tx1),
          hireId: hire.id,
          payer: StellarAddress.parse(_alice),
          payee: StellarAddress.parse(_provider),
          amount: UsdcAmount.stroops(5000000),
        );

        final paidHire = await repo.recordPayment(hire, payment, 3);

        expect(paidHire.id, hire.id);
        expect(paidHire.status, HireStatus.funded);
        expect(paidHire.paymentTransaction, payment.transaction);

        final reloaded = await repo.findById(hire.id);
        expect(reloaded, isNotNull);
        expect(reloaded!.status, HireStatus.funded);
        expect(reloaded.paymentTransaction, payment.transaction);
      });

      test('unique index collisions map to HirePaymentConflict', () async {
        final session = sessionBuilder.build();
        final repo = ServerpodHireRepository(session);

        final hire1 = await repo.create(
          agentId: AgentId(7),
          consumer: StellarAddress.parse(_alice),
          price: UsdcAmount.stroops(5000000),
          manifestVersion: 1,
          expiredAt: 1700000000,
        );

        final hire2 = await repo.create(
          agentId: AgentId(7),
          consumer: StellarAddress.parse(_alice),
          price: UsdcAmount.stroops(5000000),
          manifestVersion: 1,
          expiredAt: 1700000000,
        );

        final payment1 = Payment(
          transaction: TransactionHash.parse(_tx1),
          hireId: hire1.id,
          payer: StellarAddress.parse(_alice),
          payee: StellarAddress.parse(_provider),
          amount: UsdcAmount.stroops(5000000),
        );

        await repo.recordPayment(hire1, payment1, 101);

        // 1. hire_id collision (same hire, different tx hash)
        final payment1DiffTx = Payment(
          transaction: TransactionHash.parse(_tx2),
          hireId: hire1.id,
          payer: StellarAddress.parse(_alice),
          payee: StellarAddress.parse(_provider),
          amount: UsdcAmount.stroops(5000000),
        );
        // Awaited: each call runs a transaction, and the test database
        // does not allow concurrent ones while it rolls back.
        await expectLater(
          repo.recordPayment(hire1, payment1DiffTx, 102),
          throwsA(
            isA<HirePaymentConflict>().having(
              (e) => e.index,
              'index',
              HirePaymentIndex.hireId,
            ),
          ),
        );

        // 2. transaction_hash collision (different hire, same tx hash)
        final payment2SameTx = Payment(
          transaction: TransactionHash.parse(_tx1),
          hireId: hire2.id,
          payer: StellarAddress.parse(_alice),
          payee: StellarAddress.parse(_provider),
          amount: UsdcAmount.stroops(5000000),
        );
        // Awaited: each call runs a transaction, and the test database
        // does not allow concurrent ones while it rolls back.
        await expectLater(
          repo.recordPayment(hire2, payment2SameTx, 103),
          throwsA(
            isA<HirePaymentConflict>().having(
              (e) => e.index,
              'index',
              HirePaymentIndex.transactionHash,
            ),
          ),
        );

        // 3. job_id collision (different hire, different tx, same job_id)
        final payment2SameJob = Payment(
          transaction: TransactionHash.parse(_tx2),
          hireId: hire2.id,
          payer: StellarAddress.parse(_alice),
          payee: StellarAddress.parse(_provider),
          amount: UsdcAmount.stroops(5000000),
        );
        // Awaited: each call runs a transaction, and the test database
        // does not allow concurrent ones while it rolls back.
        await expectLater(
          repo.recordPayment(hire2, payment2SameJob, 101),
          throwsA(
            isA<HirePaymentConflict>().having(
              (e) => e.index,
              'index',
              HirePaymentIndex.jobId,
            ),
          ),
        );

        // Hire2 had collisions and failed to record, so it must still be open
        final hire2Reloaded = await repo.findById(hire2.id);
        expect(hire2Reloaded, isNotNull);
        expect(hire2Reloaded!.status, HireStatus.open);
      });

      test('concurrent same-hire same-hash retry returns funded view', () async {
        final session = sessionBuilder.build();
        final repo = ServerpodHireRepository(session);

        final hire = await repo.create(
          agentId: AgentId(7),
          consumer: StellarAddress.parse(_alice),
          price: UsdcAmount.stroops(5000000),
          manifestVersion: 1,
          expiredAt: 1700000000,
        );

        final payment = Payment(
          transaction: TransactionHash.parse(_tx1),
          hireId: hire.id,
          payer: StellarAddress.parse(_alice),
          payee: StellarAddress.parse(_provider),
          amount: UsdcAmount.stroops(5000000),
        );

        final first = await repo.recordPayment(hire, payment, 201);
        expect(first.status, HireStatus.funded);

        // Concurrent retry with same hire and same payment returns funded view without error
        final retry = await repo.recordPayment(hire, payment, 201);
        expect(retry.status, HireStatus.funded);
        expect(retry.id, hire.id);
        expect(retry.paymentTransaction, payment.transaction);
      });

      test('preparedExpiry returns the expiry stored by create', () async {
        final session = sessionBuilder.build();
        final repo = ServerpodHireRepository(session);

        final hire = await repo.create(
          agentId: AgentId(7),
          consumer: StellarAddress.parse(_alice),
          price: UsdcAmount.stroops(5000000),
          manifestVersion: 1,
          expiredAt: 1700000000,
        );

        expect(await repo.preparedExpiry(hire.id), 1700000000);
        expect(await repo.preparedExpiry(HireId(999999999)), isNull);
      });

      test('one migration creates only hire and hire_payment', () {
        final migrations = Directory('migrations')
            .listSync()
            .whereType<Directory>()
            .map((d) => File('${d.path}/migration.json'))
            .where((f) => f.existsSync())
            .map(
              (f) =>
                  (jsonDecode(f.readAsStringSync())
                          as Map<String, dynamic>)['actions']
                      as List,
            )
            .where(
              (actions) => actions.any(
                (a) => (a as Map)['createTable']?['name'] == 'hire_payment',
              ),
            )
            .toList();

        expect(migrations, hasLength(1));
        final tableNames = migrations.single
            .map((a) => (a as Map)['createTable']['name'] as String)
            .toList();
        expect(tableNames, unorderedEquals(['hire', 'hire_payment']));
      });
    });
  }, tags: 'integration');
}
