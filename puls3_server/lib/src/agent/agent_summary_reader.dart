import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart';

import '../generated/protocol.dart';
import 'agent_metadata.dart';
import 'registry_reader.dart';

/// One agent of the catalog, read from [registry], or `null` when its
/// metadata is missing or invalid (for example a superseded registration).
///
/// Shared by the on-chain catalog (`AgentCatalogService`) and the indexer
/// (`CatalogIndexer`), so both accept exactly the same agents.
Future<AgentSummary?> readAgentSummary(
  RegistryReader registry,
  int registryId,
) async {
  final agent = AgentId(registryId);

  Future<Uint8List?> metadata(String key) =>
      registry.agentMetadata(agent, key);

  final id = parseAgentId(await metadata('id'));
  if (id == null) return null;
  final name = parseName(await metadata('name'));
  final description = parseDescription(await metadata('description'));
  final skills = parseSkills(await metadata('skills'));
  final price = parsePriceUsdcStroops(await metadata('priceUsdcStroops'));
  if (name == null ||
      description == null ||
      skills == null ||
      price == null) {
    return null;
  }
  final model = parseModel(await metadata('model'));
  final wallet = await registry.agentWallet(agent);
  return AgentSummary(
    id: id,
    registryId: registryId,
    name: name,
    description: description,
    skills: skills,
    priceUsdcStroops: price,
    wallet: wallet?.value,
    model: model,
  );
}
