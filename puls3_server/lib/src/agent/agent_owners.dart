import 'package:puls3_domain/puls3_domain.dart' show AgentId, AgentOwnerReader;
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';

/// The owners of the agents with the given registry ids (ADR-0011 D10).
///
/// An id that maps to a set has those owner addresses; an id that maps to
/// `null` has owners that could not be read (unknown); an id that is absent
/// has no owner in this source. The search treats an agent with no known
/// owner, or an unknown one, as a related party (fail closed).
typedef AgentOwnersLookup =
    Future<Map<int, Set<String>?>> Function(Set<int> registryIds);

/// The owners the database knows: the builder of each custodied wallet bound
/// to the agent (`agent_wallet.owner`) and the owner of each Studio deploy of
/// it (`studio_deploy.owner`).
AgentOwnersLookup databaseOwnersLookup(Session session) => (ids) async {
  if (ids.isEmpty) return const {};
  final owners = <int, Set<String>?>{};
  void add(int? id, String owner) {
    if (id == null || owner.isEmpty) return;
    (owners[id] ??= <String>{}).add(owner);
  }

  final wallets = await AgentWallet.db.find(
    session,
    where: (t) => t.agentId.inSet(ids),
  );
  for (final wallet in wallets) {
    add(wallet.agentId, wallet.owner);
  }
  final deploys = await StudioDeployRecord.db.find(
    session,
    where: (t) => t.registryAgentId.inSet(ids),
  );
  for (final deploy in deploys) {
    add(deploy.registryAgentId, deploy.owner);
  }
  return owners;
};

/// The identity registry owner (`owner_of`) of each agent. An agent the
/// registry does not know is absent; a read that fails is unknown (`null`),
/// so a registry outage never makes two agents look independent.
AgentOwnersLookup registryOwnersLookup(AgentOwnerReader reader) => (ids) async {
  final entries = await Future.wait(
    ids.map((id) async {
      try {
        final owner = await reader.ownerOf(AgentId(id));
        return (id: id, owners: owner == null ? <String>{} : {owner.value});
      } on Exception {
        return (id: id, owners: null);
      }
    }),
  );
  return {
    for (final entry in entries)
      if (entry.owners == null || entry.owners!.isNotEmpty)
        entry.id: entry.owners,
  };
};

/// The union of [sources]. Unknown is sticky: an agent any source could not
/// read stays unknown, and a source that throws makes every asked agent
/// unknown.
AgentOwnersLookup combinedOwnersLookup(List<AgentOwnersLookup> sources) =>
    (ids) async {
      final combined = <int, Set<String>?>{};
      final unknown = <int>{};
      for (final source in sources) {
        Map<int, Set<String>?> found;
        try {
          found = await source(ids);
        } on Exception {
          unknown.addAll(ids);
          continue;
        }
        found.forEach((id, owners) {
          if (owners == null) {
            unknown.add(id);
          } else {
            (combined[id] ??= <String>{}).addAll(owners);
          }
        });
      }
      for (final id in unknown) {
        combined[id] = null;
      }
      return combined;
    };
