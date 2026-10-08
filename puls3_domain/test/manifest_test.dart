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

  group('Hardening: runes, equality, aliasing, deploy edges', () {
    const emoji = '\u{1F600}';
    String emojis(int n) => emoji * n;

    test('name counts runes, not UTF-16 units', () {
      expect(emojis(2).length, 4);
      expect(deploy(complete(name: emojis(2))), [ManifestProblem.nameTooShort]);
      expect(deploy(complete(name: emojis(3))), isEmpty);
      expect(deploy(complete(name: emojis(25))), isEmpty);
      expect(deploy(complete(name: emojis(48))), isEmpty);
      expect(
        () => complete(name: emojis(49)),
        problems([ManifestProblem.nameTooLong]),
      );
    });

    test('description counts runes, not UTF-16 units', () {
      expect(deploy(complete(description: emojis(5))), [
        ManifestProblem.descriptionTooShort,
      ]);
      expect(deploy(complete(description: emojis(10))), isEmpty);
      expect(deploy(complete(description: emojis(280))), isEmpty);
      expect(
        () => complete(description: emojis(281)),
        problems([ManifestProblem.descriptionTooLong]),
      );
    });

    test('systemPrompt counts runes, not UTF-16 units', () {
      expect(deploy(complete(systemPrompt: emojis(10))), [
        ManifestProblem.systemPromptTooShort,
      ]);
      expect(deploy(complete(systemPrompt: emojis(20))), isEmpty);
      expect(deploy(complete(systemPrompt: emojis(8000))), isEmpty);
      expect(
        () => complete(systemPrompt: emojis(8001)),
        problems([ManifestProblem.systemPromptTooLong]),
      );
    });

    Skill tagged({
      String id = 'rewrite',
      String name = 'Rewrite',
      String description = 'Rewrites',
      List<String> tags = const ['copy'],
    }) => Skill(id: id, name: name, description: description, tags: tags);

    AgentManifest build({
      int version = 1,
      String name = 'Copy Forge',
      String description = 'Rewrites marketing copy.',
      List<Skill>? skills,
      ModelId? model,
      String systemPrompt = 'You rewrite copy in a clear voice.',
      int inputMaxChars = 4000,
      OutputType outputType = OutputType.markdown,
      int outputMaxChars = 8000,
      int price = 3000000,
    }) => AgentManifestDraft(
      name: name,
      description: description,
      skills: skills ?? [tagged()],
      model: model ?? llama,
      systemPrompt: systemPrompt,
      inputType: InputType.text,
      inputMaxChars: inputMaxChars,
      outputType: outputType,
      outputMaxChars: outputMaxChars,
      price: UsdcAmount.stroops(price),
    ).validate(policy, ManifestVersion(version));

    test('equal manifests have equal hash codes', () {
      expect(build(), build());
      expect(build().hashCode, build().hashCode);
    });

    test('a manifest differing in one field only is not equal', () {
      final base = build();
      final variants = <String, AgentManifest>{
        'version': build(version: 2),
        'name': build(name: 'Other Name'),
        'description': build(description: 'Rewrites other copy.'),
        'skill id': build(skills: [tagged(id: 'other')]),
        'skill name': build(skills: [tagged(name: 'Other')]),
        'skill description': build(skills: [tagged(description: 'Different')]),
        'skill tags': build(
          skills: [
            tagged(tags: ['other']),
          ],
        ),
        'skill tag count': build(
          skills: [
            tagged(tags: ['copy', 'more']),
          ],
        ),
        'skill count': build(skills: [tagged(), skill('second')]),
        'model': build(
          model: ModelId(provider: 'anthropic', id: 'x'),
        ),
        'systemPrompt': build(systemPrompt: 'You rewrite copy differently.'),
        'inputMaxChars': build(inputMaxChars: 4001),
        'outputType': build(outputType: OutputType.text),
        'outputMaxChars': build(outputMaxChars: 8001),
        'price': build(price: 3000001),
      };
      variants.forEach((field, other) {
        expect(base == other, isFalse, reason: field);
        expect(other == base, isFalse, reason: field);
      });
    });

    test(
      'changing the original skills list after building changes nothing',
      () {
        final original = [skill('a')];
        final draft = complete(skills: original);
        final manifest = draft.validate(policy, ManifestVersion.first);
        final expected = complete(
          skills: [skill('a')],
        ).validate(policy, ManifestVersion.first);

        original
          ..add(skill('b'))
          ..add(skill('c'));
        expect(draft.skills!.map((s) => s.id), ['a']);
        expect(manifest.skills.map((s) => s.id), ['a']);
        expect(manifest, expected);

        original.clear();
        expect(draft.skills!.map((s) => s.id), ['a']);
        expect(manifest.skills.map((s) => s.id), ['a']);
        expect(draft.problemsForDeploy(policy), isEmpty);
        expect(manifest, expected);
      },
    );

    test('changing the list after validate leaves the manifest alone', () {
      final original = [skill('a')];
      final draft = complete(skills: original);
      final manifest = draft.validate(policy, ManifestVersion.first);
      original.add(skill('b'));
      expect(draft.validate(policy, ManifestVersion.first), manifest);
      expect(manifest.skills, hasLength(1));
    });

    test('a draft skills list cannot be changed', () {
      final draft = complete();
      expect(() => draft.skills!.add(skill('x')), throwsUnsupportedError);
    });

    test('input or output type without a max is missing on deploy', () {
      final full = complete();
      final noInputMax = AgentManifestDraft(
        name: full.name,
        description: full.description,
        skills: full.skills,
        model: full.model,
        systemPrompt: full.systemPrompt,
        inputType: InputType.text,
        outputType: OutputType.markdown,
        outputMaxChars: 8000,
        price: full.price,
      );
      expect(deploy(noInputMax), [ManifestProblem.inputMissing]);
      final noOutputMax = AgentManifestDraft(
        name: full.name,
        description: full.description,
        skills: full.skills,
        model: full.model,
        systemPrompt: full.systemPrompt,
        inputType: InputType.text,
        inputMaxChars: 4000,
        outputType: OutputType.markdown,
        price: full.price,
      );
      expect(deploy(noOutputMax), [ManifestProblem.outputMissing]);
    });

    test('toDraft then validate gives back an equal manifest', () {
      final m = build();
      final again = m.toDraft().validate(policy, m.version);
      expect(again, m);
      expect(again.hashCode, m.hashCode);
    });

    test('a whitespace-only systemPrompt is missing on deploy only', () {
      final d = complete(systemPrompt: ' \n\t ');
      expect(d.systemPrompt, ' \n\t ');
      expect(deploy(d), [ManifestProblem.systemPromptMissing]);
      expect(
        () => d.validate(policy, ManifestVersion.first),
        problems([ManifestProblem.systemPromptMissing]),
      );
    });
  });
  group('Draft JSON', () {
    test('parses the wire shape into the Dart fields', () {
      final d = AgentManifestDraft.fromJson(draftDoc());
      expect(d.name, 'Copy Forge');
      expect(d.skills!.single.id, 'rewrite');
      expect(d.skills!.single.tags, ['copy']);
      expect(d.model, llama);
      expect(d.systemPrompt, 'You rewrite copy in a clear voice.');
      expect(d.inputType, InputType.text);
      expect(d.inputMaxChars, 4000);
      expect(d.outputType, OutputType.markdown);
      expect(d.outputMaxChars, 8000);
      expect(d.price, UsdcAmount.stroops(3000000));
      expect(deploy(d), isEmpty);
    });

    test('S4 wrong types become problems, never exceptions', () {
      expect(
        () => AgentManifestDraft.fromJson(
          draftDoc()
            ..['name'] = 7
            ..['description'] = true
            ..['skills'] = 'rewrite'
            ..['model'] = 'x'
            ..['system_prompt'] = []
            ..['input'] = 3
            ..['output'] = {'type': 'markdown', 'max_chars': '8000'}
            ..['price'] = {'asset': 'USDC', 'amount': '3000000'},
        ),
        problems([
          ManifestProblem.nameMalformed,
          ManifestProblem.descriptionMalformed,
          ManifestProblem.skillsMalformed,
          ManifestProblem.modelMalformed,
          ManifestProblem.systemPromptMalformed,
          ManifestProblem.inputMalformed,
          ManifestProblem.outputMalformed,
          ManifestProblem.priceMalformed,
        ]),
      );
    });

    test('S4 a float or out-of-range price amount is malformed', () {
      for (final amount in [1.5, 3000000.0, -1, UsdcAmount.maxStroops + 1]) {
        expect(
          () => AgentManifestDraft.fromJson(
            draftDoc()..['price'] = {'asset': 'USDC', 'amount': amount},
          ),
          problems([ManifestProblem.priceMalformed]),
          reason: '$amount',
        );
      }
    });

    test('a non-object is notAnObject', () {
      for (final value in [null, 'x', 3, <Object?>[]]) {
        expect(
          () => AgentManifestDraft.fromJson(value),
          problems([ManifestProblem.notAnObject]),
          reason: '$value',
        );
      }
    });

    test('S24 tools has its own problem, apart from unknownKey', () {
      expect(
        () => AgentManifestDraft.fromJson(draftDoc()..['tools'] = []),
        problems([ManifestProblem.toolsNotSupported]),
      );
    });

    test('a version in a draft is versionInDraft', () {
      expect(
        () => AgentManifestDraft.fromJson(draftDoc()..['version'] = 1),
        problems([ManifestProblem.versionInDraft]),
      );
    });

    test('S19/S32 unknown keys are rejected at every level', () {
      final cases = <String, void Function(Map<String, Object?>)>{
        'top': (d) => d['credential'] = 'x',
        'skill': (d) => ((d['skills']! as List).first as Map)['x'] = 1,
        'model': (d) => (d['model']! as Map)['api_key'] = 'sk',
        'input': (d) => (d['input']! as Map)['x'] = 1,
        'output': (d) => (d['output']! as Map)['x'] = 1,
        'price': (d) => (d['price']! as Map)['x'] = 1,
        'schema in a draft': (d) => d['schema'] = 'puls3.agent-manifest/v1',
      };
      cases.forEach((label, mutate) {
        final doc = draftDoc();
        mutate(doc);
        expect(
          () => AgentManifestDraft.fromJson(doc),
          problems([ManifestProblem.unknownKey]),
          reason: label,
        );
      });
    });

    test('S14 per-skill problems arrive through JSON', () {
      final doc = draftDoc()
        ..['skills'] = [
          {'id': 'Not Kebab', 'name': 'Fine'},
          {'id': 'ok-id', 'name': ''},
        ];
      expect(
        () => AgentManifestDraft.fromJson(doc),
        problems([
          ManifestProblem.skillIdNotKebabCase,
          ManifestProblem.skillNameLength,
        ]),
      );
    });

    test('skill items of the wrong type are skillsMalformed', () {
      final bad = <List<Object?>>[
        ['x'],
        [
          {'id': 3, 'name': 'A'},
        ],
        [
          {'id': 'a', 'name': 'A', 'tags': 'x'},
        ],
        [
          {
            'id': 'a',
            'name': 'A',
            'tags': [1],
          },
        ],
        [
          {'id': 'a', 'name': 'A', 'description': 1},
        ],
      ];
      for (final skills in bad) {
        expect(
          () => AgentManifestDraft.fromJson(draftDoc()..['skills'] = skills),
          problems([ManifestProblem.skillsMalformed]),
          reason: '$skills',
        );
      }
    });

    test('unsupported input/output types and assets are named', () {
      expect(
        () => AgentManifestDraft.fromJson(
          draftDoc()
            ..['input'] = {'type': 'image', 'max_chars': 1}
            ..['output'] = {'type': 'html', 'max_chars': 1}
            ..['price'] = {'asset': 'XLM', 'amount': 1},
        ),
        problems([
          ManifestProblem.inputTypeUnsupported,
          ManifestProblem.outputTypeUnsupported,
          ManifestProblem.priceAssetUnsupported,
        ]),
      );
    });

    test('a malformed model is modelMalformed', () {
      final bad = <Map<String, Object?>>[
        {'provider': 'Bad Name', 'id': 'x'},
        {'provider': 'a'},
        {'provider': 1, 'id': 'x'},
      ];
      for (final model in bad) {
        expect(
          () => AgentManifestDraft.fromJson(draftDoc()..['model'] = model),
          problems([ManifestProblem.modelMalformed]),
          reason: '$model',
        );
      }
    });

    test('draft rules still apply: above-maximum is rejected', () {
      expect(
        () => AgentManifestDraft.fromJson(
          draftDoc()..['input'] = {'type': 'text', 'max_chars': 8001},
        ),
        problems([ManifestProblem.inputMaxCharsTooHigh]),
      );
    });

    test('S31 a partial draft round-trips with the same fields set', () {
      final partial = AgentManifestDraft(
        name: 'Copy Forge',
        inputType: InputType.text,
        price: UsdcAmount.stroops(5),
      );
      final json = partial.toJson();
      expect(json, {
        'name': 'Copy Forge',
        'input': {'type': 'text'},
        'price': {'asset': 'USDC', 'amount': 5},
      });
      final again = AgentManifestDraft.fromJson(json);
      expect(again.name, 'Copy Forge');
      expect(again.inputType, InputType.text);
      expect(again.inputMaxChars, isNull);
      expect(again.price, UsdcAmount.stroops(5));
      expect(again.skills, isNull);
      expect(again.model, isNull);
      expect(again.toJson(), json);
      expect(AgentManifestDraft().toJson(), isEmpty);
    });

    test('toJson is the snake_case wire shape and never has a version', () {
      expect(complete().toJson(), {
        'name': 'Copy Forge',
        'description': 'Rewrites marketing copy.',
        'skills': [
          {'id': 'rewrite', 'name': 'Rewrite', 'description': '', 'tags': []},
        ],
        'model': {
          'provider': 'workers-ai',
          'id': '@cf/meta/llama-3.1-8b-instruct',
        },
        'system_prompt': 'You rewrite copy in a clear voice.',
        'input': {'type': 'text', 'max_chars': 4000},
        'output': {'type': 'markdown', 'max_chars': 8000},
        'price': {'asset': 'USDC', 'amount': 3000000},
      });
    });
  });
}

Map<String, Object?> draftDoc() => {
  'name': 'Copy Forge',
  'description': 'Rewrites marketing copy.',
  'skills': [
    {
      'id': 'rewrite',
      'name': 'Rewrite',
      'description': 'Rewrites copy.',
      'tags': ['copy'],
    },
  ],
  'model': {'provider': 'workers-ai', 'id': '@cf/meta/llama-3.1-8b-instruct'},
  'system_prompt': 'You rewrite copy in a clear voice.',
  'input': {'type': 'text', 'max_chars': 4000},
  'output': {'type': 'markdown', 'max_chars': 8000},
  'price': {'asset': 'USDC', 'amount': 3000000},
};
