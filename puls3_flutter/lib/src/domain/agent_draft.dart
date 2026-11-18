/// The catalog id of the agent deployed from Studio draft [draftId], as the
/// server catalog lists it (`StudioDeployService`). It is not the on-chain
/// registry id.
String studioCatalogId(int draftId) => 'studio-$draftId';

/// Immutable snapshot of the Studio form, handed to the deploy flow.
class AgentDraft {
  const AgentDraft({
    required this.name,
    required this.description,
    required this.model,
    required this.systemPrompt,
    required this.skills,
    required this.priceUsdcStroops,
    this.draftId,
  });

  final String name;
  final String description;
  final String model;
  final String systemPrompt;
  final List<String> skills;
  final int priceUsdcStroops;

  /// The saved Studio draft, when this snapshot came from one.
  final int? draftId;
}
