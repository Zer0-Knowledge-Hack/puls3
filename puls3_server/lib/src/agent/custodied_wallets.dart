import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';

/// The payment addresses, among [addresses], whose agent wallet the server
/// custodies (ADR-0003 decision 4): it holds the secret seed, so it can sign
/// that agent's escrow `submit`.
///
/// This is the one custody rule. `HireService.createHire`, the catalog's
/// `hireable` field and `ServerpodDueSubmitSource` all ask it, so an agent is
/// hireable exactly when the server can deliver for it.
Future<Set<String>> custodiedAddresses(
  Session session,
  Set<String> addresses,
) async {
  if (addresses.isEmpty) return const {};
  final wallets = await AgentWallet.db.find(
    session,
    where: (t) => t.address.inSet(addresses),
  );
  return {for (final wallet in wallets) wallet.address};
}

/// [custodiedAddresses] of one request's [session], for the catalog and hire
/// wiring.
typedef CustodyLookup = Future<Set<String>> Function(Set<String> addresses);

/// A [CustodyLookup] over [session].
CustodyLookup custodyOn(Session session) =>
    (addresses) => custodiedAddresses(session, addresses);

/// The registry ids, among [registryIds], of Studio agents that are not
/// published: they have a `studio_deploy` row and none of their rows is
/// `active`. Such an agent is registered on chain but has no published
/// version, so the server cannot run it. An agent with no Studio deploy row
/// (seeded or demo) is never in the result.
Future<Set<int>> unpublishedStudioAgents(
  Session session,
  Set<int> registryIds,
) async {
  if (registryIds.isEmpty) return const {};
  final rows = await StudioDeployRecord.db.find(
    session,
    where: (t) => t.registryAgentId.inSet(registryIds),
  );
  final studio = <int>{};
  final published = <int>{};
  for (final row in rows) {
    final id = row.registryAgentId;
    if (id == null) continue;
    studio.add(id);
    if (row.state == 'active') published.add(id);
  }
  return studio.difference(published);
}

/// [unpublishedStudioAgents] of one request's session.
typedef PublicationLookup = Future<Set<int>> Function(Set<int> registryIds);

/// A [PublicationLookup] that knows no Studio agents, for wiring without a
/// database: every agent keeps the custody rule alone.
Future<Set<int>> noStudioAgents(Set<int> registryIds) async => const {};

/// A [PublicationLookup] over [session].
PublicationLookup publicationOn(Session session) =>
    (registryIds) => unpublishedStudioAgents(session, registryIds);

/// The one deliverability rule: the server can deliver a hire of the agent
/// [registryId] paid to [wallet] when the wallet is [custodied] and the agent
/// is not an [unpublished] Studio agent. The catalog's `hireable` field and
/// `HireService.createHire` both ask it.
bool canDeliver({
  required int registryId,
  required String? wallet,
  required Set<String> custodied,
  required Set<int> unpublished,
}) =>
    wallet != null &&
    wallet.isNotEmpty &&
    custodied.contains(wallet) &&
    !unpublished.contains(registryId);
