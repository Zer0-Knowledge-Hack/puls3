import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;
import 'package:test/test.dart';

/// One feedback entry as the chain holds it.
typedef SeededFeedback = ({
  AgentId agent,
  StellarAddress client,
  int score,
  bool revoked,
});

/// The backing store of a [ReputationRegistry] under test: it lets the shared
/// suite put feedback where the implementation reads it, and break the read.
abstract interface class ReputationRegistryRig {
  ReputationRegistry get registry;

  /// Records [entry] the way the registry would hold it.
  void seed(SeededFeedback entry);

  /// Makes every later read fail, as an unreachable registry would.
  void breakReads();
}

/// Builds a fresh rig. Called inside each test body.
typedef ReputationRegistryRigFactory = ReputationRegistryRig Function();

final _alice = StellarAddress.parse(
  'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H',
);
final _bob = StellarAddress.parse(
  'GCHX6NRPMSB4CIZM3ZLHPOC2VD6DJVAN6IY3NE5QSAMOWJ7N4TAWK6HN',
);

SeededFeedback _entry(
  int agent,
  StellarAddress client,
  int score, {
  bool revoked = false,
}) => (agent: AgentId(agent), client: client, score: score, revoked: revoked);

/// The behavior every [ReputationRegistry] shares for reads: what the catalog
/// reputation (#21) is computed from. Run it from a `group` with the fake and
/// with the Soroban adapter over a scripted RPC.
///
/// `giveFeedback` is not part of it: the server never signs, it relays the
/// wallet-signed `give_feedback` (ReputationCalls), so the port has no
/// working write in production.
void reputationRegistryContract(ReputationRegistryRigFactory build) {
  late ReputationRegistryRig rig;

  setUp(() => rig = build());

  group('feedbacksOf', () {
    test('an agent without feedback has none', () async {
      expect(await rig.registry.feedbacksOf(AgentId(7)), isEmpty);
    });

    test('returns every score of the agent, with its client', () async {
      rig
        ..seed(_entry(7, _alice, 5))
        ..seed(_entry(7, _bob, 3));

      final feedback = await rig.registry.feedbacksOf(AgentId(7));

      expect(feedback.map((f) => (f.client, f.score)).toSet(), {
        (_alice, 5),
        (_bob, 3),
      });
      expect(feedback.every((f) => f.agentId == AgentId(7)), isTrue);
    });

    test('keeps several scores of one client', () async {
      rig
        ..seed(_entry(7, _alice, 5))
        ..seed(_entry(7, _alice, 2));

      final feedback = await rig.registry.feedbacksOf(AgentId(7));

      expect(feedback.map((f) => f.score), unorderedEquals([5, 2]));
    });

    test('does not return the feedback of another agent', () async {
      rig
        ..seed(_entry(7, _alice, 5))
        ..seed(_entry(8, _alice, 1));

      final feedback = await rig.registry.feedbacksOf(AgentId(8));

      expect(feedback.map((f) => f.score), [1]);
    });

    test('leaves out revoked feedback', () async {
      rig
        ..seed(_entry(7, _alice, 5, revoked: true))
        ..seed(_entry(7, _bob, 4));

      final feedback = await rig.registry.feedbacksOf(AgentId(7));

      expect(feedback.map((f) => f.score), [4]);
    });

    test('a read failure is an error, never an empty list', () async {
      rig
        ..seed(_entry(7, _alice, 5))
        ..breakReads();

      await expectLater(
        rig.registry.feedbacksOf(AgentId(7)),
        throwsA(isA<Exception>()),
      );
    });
  });
}
