import '../generated/protocol.dart';
import 'catalog_reader.dart';
import 'custodied_wallets.dart';

/// Adds `hireable` to every agent of an inner [CatalogReader].
///
/// An agent is hireable when its payment wallet is custodied (see
/// [custodiedAddresses]), the same rule `HireService.createHire` and
/// `ServerpodDueSubmitSource` use. It is false while the wallet is not
/// registered or not custodied, so the app disables Hire instead of taking a
/// payment the server cannot deliver.
final class HireableCatalogReader implements CatalogReader {
  HireableCatalogReader({
    required CatalogReader inner,
    required CustodyLookup custody,
  }) : _inner = inner,
       _custody = custody;

  final CatalogReader _inner;
  final CustodyLookup _custody;

  @override
  Future<List<AgentSummary>> list() async {
    final agents = await _inner.list();
    final wallets = {
      for (final agent in agents)
        if (agent.wallet != null && agent.wallet!.isNotEmpty) agent.wallet!,
    };
    final custodied = await _custody(wallets);
    return [
      for (final agent in agents) _withHireable(agent, custodied),
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
    return _withHireable(agent, custodied);
  }

  AgentSummary _withHireable(AgentSummary agent, Set<String> custodied) {
    final wallet = agent.wallet;
    return agent.copyWith(
      hireable:
          wallet != null && wallet.isNotEmpty && custodied.contains(wallet),
    );
  }
}
