import 'errors.dart';
import 'entities.dart';
import 'values.dart';

/// The version of a deployed agent manifest: an integer from 1 to 2^53-1.
///
/// Drafts have no version. The caller passes `latest?.next() ?? first` when it
/// validates a draft, because only storage knows the latest version.
final class ManifestVersion implements Comparable<ManifestVersion> {
  const ManifestVersion._(this.value);

  factory ManifestVersion(int value) {
    if (value < 1 || value > maxValue) {
      throw InvalidManifest([ManifestProblem.versionInvalid]);
    }
    return ManifestVersion._(value);
  }

  static const first = ManifestVersion._(1);

  /// The largest version: 2^53-1, so it stays exact when serialized as JSON.
  static const maxValue = 9007199254740991;

  final int value;

  /// The following version. Fails with [ManifestProblem.versionInvalid] at
  /// [maxValue].
  ManifestVersion next() => ManifestVersion(value + 1);

  @override
  int compareTo(ManifestVersion other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) =>
      other is ManifestVersion && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'v$value';
}

/// The model one agent runs on: a provider and a provider-specific id.
///
/// It never holds a credential. A paid provider's key is a reference in the
/// server's deploy record, so rotating it needs no new manifest version.
final class ModelId {
  const ModelId._(this.provider, this.id);

  /// [provider] is kebab-case of at most 32 characters. [id] is non-blank,
  /// has no whitespace and is at most 128 runes.
  factory ModelId({required String provider, required String id}) {
    if (provider.length > _maxProviderLength ||
        !_kebabCase.hasMatch(provider) ||
        id.isEmpty ||
        id.runes.length > _maxIdRunes ||
        _whitespace.hasMatch(id)) {
      throw InvalidManifest([ManifestProblem.modelMalformed]);
    }
    return ModelId._(provider, id);
  }

  final String provider;
  final String id;

  @override
  bool operator ==(Object other) =>
      other is ModelId && other.provider == provider && other.id == id;

  @override
  int get hashCode => Object.hash(provider, id);

  @override
  String toString() => '$provider/$id';
}

const _maxProviderLength = 32;
const _maxIdRunes = 128;
final _kebabCase = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');
final _whitespace = RegExp(r'\s');

/// Which models agents may use. It is injected into validation, never a
/// domain constant: the lists are configuration.
///
/// `workers-ai` (free) passes only for ids in [workersAiModels]. A paid
/// provider (BYOK) passes when it is in [paidProviders], with any id.
final class ModelPolicy {
  /// Throws [ArgumentError] if [paidProviders] contains [freeProvider].
  ModelPolicy({
    required Set<String> workersAiModels,
    required Set<String> paidProviders,
  }) : workersAiModels = Set.unmodifiable(workersAiModels),
       paidProviders = Set.unmodifiable(paidProviders) {
    if (paidProviders.contains(freeProvider)) {
      throw ArgumentError.value(
        paidProviders,
        'paidProviders',
        '$freeProvider is the free provider, not a paid one',
      );
    }
  }

  static const freeProvider = 'workers-ai';

  final Set<String> workersAiModels;
  final Set<String> paidProviders;

  bool allows(ModelId model) => model.provider == freeProvider
      ? workersAiModels.contains(model.id)
      : paidProviders.contains(model.provider);

  /// Whether [provider] needs the builder's own API key.
  bool isPaid(String provider) => provider != freeProvider;
}

/// What an agent accepts as input. Only plain text for now.
enum InputType { text }

/// What an agent returns.
enum OutputType { text, markdown }

/// An agent manifest still being edited: every field is optional and there is
/// no version.
///
/// Building a draft accepts missing fields and texts below their minimum, so a
/// half-written manifest can be saved. It rejects values above a maximum.
/// [validate] is the deploy gate.
final class AgentManifestDraft {
  AgentManifestDraft._(
    this.name,
    this.description,
    this.skills,
    this.model,
    this.systemPrompt,
    this.inputType,
    this.inputMaxChars,
    this.outputType,
    this.outputMaxChars,
    this.price,
  );

  /// Throws [InvalidManifest] listing every rule the fields break.
  factory AgentManifestDraft({
    String? name,
    String? description,
    List<Skill>? skills,
    ModelId? model,
    String? systemPrompt,
    InputType? inputType,
    int? inputMaxChars,
    OutputType? outputType,
    int? outputMaxChars,
    UsdcAmount? price,
  }) {
    final draft = AgentManifestDraft._(
      name,
      description,
      skills == null ? null : List.unmodifiable(skills),
      model,
      systemPrompt,
      inputType,
      inputMaxChars,
      outputType,
      outputMaxChars,
      price,
    );
    final problems = draft._check(forDeploy: false);
    if (problems.isNotEmpty) throw InvalidManifest(problems);
    return draft;
  }

  final String? name;
  final String? description;
  final List<Skill>? skills;
  final ModelId? model;
  final String? systemPrompt;
  final InputType? inputType;
  final int? inputMaxChars;
  final OutputType? outputType;
  final int? outputMaxChars;
  final UsdcAmount? price;

  /// Every rule this draft breaks as a deployable manifest, in field order.
  /// The Studio's test run uses it before the deploy.
  List<ManifestProblem> problemsForDeploy(ModelPolicy policy) =>
      _check(forDeploy: true, policy: policy);

  /// The deployable manifest, or [InvalidManifest] listing every broken rule.
  /// The caller passes `latest?.next() ?? ManifestVersion.first` as [version].
  AgentManifest validate(ModelPolicy policy, ManifestVersion version) {
    final problems = problemsForDeploy(policy);
    if (problems.isNotEmpty) throw InvalidManifest(problems);
    return AgentManifest._(
      version,
      name!,
      description!,
      skills!,
      model!,
      systemPrompt!,
      inputType!,
      inputMaxChars!,
      outputType!,
      outputMaxChars!,
      price!,
    );
  }

  /// One pass over the fields in manifest order. A draft skips only the
  /// missing and below-minimum rules; everything else always applies.
  List<ManifestProblem> _check({required bool forDeploy, ModelPolicy? policy}) {
    final found = <ManifestProblem>[];
    void text(
      String? value,
      int min,
      int max,
      ManifestProblem missing,
      ManifestProblem tooShort,
      ManifestProblem tooLong,
    ) {
      final length = value?.runes.length ?? 0;
      if (value == null || value.trim().isEmpty) {
        if (forDeploy) found.add(missing);
      } else if (length > max) {
        found.add(tooLong);
      } else if (forDeploy && length < min) {
        found.add(tooShort);
      }
    }

    text(
      name,
      3,
      48,
      ManifestProblem.nameMissing,
      ManifestProblem.nameTooShort,
      ManifestProblem.nameTooLong,
    );
    text(
      description,
      10,
      280,
      ManifestProblem.descriptionMissing,
      ManifestProblem.descriptionTooShort,
      ManifestProblem.descriptionTooLong,
    );
    final list = skills;
    if (list == null || list.isEmpty) {
      if (forDeploy) found.add(ManifestProblem.skillsMissing);
    } else {
      if (list.length > 5) found.add(ManifestProblem.skillsTooMany);
      if (list.map((s) => s.id).toSet().length != list.length) {
        found.add(ManifestProblem.skillIdDuplicate);
      }
    }
    final chosen = model;
    if (chosen == null) {
      if (forDeploy) found.add(ManifestProblem.modelMissing);
    } else if (forDeploy && policy != null && !policy.allows(chosen)) {
      found.add(
        chosen.provider == ModelPolicy.freeProvider
            ? ManifestProblem.modelNotAllowed
            : ManifestProblem.modelProviderNotEnabled,
      );
    }
    text(
      systemPrompt,
      20,
      8000,
      ManifestProblem.systemPromptMissing,
      ManifestProblem.systemPromptTooShort,
      ManifestProblem.systemPromptTooLong,
    );
    void chars(
      bool present,
      int? max,
      int limit,
      ManifestProblem missing,
      ManifestProblem tooLow,
      ManifestProblem tooHigh,
    ) {
      if (max != null && max > limit) {
        found.add(tooHigh);
      } else if (forDeploy) {
        if (!present || max == null) {
          found.add(missing);
        } else if (max < 1) {
          found.add(tooLow);
        }
      }
    }

    chars(
      inputType != null,
      inputMaxChars,
      8000,
      ManifestProblem.inputMissing,
      ManifestProblem.inputMaxCharsTooLow,
      ManifestProblem.inputMaxCharsTooHigh,
    );
    chars(
      outputType != null,
      outputMaxChars,
      16000,
      ManifestProblem.outputMissing,
      ManifestProblem.outputMaxCharsTooLow,
      ManifestProblem.outputMaxCharsTooHigh,
    );
    final cost = price;
    if (cost == null) {
      if (forDeploy) found.add(ManifestProblem.priceMissing);
    } else if (forDeploy && !cost.isPositive) {
      found.add(ManifestProblem.priceNotPositive);
    }
    return found;
  }
}

/// A validated, immutable agent manifest ready to deploy. Every field is set
/// and the skill lists cannot be changed.
final class AgentManifest {
  AgentManifest._(
    this.version,
    this.name,
    this.description,
    this.skills,
    this.model,
    this.systemPrompt,
    this.inputType,
    this.inputMaxChars,
    this.outputType,
    this.outputMaxChars,
    this.price,
  );

  static const schemaId = 'puls3.agent-manifest/v1';

  final ManifestVersion version;
  final String name;
  final String description;
  final List<Skill> skills;
  final ModelId model;
  final String systemPrompt;
  final InputType inputType;
  final int inputMaxChars;
  final OutputType outputType;
  final int outputMaxChars;
  final UsdcAmount price;

  String get schema => schemaId;

  /// The editable form, without a version. This manifest is not changed.
  AgentManifestDraft toDraft() => AgentManifestDraft(
    name: name,
    description: description,
    skills: skills,
    model: model,
    systemPrompt: systemPrompt,
    inputType: inputType,
    inputMaxChars: inputMaxChars,
    outputType: outputType,
    outputMaxChars: outputMaxChars,
    price: price,
  );

  @override
  bool operator ==(Object other) =>
      other is AgentManifest &&
      other.version == version &&
      other.name == name &&
      other.description == description &&
      _sameSkills(other.skills, skills) &&
      other.model == model &&
      other.systemPrompt == systemPrompt &&
      other.inputType == inputType &&
      other.inputMaxChars == inputMaxChars &&
      other.outputType == outputType &&
      other.outputMaxChars == outputMaxChars &&
      other.price == price;

  @override
  int get hashCode => Object.hash(
    version,
    name,
    description,
    Object.hashAll(skills.map((s) => s.id)),
    model,
    systemPrompt,
    inputType,
    inputMaxChars,
    outputType,
    outputMaxChars,
    price,
  );
}

bool _sameSkills(List<Skill> a, List<Skill> b) =>
    a.length == b.length &&
    [
      for (var i = 0; i < a.length; i++)
        a[i].id == b[i].id &&
            a[i].name == b[i].name &&
            a[i].description == b[i].description &&
            a[i].tags.length == b[i].tags.length &&
            a[i].tags.indexed.every((t) => b[i].tags[t.$1] == t.$2),
    ].every((same) => same);
