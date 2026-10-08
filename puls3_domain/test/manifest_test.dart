import 'package:puls3_domain/puls3_domain.dart';
import 'package:test/test.dart';

/// Matches an [InvalidManifest] whose problem list equals [expected].
Matcher problems(List<ManifestProblem> expected) => throwsA(
  isA<InvalidManifest>().having((e) => e.problems, 'problems', expected),
);

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
      expect(e.message, contains('nameMissing'));
      expect(e.message, contains('priceMissing'));
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
