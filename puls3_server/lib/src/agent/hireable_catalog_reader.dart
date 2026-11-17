import '../generated/protocol.dart';
import 'catalog_reader.dart';
import 'custodied_wallets.dart';

/// Adds `hireable` to every agent of an inner [CatalogReader].
///
/// An agent is hireable when [canDeliver] says so: its payment wallet is
/// custodied (see [custodiedAddresses]) and it is not an unpublished Studio
/// agent (see [unpublishedStudioAgents]), the same rule
/// `HireService.createHire` uses. It is false otherwise, so the app disables
/// Hire instead of taking a payment the server cannot deliver.
final class HireableCatalogReader implements CatalogReader {
  HireableCatalogReader({
    required CatalogReader inner,
    required CustodyLookup custody,
    PublicationLookup unpublished = noStudioAgents,
  }) : _inner = inner,
       _custody = custody,
       _unpublished = unpublished;

  final CatalogReader _inner;
  final CustodyLookup _custody;
  final PublicationLookup _unpublished;

  @override
  Future<List<AgentSummary>> list() async {
    final agents = await _inner.list();
    final wallets = {
      for (final agent in agents)
        if (agent.wallet != null && agent.wallet!.isNotEmpty) agent.wallet!,
    };
    final custodied = await _custody(wallets);
    final unpublished = agents.isEmpty
        ? const <int>{}
        : await _unpublished({for (final agent in agents) agent.registryId});
    return [
      for (final agent in agents) _withHireable(agent, custodied, unpublished),
    ];
  }

  @override
  Future<AgentSummary?> get(String id) async {
    final agent = await _inner.get(id);
    if (agent == null) return null;
    final wallet = agent.wallet;
    final custodied = wallet == null || wallet.isEmpty
        ? const <String>{}
        : await _custody({wallet});
    final unpublished = custodied.isEmpty
        ? const <int>{}
        : await _unpublished({agent.registryId});
    return _withHireable(agent, custodied, unpublished);
  }

  AgentSummary _withHireable(
    AgentSummary agent,
    Set<String> custodied,
    Set<int> unpublished,
  ) => agent.copyWith(
    hireable: canDeliver(
      registryId: agent.registryId,
      wallet: agent.wallet,
      custodied: custodied,
      unpublished: unpublished,
    ),
  );
}
