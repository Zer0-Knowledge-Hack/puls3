import 'package:puls3_domain/puls3_domain.dart';

import '../domain/usdc.dart';
import 'studio_models.dart';

/// The Studio form fields, in manifest order (ADR-0004).
enum StudioField {
  name,
  description,
  skills,
  model,
  systemPrompt,
  input,
  output,
  price,
}

/// What the builder typed, as typed.
class StudioFormValues {
  const StudioFormValues({
    this.name = '',
    this.description = '',
    this.skills = const [],
    this.model,
    this.systemPrompt = '',
    this.inputMaxChars = '',
    this.outputType = OutputType.text,
    this.outputMaxChars = '',
    this.price = '',
  });

  final String name;
  final String description;

  /// Skill display names; each becomes a kebab-case skill id.
  final List<String> skills;
  final StudioModelOption? model;
  final String systemPrompt;
  final String inputMaxChars;
  final OutputType outputType;
  final String outputMaxChars;

  /// USDC, for example `0.50`.
  final String price;
}

/// The result of checking the form against the domain manifest rules.
class StudioFormCheck {
  const StudioFormCheck({required this.errors, this.manifest});

  /// The first problem of each field, as text for the builder.
  final Map<StudioField, String> errors;

  /// The deployable manifest; null while any rule is broken.
  final AgentManifest? manifest;

  bool get canDeploy => manifest != null;
}

/// Checks [values] with the domain's `AgentManifestDraft` (#34): the Studio
/// keeps no copy of the manifest rules, it only parses what was typed and
/// words the domain's problems for each field.
StudioFormCheck checkStudioForm(
  StudioFormValues values, {
  ModelPolicy? policy,
}) {
  final errors = <StudioField, String>{};
  void error(StudioField field, String message) =>
      errors.putIfAbsent(field, () => message);

  int? count(String raw, StudioField field) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final value = int.tryParse(text);
    if (value == null) error(field, 'Enter a whole number of characters.');
    return value;
  }

  UsdcAmount? price;
  if (values.price.trim().isNotEmpty) {
    final stroops = parseUsdcToStroops(values.price);
    if (stroops == null) {
      error(StudioField.price, 'Enter an amount like 0.50.');
    } else {
      price = UsdcAmount.stroops(stroops);
    }
  }

  List<Skill>? skills;
  try {
    skills = [
      for (final name in values.skills)
        Skill(id: skillIdFor(name), name: name.trim()),
    ];
  } on InvalidSkill catch (e) {
    error(StudioField.skills, switch (e.problem) {
      SkillProblem.idNotKebabCase =>
        'Use letters or numbers in each skill name.',
      SkillProblem.nameLength => 'A skill name is too long.',
    });
  }

  final inputMax = count(values.inputMaxChars, StudioField.input);
  final outputMax = count(values.outputMaxChars, StudioField.output);

  String? text(String value) => value.trim().isEmpty ? null : value.trim();

  List<ManifestProblem> problems;
  AgentManifest? manifest;
  try {
    final draft = AgentManifestDraft(
      name: text(values.name),
      description: text(values.description),
      skills: skills,
      model: values.model?.modelId,
      systemPrompt: text(values.systemPrompt),
      inputType: InputType.text,
      inputMaxChars: inputMax,
      outputType: values.outputType,
      outputMaxChars: outputMax,
      price: price,
    );
    final rules = policy ?? studioModelPolicy;
    problems = draft.problemsForDeploy(rules);
    if (problems.isEmpty && errors.isEmpty) {
      manifest = draft.validate(rules, ManifestVersion.first);
    }
  } on InvalidManifest catch (e) {
    // A value above a maximum: the draft itself is refused.
    problems = e.problems;
  }

  for (final problem in problems) {
    final (field, message) = describeManifestProblem(problem);
    error(field, message);
  }
  return StudioFormCheck(errors: Map.unmodifiable(errors), manifest: manifest);
}

/// The kebab-case skill id for a display [name], for example
/// "On-chain analytics" → `on-chain-analytics`.
String skillIdFor(String name) => name
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

/// The field a domain [problem] belongs to, and how to say it.
(StudioField, String) describeManifestProblem(
  ManifestProblem problem,
) => switch (problem) {
  ManifestProblem.nameMissing => (StudioField.name, 'Give your agent a name.'),
  ManifestProblem.nameTooShort => (StudioField.name, 'The name is too short.'),
  ManifestProblem.nameTooLong => (StudioField.name, 'The name is too long.'),
  ManifestProblem.nameMalformed => (StudioField.name, 'Check the name.'),
  ManifestProblem.descriptionMissing => (
    StudioField.description,
    'Say what the agent does.',
  ),
  ManifestProblem.descriptionTooShort => (
    StudioField.description,
    'The description is too short.',
  ),
  ManifestProblem.descriptionTooLong => (
    StudioField.description,
    'The description is too long.',
  ),
  ManifestProblem.descriptionMalformed => (
    StudioField.description,
    'Check the description.',
  ),
  ManifestProblem.skillsMissing => (
    StudioField.skills,
    'Add at least one skill.',
  ),
  ManifestProblem.skillsTooMany => (
    StudioField.skills,
    'Too many skills: remove some.',
  ),
  ManifestProblem.skillIdDuplicate => (
    StudioField.skills,
    'Two skills have the same name.',
  ),
  ManifestProblem.skillIdNotKebabCase ||
  ManifestProblem.skillNameLength ||
  ManifestProblem.skillsMalformed => (
    StudioField.skills,
    'Check the skill names.',
  ),
  ManifestProblem.modelMissing => (StudioField.model, 'Choose a model.'),
  ManifestProblem.modelNotAllowed => (
    StudioField.model,
    'This model is not available on the free tier.',
  ),
  ManifestProblem.modelProviderNotEnabled => (
    StudioField.model,
    'This provider is not enabled yet.',
  ),
  ManifestProblem.modelMalformed => (StudioField.model, 'Choose a model.'),
  ManifestProblem.systemPromptMissing => (
    StudioField.systemPrompt,
    'Write the instructions the agent follows.',
  ),
  ManifestProblem.systemPromptTooShort => (
    StudioField.systemPrompt,
    'The instructions are too short.',
  ),
  ManifestProblem.systemPromptTooLong => (
    StudioField.systemPrompt,
    'The instructions are too long.',
  ),
  ManifestProblem.systemPromptMalformed => (
    StudioField.systemPrompt,
    'Check the instructions.',
  ),
  ManifestProblem.inputMissing => (
    StudioField.input,
    'Set the longest input the agent accepts.',
  ),
  ManifestProblem.inputMaxCharsTooLow => (
    StudioField.input,
    'The input limit must be at least 1 character.',
  ),
  ManifestProblem.inputMaxCharsTooHigh => (
    StudioField.input,
    'The input limit is above what agents accept.',
  ),
  ManifestProblem.inputMalformed || ManifestProblem.inputTypeUnsupported => (
    StudioField.input,
    'Check the input.',
  ),
  ManifestProblem.outputMissing => (
    StudioField.output,
    'Set the longest answer the agent returns.',
  ),
  ManifestProblem.outputMaxCharsTooLow => (
    StudioField.output,
    'The answer limit must be at least 1 character.',
  ),
  ManifestProblem.outputMaxCharsTooHigh => (
    StudioField.output,
    'The answer limit is above what agents return.',
  ),
  ManifestProblem.outputMalformed || ManifestProblem.outputTypeUnsupported => (
    StudioField.output,
    'Check the output.',
  ),
  ManifestProblem.priceMissing => (StudioField.price, 'Set a price.'),
  ManifestProblem.priceNotPositive => (
    StudioField.price,
    'The price must be more than 0.',
  ),
  ManifestProblem.priceMalformed || ManifestProblem.priceAssetUnsupported => (
    StudioField.price,
    'Check the price.',
  ),
  // Wire-only problems: the Studio never builds these documents.
  ManifestProblem.notAnObject ||
  ManifestProblem.unknownKey ||
  ManifestProblem.toolsNotSupported ||
  ManifestProblem.versionInDraft ||
  ManifestProblem.schemaUnsupported ||
  ManifestProblem.versionInvalid => (
    StudioField.name,
    'This agent cannot be saved.',
  ),
};
