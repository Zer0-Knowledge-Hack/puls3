import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/hire/hire_lifecycle_store.dart';
import 'package:puls3_server/src/hire/serverpod_hire_repository.dart';
import 'package:test/test.dart';

import '../support/hire_lifecycle_store_contract.dart';
import 'test_tools/serverpod_test_tools.dart';

const _alice = 'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H';
const _provider = 'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY';
const _tx = '43cd3e847c1a8d11d13f9611b7a2d677d2919323c6f2a74c76b9e289f6652437';

void main() {
  withServerpod('Given the Serverpod HireLifecycleStore', (sessionBuilder, _) {
    hireLifecycleStoreContract(
      () => ServerpodHireRepository(sessionBuilder.build()),
    );

    test('a funded hire reports funded with its payment', () async {
      final repo = ServerpodHireRepository(sessionBuilder.build());
      final row = await repo.insertHire(
        const NewHire(
          consumer: _alice,
          agentId: 7,
          price: 5000000,
          manifestVersion: 1,
          expiredAt: 1800000000,
          requestId: 'request-funded',
          input: 'input',
        ),
      );
      await repo.bindJob(row.id, 3, expiredAt: 1800000000);
      final hire = (await repo.findById(HireId(row.id)))!;
      final payment = Payment(
        transaction: TransactionHash.parse(_tx),
        hireId: hire.id,
        payer: StellarAddress.parse(_alice),
        payee: StellarAddress.parse(_provider),
        amount: UsdcAmount.stroops(5000000),
      );
      await repo.recordPayment(hire, payment, 3);

      final funded = (await repo.findHire(row.id))!;

      expect(funded.status, HireStatus.funded);
      expect(funded.paymentTransaction, _tx);
    });
  });
}
