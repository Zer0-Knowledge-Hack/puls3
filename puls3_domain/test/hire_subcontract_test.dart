import 'package:puls3_domain/puls3_domain.dart';
import 'package:test/test.dart';

final consumer = StellarAddress.parse(
  'GCL2Q3PX6FDMF7XMSE7C6UEHYVEER2ZTVIQEJVUSSL4IFQX7YOIZEPOV',
);
final agentWallet = StellarAddress.parse(
  'GAV3KOEEBJC77IP4T2JT7FDUTQ5Y5GJXTIZGRG4CZFZ3GZX7V6IUPBUK',
);
final txHash = TransactionHash.parse('ab' * 32);

Hire hire({
  int id = 7,
  UsdcAmount? subcontractReserve,
  bool? allowRelatedParty,
  HireId? parentHireId,
}) => Hire(
  id: HireId(id),
  agentId: AgentId(0),
  consumer: consumer,
  price: UsdcAmount.stroops(3000000),
  manifestVersion: 1,
  subcontractReserve: subcontractReserve,
  allowRelatedParty: allowRelatedParty,
  parentHireId: parentHireId,
);

Matcher hireProblem(HireProblem expected) =>
    throwsA(isA<InvalidHire>().having((e) => e.problem, 'problem', expected));

void main() {
  group('Hire subcontracting (ADR-0011)', () {
    test('a hire without a reserve cannot subcontract and is a root', () {
      final h = Hire(
        id: HireId(7),
        agentId: AgentId(0),
        consumer: consumer,
        price: UsdcAmount.stroops(3000000),
        manifestVersion: 1,
      );

      expect(h.subcontractReserve, UsdcAmount.zero);
      expect(h.canSubcontract, isFalse);
      expect(h.allowRelatedParty, isTrue, reason: 'D10 default: allowed');
      expect(h.parentHireId, isNull);
      expect(h.isChild, isFalse);
    });

    test('a reserve above zero lets the agent subcontract (D1)', () {
      final h = hire(subcontractReserve: UsdcAmount.stroops(2000000));

      expect(h.subcontractReserve, UsdcAmount.stroops(2000000));
      expect(h.canSubcontract, isTrue);
    });

    test('the consumer can opt out of related-party children (D10)', () {
      expect(hire(allowRelatedParty: false).allowRelatedParty, isFalse);
    });

    test('a child hire records its parent as data (D7)', () {
      final child = hire(id: 9, parentHireId: HireId(7));

      expect(child.parentHireId, HireId(7));
      expect(child.isChild, isTrue);
      expect(child.status, HireStatus.open);
    });

    test('a hire cannot be its own parent', () {
      expect(
        () => hire(id: 7, parentHireId: HireId(7)),
        hireProblem(HireProblem.parentIsSelf),
      );
    });

    test('a child hire has no reserve of its own: depth 1 first (D2, D5)', () {
      expect(
        () => hire(
          id: 9,
          parentHireId: HireId(7),
          subcontractReserve: UsdcAmount.stroops(1),
        ),
        hireProblem(HireProblem.childReserveNotSupported),
      );
    });

    test('every transition keeps the subcontract fields', () {
      final h = hire(
        subcontractReserve: UsdcAmount.stroops(2000000),
        allowRelatedParty: false,
      );
      final payment = Payment(
        transaction: txHash,
        hireId: h.id,
        payer: consumer,
        payee: agentWallet,
        amount: h.price,
      );

      final done = h
          .fund(payment, agentWallet: agentWallet)
          .startRun()
          .submit()
          .complete();

      expect(done.status, HireStatus.completed);
      expect(done.subcontractReserve, UsdcAmount.stroops(2000000));
      expect(done.allowRelatedParty, isFalse);
      expect(done.parentHireId, isNull);
    });

    test('the payment still settles the price only, never the reserve', () {
      final h = hire(subcontractReserve: UsdcAmount.stroops(2000000));
      final withReserve = Payment(
        transaction: txHash,
        hireId: h.id,
        payer: consumer,
        payee: agentWallet,
        amount: UsdcAmount.stroops(5000000),
      );

      expect(withReserve.settles(h, agentWallet: agentWallet), isFalse);
    });
  });
}
