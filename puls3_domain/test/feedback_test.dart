import 'package:puls3_domain/puls3_domain.dart';
import 'package:test/test.dart';

final agentWallet = StellarAddress.parse(
  'GAV3KOEEBJC77IP4T2JT7FDUTQ5Y5GJXTIZGRG4CZFZ3GZX7V6IUPBUK',
);
final consumer = StellarAddress.parse(
  'GCL2Q3PX6FDMF7XMSE7C6UEHYVEER2ZTVIQEJVUSSL4IFQX7YOIZEPOV',
);
final owner = StellarAddress.parse(
  'GBY33NK3HMKQUKHL7YSCJ2W5JMJ62MEVKEJTRUWNQXBQIFLUVZY6TJ4R',
);
final payTx = TransactionHash.parse(
  '17ac14e085609df8e042b84e6c25aac7e1c30344eaa1b1fd0bcbed399b65243f',
);
final feedbackTx = TransactionHash.parse(
  '05724ac7d1e9a5f3b2c4d6e8f0a1b3c5d7e9f1a3b5c7d9e1f3a5b7c9d1e3f5a7',
);

Hire funded() =>
    Hire(
      id: HireId(7),
      agentId: AgentId(0),
      consumer: consumer,
      price: UsdcAmount.stroops(3000000),
      manifestVersion: 1,
    ).fund(
      Payment(
        transaction: payTx,
        hireId: HireId(7),
        payer: consumer,
        payee: agentWallet,
        amount: UsdcAmount.stroops(3000000),
      ),
      agentWallet: agentWallet,
    );

Hire completed() => funded().submit().complete();

Feedback feedbackBy(StellarAddress client, {int score = 4, int hireId = 7}) =>
    Feedback(
      hireId: HireId(hireId),
      agentId: AgentId(0),
      client: client,
      score: score,
    );

final class FakeRegistry implements ReputationRegistry {
  final given = <Feedback>[];

  @override
  Future<TransactionHash> giveFeedback(Feedback feedback) async {
    given.add(feedback);
    return feedbackTx;
  }

  @override
  Future<List<Feedback>> feedbacksOf(AgentId agent) async =>
      given.where((f) => f.agentId == agent).toList();
}

final class FakeOwners implements AgentOwnerReader {
  FakeOwners(this.owner);

  final StellarAddress? owner;

  @override
  Future<StellarAddress?> ownerOf(AgentId agent) async => owner;
}

void main() {
  group('checkHireRateable', () {
    test('accepts a completed, unrated hire from its consumer', () {
      checkHireRateable(
        status: HireStatus.completed,
        rated: false,
        matchesHire: true,
      );
    });

    test('rejects every status but completed', () {
      for (final status in HireStatus.values.where(
        (s) => s != HireStatus.completed,
      )) {
        expect(
          () => checkHireRateable(
            status: status,
            rated: false,
            matchesHire: true,
          ),
          throwsA(
            isA<HireNotCompleted>().having((e) => e.status, 'status', status),
          ),
          reason: status.name,
        );
      }
    });

    test('checks completed before already rated before mismatch', () {
      expect(
        () => checkHireRateable(
          status: HireStatus.funded,
          rated: true,
          matchesHire: false,
        ),
        throwsA(isA<HireNotCompleted>()),
      );
      expect(
        () => checkHireRateable(
          status: HireStatus.completed,
          rated: true,
          matchesHire: false,
        ),
        throwsA(isA<HireAlreadyRated>()),
      );
      expect(
        () => checkHireRateable(
          status: HireStatus.completed,
          rated: false,
          matchesHire: false,
        ),
        throwsA(isA<FeedbackDoesNotMatchHire>()),
      );
    });
  });

  group('checkFeedbackAllowed', () {
    test('rejects the agent owner rating its own agent', () {
      expect(
        () => checkFeedbackAllowed(
          status: HireStatus.completed,
          rated: false,
          matchesHire: true,
          feedback: feedbackBy(owner),
          owner: owner,
        ),
        throwsA(isA<FeedbackFromAgentOwner>()),
      );
    });

    test('accepts a client that is not the owner', () {
      checkFeedbackAllowed(
        status: HireStatus.completed,
        rated: false,
        matchesHire: true,
        feedback: feedbackBy(consumer),
        owner: owner,
      );
    });

    test('hire rules run before the owner rule', () {
      expect(
        () => checkFeedbackAllowed(
          status: HireStatus.funded,
          rated: false,
          matchesHire: true,
          feedback: feedbackBy(owner),
          owner: owner,
        ),
        throwsA(isA<HireNotCompleted>()),
      );
    });
  });

  group('SubmitFeedback', () {
    late FakeRegistry registry;

    SubmitFeedback useCase({StellarAddress? agentOwner}) => SubmitFeedback(
      registry: registry,
      owners: FakeOwners(agentOwner ?? owner),
    );

    setUp(() => registry = FakeRegistry());

    test('happy path: one feedback reaches the registry', () async {
      final rated = await useCase()(completed(), feedbackBy(consumer));

      expect(registry.given, hasLength(1));
      expect(registry.given.single.score, 4);
      expect(rated.feedbackReference, feedbackTx);
      expect(rated.status, HireStatus.completed);
    });

    test(
      'a non-completed hire is rejected and the registry untouched',
      () async {
        for (final status in [HireStatus.open, HireStatus.funded]) {
          final hire = status == HireStatus.open
              ? Hire(
                  id: HireId(7),
                  agentId: AgentId(0),
                  consumer: consumer,
                  price: UsdcAmount.stroops(3000000),
                  manifestVersion: 1,
                )
              : funded();
          await expectLater(
            useCase()(hire, feedbackBy(consumer)),
            throwsA(isA<HireNotCompleted>()),
            reason: status.name,
          );
        }
        expect(registry.given, isEmpty);
      },
    );

    test('a client that is not the consumer is rejected', () async {
      await expectLater(
        useCase()(completed(), feedbackBy(owner)),
        throwsA(isA<FeedbackDoesNotMatchHire>()),
      );
      expect(registry.given, isEmpty);
    });

    test('feedback for another hire is rejected', () async {
      await expectLater(
        useCase()(completed(), feedbackBy(consumer, hireId: 8)),
        throwsA(isA<FeedbackDoesNotMatchHire>()),
      );
      expect(registry.given, isEmpty);
    });

    test('the owner rating its own agent is rejected', () async {
      await expectLater(
        useCase(agentOwner: consumer)(completed(), feedbackBy(consumer)),
        throwsA(isA<FeedbackFromAgentOwner>()),
      );
      expect(registry.given, isEmpty);
    });

    test('a second feedback is rejected and not given', () async {
      final useCaseOnce = useCase();
      final rated = await useCaseOnce(completed(), feedbackBy(consumer));
      await expectLater(
        useCaseOnce(rated, feedbackBy(consumer, score: 5)),
        throwsA(isA<HireAlreadyRated>()),
      );
      expect(registry.given, hasLength(1));
    });

    test('an unknown owner fails closed', () async {
      final unknown = SubmitFeedback(
        registry: registry,
        owners: FakeOwners(null),
      );
      await expectLater(
        unknown(completed(), feedbackBy(consumer)),
        throwsA(isA<AgentOwnerUnavailable>()),
      );
      expect(registry.given, isEmpty);
    });
  });
}
