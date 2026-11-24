import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_flutter/src/studio/studio_brief.dart';

void main() {
  group('descriptionFromBrief', () {
    test('uses the first sentence and collapses whitespace', () {
      expect(
        descriptionFromBrief('  Summarizes\nlong text. It keeps it short.  '),
        'Summarizes long text.',
      );
    });

    test('keeps the whole brief when the first sentence is too short', () {
      expect(
        descriptionFromBrief('Hi. This agent summarizes long articles.'),
        'Hi. This agent summarizes long articles.',
      );
    });

    test('truncates to the manifest limit', () {
      final description = descriptionFromBrief('a' * 400);

      expect(description.runes.length, 280);
      expect(description, endsWith('…'));
    });

    test('an empty brief has no description', () {
      expect(descriptionFromBrief('   \n\t '), isEmpty);
    });
  });

  group('systemPromptFromBrief', () {
    test('gives the brief a role and a way to work, with the agent name', () {
      final prompt = systemPromptFromBrief(
        'Summarizes long text into a short brief.',
        name: 'Brief Bot',
      );

      expect(prompt, startsWith('You are Brief Bot'));
      expect(prompt, contains('Summarizes long text into a short brief.'));
      expect(prompt, contains('How to work:'));
      expect(prompt, contains('outside it'));
      expect(prompt.runes.length, greaterThanOrEqualTo(20));
    });

    test('works without a name yet', () {
      final prompt = systemPromptFromBrief('Summarizes text.');

      expect(prompt, startsWith('You are an autonomous agent'));
      expect(prompt, contains('Summarizes text.'));
    });

    test('an empty brief has no prompt', () {
      expect(systemPromptFromBrief('  '), isEmpty);
    });
  });
}
