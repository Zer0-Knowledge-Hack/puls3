import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_flutter/l10n/generated/app_localizations.dart';
import 'package:puls3_flutter/l10n/generated/app_localizations_en.dart';

import '../domain/skill_display_name.dart';
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
  const StudioFormCheck({required this.errors, this.draft, this.manifest});

  /// The first problem of each field, as text for the builder.
  final Map<StudioField, String> errors;

  /// What can be saved as a draft (F8): the typed fields, complete or not.
  /// Null when a value is refused outright (above a maximum) or a field
  /// cannot be read (a price or a count that is not a number).
  final AgentManifestDraft? draft;

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
  AppLocalizations? l10n,
}) {
  final copy = l10n ?? AppLocalizationsEn();
  final errors = <StudioField, String>{};
  void error(StudioField field, String message) =>
      errors.putIfAbsent(field, () => message);

  int? count(String raw, StudioField field) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final value = int.tryParse(text);
    if (value == null) error(field, copy.studioErrWholeNumber);
    return value;
  }

  UsdcAmount? price;
  if (values.price.trim().isNotEmpty) {
    final stroops = parseUsdcToStroops(values.price);
    if (stroops == null) {
      error(StudioField.price, copy.studioErrPriceFormat);
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
      SkillProblem.idNotKebabCase => copy.studioErrSkillLetters,
      SkillProblem.nameLength => copy.studioErrSkillTooLong,
    });
  }

  final inputMax = count(values.inputMaxChars, StudioField.input);
  final outputMax = count(values.outputMaxChars, StudioField.output);

  String? text(String value) => value.trim().isEmpty ? null : value.trim();

  List<ManifestProblem> problems;
  AgentManifestDraft? saved;
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
    if (errors.isEmpty) saved = draft;
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
    final (field, message) = describeManifestProblem(problem, copy);
    error(field, message);
  }
  return StudioFormCheck(
    errors: Map.unmodifiable(errors),
    draft: saved,
    manifest: manifest,
  );
}

/// The form values for a saved [draft], for "Continue editing" and "Edit"
/// (F8, F10). A model the Studio no longer offers is left unselected.
StudioFormValues studioFormValuesFor(AgentManifestDraft draft) {
  final model = draft.model;
  return StudioFormValues(
    name: draft.name ?? '',
    description: draft.description ?? '',
    skills: [for (final skill in draft.skills ?? const <Skill>[]) skill.name],
    model: model == null
        ? null
        : studioModelOptions
              .where((o) => o.provider == model.provider && o.id == model.id)
              .firstOrNull,
    systemPrompt: draft.systemPrompt ?? '',
    inputMaxChars: draft.inputMaxChars?.toString() ?? '',
    outputType: draft.outputType ?? OutputType.text,
    outputMaxChars: draft.outputMaxChars?.toString() ?? '',
    price: switch (draft.price) {
      final price? => formatUsdc(price.stroops),
      null => '',
    },
  );
}

/// The kebab-case skill id for a display [name], for example
/// "On-chain analytics" → `on-chain-analytics`.
String skillIdFor(String name) => canonicalSkillId(name);

/// The field a domain [problem] belongs to, and how to say it.
(StudioField, String) describeManifestProblem(
  ManifestProblem problem, [
  AppLocalizations? l10n,
]) {
  final copy = l10n ?? AppLocalizationsEn();
  return switch (problem) {
    ManifestProblem.nameMissing => (StudioField.name, copy.studioErrNameMissing),
    ManifestProblem.nameTooShort => (
      StudioField.name,
      copy.studioErrNameTooShort,
    ),
    ManifestProblem.nameTooLong => (StudioField.name, copy.studioErrNameTooLong),
    ManifestProblem.nameMalformed => (StudioField.name, copy.studioErrNameCheck),
    ManifestProblem.descriptionMissing => (
      StudioField.description,
      copy.studioErrDescMissing,
    ),
    ManifestProblem.descriptionTooShort => (
      StudioField.description,
      copy.studioErrDescTooShort,
    ),
    ManifestProblem.descriptionTooLong => (
      StudioField.description,
      copy.studioErrDescTooLong,
    ),
    ManifestProblem.descriptionMalformed => (
      StudioField.description,
      copy.studioErrDescCheck,
    ),
    ManifestProblem.skillsMissing => (
      StudioField.skills,
      copy.studioErrSkillsMissing,
    ),
    ManifestProblem.skillsTooMany => (
      StudioField.skills,
      copy.studioErrSkillsTooMany,
    ),
    ManifestProblem.skillIdDuplicate => (
      StudioField.skills,
      copy.studioErrSkillDuplicate,
    ),
    ManifestProblem.skillIdNotKebabCase ||
    ManifestProblem.skillNameLength ||
    ManifestProblem.skillsMalformed => (
      StudioField.skills,
      copy.studioErrSkillCheck,
    ),
    ManifestProblem.modelMissing => (
      StudioField.model,
      copy.studioErrModelMissing,
    ),
    ManifestProblem.modelNotAllowed => (
      StudioField.model,
      copy.studioErrModelFreeTier,
    ),
    ManifestProblem.modelProviderNotEnabled => (
      StudioField.model,
      copy.studioErrModelProvider,
    ),
    ManifestProblem.modelMalformed => (
      StudioField.model,
      copy.studioErrModelMissing,
    ),
    ManifestProblem.systemPromptMissing => (
      StudioField.systemPrompt,
      copy.studioErrPromptMissing,
    ),
    ManifestProblem.systemPromptTooShort => (
      StudioField.systemPrompt,
      copy.studioErrPromptTooShort,
    ),
    ManifestProblem.systemPromptTooLong => (
      StudioField.systemPrompt,
      copy.studioErrPromptTooLong,
    ),
    ManifestProblem.systemPromptMalformed => (
      StudioField.systemPrompt,
      copy.studioErrPromptCheck,
    ),
    ManifestProblem.inputMissing => (
      StudioField.input,
      copy.studioErrInputMissing,
    ),
    ManifestProblem.inputMaxCharsTooLow => (
      StudioField.input,
      copy.studioErrInputTooLow,
    ),
    ManifestProblem.inputMaxCharsTooHigh => (
      StudioField.input,
      copy.studioErrInputTooHigh,
    ),
    ManifestProblem.inputMalformed || ManifestProblem.inputTypeUnsupported => (
      StudioField.input,
      copy.studioErrInputCheck,
    ),
    ManifestProblem.outputMissing => (
      StudioField.output,
      copy.studioErrOutputMissing,
    ),
    ManifestProblem.outputMaxCharsTooLow => (
      StudioField.output,
      copy.studioErrOutputTooLow,
    ),
    ManifestProblem.outputMaxCharsTooHigh => (
      StudioField.output,
      copy.studioErrOutputTooHigh,
    ),
    ManifestProblem.outputMalformed || ManifestProblem.outputTypeUnsupported => (
      StudioField.output,
      copy.studioErrOutputCheck,
    ),
    ManifestProblem.priceMissing => (
      StudioField.price,
      copy.studioErrPriceMissing,
    ),
    ManifestProblem.priceNotPositive => (
      StudioField.price,
      copy.studioErrPricePositive,
    ),
    ManifestProblem.priceMalformed || ManifestProblem.priceAssetUnsupported => (
      StudioField.price,
      copy.studioErrPriceCheck,
    ),
    ManifestProblem.notAnObject ||
    ManifestProblem.unknownKey ||
    ManifestProblem.toolsNotSupported ||
    ManifestProblem.versionInDraft ||
    ManifestProblem.schemaUnsupported ||
    ManifestProblem.versionInvalid => (
      StudioField.name,
      copy.studioErrCannotSave,
    ),
  };
}
