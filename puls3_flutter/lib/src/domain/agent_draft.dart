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

/// The fields a draft is validated on.
enum AgentDraftField { name, description, prompt, skills, price }

/// Manifest rules from the agent-definition spike (ADR-0004): name 3–48
/// chars, description 10–280, system prompt 20–8,000, 1–5 skills, price > 0.
abstract final class AgentDraftRules {
  static const nameMin = 3;
  static const nameMax = 48;
  static const descriptionMin = 10;
  static const descriptionMax = 280;
  static const promptMin = 20;
  static const promptMax = 8000;
  static const skillsMin = 1;
  static const skillsMax = 5;

  /// One human message per failing field; empty when the draft can deploy.
  /// [priceStroops] is null when the price text does not parse.
  static Map<AgentDraftField, String> validate({
    required String name,
    required String description,
    required String prompt,
    required List<String> skills,
    required int? priceStroops,
  }) {
    final n = name.trim().length;
    final d = description.trim().length;
    final p = prompt.trim().length;
    return {
      if (n < nameMin || n > nameMax)
        AgentDraftField.name: 'Use $nameMin–$nameMax characters',
      if (d < descriptionMin || d > descriptionMax)
        AgentDraftField.description:
            'Use $descriptionMin–$descriptionMax characters',
      if (p < promptMin || p > promptMax)
        AgentDraftField.prompt: 'Write at least $promptMin characters',
      if (skills.length < skillsMin || skills.length > skillsMax)
        AgentDraftField.skills: 'Add $skillsMin–$skillsMax skills',
      if (priceStroops == null || priceStroops <= 0)
        AgentDraftField.price: 'Enter a price above 0, like 0.50',
    };
  }
}
