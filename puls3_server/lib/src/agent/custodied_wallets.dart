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
