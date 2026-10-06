import 'package:puls3_domain/puls3_domain.dart';
import 'package:test/test.dart';

/// A repository whose `recordPayment` always hits [conflict]: proves the port
/// can be implemented and that adapters report the violated index by type.
final class _ConflictingRepository implements HireRepository {
  _ConflictingRepository(this.conflict);

  final HirePaymentIndex conflict;

  @override
  Future<Hire> create({
    required AgentId agentId,
    required StellarAddress consumer,
    required UsdcAmount price,
    required int manifestVersion,
    required int expiredAt,
  }) => throw UnimplementedError();

  @override
  Future<Hire?> findById(HireId id) async => null;

  @override
  Future<int?> preparedExpiry(HireId id) async => null;

  @override
  Future<Hire> recordPayment(Hire paid, Payment payment, int jobId) async =>
      throw HirePaymentConflict(conflict);
}

final wallet = StellarAddress.parse(
  'GAV3KOEEBJC77IP4T2JT7FDUTQ5Y5GJXTIZGRG4CZFZ3GZX7V6IUPBUK',
);
final consumer = StellarAddress.parse(
  'GCL2Q3PX6FDMF7XMSE7C6UEHYVEER2ZTVIQEJVUSSL4IFQX7YOIZEPOV',
);

void main() {
  test('HirePaymentConflict names the three unique indexes', () {
    expect(HirePaymentIndex.values.map((i) => i.name), [
      'hireId',
      'transactionHash',
      'jobId',
    ]);
  });

  for (final index in HirePaymentIndex.values) {
    test('recordPayment reports a ${index.name} conflict by index', () async {
      final repository = _ConflictingRepository(index);
      final hire = Hire(
        id: HireId(1),
        agentId: AgentId(3),
        consumer: consumer,
        price: UsdcAmount.stroops(5000000),
        manifestVersion: 1,
      );
      final payment = Payment(
        transaction: TransactionHash.parse('ab' * 32),
        hireId: hire.id,
        payer: consumer,
        payee: wallet,
        amount: hire.price,
      );

      await expectLater(
        repository.recordPayment(hire, payment, 3),
        throwsA(
          isA<HirePaymentConflict>().having((e) => e.index, 'index', index),
        ),
      );
    });
  }
}
