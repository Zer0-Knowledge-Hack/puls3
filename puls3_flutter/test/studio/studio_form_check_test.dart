import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_flutter/src/studio/studio_form_check.dart';
import 'package:puls3_flutter/src/studio/studio_models.dart';

final _llama = studioModelOptions.firstWhere((m) => m.isFree);

StudioFormValues _valid({
  String name = 'Brief Bot',
  String description = 'Summarizes long text into a short brief.',
  List<String> skills = const ['Summaries'],
  String prompt = 'You are Brief Bot. Reply with five bullet points.',
  String inputMax = '6000',
  String outputMax = '2000',
  String price = '0.10',
}) => StudioFormValues(
  name: name,
  description: description,
  skills: skills,
  model: _llama,
  systemPrompt: prompt,
  inputMaxChars: inputMax,
  outputType: OutputType.markdown,
  outputMaxChars: outputMax,
  price: price,
);

void main() {
  group('checkStudioForm uses the domain rules (#34)', () {
    test('a complete form yields the deployable manifest', () {
      final check = checkStudioForm(_valid());
      expect(check.errors, isEmpty);
      expect(check.canDeploy, isTrue);
      final manifest = check.manifest!;
      expect(manifest.name, 'Brief Bot');
      expect(manifest.skills.single.id, 'summaries');
      expect(manifest.model.provider, 'workers-ai');
      expect(manifest.outputType, OutputType.markdown);
      expect(manifest.price.stroops, 1000000);
      expect(manifest.version, ManifestVersion.first);
    });

    test('an empty form lists every missing field and cannot deploy', () {
      final check = checkStudioForm(const StudioFormValues());
      expect(check.canDeploy, isFalse);
      expect(check.errors.keys, containsAll(StudioField.values));
    });

    test('the domain decides the limits: exact boundaries', () {
      // 3 and 48 runes pass for the name, 2 and 49 do not.
      expect(checkStudioForm(_valid(name: 'abc')).canDeploy, isTrue);
      expect(checkStudioForm(_valid(name: 'a' * 48)).canDeploy, isTrue);
      expect(
        checkStudioForm(_valid(name: 'ab')).errors[StudioField.name],
        'The name is too short.',
      );
      expect(
        checkStudioForm(_valid(name: 'a' * 49)).errors[StudioField.name],
        'The name is too long.',
      );
      // Runes, not UTF-16 units: 48 emoji are 48 characters.
      expect(checkStudioForm(_valid(name: '🤖' * 48)).canDeploy, isTrue);
    });

    test('one to five skills; duplicates are refused', () {
      expect(
        checkStudioForm(
          _valid(skills: ['A1', 'B2', 'C3', 'D4', 'E5']),
        ).canDeploy,
        isTrue,
      );
      expect(
        checkStudioForm(
          _valid(skills: ['A1', 'B2', 'C3', 'D4', 'E5', 'F6']),
        ).errors[StudioField.skills],
        'Too many skills: remove some.',
      );
      expect(
        checkStudioForm(
          _valid(skills: ['Data cleaning', 'data  cleaning']),
        ).errors[StudioField.skills],
        'Two skills have the same name.',
      );
    });

    test('input and output limits come from ADR-0004 via the domain', () {
      expect(checkStudioForm(_valid(inputMax: '8000')).canDeploy, isTrue);
      expect(
        checkStudioForm(_valid(inputMax: '8001')).errors[StudioField.input],
        'The input limit is above what agents accept.',
      );
      expect(checkStudioForm(_valid(outputMax: '16000')).canDeploy, isTrue);
      expect(
        checkStudioForm(_valid(outputMax: '0')).errors[StudioField.output],
        'The answer limit must be at least 1 character.',
      );
      expect(
        checkStudioForm(_valid(inputMax: 'lots')).errors[StudioField.input],
        'Enter a whole number of characters.',
      );
    });

    test('price must parse and be positive', () {
      expect(
        checkStudioForm(_valid(price: '0')).errors[StudioField.price],
        'The price must be more than 0.',
      );
      expect(
        checkStudioForm(_valid(price: 'free')).errors[StudioField.price],
        'Enter an amount like 0.50.',
      );
    });

    test('a model outside the policy is refused', () {
      final check = checkStudioForm(
        StudioFormValues(
          name: 'Brief Bot',
          description: 'Summarizes long text into a short brief.',
          skills: const ['Summaries'],
          model: const StudioModelOption(
            provider: 'workers-ai',
            id: '@cf/unknown/model',
            label: 'Unknown',
          ),
          systemPrompt: 'You are Brief Bot. Reply with five bullet points.',
          inputMaxChars: '6000',
          outputMaxChars: '2000',
          price: '0.10',
        ),
      );
      expect(
        check.errors[StudioField.model],
        'This model is not available on the free tier.',
      );
    });

    test('every domain problem maps to a field and a message', () {
      for (final problem in ManifestProblem.values) {
        final (_, message) = describeManifestProblem(problem);
        expect(message, isNotEmpty, reason: '$problem');
      }
    });

    test('skill ids are kebab-case', () {
      expect(skillIdFor('On-chain analytics'), 'on-chain-analytics');
      expect(skillIdFor('  Smart  contracts! '), 'smart-contracts');
    });
  });
}
