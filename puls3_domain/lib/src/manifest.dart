import 'dart:convert';

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

  /// Whether [provider] is a paid provider rather than the Workers AI free
  /// tier. For display and pricing only: every builder agent runs on the
  /// builder's own account, so deploy needs a stored credential for any
  /// provider (ADR-0004 amendment).
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

  static const _wireKeys = {
    'name',
    'description',
    'skills',
    'model',
    'system_prompt',
    'input',
    'output',
    'price',
    'version',
  };

  /// Reads the wire document (snake_case, nested) without ever throwing a type
  /// error: every mismatch becomes a problem. Throws [InvalidManifest] listing
  /// the parse problems together with the draft rules the fields break.
  factory AgentManifestDraft.fromJson(Object? json) {
    final parsed = _parseDocument(json, manifest: false);
    final problems = _merge(
      parsed.problems,
      parsed.draft._check(forDeploy: false),
    );
    if (problems.isNotEmpty) throw InvalidManifest(problems);
    return parsed.draft;
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

  /// The wire document: snake_case and nested, missing fields omitted, no
  /// `schema` and no version.
  Map<String, Object?> toJson() {
    final skills = this.skills, model = this.model, price = this.price;
    final inType = inputType, inMax = inputMaxChars;
    final outType = outputType, outMax = outputMaxChars;
    return {
      'name': ?name,
      'description': ?description,
      if (skills != null)
        'skills': [
          for (final s in skills)
            {
              'id': s.id,
              'name': s.name,
              'description': s.description,
              'tags': [...s.tags],
            },
        ],
      if (model != null) 'model': {'provider': model.provider, 'id': model.id},
      'system_prompt': ?systemPrompt,
      if (inType != null || inMax != null)
        'input': {
          'type': ?inType?.name,
          'max_chars': ?inMax,
        },
      if (outType != null || outMax != null)
        'output': {
          'type': ?outType?.name,
          'max_chars': ?outMax,
        },
      if (price != null) 'price': {'asset': _asset, 'amount': price.stroops},
    };
  }

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
      // A non-positive limit is malformed, not incomplete: both modes reject.
      if (max != null && max > limit) {
        found.add(tooHigh);
      } else if (max != null && max < 1) {
        found.add(tooLow);
      } else if (forDeploy && (!present || max == null)) {
        found.add(missing);
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

  /// Reads a deployable manifest from the wire document. `schema` is optional
  /// but must match; `version` is required. Throws [InvalidManifest] listing
  /// every parse problem and every deploy rule the fields break under [policy].
  factory AgentManifest.fromJson(Object? json, ModelPolicy policy) {
    final parsed = _parseDocument(json, manifest: true);
    final problems = _merge(
      parsed.problems,
      parsed.draft._check(forDeploy: true, policy: policy),
    );
    if (problems.isNotEmpty) throw InvalidManifest(problems);
    return parsed.draft.validate(policy, parsed.version!);
  }

  /// The wire document, `schema` and `version` included.
  Map<String, Object?> toJson() => {
    'schema': schema,
    'version': version.value,
    ...toDraft().toJson(),
  };

  /// The canonical form: see [canonicalJson]. Encode it as UTF-8 to hash it
  /// (hashing and salting belong to the server, #18).
  String toCanonicalJson() => canonicalJson(toJson());

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

const _asset = 'USDC';

/// A parsed document: the problems found while reading it and the draft built
/// from the fields that did parse.
final class _Parsed {
  _Parsed(this.problems, this.draft, [this.version]);

  final List<ManifestProblem> problems;
  final AgentManifestDraft draft;
  final ManifestVersion? version;
}

/// Deduplicates, orders by field (the enum order, so a parse problem and a rule
/// problem on different fields interleave as the fields do) and drops a "missing" problem when the same field
/// already has a "malformed" one, so one bad field is reported once.
List<ManifestProblem> _merge(
  List<ManifestProblem> parse,
  List<ManifestProblem> check,
) {
  if (parse.contains(ManifestProblem.notAnObject)) return parse;
  final all = [
    ...{...parse, ...check},
  ]..sort((a, b) => a.index.compareTo(b.index));
  return [
    for (final p in all)
      if (!(_supersededBy[p] ?? const {}).any(all.contains)) p,
  ];
}

/// A wire number read as an integer: see [_integer]. Anything beyond +-(2^53-1)
/// is refused, because dart2js cannot hold it exactly. On the web `3.0` and
/// `3` are one value, so an integral number is accepted whichever way it was
/// written.
int? _wireInteger(Object? value) {
  final n = _integer(value);
  return n == null || n.abs() > ManifestVersion.maxValue ? null : n;
}

const _supersededBy = <ManifestProblem, Set<ManifestProblem>>{
  ManifestProblem.nameMissing: {ManifestProblem.nameMalformed},
  ManifestProblem.descriptionMissing: {ManifestProblem.descriptionMalformed},
  ManifestProblem.skillsMissing: {
    ManifestProblem.skillsMalformed,
    ManifestProblem.skillIdNotKebabCase,
    ManifestProblem.skillNameLength,
  },
  ManifestProblem.modelMissing: {ManifestProblem.modelMalformed},
  ManifestProblem.systemPromptMissing: {ManifestProblem.systemPromptMalformed},
  ManifestProblem.inputMissing: {ManifestProblem.inputMalformed},
  ManifestProblem.outputMissing: {ManifestProblem.outputMalformed},
  ManifestProblem.priceMissing: {
    ManifestProblem.priceMalformed,
    ManifestProblem.priceAssetUnsupported,
  },
};

_Parsed _parseDocument(Object? json, {required bool manifest}) {
  final found = <ManifestProblem>[];

  Map<Object?, Object?>? object(
    Object? value,
    Set<String> keys,
    ManifestProblem malformed,
  ) {
    if (value == null) return null;
    if (value is! Map) {
      found.add(malformed);
      return null;
    }
    for (final key in value.keys) {
      if (key == 'tools') {
        found.add(ManifestProblem.toolsNotSupported);
      } else if (!keys.contains(key)) {
        found.add(ManifestProblem.unknownKey);
      }
    }
    return value;
  }

  String? text(Map<Object?, Object?> from, String key, ManifestProblem bad) {
    final value = from[key];
    if (value == null) return null;
    if (value is String) return value;
    found.add(bad);
    return null;
  }

  int? whole(Map<Object?, Object?> from, String key, ManifestProblem bad) {
    final value = from[key];
    if (value == null) return null;
    final n = _wireInteger(value);
    if (n != null) return n;
    found.add(bad);
    return null;
  }

  (T?, int?) section<T extends Enum>(
    Object? value,
    List<T> types,
    ManifestProblem malformed,
    ManifestProblem unsupported,
  ) {
    final map = object(value, {'type', 'max_chars'}, malformed);
    if (map == null) return (null, null);
    final name = text(map, 'type', malformed);
    final type = types.where((t) => t.name == name).firstOrNull;
    if (name != null && type == null) found.add(unsupported);
    return (type, whole(map, 'max_chars', malformed));
  }

  if (json is! Map) {
    return _Parsed(
      [
        ManifestProblem.notAnObject,
      ],
      AgentManifestDraft._(
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
      ),
    );
  }
  final doc = object(json, {
    ...AgentManifestDraft._wireKeys,
    if (manifest) 'schema',
  }, ManifestProblem.notAnObject)!;
  ManifestVersion? version;
  if (manifest) {
    final schema = doc['schema'];
    if (schema != null && schema != AgentManifest.schemaId) {
      found.add(ManifestProblem.schemaUnsupported);
    }
    final raw = doc['version'];
    try {
      final n = _wireInteger(raw);
      version = n == null ? null : ManifestVersion(n);
    } on InvalidManifest {
      version = null;
    }
    if (version == null) found.add(ManifestProblem.versionInvalid);
  } else if (doc.containsKey('version')) {
    found.add(ManifestProblem.versionInDraft);
  }

  final name = text(doc, 'name', ManifestProblem.nameMalformed);
  final description = text(
    doc,
    'description',
    ManifestProblem.descriptionMalformed,
  );

  List<Skill>? skills;
  final rawSkills = doc['skills'];
  if (rawSkills is List) {
    skills = [];
    for (final item in rawSkills) {
      final map = object(item ?? 0, {
        'id',
        'name',
        'description',
        'tags',
      }, ManifestProblem.skillsMalformed);
      if (map == null) continue;
      final id = map['id'] ?? '', skillName = map['name'] ?? '';
      final about = map['description'] ?? '', tags = map['tags'] ?? [];
      if (id is! String ||
          skillName is! String ||
          about is! String ||
          tags is! List ||
          !tags.every((t) => t is String)) {
        found.add(ManifestProblem.skillsMalformed);
        continue;
      }
      try {
        skills.add(
          Skill(
            id: id,
            name: skillName,
            description: about,
            tags: tags.cast<String>(),
          ),
        );
      } on InvalidSkill catch (e) {
        found.add(switch (e.problem) {
          SkillProblem.idNotKebabCase => ManifestProblem.skillIdNotKebabCase,
          SkillProblem.nameLength => ManifestProblem.skillNameLength,
        });
      }
    }
  } else if (rawSkills != null) {
    found.add(ManifestProblem.skillsMalformed);
  }

  ModelId? model;
  final modelMap = object(doc['model'], {
    'provider',
    'id',
  }, ManifestProblem.modelMalformed);
  if (modelMap != null) {
    final provider = modelMap['provider'], id = modelMap['id'];
    try {
      if (provider is! String || id is! String) {
        throw InvalidManifest([ManifestProblem.modelMalformed]);
      }
      model = ModelId(provider: provider, id: id);
    } on InvalidManifest {
      found.add(ManifestProblem.modelMalformed);
    }
  }

  final systemPrompt = text(
    doc,
    'system_prompt',
    ManifestProblem.systemPromptMalformed,
  );
  final (inputType, inputMax) = section(
    doc['input'],
    InputType.values,
    ManifestProblem.inputMalformed,
    ManifestProblem.inputTypeUnsupported,
  );
  final (outputType, outputMax) = section(
    doc['output'],
    OutputType.values,
    ManifestProblem.outputMalformed,
    ManifestProblem.outputTypeUnsupported,
  );

  UsdcAmount? price;
  final priceMap = object(doc['price'], {
    'asset',
    'amount',
  }, ManifestProblem.priceMalformed);
  if (priceMap != null) {
    if (priceMap['asset'] != _asset) {
      found.add(ManifestProblem.priceAssetUnsupported);
    }
    final amount = whole(priceMap, 'amount', ManifestProblem.priceMalformed);
    try {
      price = amount == null ? null : UsdcAmount.stroops(amount);
    } on InvalidAmount {
      found.add(ManifestProblem.priceMalformed);
    }
  }

  return _Parsed(
    found,
    AgentManifestDraft._(
      name,
      description,
      skills == null ? null : List.unmodifiable(skills),
      model,
      systemPrompt,
      inputType,
      inputMax,
      outputType,
      outputMax,
      price,
    ),
    version,
  );
}

/// The canonical JSON text of [value]: object keys sorted at every depth, no
/// whitespace, array order kept, and integers only.
///
/// The same data always gives the same text, whatever the key order it was
/// built with. Non-ASCII text is kept as is, so UTF-8 encoding the result gives
/// the canonical bytes.
///
/// Numbers must be integers. An integral `double` such as `3.0` is written as
/// `3`: on the web (dart2js) `3.0` and `3` are the same value, so they cannot
/// be told apart. Throws [StateError] on a non-integral or non-finite number, on
/// an integral `double` outside +-(2^53-1), and on any map key that is not a
/// `String`.
String canonicalJson(Object? value) => jsonEncode(_sortKeysDeep(value));

Object? _sortKeysDeep(Object? node) => switch (node) {
  Map() => {
    for (final key in (_stringKeys(node)..sort()))
      key: _sortKeysDeep(node[key]),
  },
  List() => [for (final item in node) _sortKeysDeep(item)],
  num() =>
    _integer(node) ??
        (throw StateError('canonical JSON allows integers only: $node')),
  _ => node,
};

List<String> _stringKeys(Map<Object?, Object?> map) {
  for (final key in map.keys) {
    if (key is! String) {
      throw StateError('canonical JSON keys must be strings: $key');
    }
  }
  return map.keys.cast<String>().toList();
}

/// [value] as an `int` when it is an integer: an `int`, or a finite integral
/// `double` within +-(2^53-1) (the range a double holds exactly). Otherwise
/// null. The range applies to `int` too: on dart2js every integral double is
/// an `int`, so the check must not depend on the platform.
int? _integer(Object? value) {
  if (value is int) {
    return value.abs() <= ManifestVersion.maxValue ? value : null;
  }
  if (value is double &&
      value.isFinite &&
      value == value.truncateToDouble() &&
      value.abs() <= ManifestVersion.maxValue) {
    return value.toInt();
  }
  return null;
}
