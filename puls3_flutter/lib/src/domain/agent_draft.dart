/// Immutable snapshot of the Studio form, handed to the deploy flow.
class AgentDraft {
  const AgentDraft({
    required this.name,
    required this.description,
    required this.model,
    required this.systemPrompt,
    required this.skills,
    required this.priceUsdcStroops,
  });

  final String name;
  final String description;
  final String model;
  final String systemPrompt;
  final List<String> skills;
  final int priceUsdcStroops;
}
