import 'package:puls3_domain/puls3_domain.dart';
import 'package:test/test.dart';

final owner = StellarAddress.parse(
  'GBY33NK3HMKQUKHL7YSCJ2W5JMJ62MEVKEJTRUWNQXBQIFLUVZY6TJ4R',
);
final agentWallet = StellarAddress.parse(
  'GAV3KOEEBJC77IP4T2JT7FDUTQ5Y5GJXTIZGRG4CZFZ3GZX7V6IUPBUK',
);
final consumer = StellarAddress.parse(
  'GCL2Q3PX6FDMF7XMSE7C6UEHYVEER2ZTVIQEJVUSSL4IFQX7YOIZEPOV',
);
final txHash = TransactionHash.parse(
  '17ac14e085609df8e042b84e6c25aac7e1c30344eaa1b1fd0bcbed399b65243f',
);

Skill skill([String id = 'release-notes']) =>
    Skill(id: id, name: 'Release notes');

Agent agent({
  String name = 'Copy Forge',
  String description = 'Writes landing pages and release notes.',
  List<Skill>? skills,
  UsdcAmount? price,
}) => Agent(
  id: AgentId(0),
  owner: owner,
  wallet: agentWallet,
  name: name,
  description: description,
  skills: skills ?? [skill()],
  price: price ?? UsdcAmount.stroops(3000000),
);

Hire hire({UsdcAmount? price, int manifestVersion = 1, int id = 7}) => Hire(
  id: HireId(id),
  agentId: AgentId(0),
  consumer: consumer,
  price: price ?? UsdcAmount.stroops(3000000),
  manifestVersion: manifestVersion,
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

Matcher problem<E extends DomainError, P>(P expected, P Function(E) read) =>
    throwsA(isA<E>().having(read, 'problem', expected));

void main() {
  group('I6 Skill', () {
    test('accepts a kebab-case id and a name', () {
      final s = Skill(
        id: 'social-thread',
        name: 'Social thread',
        description: 'Up to eight posts.',
        tags: ['social'],
      );
      expect(s.id, 'social-thread');
      expect(s.tags, ['social']);
    });

    test('rejects an id that is not kebab-case', () {
      for (final id in [
        'Release notes',
        'release_notes',
        '-notes',
        'notes-',
        '',
      ]) {
        expect(
          () => Skill(id: id, name: 'Notes'),
          problem<InvalidSkill, SkillProblem>(
            SkillProblem.idNotKebabCase,
            (e) => e.problem,
          ),
          reason: id,
        );
      }
    });

    test('rejects an empty or too long name', () {
      expect(
        () => Skill(id: 'notes', name: ''),
        problem<InvalidSkill, SkillProblem>(
          SkillProblem.nameLength,
          (e) => e.problem,
        ),
      );
      expect(
        () => Skill(id: 'notes', name: 'x' * 49),
        problem<InvalidSkill, SkillProblem>(
          SkillProblem.nameLength,
          (e) => e.problem,
        ),
      );
    });
  });

  group('Agent', () {
    test('a valid agent keeps its fields', () {
      final a = agent();
      expect(a.name, 'Copy Forge');
      expect(a.skills.single.id, 'release-notes');
      expect(a.price, UsdcAmount.stroops(3000000));
    });

    test('its skill list cannot be changed from outside', () {
      final skills = [skill()];
      final a = agent(skills: skills);
      skills.add(skill('extra'));
      expect(a.skills, hasLength(1));
      expect(() => a.skills.add(skill('other')), throwsUnsupportedError);
    });

    test('I7 name is 3 to 48 characters', () {
      expect(agent(name: 'abc').name, 'abc');
      for (final name in ['ab', 'x' * 49]) {
        expect(
          () => agent(name: name),
          problem<InvalidAgent, AgentProblem>(
            AgentProblem.nameLength,
            (e) => e.problem,
          ),
        );
      }
    });

    test('I8 description is 10 to 280 characters', () {
      for (final description in ['too short', 'x' * 281]) {
        expect(
          () => agent(description: description),
          problem<InvalidAgent, AgentProblem>(
            AgentProblem.descriptionLength,
            (e) => e.problem,
          ),
        );
      }
    });

    test('I9 has between 1 and 5 skills', () {
      expect(
        agent(skills: [for (var i = 0; i < 5; i++) skill('s$i')]).skills,
        hasLength(5),
      );
      for (final skills in [
        <Skill>[],
        [for (var i = 0; i < 6; i++) skill('s$i')],
      ]) {
        expect(
          () => agent(skills: skills),
          problem<InvalidAgent, AgentProblem>(
            AgentProblem.skillCount,
            (e) => e.problem,
          ),
        );
      }
    });

    test('I10 skill ids are unique', () {
      expect(
        () => agent(skills: [skill('notes'), skill('notes')]),
        problem<InvalidAgent, AgentProblem>(
          AgentProblem.duplicateSkillId,
          (e) => e.problem,
        ),
      );
    });

    test('I11 price is greater than zero', () {
      expect(
        () => agent(price: UsdcAmount.zero),
        problem<InvalidAgent, AgentProblem>(
          AgentProblem.priceNotPositive,
          (e) => e.problem,
        ),
      );
    });
  });

  group('Hire', () {
    test('a valid hire keeps its fields', () {
      final h = hire();
      expect(h.id, HireId(7));
      expect(h.manifestVersion, 1);
    });

    test('I12 price is greater than zero', () {
      expect(
        () => hire(price: UsdcAmount.zero),
        problem<InvalidHire, HireProblem>(
          HireProblem.priceNotPositive,
          (e) => e.problem,
        ),
      );
    });

    test('I13 manifest version is at least 1', () {
      expect(
        () => hire(manifestVersion: 0),
        problem<InvalidHire, HireProblem>(
          HireProblem.manifestVersionBelowOne,
          (e) => e.problem,
        ),
      );
    });
  });

  group('Payment', () {
    test('I14 amount is greater than zero', () {
      expect(() => payment(stroops: 0), throwsA(isA<InvalidPayment>()));
    });

    test('I15 settles a hire when hire id, payee and exact amount match', () {
      expect(payment().settles(hire(), agentWallet: agentWallet), isTrue);
    });

    test('I15 does not settle another hire', () {
      expect(
        payment(hireId: 8).settles(hire(), agentWallet: agentWallet),
        isFalse,
      );
    });

    test('I15 does not settle when paid to someone else', () {
      expect(
        payment(payee: consumer).settles(hire(), agentWallet: agentWallet),
        isFalse,
      );
    });

    test('I15 does not settle with a different amount', () {
      expect(
        payment(stroops: 2999999).settles(hire(), agentWallet: agentWallet),
        isFalse,
      );
      expect(
        payment(stroops: 3000001).settles(hire(), agentWallet: agentWallet),
        isFalse,
      );
    });
  });

  group('Feedback', () {
    Feedback feedback({int score = 5, String comment = ''}) => Feedback(
      hireId: HireId(7),
      agentId: AgentId(0),
      client: consumer,
      score: score,
      comment: comment,
    );

    test('a valid feedback keeps its fields', () {
      expect(feedback(score: 1).score, 1);
      expect(feedback(comment: 'x' * 500).comment, hasLength(500));
    });

    test('I16 score is from 1 to 5', () {
      for (final score in [0, 6, -1]) {
        expect(
          () => feedback(score: score),
          problem<InvalidFeedback, FeedbackProblem>(
            FeedbackProblem.scoreOutOfRange,
            (e) => e.problem,
          ),
        );
      }
    });

    test('I17 comment is at most 500 characters', () {
      expect(
        () => feedback(comment: 'x' * 501),
        problem<InvalidFeedback, FeedbackProblem>(
          FeedbackProblem.commentTooLong,
          (e) => e.problem,
        ),
      );
    });
  });
}
