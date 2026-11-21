import 'package:puls3_domain/puls3_domain.dart';

import 'registry_reader.dart';

/// Whether registry id [later] may take over a catalog id that registry id
/// [earlier] registered first (audit I-1, #206).
///
/// Registration is permissionless, and the catalog keeps the newest
/// registration of each metadata id (for example `agt-001`), so a redeploy
/// replaces the old version. Without an owner check, anyone could register a
/// copy of an agent's metadata with their own wallet and take over its
/// catalog entry, and with it every new hire and payment. A catalog id
/// therefore belongs to whoever registered it first: only a registration by
/// the same owner supersedes it.
///
/// It fails closed: when either owner is unknown, [later] does not take over.
/// An unreadable chain throws a `LedgerException`.
Future<bool> mayTakeOverCatalogId(
  RegistryReader registry, {
  required int earlier,
  required int later,
}) async {
  final first = await registry.ownerOf(AgentId(earlier));
  if (first == null) return false;
  final next = await registry.ownerOf(AgentId(later));
  return next != null && next == first;
}
