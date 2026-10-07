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
final feedbackTx = TransactionHash.parse(
  '05724ac7d1e9a5f3b2c4d6e8f0a1b3c5d7e9f1a3b5c7d9e1f3a5b7c9d1e3f5a7',
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
  HireEvent.fund => hire.fund(payment(), agentWallet: agentWallet),
  HireEvent.submit => hire.submit(),
  HireEvent.complete => hire.complete(),
  HireEvent.reject => hire.reject(),
  HireEvent.expire => hire.expire(),
};

/// A hire in [status], reached only through valid transitions.
Hire inState(HireStatus status) => switch (status) {
  HireStatus.open => newHire(),
  HireStatus.funded => fire(newHire(), HireEvent.fund),
  HireStatus.submitted => inState(HireStatus.funded).submit(),
  HireStatus.completed => inState(HireStatus.submitted).complete(),
  HireStatus.rejected => inState(HireStatus.submitted).reject(),
  HireStatus.expired => inState(HireStatus.funded).expire(),
};

/// The transition table of docs/domain/hire-lifecycle.md (ADR-0005 D6).
const table = <(HireStatus, HireEvent, HireStatus)>[
  (HireStatus.open, HireEvent.fund, HireStatus.funded),
  (HireStatus.open, HireEvent.reject, HireStatus.rejected),
  (HireStatus.open, HireEvent.expire, HireStatus.expired),
  (HireStatus.funded, HireEvent.submit, HireStatus.submitted),
  (HireStatus.funded, HireEvent.reject, HireStatus.rejected),
  (HireStatus.funded, HireEvent.expire, HireStatus.expired),
  (HireStatus.submitted, HireEvent.complete, HireStatus.completed),
  (HireStatus.submitted, HireEvent.reject, HireStatus.rejected),
];

const terminal = [
  HireStatus.completed,
  HireStatus.rejected,
  HireStatus.expired,
];

Matcher invalidTransition(HireStatus from, HireEvent event) => throwsA(
  isA<InvalidHireTransition>()
      .having((e) => e.from, 'from', from)
      .having((e) => e.event, 'event', event),
);

Matcher invalidRunUpdate(HireStatus status, RuntimeStatus? runtime) => throwsA(
  isA<InvalidRuntimeTransition>()
      .having((e) => e.status, 'status', status)
      .having((e) => e.runtimeStatus, 'runtimeStatus', runtime),
);

void main() {
  test('HireStatus has exactly the ERC-8183 states, in order', () {
    expect(HireStatus.values.map((s) => s.name), [
      'open',
      'funded',
      'submitted',
      'completed',
      'rejected',
      'expired',
    ]);
  });

  test('HireEvent has exactly the ERC-8183 transitions', () {
    expect(HireEvent.values.map((e) => e.name), [
      'fund',
      'submit',
      'complete',
      'reject',
      'expire',
    ]);
  });

  test('RuntimeStatus is separate from HireStatus', () {
    expect(RuntimeStatus.values.map((s) => s.name), [
      'queued',
      'running',
      'failed',
    ]);
  });

  test('a new hire starts open, with no payment or hire data', () {
    final hire = newHire();
    expect(hire.status, HireStatus.open);
    expect(hire.paymentTransaction, isNull);
    expect(hire.runtimeStatus, isNull);
    expect(hire.failureReason, isNull);
    expect(hire.rejectedFrom, isNull);
    expect(hire.feedbackReference, isNull);
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
        expect(after.consumer, before.consumer);
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

    test('a submitted hire cannot expire (ADR-0005 D4)', () {
      expect(
        () => inState(HireStatus.submitted).expire(),
        invalidTransition(HireStatus.submitted, HireEvent.expire),
      );
    });
  });

  group('I18 terminal states accept no further transitions', () {
    for (final status in terminal) {
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
        HireStatus.open,
        HireStatus.funded,
        HireStatus.submitted,
      ]) {
        expect(status.isTerminal, isFalse, reason: '$status');
      }
    });
  });

  group('I19 funded is reached only with a payment reference', () {
    test('fund records the payment transaction hash', () {
      expect(inState(HireStatus.funded).paymentTransaction, txHash);
    });

    test('the transaction hash is kept in every later state', () {
      for (final hire in [
        inState(HireStatus.submitted),
        inState(HireStatus.completed),
        inState(HireStatus.rejected),
        inState(HireStatus.expired),
      ]) {
        expect(hire.paymentTransaction, txHash, reason: '${hire.status}');
      }
    });

    test('a hire rejected or expired while open never had a payment', () {
      expect(newHire().reject().paymentTransaction, isNull);
      expect(newHire().expire().paymentTransaction, isNull);
    });

    test('fund rejects a payment for another hire', () {
      expect(
        () => newHire().fund(payment(hireId: 8), agentWallet: agentWallet),
        throwsA(isA<PaymentDoesNotSettleHire>()),
      );
    });

    test('fund rejects a payment to another provider', () {
      expect(
        () =>
            newHire().fund(payment(payee: stranger), agentWallet: agentWallet),
        throwsA(isA<PaymentDoesNotSettleHire>()),
      );
    });

    test('fund rejects a payment with a different amount', () {
      for (final stroops in [2999999, 3000001]) {
        expect(
          () => newHire().fund(
            payment(stroops: stroops),
            agentWallet: agentWallet,
          ),
          throwsA(isA<PaymentDoesNotSettleHire>()),
          reason: '$stroops',
        );
      }
    });

    test('fund rejects a payment made by someone other than the consumer', () {
      final fromStranger = Payment(
        transaction: txHash,
        hireId: HireId(7),
        payer: stranger,
        payee: agentWallet,
        amount: price,
      );
      expect(
        () => newHire().fund(fromStranger, agentWallet: agentWallet),
        throwsA(isA<PaymentNotFromConsumer>()),
      );
    });

    test('a rejected payment leaves the hire open', () {
      final hire = newHire();
      expect(
        () => hire.fund(payment(hireId: 8), agentWallet: agentWallet),
        throwsA(isA<PaymentDoesNotSettleHire>()),
      );
      expect(hire.status, HireStatus.open);
      expect(hire.paymentTransaction, isNull);
    });
  });

  group('reject records the state it came from (D6, D8)', () {
    for (final from in [
      HireStatus.open,
      HireStatus.funded,
      HireStatus.submitted,
    ]) {
      test('reject from $from', () {
        final rejected = inState(from).reject();
        expect(rejected.status, HireStatus.rejected);
        expect(rejected.rejectedFrom, from);
      });
    }

    test('rejectedFrom stays null for completed and expired hires', () {
      expect(inState(HireStatus.completed).rejectedFrom, isNull);
      expect(inState(HireStatus.expired).rejectedFrom, isNull);
    });
  });

  group('runtime progress is hire data, not a hire state', () {
    test('fund queues the run', () {
      final funded = inState(HireStatus.funded);
      expect(funded.runtimeStatus, RuntimeStatus.queued);
      expect(funded.status, HireStatus.funded);
    });

    test('startRun moves queued to running and keeps the hire funded', () {
      final running = inState(HireStatus.funded).startRun();
      expect(running.runtimeStatus, RuntimeStatus.running);
      expect(running.status, HireStatus.funded);
    });

    test('failRun records the reason and keeps the hire funded', () {
      for (final hire in [
        inState(HireStatus.funded),
        inState(HireStatus.funded).startRun(),
      ]) {
        final failed = hire.failRun(reason: 'model timeout');
        expect(failed.runtimeStatus, RuntimeStatus.failed);
        expect(failed.failureReason, 'model timeout');
        expect(failed.status, HireStatus.funded);
      }
    });

    test('a failed run can still be rejected or expire, and keeps its '
        'reason', () {
      final failed = inState(HireStatus.funded).failRun(reason: 'crash');
      final rejected = failed.reject();
      expect(rejected.rejectedFrom, HireStatus.funded);
      expect(rejected.failureReason, 'crash');
      expect(failed.expire().status, HireStatus.expired);
    });

    test('startRun is refused unless the run is queued', () {
      final running = inState(HireStatus.funded).startRun();
      expect(
        running.startRun,
        invalidRunUpdate(HireStatus.funded, RuntimeStatus.running),
      );
      final failed = inState(HireStatus.funded).failRun(reason: 'crash');
      expect(
        failed.startRun,
        invalidRunUpdate(HireStatus.funded, RuntimeStatus.failed),
      );
    });

    test('failRun is refused once the run already failed', () {
      final failed = inState(HireStatus.funded).failRun(reason: 'crash');
      expect(
        () => failed.failRun(reason: 'again'),
        invalidRunUpdate(HireStatus.funded, RuntimeStatus.failed),
      );
    });

    test('runtime updates are refused outside funded', () {
      for (final status in HireStatus.values) {
        if (status == HireStatus.funded) continue;
        final hire = inState(status);
        expect(
          hire.startRun,
          invalidRunUpdate(status, hire.runtimeStatus),
          reason: '$status startRun',
        );
        expect(
          () => hire.failRun(reason: 'crash'),
          invalidRunUpdate(status, hire.runtimeStatus),
          reason: '$status failRun',
        );
      }
    });

    test('failRun rejects a blank or empty reason', () {
      for (final reason in ['', '   ']) {
        expect(
          () => inState(HireStatus.funded).failRun(reason: reason),
          throwsA(
            isA<InvalidHire>().having(
              (e) => e.problem,
              'problem',
              HireProblem.failureReasonEmpty,
            ),
          ),
          reason: '"$reason"',
        );
      }
    });
  });

  group('I20 feedback is hire data, recorded only on completed hires', () {
    final completed = inState(HireStatus.completed);

    test('recordFeedback stores the reference without changing state', () {
      final rated = completed.recordFeedback(
        feedback(),
        reference: feedbackTx,
      );
      expect(rated.status, HireStatus.completed);
      expect(rated.feedbackReference, feedbackTx);
      expect(rated.paymentTransaction, txHash);
      expect(completed.feedbackReference, isNull);
    });

    test('a hire is rated at most once', () {
      final rated = completed.recordFeedback(
        feedback(),
        reference: feedbackTx,
      );
      expect(
        () => rated.recordFeedback(feedback(), reference: feedbackTx),
        throwsA(isA<HireAlreadyRated>()),
      );
    });

    test('only a completed hire can be rated', () {
      for (final status in HireStatus.values) {
        if (status == HireStatus.completed) continue;
        expect(
          () => inState(
            status,
          ).recordFeedback(feedback(), reference: feedbackTx),
          throwsA(
            isA<HireNotCompleted>().having((e) => e.status, 'status', status),
          ),
          reason: '$status',
        );
      }
    });

    test('rejects feedback for another hire', () {
      expect(
        () => completed.recordFeedback(
          feedback(hireId: 8),
          reference: feedbackTx,
        ),
        throwsA(isA<FeedbackDoesNotMatchHire>()),
      );
    });

    test('rejects feedback for another agent', () {
      expect(
        () => completed.recordFeedback(
          feedback(agentId: 1),
          reference: feedbackTx,
        ),
        throwsA(isA<FeedbackDoesNotMatchHire>()),
      );
    });

    test('rejects feedback from someone other than the consumer', () {
      expect(
        () => completed.recordFeedback(
          feedback(client: stranger),
          reference: feedbackTx,
        ),
        throwsA(isA<FeedbackDoesNotMatchHire>()),
      );
    });
  });
}
