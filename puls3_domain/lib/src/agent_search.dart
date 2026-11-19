/// Marketplace search for agent subcontracting (ADR-0011 D9, D10).
///
/// Pure filter and ranking rules over data the server supplies: the catalog
/// listings, the hiring agent's ancestor chain and the owners of every agent.
/// The model sees the ranked list and chooses from it; it cannot reorder or
/// add candidates.
library;

/// Weight of the skill match in [AgentCandidate.score].
const double searchSkillWeight = 0.50;

/// Weight of the normalized Bayesian rating (ADR-0008) in the score.
const double searchRatingWeight = 0.25;

/// Weight of the saturating paid hire count in the score.
const double searchHiresWeight = 0.15;

/// Weight of the price, cheaper being better, in the score.
const double searchPriceWeight = 0.10;

/// The paid hire count that scores half of [searchHiresWeight]. The hire term
/// is `hires / (hires + searchHiresHalfPoint)`, so it saturates instead of
/// letting one very busy agent dominate.
const int searchHiresHalfPoint = 10;

/// Share of the skill match taken from the requested skills when both
/// skills and a free-text query are given; the query gets the rest.
const double searchSkillsShare = 0.6;

/// How far below a related-party pick's skill match an independent candidate
/// may be and still count as a comparable alternative (D10): an independent
/// with `skillMatch >= pick.skillMatch - relatedPartySkillTolerance` is
/// comparable. An independent with a better match is always comparable.
const double relatedPartySkillTolerance = 0.10;

const double _epsilon = 1e-9;

/// One catalog agent, as the search reads it.
final class AgentListing {
  const AgentListing({
    required this.id,
    required this.registryId,
    required this.name,
    required this.description,
    required this.skills,
    required this.priceStroops,
    required this.wallet,
    required this.rating,
    required this.paidHireCount,
    required this.hireable,
  });

  /// The metadata id, for example `agt-001`.
  final String id;

  /// The identity registry id.
  final int registryId;
  final String name;
  final String description;

  /// Skill ids in kebab-case.
  final List<String> skills;

  /// The current price of one hire in USDC stroops.
  final int priceStroops;

  /// The provider wallet that receives payments, when registered.
  final String? wallet;

  /// The Bayesian rating from 1 to 5 (ADR-0008).
  final double rating;
  final int paidHireCount;

  /// Whether the server can deliver a hire of the agent: custodied wallet and
  /// a published version, which is what "active" means for the server.
  final bool hireable;
}

/// What a hiring agent asks the marketplace for.
final class AgentSearchRequest {
  const AgentSearchRequest({
    required this.hiringAgent,
    required this.ancestorAgents,
    required this.ancestorWallets,
    required this.remainingReserveStroops,
    required this.allowRelatedParty,
    required this.query,
    this.skills = const [],
    this.limit,
  });

  /// The registry id of the agent that subcontracts (A).
  final int hiringAgent;

  /// Registry ids of every agent above A in its hire chain (D5).
  final Set<int> ancestorAgents;

  /// Provider wallets of A and of every agent above it (D5).
  final Set<String> ancestorWallets;

  /// USDC stroops left in the reserve that would fund the child.
  final int remainingReserveStroops;

  /// The consumer's related-party opt-out (D10); false filters them out.
  final bool allowRelatedParty;

  /// Free text describing the subtask.
  final String query;

  /// Skill ids the subtask needs, matched case-insensitively.
  final List<String> skills;

  /// At most this many candidates, after ranking; null keeps all.
  final int? limit;
}

/// One ranked candidate of a search.
final class AgentCandidate {
  const AgentCandidate({
    required this.id,
    required this.registryId,
    required this.name,
    required this.skills,
    required this.priceStroops,
    required this.rating,
    required this.paidHireCount,
    required this.skillMatch,
    required this.score,
    required this.rank,
    required this.isRelatedParty,
    required this.ownershipKnown,
  });

  final String id;
  final int registryId;
  final String name;
  final List<String> skills;
  final int priceStroops;
  final double rating;
  final int paidHireCount;

  /// [agentSkillMatch] of the agent, from 0 to 1.
  final double skillMatch;

  /// The objective score the ranking sorts by, from 0 to 1.
  final double score;

  /// 1 for the best candidate.
  final int rank;

  /// Whether the agent shares an owner with the hiring agent, or its
  /// ownership could not be established (see [ownershipKnown]).
  final bool isRelatedParty;

  /// False when the owners of the candidate or of the hiring agent are
  /// unknown; such a candidate is treated as related (fail closed).
  final bool ownershipKnown;
}

/// The candidates of [agents] for [request], ranked by [AgentCandidate.score]
/// descending, then by lowest registry id.
///
/// Filters: the agent is hireable, priced within the remaining reserve, is not
/// the hiring agent nor an ancestor (by registry id or provider wallet), and is
/// not a related party when the consumer opted out.
///
/// [owners] maps a registry id to the addresses that own it (Studio deploy
/// owner, custody owner, registry owner). A missing or empty entry means the
/// owners are unknown; an unknown candidate, or an unknown hiring agent, makes
/// the candidate a related party, so an opt-out excludes it and a pick of it
/// must pass [justifyRelatedPartyPick].
///
/// The score is
/// `0.50 * skillMatch + 0.25 * (rating - 1) / 4
///  + 0.15 * hires / (hires + 10) + 0.10 * (1 - price / reserve)`,
/// each term in 0..1 (price term 1 when the reserve is 0).
List<AgentCandidate> rankAgentCandidates(
  List<AgentListing> agents,
  AgentSearchRequest request, {
  required Map<int, Set<String>> owners,
}) {
  final hiringOwners = owners[request.hiringAgent] ?? const <String>{};
  final scored =
      <
        ({
          AgentListing agent,
          double match,
          double score,
          bool related,
          bool known,
        })
      >[];
  for (final agent in agents) {
    if (!isSubcontractEligible(agent, request)) continue;
    final candidateOwners = owners[agent.registryId] ?? const <String>{};
    final known = hiringOwners.isNotEmpty && candidateOwners.isNotEmpty;
    final related = !known || candidateOwners.any(hiringOwners.contains);
    if (related && !request.allowRelatedParty) continue;

    final match = agentSkillMatch(
      agent,
      query: request.query,
      skills: request.skills,
    );
    scored.add((
      agent: agent,
      match: match,
      score: _score(agent, match, request.remainingReserveStroops),
      related: related,
      known: known,
    ));
  }
  scored.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0
        ? byScore
        : a.agent.registryId.compareTo(b.agent.registryId);
  });
  final limit = request.limit;
  final kept = limit == null || limit >= scored.length
      ? scored
      : scored.sublist(0, limit < 0 ? 0 : limit);
  return [
    for (var i = 0; i < kept.length; i++)
      AgentCandidate(
        id: kept[i].agent.id,
        registryId: kept[i].agent.registryId,
        name: kept[i].agent.name,
        skills: List.unmodifiable(kept[i].agent.skills),
        priceStroops: kept[i].agent.priceStroops,
        rating: kept[i].agent.rating,
        paidHireCount: kept[i].agent.paidHireCount,
        skillMatch: kept[i].match,
        score: kept[i].score,
        rank: i + 1,
        isRelatedParty: kept[i].related,
        ownershipKnown: kept[i].known,
      ),
  ];
}

/// Whether [agent] passes the ownership-free filters of [request]: hireable,
/// priced within the remaining reserve, and neither the hiring agent nor an
/// ancestor by registry id or provider wallet (D5, D9). The server uses it to
/// read owners only for agents that can still be candidates.
bool isSubcontractEligible(AgentListing agent, AgentSearchRequest request) {
  if (!agent.hireable) return false;
  if (agent.priceStroops < 0 ||
      agent.priceStroops > request.remainingReserveStroops) {
    return false;
  }
  if (agent.registryId == request.hiringAgent) return false;
  if (request.ancestorAgents.contains(agent.registryId)) return false;
  final wallet = agent.wallet;
  return wallet == null || !request.ancestorWallets.contains(wallet);
}

double _score(AgentListing agent, double match, int reserve) {
  final rating = ((agent.rating - 1) / 4).clamp(0.0, 1.0);
  final hires = agent.paidHireCount <= 0
      ? 0.0
      : agent.paidHireCount / (agent.paidHireCount + searchHiresHalfPoint);
  final price = reserve <= 0
      ? 1.0
      : (1 - agent.priceStroops / reserve).clamp(0.0, 1.0);
  final score =
      searchSkillWeight * match +
      searchRatingWeight * rating +
      searchHiresWeight * hires +
      searchPriceWeight * price;
  // Rounded so float noise never decides a tie; ties fall to the registry id.
  return (score * 1e9).round() / 1e9;
}

/// How well [agent] matches a subtask, from 0 to 1.
///
/// - Requested [skills]: the fraction found in the agent's skills, compared
///   case-insensitively.
/// - The [query]: the fraction of its words (lowercase, letters and digits,
///   two characters or more) found among the words of the agent's name,
///   description and skills (kebab-case split into words).
///
/// With both, `0.6 * skills + 0.4 * query`; with one, that one; with neither,
/// 0, so the ranking falls to rating, hires and price.
double agentSkillMatch(
  AgentListing agent, {
  required String query,
  required List<String> skills,
}) {
  final requested = {
    for (final skill in skills)
      if (skill.trim().isNotEmpty) skill.trim().toLowerCase(),
  };
  final queryWords = _words(query);
  final agentSkills = {for (final s in agent.skills) s.trim().toLowerCase()};

  double? skillScore;
  if (requested.isNotEmpty) {
    skillScore =
        requested.where(agentSkills.contains).length / requested.length;
  }
  double? queryScore;
  if (queryWords.isNotEmpty) {
    final agentWords = {
      ..._words(agent.name),
      ..._words(agent.description),
      for (final skill in agent.skills) ..._words(skill),
    };
    queryScore =
        queryWords.where(agentWords.contains).length / queryWords.length;
  }
  if (skillScore != null && queryScore != null) {
    return searchSkillsShare * skillScore +
        (1 - searchSkillsShare) * queryScore;
  }
  return skillScore ?? queryScore ?? 0;
}

final _wordSplit = RegExp('[^a-z0-9]+');

Set<String> _words(String text) => {
  for (final word in text.toLowerCase().split(_wordSplit))
    if (word.length >= 2) word,
};

/// Why a pick is, or is not, acceptable under D10's justification rule.
enum RelatedPartyJustification {
  /// The pick is not a related party; no justification is needed.
  independent(accepted: true),

  /// The related-party pick is the top-ranked candidate.
  topRanked(accepted: true),

  /// The related-party pick costs no more than the best-ranked independent
  /// candidate with a comparable skill match.
  notPricierThanIndependent(accepted: true),

  /// No independent candidate has a comparable skill match.
  noComparableIndependent(accepted: true),

  /// A comparable independent candidate is cheaper: the pick is refused.
  refused(accepted: false),

  /// The pick is not among the candidates: it is refused.
  notACandidate(accepted: false);

  const RelatedPartyJustification({required this.accepted});

  /// Whether the server accepts the pick.
  final bool accepted;
}

/// The D10 rule for the pick [registryId] among the [ranked] candidates of
/// one search (the snapshot stored with the child hire).
///
/// A related-party pick is accepted when it is rank 1, or when its price is
/// at most that of the best-ranked independent candidate whose skill match is
/// comparable (at least the pick's minus [relatedPartySkillTolerance]), or
/// when no such independent candidate exists. Rank ties are impossible:
/// ranks are distinct by construction.
RelatedPartyJustification justifyRelatedPartyPick(
  int registryId,
  List<AgentCandidate> ranked,
) {
  AgentCandidate? pick;
  for (final candidate in ranked) {
    if (candidate.registryId == registryId) pick = candidate;
  }
  if (pick == null) return RelatedPartyJustification.notACandidate;
  if (!pick.isRelatedParty) return RelatedPartyJustification.independent;
  if (pick.rank == 1) return RelatedPartyJustification.topRanked;

  final threshold = pick.skillMatch - relatedPartySkillTolerance - _epsilon;
  final comparable = [
    for (final candidate in ranked)
      if (!candidate.isRelatedParty && candidate.skillMatch >= threshold)
        candidate,
  ]..sort((a, b) => a.rank.compareTo(b.rank));
  if (comparable.isEmpty) {
    return RelatedPartyJustification.noComparableIndependent;
  }
  return pick.priceStroops <= comparable.first.priceStroops
      ? RelatedPartyJustification.notPricierThanIndependent
      : RelatedPartyJustification.refused;
}
