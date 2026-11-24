import 'package:puls3_domain/puls3_domain.dart';

import '../generated/protocol.dart';
import '../hire/hire_lifecycle_store.dart';
import 'agent_owners.dart';
import 'catalog_reader.dart';

/// How many candidates a search returns unless the caller asks otherwise.
const defaultAgentSearchLimit = 10;

/// The longest hire chain the search walks. ADR-0011 D5 allows three hires
/// (consumer → A → B → C); the margin only guards against corrupt data.
const maxAgentSearchChain = 8;

/// The hire a search runs for, or one of its ancestors, cannot be read, or
/// the chain loops or is too long. The search refuses instead of guessing
/// which agents are ancestors.
final class AgentSearchContextMissing implements Exception {
  const AgentSearchContextMissing(this.message);

  final String message;

  @override
  String toString() => 'AgentSearchContextMissing: $message';
}

/// The marketplace search of ADR-0011 D9, for an agent that subcontracts.
///
/// It reads the catalog (rating, paid hires and `hireable` already joined in),
/// walks the hire chain for the ancestors (D5) and the related-party opt-out
/// (D10), reads owners for the agents that can still be candidates, and ranks
/// with [rankAgentCandidates]. The `search_agents` tool (T5) calls it.
final class AgentSearchService {
  AgentSearchService({
    required CatalogReader catalog,
    required HireLifecycleStore hires,
    required AgentOwnersLookup owners,
  }) : _catalog = catalog,
       _hires = hires,
       _owners = owners;

  final CatalogReader _catalog;
  final HireLifecycleStore _hires;
  final AgentOwnersLookup _owners;

  /// Ranked candidates for the agent running hire [hireId], priced within
  /// [remainingReserveStroops].
  ///
  /// Related parties are excluded when that hire or any ancestor hire opted
  /// out: an opt-out anywhere in the chain binds the whole tree.
  ///
  /// Throws [AgentSearchContextMissing] when the chain cannot be read, and
  /// whatever the catalog throws (`AgentCatalogUnavailable`).
  Future<List<AgentCandidate>> search({
    required int hireId,
    required int remainingReserveStroops,
    required String query,
    List<String> skills = const [],
    int limit = defaultAgentSearchLimit,
  }) async {
    final chain = await _chain(hireId);
    final hiringAgent = chain.first.agentId;
    final ancestorAgents = {for (final hire in chain.skip(1)) hire.agentId};
    final chainAgents = {hiringAgent, ...ancestorAgents};

    final agents = await _catalog.list();
    final listings = [for (final agent in agents) _listing(agent)];
    final request = AgentSearchRequest(
      hiringAgent: hiringAgent,
      ancestorAgents: ancestorAgents,
      ancestorWallets: {
        for (final agent in agents)
          if (chainAgents.contains(agent.registryId) &&
              agent.wallet != null &&
              agent.wallet!.isNotEmpty)
            agent.wallet!,
      },
      remainingReserveStroops: remainingReserveStroops,
      allowRelatedParty: chain.every((hire) => hire.allowRelatedParty),
      query: query,
      skills: skills,
      limit: limit,
    );

    final asked = {
      hiringAgent,
      for (final listing in listings)
        if (isSubcontractEligible(listing, request)) listing.registryId,
    };
    final owners = await _owners(asked);
    return rankAgentCandidates(
      listings,
      request,
      owners: {
        for (final entry in owners.entries)
          if (entry.value != null) entry.key: entry.value!,
      },
    );
  }

  /// Hire [hireId] followed by its ancestors, nearest first.
  Future<List<HireRow>> _chain(int hireId) async {
    final chain = <HireRow>[];
    final seen = <int>{};
    int? next = hireId;
    while (next != null) {
      if (!seen.add(next) || chain.length >= maxAgentSearchChain) {
        throw AgentSearchContextMissing('hire chain of $hireId loops');
      }
      final hire = await _hires.findHire(next);
      if (hire == null) {
        throw AgentSearchContextMissing('hire $next does not exist');
      }
      chain.add(hire);
      next = hire.parentHireId;
    }
    return chain;
  }

  AgentListing _listing(AgentSummary agent) => AgentListing(
    id: agent.id,
    registryId: agent.registryId,
    name: agent.name,
    description: agent.description,
    skills: agent.skills,
    priceStroops: agent.priceUsdcStroops,
    wallet: agent.wallet,
    rating: agent.rating,
    paidHireCount: agent.paidHireCount,
    hireable: agent.hireable,
  );
}
