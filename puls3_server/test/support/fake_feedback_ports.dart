import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;
import 'package:puls3_server/src/feedback/reputation_calls.dart';
import 'package:puls3_server/src/ledger/xdr_invoke_encoder.dart';

import 'reputation_registry_contract.dart';

/// The contract the fake calls go to: a registry, not the escrow.
final fakeReputationRegistry = StellarAddress.parse(
  'CD5QZOKGRBV35C5SDT6PG7S72XGG4BHQAC2L56YLNBJDUL4LDMTXFIJJ',
);

/// An [AgentOwnerReader] over a map. An agent that is not in [owners] has no
/// owner on chain; [failure] makes every read throw.
final class FakeAgentOwners implements AgentOwnerReader {
  FakeAgentOwners(this.owners);

  final Map<int, StellarAddress> owners;
  Exception? failure;
  var reads = 0;

  @override
  Future<StellarAddress?> ownerOf(AgentId agent) async {
    reads++;
    if (failure != null) throw failure!;
    return owners[agent.value];
  }
}

/// A [ReputationCalls] that records what it was asked to build.
final class FakeReputationCalls implements ReputationCalls {
  final built = <({StellarAddress client, AgentId agent, Feedback feedback})>[];

  @override
  ContractCall giveFeedback({
    required StellarAddress client,
    required AgentId agent,
    required Feedback feedback,
  }) {
    built.add((client: client, agent: agent, feedback: feedback));
    return ContractCall(
      contract: fakeReputationRegistry,
      function: 'give_feedback',
      args: [
        ScArg.address(client),
        ScArg.u32(agent.value),
        ScArg.u32(feedback.score),
      ],
    );
  }
}

/// A [ReputationRegistry] that keeps what it is given and can be made to fail.
final class FakeReputationRegistry implements ReputationRegistry {
  final given = <Feedback>[];
  Exception? failure;

  /// Agents whose reads fail while every other agent still reads.
  final unreadable = <AgentId>{};
  var reads = 0;

  @override
  Future<TransactionHash> giveFeedback(Feedback feedback) =>
      throw UnimplementedError('the server relays give_feedback, see #14');

  @override
  Future<List<Feedback>> feedbacksOf(AgentId agent) async {
    reads++;
    if (failure != null) throw failure!;
    if (unreadable.contains(agent)) throw Exception('agent $agent unreadable');
    return given.where((f) => f.agentId == agent).toList();
  }
}

/// The shared contract suite's view of [FakeReputationRegistry]. Revoked
/// feedback is not kept, as the real registry's reads skip it.
final class FakeReputationRegistryRig implements ReputationRegistryRig {
  final _fake = FakeReputationRegistry();
  var _next = 1;

  @override
  ReputationRegistry get registry => _fake;

  @override
  void seed(SeededFeedback entry) {
    if (entry.revoked) return;
    _fake.given.add(
      Feedback(
        hireId: HireId(_next++),
        agentId: entry.agent,
        client: entry.client,
        score: entry.score,
      ),
    );
  }

  @override
  void breakReads() => _fake.failure = Exception('the registry is down');
}
