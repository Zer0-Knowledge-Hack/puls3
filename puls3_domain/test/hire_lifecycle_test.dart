import 'package:puls3_domain/puls3_domain.dart';
import 'package:test/test.dart';

final agentWallet = StellarAddress.parse(
  'GAV3KOEEBJC77IP4T2JT7FDUTQ5Y5GJXTIZGRG4CZFZ3GZX7V6IUPBUK',
);
final consumer = StellarAddress.parse(
  'GCL2Q3PX6FDMF7XMSE7C6UEHYVEER2ZTVIQEJVUSSL4IFQX7YOIZEPOV',
);
final stranger = StellarAddress.parse(
  'GBY33NK3HMKQUKHL7YSCJ2W5JMJ62MEVKEJTRUWNQXBQIFLUVZY6TJ4R',
);
final txHash = TransactionHash.parse(
  '17ac14e085609df8e042b84e6c25aac7e1c30344eaa1b1fd0bcbed399b65243f',
);
final price = UsdcAmount.stroops(3000000);

Hire newHire() => Hire(
  id: HireId(7),
  agentId: AgentId(0),
  consumer: consumer,
  price: price,
  manifestVersion: 1,
);

Payment payment({
  int hireId = 7,
  StellarAddress? payee,
  int stroops = 3000000,
}) => Payment(
  transaction: txHash,
  hireId: HireId(hireId),
  payer: consumer,
  payee: payee ?? agentWallet,
  amount: UsdcAmount.stroops(stroops),
);

Feedback feedback({int hireId = 7, int agentId = 0, StellarAddress? client}) =>
    Feedback(
      hireId: HireId(hireId),
      agentId: AgentId(agentId),
      client: client ?? consumer,
      score: 5,
    );

/// Fires [event] on [hire] with arguments that satisfy its guard.
Hire fire(Hire hire, HireEvent event) => switch (event) {
  HireEvent.pay => hire.pay(payment(), agentWallet: agentWallet),
  HireEvent.cancel => hire.cancel(),
  HireEvent.start => hire.start(),
  HireEvent.deliver => hire.deliver(),
  HireEvent.fail => hire.fail(reason: 'model timeout'),
  HireEvent.rate => hire.rate(feedback()),
};

/// A hire in [status], reached only through valid transitions.
Hire inState(HireStatus status) => switch (status) {
  HireStatus.requested => newHire(),
  HireStatus.paid => fire(newHire(), HireEvent.pay),
  HireStatus.inProgress => inState(HireStatus.paid).start(),
  HireStatus.delivered => inState(HireStatus.inProgress).deliver(),
  HireStatus.rated => inState(HireStatus.delivered).rate(feedback()),
  HireStatus.cancelled => newHire().cancel(),
  HireStatus.failed => inState(HireStatus.inProgress).fail(reason: 'crash'),
};

/// The transition table of docs/domain/hire-lifecycle.md.
const table = <(HireStatus, HireEvent, HireStatus)>[
  (HireStatus.requested, HireEvent.pay, HireStatus.paid),
  (HireStatus.requested, HireEvent.cancel, HireStatus.cancelled),
  (HireStatus.paid, HireEvent.start, HireStatus.inProgress),
  (HireStatus.paid, HireEvent.fail, HireStatus.failed),
  (HireStatus.inProgress, HireEvent.deliver, HireStatus.delivered),
  (HireStatus.inProgress, HireEvent.fail, HireStatus.failed),
  (HireStatus.delivered, HireEvent.rate, HireStatus.rated),
];

Matcher invalidTransition(HireStatus from, HireEvent event) => throwsA(
  isA<InvalidHireTransition>()
      .having((e) => e.from, 'from', from)
      .having((e) => e.event, 'event', event),
);

void main() {
  test('a new hire starts in requested, with no payment', () {
    final hire = newHire();
    expect(hire.status, HireStatus.requested);
    expect(hire.paymentTransaction, isNull);
    expect(hire.failureReason, isNull);
  });

  group('valid transitions (one per row of the table)', () {
    for (final (from, event, to) in table) {
      test('$from --$event--> $to', () {
        final before = inState(from);
        final after = fire(before, event);
        expect(after.status, to);
        expect(before.status, from, reason: 'transitions return a new Hire');
        expect(after.id, before.id);
        expect(after.price, before.price);
      });
    }
  });

  group('I18 invalid events are rejected with a typed error', () {
    for (final status in HireStatus.values) {
      for (final event in HireEvent.values) {
        final allowed = table.any((row) => row.$1 == status && row.$2 == event);
        if (allowed) continue;
        test('$status rejects $event', () {
          expect(
            () => fire(inState(status), event),
            invalidTransition(status, event),
          );
        });
      }
    }
  });

  group('I18 terminal states accept no further transitions', () {
    for (final status in [
      HireStatus.rated,
      HireStatus.cancelled,
      HireStatus.failed,
    ]) {
      test('$status is terminal and rejects every event', () {
        expect(status.isTerminal, isTrue);
        for (final event in HireEvent.values) {
          expect(
            () => fire(inState(status), event),
            invalidTransition(status, event),
          );
        }
      });
    }

    test('non-terminal states are not terminal', () {
      for (final status in [
        HireStatus.requested,
        HireStatus.paid,
        HireStatus.inProgress,
        HireStatus.delivered,
      ]) {
        expect(status.isTerminal, isFalse, reason: '$status');
      }
    });
  });

  group('I19 paid is reached only with a payment reference', () {
    test('pay records the payment transaction hash', () {
      final paid = inState(HireStatus.paid);
      expect(paid.paymentTransaction, txHash);
    });

    test('the transaction hash is kept in every later state', () {
      for (final status in [
        HireStatus.inProgress,
        HireStatus.delivered,
        HireStatus.rated,
        HireStatus.failed,
      ]) {
        expect(inState(status).paymentTransaction, txHash, reason: '$status');
      }
    });

    test('a cancelled hire never had a payment', () {
      expect(inState(HireStatus.cancelled).paymentTransaction, isNull);
    });

    test('pay rejects a payment for another hire', () {
      expect(
        () => newHire().pay(payment(hireId: 8), agentWallet: agentWallet),
        throwsA(isA<PaymentDoesNotSettleHire>()),
      );
    });

    test('pay rejects a payment sent to another address', () {
      expect(
        () => newHire().pay(payment(payee: stranger), agentWallet: agentWallet),
        throwsA(isA<PaymentDoesNotSettleHire>()),
      );
    });

    test('pay rejects a payment with a different amount', () {
      for (final stroops in [2999999, 3000001]) {
        expect(
          () => newHire().pay(
            payment(stroops: stroops),
            agentWallet: agentWallet,
          ),
          throwsA(isA<PaymentDoesNotSettleHire>()),
          reason: '$stroops',
        );
      }
    });

    test('a rejected payment leaves the hire requested', () {
      final hire = newHire();
      expect(
        () => hire.pay(payment(hireId: 8), agentWallet: agentWallet),
        throwsA(isA<PaymentDoesNotSettleHire>()),
      );
      expect(hire.status, HireStatus.requested);
      expect(hire.paymentTransaction, isNull);
    });
  });

  group('fail', () {
    test('records the reason', () {
      expect(inState(HireStatus.failed).failureReason, 'crash');
    });

    test('rejects an empty reason', () {
      expect(
        () => inState(HireStatus.inProgress).fail(reason: ''),
        throwsA(
          isA<InvalidHire>().having(
            (e) => e.problem,
            'problem',
            HireProblem.failureReasonEmpty,
          ),
        ),
      );
    });
  });

  group('I20 rate', () {
    final delivered = inState(HireStatus.delivered);

    test('rejects feedback for another hire', () {
      expect(
        () => delivered.rate(feedback(hireId: 8)),
        throwsA(isA<FeedbackDoesNotMatchHire>()),
      );
    });

    test('rejects feedback for another agent', () {
      expect(
        () => delivered.rate(feedback(agentId: 1)),
        throwsA(isA<FeedbackDoesNotMatchHire>()),
      );
    });

    test('rejects feedback from someone other than the consumer', () {
      expect(
        () => delivered.rate(feedback(client: stranger)),
        throwsA(isA<FeedbackDoesNotMatchHire>()),
      );
    });
  });
}
