import 'package:puls3_domain/puls3_domain.dart';

import '../ledger/ledger_errors.dart';
import 'registry_reader.dart';

/// Who may hold a catalog id, when the server knows it before the chain does
/// (audit I-1, #206, #381).
sealed class CatalogIdClaim {
  const CatalogIdClaim();
}

/// The server knows nothing about the id: it belongs to whoever registered it
/// first ([mayTakeOverCatalogId]). The seed agents (`agt-*`) are such ids.
final class FirstRegistrantClaim extends CatalogIdClaim {
  const FirstRegistrantClaim();
}

/// Only a registration owned by [owner] may hold the id, whatever its order:
/// the newest one wins. A Studio id `studio-<draftId>` belongs to the wallet
/// that owns the draft, so registering it first does not take it.
final class OwnerClaim extends CatalogIdClaim {
  const OwnerClaim(this.owner);

  final StellarAddress owner;
}

/// No registration may hold the id: a `studio-` id with no draft behind it.
final class NobodyClaim extends CatalogIdClaim {
  const NobodyClaim();
}

/// Tells the catalog who may hold a catalog id.
abstract interface class CatalogIdOwners {
  /// The claim on [catalogId]. A store that cannot be read throws a
  /// [LedgerUnavailable], so the catalog keeps its last list instead of
  /// guessing.
  Future<CatalogIdClaim> claimOf(String catalogId);
}

/// No off-chain knowledge: every id follows the first-registrant rule.
final class FirstRegistrantOnly implements CatalogIdOwners {
  const FirstRegistrantOnly();

  @override
  Future<CatalogIdClaim> claimOf(String catalogId) async =>
      const FirstRegistrantClaim();
}

/// Studio ids are predictable (`studio-` and the draft's row id), so anyone
/// could register the next one before its builder deploys it. Their owner is
/// known off chain: the wallet that owns the draft. [ownerOfDraft] reads it,
/// or answers `null` when there is no such draft.
///
/// The whole `studio-` prefix is reserved: the Studio writes only
/// `studio-<positive integer>`, so any other `studio-` id, and one whose draft
/// does not exist, is held by nobody. Every other id keeps the
/// first-registrant rule.
final class StudioCatalogIdOwners implements CatalogIdOwners {
  StudioCatalogIdOwners(this._ownerOfDraft);

  final Future<String?> Function(int draftId) _ownerOfDraft;

  static const _prefix = 'studio-';
  static final _studioId = RegExp(r'^studio-([1-9][0-9]{0,15})$');

  @override
  Future<CatalogIdClaim> claimOf(String catalogId) async {
    if (!catalogId.startsWith(_prefix)) return const FirstRegistrantClaim();
    final match = _studioId.firstMatch(catalogId);
    if (match == null) return const NobodyClaim();
    final String? owner;
    try {
      owner = await _ownerOfDraft(int.parse(match.group(1)!));
    } on Object catch (e) {
      throw LedgerUnavailable('the owner of $catalogId cannot be read: $e');
    }
    if (owner == null) return const NobodyClaim();
    try {
      return OwnerClaim(StellarAddress.parse(owner));
    } on InvalidStellarAddress {
      return const NobodyClaim();
    }
  }
}

/// Whether registry id [registryId] is owned by [owner]. An unknown owner is
/// not a match (fails closed).
Future<bool> isOwnedBy(
  RegistryReader registry,
  int registryId,
  StellarAddress owner,
) async => await registry.ownerOf(AgentId(registryId)) == owner;

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
