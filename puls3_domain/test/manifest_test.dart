import 'package:puls3_domain/puls3_domain.dart';
import 'package:test/test.dart';

/// Matches an [InvalidManifest] whose problem list equals [expected].
Matcher problems(List<ManifestProblem> expected) => throwsA(
  isA<InvalidManifest>().having((e) => e.problems, 'problems', expected),
);

final policy = ModelPolicy(
  workersAiModels: {'@cf/meta/llama-3.1-8b-instruct'},
  paidProviders: {'anthropic'},
);

final llama = ModelId(
  provider: 'workers-ai',
  id: '@cf/meta/llama-3.1-8b-instruct',
);

Skill skill([String id = 'rewrite']) => Skill(id: id, name: 'Rewrite');

/// A draft that passes every deploy rule; [overrides] replace single fields.
AgentManifestDraft complete({
  String? name,
  String? description,
  List<Skill>? skills,
  ModelId? model,
  String? systemPrompt,
  int? inputMaxChars,
  int? outputMaxChars,
  UsdcAmount? price,
}) => AgentManifestDraft(
  name: name ?? 'Copy Forge',
  description: description ?? 'Rewrites marketing copy.',
  skills: skills ?? [skill()],
  model: model ?? llama,
  systemPrompt: systemPrompt ?? 'You rewrite copy in a clear voice.',
  inputType: InputType.text,
  inputMaxChars: inputMaxChars ?? 4000,
  outputType: OutputType.markdown,
  outputMaxChars: outputMaxChars ?? 8000,
  price: price ?? UsdcAmount.stroops(3000000),
);

List<ManifestProblem> deploy(AgentManifestDraft d) =>
    d.problemsForDeploy(policy);

String runes(int n) => 'a' * n;

void main() {
  group('I25 ManifestVersion', () {
    test('rejects 0 and negative numbers', () {
      for (final v in [0, -1]) {
        expect(
          () => ManifestVersion(v),
          problems([ManifestProblem.versionInvalid]),
          reason: '$v',
        );
      }
    });

    test('accepts 1 and larger', () {
      expect(ManifestVersion(1).value, 1);
      expect(ManifestVersion(42).value, 42);
    });

    test('first is 1', () {
      expect(ManifestVersion.first, ManifestVersion(1));
    });

    test('next is the following number and leaves the original alone', () {
      final v3 = ManifestVersion(3);
      expect(v3.next(), ManifestVersion(4));
      expect(v3.value, 3);
    });

    test('caps at 2^53-1 and next() at the cap fails with a typed problem', () {
      const cap = 9007199254740991;
      expect(ManifestVersion(cap).value, cap);
      expect(
        () => ManifestVersion(cap + 1),
        problems([ManifestProblem.versionInvalid]),
      );
      expect(
        () => ManifestVersion(cap).next(),
        problems([ManifestProblem.versionInvalid]),
      );
      expect(ManifestVersion(cap - 1).next(), ManifestVersion(cap));
    });

    test('orders by value and has value equality', () {
      expect(ManifestVersion(2).compareTo(ManifestVersion(3)), lessThan(0));
      expect(ManifestVersion(3).compareTo(ManifestVersion(2)), greaterThan(0));
      expect(ManifestVersion(2), ManifestVersion(2));
      expect(ManifestVersion(2).hashCode, ManifestVersion(2).hashCode);
    });
  });

  group('I23 ModelId', () {
    test('holds a provider and an id and has value equality', () {
      final m = ModelId(provider: 'anthropic', id: 'claude-sonnet-4');
      expect(m.provider, 'anthropic');
      expect(m.id, 'claude-sonnet-4');
      expect(
        m,
        ModelId(provider: 'anthropic', id: 'claude-sonnet-4'),
      );
      expect(
        m.hashCode,
        ModelId(provider: 'anthropic', id: 'claude-sonnet-4').hashCode,
      );
      expect(m, isNot(ModelId(provider: 'anthropic', id: 'other')));
      expect(m, isNot(ModelId(provider: 'openai', id: 'claude-sonnet-4')));
    });

    test('accepts a workers-ai id with slashes, dots and at sign', () {
      final m = ModelId(
        provider: 'workers-ai',
        id: '@cf/meta/llama-3.1-8b-instruct',
      );
      expect(m.id, '@cf/meta/llama-3.1-8b-instruct');
    });

    test('provider must be kebab-case', () {
      for (final p in ['', 'Anthropic', 'open ai', 'open_ai', '-a', 'a-']) {
        expect(
          () => ModelId(provider: p, id: 'x'),
          problems([ManifestProblem.modelMalformed]),
          reason: p,
        );
      }
    });

    test('provider is at most 32 characters', () {
      expect(ModelId(provider: 'a' * 32, id: 'x').provider, 'a' * 32);
      expect(
        () => ModelId(provider: 'a' * 33, id: 'x'),
        problems([ManifestProblem.modelMalformed]),
      );
    });

    test('id is at most 128 runes', () {
      expect(ModelId(provider: 'acme', id: 'x' * 128).id, 'x' * 128);
      expect(
        () => ModelId(provider: 'acme', id: 'x' * 129),
        problems([ManifestProblem.modelMalformed]),
      );
      // Emoji are one rune but two UTF-16 units: 128 of them still pass.
      expect(ModelId(provider: 'acme', id: '😀' * 128).id.runes.length, 128);
    });

    test('id must be non-blank and without whitespace', () {
      for (final id in ['', ' ', 'a b', 'a\tb', 'a\nb', ' a', 'a ']) {
        expect(
          () => ModelId(provider: 'acme', id: id),
          problems([ManifestProblem.modelMalformed]),
          reason: id,
        );
      }
    });
  });

  group('I24 ModelPolicy', () {
    final llama = ModelId(
      provider: 'workers-ai',
      id: '@cf/meta/llama-3.1-8b-instruct',
    );
    ModelPolicy policy({
      Set<String> workersAiModels = const {'@cf/meta/llama-3.1-8b-instruct'},
      Set<String> paidProviders = const {'anthropic'},
    }) => ModelPolicy(
      workersAiModels: workersAiModels,
      paidProviders: paidProviders,
    );

    test('free provider is workers-ai', () {
      expect(ModelPolicy.freeProvider, 'workers-ai');
    });

    test('allows a workers-ai model on the allowlist', () {
      expect(policy().allows(llama), isTrue);
    });

    test('rejects a workers-ai model off the allowlist', () {
      expect(policy(workersAiModels: const {}).allows(llama), isFalse);
      expect(
        policy().allows(ModelId(provider: 'workers-ai', id: 'other')),
        isFalse,
      );
    });

    test('allows any id of an enabled paid provider', () {
      final p = policy();
      expect(p.allows(ModelId(provider: 'anthropic', id: 'claude-x')), isTrue);
      expect(p.allows(ModelId(provider: 'anthropic', id: 'anything')), isTrue);
    });

    test('rejects a disabled or unknown paid provider', () {
      final p = policy();
      expect(p.allows(ModelId(provider: 'openai', id: 'gpt-x')), isFalse);
      expect(p.allows(ModelId(provider: 'acme', id: 'x')), isFalse);
      expect(
        policy(paidProviders: const {}).allows(
          ModelId(provider: 'anthropic', id: 'claude-x'),
        ),
        isFalse,
      );
    });

    test('isPaid is false only for workers-ai', () {
      final p = policy();
      expect(p.isPaid('workers-ai'), isFalse);
      expect(p.isPaid('anthropic'), isTrue);
      expect(p.isPaid('openai'), isTrue);
    });

    test('workers-ai cannot be a paid provider', () {
      expect(
        () => policy(paidProviders: const {'anthropic', 'workers-ai'}),
        throwsArgumentError,
      );
    });

    test('copies its sets so later changes do not leak in', () {
      final models = {'@cf/meta/llama-3.1-8b-instruct'};
      final paid = {'anthropic'};
      final p = policy(workersAiModels: models, paidProviders: paid);
      models.clear();
      paid.add('openai');
      expect(p.allows(llama), isTrue);
      expect(p.allows(ModelId(provider: 'openai', id: 'gpt-x')), isFalse);
      expect(() => p.workersAiModels.add('x'), throwsUnsupportedError);
      expect(() => p.paidProviders.add('x'), throwsUnsupportedError);
    });
  });

  group('I27 Text rules', () {
    test('count runes, so 3 emoji are a valid name', () {
      expect(deploy(complete(name: '😀😀😀')), isEmpty);
    });

    test('whitespace-only text is missing and is never trimmed', () {
      expect(deploy(complete(name: ' ' * 10)), [ManifestProblem.nameMissing]);
      expect(deploy(complete(description: ' ' * 20)), [
        ManifestProblem.descriptionMissing,
      ]);
      final kept = complete(name: '  abc  ');
      expect(kept.name, '  abc  ');
      expect(deploy(kept), isEmpty);
    });

    test('name, description and system prompt boundaries', () {
      final cases = <(String, int, int, ManifestProblem, ManifestProblem)>[
        (
          'name',
          3,
          48,
          ManifestProblem.nameTooShort,
          ManifestProblem.nameTooLong,
        ),
        (
          'description',
          10,
          280,
          ManifestProblem.descriptionTooShort,
          ManifestProblem.descriptionTooLong,
        ),
        (
          'systemPrompt',
          20,
          8000,
          ManifestProblem.systemPromptTooShort,
          ManifestProblem.systemPromptTooLong,
        ),
      ];
      AgentManifestDraft build(String field, String text) => complete(
        name: field == 'name' ? text : null,
        description: field == 'description' ? text : null,
        systemPrompt: field == 'systemPrompt' ? text : null,
      );
      for (final (field, min, max, tooShort, tooLong) in cases) {
        expect(deploy(build(field, runes(min))), isEmpty, reason: field);
        expect(deploy(build(field, runes(max))), isEmpty, reason: field);
        expect(deploy(build(field, runes(min - 1))), [tooShort]);
        expect(
          () => build(field, runes(max + 1)),
          problems([tooLong]),
          reason: field,
        );
      }
    });
  });

  group('I28-I31 Field rules', () {
    test('skills: 1 to 5 pass, 0 is missing, 6 is too many', () {
      List<Skill> n(int c) => [for (var i = 0; i < c; i++) skill('s$i')];
      expect(deploy(complete(skills: n(1))), isEmpty);
      expect(deploy(complete(skills: n(5))), isEmpty);
      expect(deploy(complete(skills: n(0))), [ManifestProblem.skillsMissing]);
      expect(
        () => complete(skills: n(6)),
        problems([
          ManifestProblem.skillsTooMany,
        ]),
      );
    });

    test('skills: a duplicate id is rejected, even in a draft', () {
      expect(
        () => complete(skills: [skill('a'), skill('a')]),
        problems([ManifestProblem.skillIdDuplicate]),
      );
    });

    test('input and output max chars: boundaries', () {
      expect(deploy(complete(inputMaxChars: 1, outputMaxChars: 1)), isEmpty);
      expect(
        deploy(complete(inputMaxChars: 8000, outputMaxChars: 16000)),
        isEmpty,
      );
      expect(deploy(complete(inputMaxChars: 0, outputMaxChars: -1)), [
        ManifestProblem.inputMaxCharsTooLow,
        ManifestProblem.outputMaxCharsTooLow,
      ]);
    });

    test('input and output are missing when unset', () {
      expect(
        deploy(AgentManifestDraft(inputMaxChars: 5)),
        contains(
          ManifestProblem.inputMissing,
        ),
      );
      expect(
        deploy(AgentManifestDraft(outputType: OutputType.text)),
        contains(
          ManifestProblem.outputMissing,
        ),
      );
    });

    test('price: positive passes, zero is not positive, unset is missing', () {
      expect(deploy(complete(price: UsdcAmount.stroops(1))), isEmpty);
      expect(deploy(complete(price: UsdcAmount.zero)), [
        ManifestProblem.priceNotPositive,
      ]);
      expect(
        deploy(AgentManifestDraft()),
        contains(
          ManifestProblem.priceMissing,
        ),
      );
    });

    test('model: allowed, outside the allowlist, disabled and unknown', () {
      ModelId m(String provider, String id) =>
          ModelId(provider: provider, id: id);
      expect(deploy(complete(model: m('anthropic', 'claude-x'))), isEmpty);
      expect(deploy(complete(model: m('workers-ai', 'other'))), [
        ManifestProblem.modelNotAllowed,
      ]);
      for (final provider in ['openai', 'acme']) {
        expect(deploy(complete(model: m(provider, 'x'))), [
          ManifestProblem.modelProviderNotEnabled,
        ], reason: provider);
      }
      expect(
        deploy(AgentManifestDraft()),
        contains(
          ManifestProblem.modelMissing,
        ),
      );
    });

    test('a draft does not check the model policy', () {
      expect(
        complete(
          model: ModelId(provider: 'acme', id: 'x'),
        ).model,
        isNotNull,
      );
    });
  });

  group('I26 Draft tolerance', () {
    test('an empty draft is accepted', () {
      expect(AgentManifestDraft().name, isNull);
    });

    test('texts below their minimum are accepted', () {
      final d = AgentManifestDraft(
        name: 'a',
        description: 'abc',
        systemPrompt: 'short',
      );
      expect(d.name, 'a');
    });

    test('values above a maximum are rejected, all at once', () {
      expect(
        () => AgentManifestDraft(
          name: runes(49),
          systemPrompt: runes(8001),
          inputMaxChars: 8001,
          outputMaxChars: 16001,
        ),
        problems([
          ManifestProblem.nameTooLong,
          ManifestProblem.systemPromptTooLong,
          ManifestProblem.inputMaxCharsTooHigh,
          ManifestProblem.outputMaxCharsTooHigh,
        ]),
      );
    });
  });

  group('I32 Deploy', () {
    test('a complete draft becomes a version 1 manifest', () {
      final m = complete().validate(policy, ManifestVersion.first);
      expect(m.version, ManifestVersion.first);
      expect(m.schema, 'puls3.agent-manifest/v1');
      expect(m.name, 'Copy Forge');
      expect(m.model, llama);
      expect(m.price, UsdcAmount.stroops(3000000));
    });

    test('an empty draft lists one missing problem per required field', () {
      expect(
        () => AgentManifestDraft().validate(policy, ManifestVersion.first),
        problems([
          ManifestProblem.nameMissing,
          ManifestProblem.descriptionMissing,
          ManifestProblem.skillsMissing,
          ManifestProblem.modelMissing,
          ManifestProblem.systemPromptMissing,
          ManifestProblem.inputMissing,
          ManifestProblem.outputMissing,
          ManifestProblem.priceMissing,
        ]),
      );
    });

    test('six problems come at once, in field order, and are stable', () {
      AgentManifestDraft bad() => complete(
        name: 'ab',
        description: 'short',
        skills: [],
        model: ModelId(provider: 'workers-ai', id: 'other'),
        inputMaxChars: 0,
        price: UsdcAmount.zero,
      );
      const expected = [
        ManifestProblem.nameTooShort,
        ManifestProblem.descriptionTooShort,
        ManifestProblem.skillsMissing,
        ManifestProblem.modelNotAllowed,
        ManifestProblem.inputMaxCharsTooLow,
        ManifestProblem.priceNotPositive,
      ];
      expect(
        () => bad().validate(policy, ManifestVersion.first),
        problems(expected),
      );
      expect(bad().problemsForDeploy(policy), expected);
      expect(bad().problemsForDeploy(policy), expected);
    });

    test('the same input gives equal manifests', () {
      final a = complete().validate(policy, ManifestVersion.first);
      final b = complete().validate(policy, ManifestVersion.first);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
        a,
        isNot(complete(name: 'Other').validate(policy, ManifestVersion.first)),
      );
      expect(a, isNot(complete().validate(policy, ManifestVersion(2))));
    });

    test('skills and tags cannot be changed afterwards', () {
      final tagged = Skill(id: 'rewrite', name: 'Rewrite', tags: ['copy']);
      final m = complete(
        skills: [tagged],
      ).validate(policy, ManifestVersion.first);
      expect(() => m.skills.add(skill('x')), throwsUnsupportedError);
      expect(() => m.skills.first.tags.add('x'), throwsUnsupportedError);
    });

    test('toDraft has no version and leaves the manifest alone', () {
      final m = complete().validate(policy, ManifestVersion(3));
      final d = m.toDraft();
      expect(d.name, m.name);
      expect(d.skills, m.skills);
      expect(d.price, m.price);
      expect(d.validate(policy, m.version.next()).version, ManifestVersion(4));
      expect(m.version, ManifestVersion(3));
    });
  });

  group('InvalidManifest', () {
    test('carries the problems in order with a readable message', () {
      final e = InvalidManifest([
        ManifestProblem.nameMissing,
        ManifestProblem.priceMissing,
      ]);
      expect(e.problems, [
        ManifestProblem.nameMissing,
        ManifestProblem.priceMissing,
      ]);
      expect(e.message, contains('name is required'));
      expect(e.message, contains('price is required'));
      expect(e.message, isNot(contains('nameMissing')));
    });

    test('every problem has its own readable text', () {
      final texts = {
        for (final p in ManifestProblem.values) InvalidManifest([p]).message: p,
      };
      expect(texts.length, ManifestProblem.values.length);
      for (final p in ManifestProblem.values) {
        expect(InvalidManifest([p]).message, isNot(contains(p.name)));
      }
    });

    test('problems list is unmodifiable', () {
      final e = InvalidManifest([ManifestProblem.nameMissing]);
      expect(
        () => e.problems.add(ManifestProblem.priceMissing),
        throwsA(anything),
      );
    });

    test('rejects an empty list', () {
      expect(() => InvalidManifest([]), throwsArgumentError);
    });
  });
}
