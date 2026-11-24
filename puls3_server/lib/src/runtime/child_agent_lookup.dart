import 'dart:convert';

import 'package:puls3_domain/puls3_domain.dart' show AgentId;

import '../agent/custodied_wallets.dart';
import '../agent/hidden_agents.dart';
import '../agent/registry_reader.dart';
import '../generated/protocol.dart' show AgentCatalogUnavailable;
import '../hire/escrow_relay_service.dart' show AgentSummaryLookup;
import '../ledger/ledger_errors.dart';
import 'escrow_subcontract_port.dart';

/// The [ChildAgentLookup] of production: the checks `HireService.createHire`
/// makes of the agent it hires, so a child is hired on the same terms as a
/// consumer's hire.
///
/// It answers `null` (the port refuses `agent_unavailable`) for an agent in
/// [hidden], one [agentOf] does not know, one the registry has no wallet
/// for, one the server cannot deliver (`canDeliver`: the wallet is not
/// [custody]-ed, or it is an [unpublished] Studio agent), and one whose
/// `puls3.manifestVersion` is missing or not a positive integer. The payee
/// is read live from the registry, never from the catalog, as in
/// `createHire`; the price comes from [agentOf].
///
/// A chain read failure is a [LedgerException], which the port turns into
/// `chain_unavailable`. An unreadable catalog ([AgentCatalogUnavailable])
/// becomes a [LedgerUnavailable] for the same reason: the port would not
/// catch it, and it would fail the parent's whole run.
ChildAgentLookup childAgentLookup({
  required AgentSummaryLookup agentOf,
  required RegistryReader registry,
  required CustodyLookup custody,
  required PublicationLookup unpublished,
  HiddenAgents hidden = HiddenAgents.none,
}) => (registryId) async {
  if (hidden.contains(registryId)) return null;
  try {
    final agent = await agentOf(registryId);
    if (agent == null) return null;
    final wallet = await registry.agentWallet(AgentId(registryId));
    if (wallet == null) return null;
    final custodied = await custody({wallet.value});
    final deliverable = canDeliver(
      registryId: registryId,
      wallet: wallet.value,
      custodied: custodied,
      unpublished: await unpublished({registryId}),
    );
    if (!deliverable) return null;
    final version = _manifestVersion(
      await registry.agentMetadata(AgentId(registryId), _manifestVersionKey),
    );
    if (version == null) return null;
    return ChildAgent(
      wallet: wallet,
      manifestVersion: version,
      priceStroops: agent.priceUsdcStroops,
    );
  } on AgentCatalogUnavailable catch (e) {
    throw LedgerUnavailable(e.message);
  }
};

const _manifestVersionKey = 'puls3.manifestVersion';

/// The same rule as `HireService`: UTF-8 text holding an integer of 1 or
/// more.
int? _manifestVersion(List<int>? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final parsed = int.tryParse(utf8.decode(raw, allowMalformed: false).trim());
    return parsed == null || parsed < 1 ? null : parsed;
  } on FormatException {
    return null;
  }
}
