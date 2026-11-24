import 'package:puls3_domain/puls3_domain.dart';
import 'package:test/test.dart';

const _ownerA = 'owner-a';
const _ownerB = 'owner-b';
const _ownerC = 'owner-c';

AgentListing listing(
  int registryId, {
  String? name,
  String description = '',
  List<String> skills = const ['translation'],
  int price = 1000000,
  String? wallet,
  double rating = reputationPriorMean,
  int paidHireCount = 0,
  bool hireable = true,
}) => AgentListing(
  id: 'agt-$registryId',
  registryId: registryId,
  name: name ?? 'Agent $registryId',
  description: description,
  skills: skills,
  priceStroops: price,
  wallet: wallet ?? 'wallet-$registryId',
  rating: rating,
  paidHireCount: paidHireCount,
  hireable: hireable,
);

AgentSearchRequest request({
  int hiringAgent = 1,
  Set<int> ancestorAgents = const {},
  Set<String> ancestorWallets = const {},
  int remainingReserve = 5000000,
  bool allowRelatedParty = true,
  String query = '',
  List<String> skills = const [],
  int? limit,
}) => AgentSearchRequest(
  hiringAgent: hiringAgent,
  ancestorAgents: ancestorAgents,
  ancestorWallets: ancestorWallets,
  remainingReserveStroops: remainingReserve,
  allowRelatedParty: allowRelatedParty,
  query: query,
  skills: skills,
  limit: limit,
);

/// Agent 1 (the hiring agent) is owned by [_ownerA]; every other agent is
/// independent unless a test says otherwise.
Map<int, Set<String>> owners([Map<int, Set<String>> extra = const {}]) => {
  1: {_ownerA},
  for (var id = 2; id < 20; id++) id: {_ownerB},
  ...extra,
};

List<int> ids(List<AgentCandidate> candidates) => [
  for (final candidate in candidates) candidate.registryId,
];

void main() {
  group('rankAgentCandidates filters', () {
    test('drops agents that are not hireable', () {
      final result = rankAgentCandidates(
        [listing(2), listing(3, hireable: false)],
        request(),
        owners: owners(),
      );
      expect(ids(result), [2]);
    });

    test('drops agents priced above the remaining reserve, keeps equal', () {
      final result = rankAgentCandidates(
        [listing(2, price: 5000000), listing(3, price: 5000001)],
        request(remainingReserve: 5000000),
        owners: owners(),
      );
      expect(ids(result), [2]);
    });

    test('drops the hiring agent itself', () {
      final result = rankAgentCandidates(
        [listing(1), listing(2)],
        request(),
        owners: owners(),
      );
      expect(ids(result), [2]);
    });

    test('drops every ancestor by agent id, at any depth', () {
      final result = rankAgentCandidates(
        [listing(2), listing(3), listing(4)],
        request(ancestorAgents: {2, 3}),
        owners: owners(),
      );
      expect(ids(result), [4]);
    });

    test('drops an agent whose wallet is an ancestor provider wallet', () {
      final result = rankAgentCandidates(
        [listing(2, wallet: 'wallet-root'), listing(3)],
        request(ancestorWallets: {'wallet-root'}),
        owners: owners(),
      );
      expect(ids(result), [3]);
    });

    test('drops related parties only when the consumer opted out', () {
      final agents = [listing(2), listing(3)];
      final sameOwner = owners({
        3: {_ownerA},
      });

      final allowed = rankAgentCandidates(
        agents,
        request(),
        owners: sameOwner,
      );
      expect(ids(allowed), [2, 3]);
      expect(
        allowed.firstWhere((c) => c.registryId == 3).isRelatedParty,
        isTrue,
      );
      expect(
        allowed.firstWhere((c) => c.registryId == 2).isRelatedParty,
        isFalse,
      );

      final optedOut = rankAgentCandidates(
        agents,
        request(allowRelatedParty: false),
        owners: sameOwner,
      );
      expect(ids(optedOut), [2]);
    });

    test('any shared owner makes a related party', () {
      final result = rankAgentCandidates(
        [listing(2)],
        request(),
        owners: owners({
          1: {_ownerA, _ownerC},
          2: {_ownerB, _ownerC},
        }),
      );
      expect(result.single.isRelatedParty, isTrue);
    });

    test('applies the limit after ranking', () {
      final result = rankAgentCandidates(
        [listing(2, rating: 3), listing(3, rating: 5), listing(4, rating: 4)],
        request(limit: 2),
        owners: owners(),
      );
      expect(ids(result), [3, 4]);
      expect([for (final c in result) c.rank], [1, 2]);
    });
  });

  group('rankAgentCandidates degraded ownership', () {
    test('a candidate with unknown owners is treated as related', () {
      final result = rankAgentCandidates(
        [listing(2), listing(3)],
        request(),
        owners: {
          1: {_ownerA},
          2: {_ownerB},
          3: <String>{},
        },
      );
      final unknown = result.firstWhere((c) => c.registryId == 3);
      expect(unknown.isRelatedParty, isTrue);
      expect(unknown.ownershipKnown, isFalse);
      expect(
        result.firstWhere((c) => c.registryId == 2).ownershipKnown,
        isTrue,
      );
    });

    test('unknown owners are filtered out when the consumer opted out', () {
      final result = rankAgentCandidates(
        [listing(2), listing(3)],
        request(allowRelatedParty: false),
        owners: {
          1: {_ownerA},
          2: {_ownerB},
        },
      );
      expect(ids(result), [2]);
    });

    test('an unknown hiring-agent owner makes every candidate related', () {
      final result = rankAgentCandidates(
        [listing(2), listing(3)],
        request(),
        owners: {
          2: {_ownerB},
          3: {_ownerC},
        },
      );
      expect(
        result.every((c) => c.isRelatedParty && !c.ownershipKnown),
        isTrue,
      );
      expect(
        rankAgentCandidates(
          [listing(2)],
          request(allowRelatedParty: false),
          owners: {
            2: {_ownerB},
          },
        ),
        isEmpty,
      );
    });
  });

  group('agentSkillMatch', () {
    test('is 0 with no query and no skills', () {
      expect(agentSkillMatch(listing(2), query: '', skills: const []), 0);
    });

    test('scores requested skills as the matched fraction', () {
      final agent = listing(2, skills: ['translation', 'legal-review']);
      expect(
        agentSkillMatch(
          agent,
          query: '',
          skills: const ['Translation', 'summarization'],
        ),
        0.5,
      );
    });

    test('scores query terms against name, description and skill words', () {
      final agent = listing(
        2,
        name: 'Contract Reader',
        description: 'Reviews legal documents.',
        skills: ['legal-review'],
      );
      expect(
        agentSkillMatch(agent, query: 'legal contract', skills: const []),
        1.0,
      );
      expect(
        agentSkillMatch(agent, query: 'legal poetry', skills: const []),
        0.5,
      );
    });

    test('weights skills 0.6 and query 0.4 when both are given', () {
      final agent = listing(2, skills: ['translation']);
      expect(
        agentSkillMatch(
          agent,
          query: 'poetry',
          skills: const ['translation'],
        ),
        closeTo(0.6, 1e-9),
      );
    });
  });

  group('rankAgentCandidates ranking', () {
    test('skill match dominates a better rating', () {
      final result = rankAgentCandidates(
        [
          listing(2, skills: ['poetry'], rating: 5, paidHireCount: 50),
          listing(3, skills: ['translation'], rating: 3),
        ],
        request(skills: ['translation']),
        owners: owners(),
      );
      expect(ids(result), [3, 2]);
    });

    test('with equal skill match, hires, rating and price order it', () {
      final result = rankAgentCandidates(
        [
          listing(2, rating: 4),
          listing(3, rating: 4.5),
          listing(4, rating: 4, paidHireCount: 20),
          listing(5, rating: 4, price: 500000),
        ],
        request(),
        owners: owners(),
      );
      expect(ids(result), [4, 3, 5, 2]);
    });

    test('ties break on the lowest registry id', () {
      final result = rankAgentCandidates(
        [listing(9), listing(4), listing(7)],
        request(),
        owners: owners(),
      );
      expect(ids(result), [4, 7, 9]);
      expect([for (final c in result) c.rank], [1, 2, 3]);
    });

    test('a zero reserve keeps free agents and scores price as best', () {
      final result = rankAgentCandidates(
        [listing(2, price: 0), listing(3, price: 1)],
        request(remainingReserve: 0),
        owners: owners(),
      );
      expect(ids(result), [2]);
      expect(result.single.score, isNot(isNaN));
    });

    test('a candidate carries the listing data and its scores', () {
      final result = rankAgentCandidates(
        [
          listing(
            2,
            name: 'Translator',
            skills: ['translation'],
            price: 2500000,
            rating: 4.5,
            paidHireCount: 10,
          ),
        ],
        request(skills: ['translation']),
        owners: owners(),
      );
      final candidate = result.single;
      expect(candidate.id, 'agt-2');
      expect(candidate.registryId, 2);
      expect(candidate.name, 'Translator');
      expect(candidate.skills, ['translation']);
      expect(candidate.priceStroops, 2500000);
      expect(candidate.rating, 4.5);
      expect(candidate.paidHireCount, 10);
      expect(candidate.skillMatch, 1.0);
      expect(candidate.rank, 1);
      expect(candidate.isRelatedParty, isFalse);
      // 0.5 * 1 + 0.25 * (3.5 / 4) + 0.15 * (10 / 20) + 0.10 * (1 - 0.5)
      expect(candidate.score, closeTo(0.84375, 1e-6));
    });
  });

  group('justifyRelatedPartyPick', () {
    AgentCandidate candidate(
      int registryId, {
      required int rank,
      double skillMatch = 1,
      int price = 1000000,
      bool related = false,
    }) => AgentCandidate(
      id: 'agt-$registryId',
      registryId: registryId,
      name: 'Agent $registryId',
      skills: const ['translation'],
      priceStroops: price,
      rating: reputationPriorMean,
      paidHireCount: 0,
      skillMatch: skillMatch,
      score: 1 - rank / 10,
      rank: rank,
      isRelatedParty: related,
      ownershipKnown: true,
    );

    test('an independent pick needs no justification', () {
      final ranked = [candidate(2, rank: 1), candidate(3, rank: 2)];
      expect(
        justifyRelatedPartyPick(3, ranked),
        RelatedPartyJustification.independent,
      );
    });

    test('a top-ranked related pick is justified', () {
      final ranked = [
        candidate(2, rank: 1, related: true, price: 9000000),
        candidate(3, rank: 2),
      ];
      expect(
        justifyRelatedPartyPick(2, ranked),
        RelatedPartyJustification.topRanked,
      );
    });

    test('a related pick no pricier than the best comparable independent', () {
      final ranked = [
        candidate(3, rank: 1, price: 2000000),
        candidate(2, rank: 2, related: true, price: 2000000),
      ];
      expect(
        justifyRelatedPartyPick(2, ranked),
        RelatedPartyJustification.notPricierThanIndependent,
      );
    });

    test('a related pick pricier than a comparable independent is refused', () {
      final ranked = [
        candidate(3, rank: 1, price: 2000000, skillMatch: 0.95),
        candidate(2, rank: 2, related: true, price: 2000001),
      ];
      expect(
        justifyRelatedPartyPick(2, ranked),
        RelatedPartyJustification.refused,
      );
    });

    test(
      'the tolerance edge: an independent 0.1 below is still comparable',
      () {
        final ranked = [
          candidate(4, rank: 1, related: true),
          candidate(3, rank: 2, price: 1000000, skillMatch: 0.7),
          candidate(2, rank: 3, related: true, price: 3000000, skillMatch: 0.8),
        ];
        expect(
          justifyRelatedPartyPick(2, ranked),
          RelatedPartyJustification.refused,
        );
      },
    );

    test('compares with the best-ranked comparable independent only', () {
      final ranked = [
        candidate(4, rank: 1, related: true),
        candidate(5, rank: 2, price: 3000000),
        candidate(2, rank: 3, related: true, price: 3000000),
        candidate(6, rank: 4, price: 100),
      ];
      expect(
        justifyRelatedPartyPick(2, ranked),
        RelatedPartyJustification.notPricierThanIndependent,
      );
    });

    test('no comparable independent justifies the pick', () {
      final ranked = [
        candidate(4, rank: 1, related: true),
        candidate(3, rank: 2, price: 1, skillMatch: 0.5),
        candidate(2, rank: 3, related: true, price: 9000000, skillMatch: 0.9),
      ];
      expect(
        justifyRelatedPartyPick(2, ranked),
        RelatedPartyJustification.noComparableIndependent,
      );
    });

    test('a pick that is not a candidate is refused', () {
      expect(
        justifyRelatedPartyPick(42, [candidate(2, rank: 1)]),
        RelatedPartyJustification.notACandidate,
      );
    });

    test('justified values say so', () {
      expect(RelatedPartyJustification.refused.accepted, isFalse);
      expect(RelatedPartyJustification.notACandidate.accepted, isFalse);
      expect(RelatedPartyJustification.topRanked.accepted, isTrue);
    });
  });
}
