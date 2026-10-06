import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_flutter/src/domain/agent_draft.dart';

import '../helpers.dart';

const _phone = Size(390, 844);

void main() {
  group('agent draft rules (ADR-0004)', () {
    Map<AgentDraftField, String> validate({
      String name = 'Visa Scout',
      String description = 'Checks visa rules for trips.',
      String prompt = 'You check visa rules for travellers.',
      List<String> skills = const ['Travel'],
      int? price = 5000000,
    }) => AgentDraftRules.validate(
      name: name,
      description: description,
      prompt: prompt,
      skills: skills,
      priceStroops: price,
    );

    test('a complete draft passes', () => expect(validate(), isEmpty));

    test('each rule reports its own field', () {
      expect(validate(name: 'ab').keys, [AgentDraftField.name]);
      expect(validate(name: 'x' * 49).keys, [AgentDraftField.name]);
      expect(validate(description: 'short').keys, [
        AgentDraftField.description,
      ]);
      expect(validate(prompt: 'too short').keys, [AgentDraftField.prompt]);
      expect(validate(skills: []).keys, [AgentDraftField.skills]);
      expect(validate(skills: List.filled(6, 's')).keys, [
        AgentDraftField.skills,
      ]);
      expect(validate(price: null).keys, [AgentDraftField.price]);
      expect(validate(price: 0).keys, [AgentDraftField.price]);
    });
  });

  group('create agent', () {
    testWidgets('deploy is blocked until requirements and policies are met', (
      tester,
    ) async {
      await pumpApp(tester, location: '/studio', size: _phone);

      await tester.enterText(find.byKey(const Key('agent-name-field')), 'ab');
      await tester.tap(find.text('Deploy to Stellar'));
      await tester.pump();

      expect(find.text('Complete 2 requirements to deploy.'), findsOneWidget);
      expect(find.text('Use 3–48 characters'), findsOneWidget);
      // No deploy sheet opened.
      expect(find.text('Deploy agent'), findsNothing);

      await tester.enterText(
        find.byKey(const Key('agent-name-field')),
        'Visa Scout',
      );
      await acceptPolicies(tester);
      await tester.tap(find.text('Deploy to Stellar'));
      await advance(tester, const Duration(milliseconds: 500));
      expect(find.text('Deploy agent'), findsOneWidget);
      await advance(tester, const Duration(milliseconds: 5000));
    });

    testWidgets('the policies sheet lists every rule', (tester) async {
      await pumpApp(tester, location: '/studio', size: _phone);

      await tester.ensureVisible(find.text('Read'));
      await tester.tap(find.text('Read'));
      await advance(tester, const Duration(milliseconds: 500));

      expect(find.text('Agent policies'), findsOneWidget);
      expect(find.text('Never ask for secrets'), findsOneWidget);
      await tester.tap(find.text('Got it'));
      await advance(tester, const Duration(milliseconds: 500));
      expect(find.text('Agent policies'), findsNothing);
    });

    testWidgets('a sixth skill cannot be added', (tester) async {
      await pumpApp(tester, location: '/studio', size: _phone);
      for (final skill in ['A1', 'B2', 'C3']) {
        await tester.enterText(
          find.widgetWithText(TextField, 'Add a skill'),
          skill,
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
      }
      expect(find.text('5 of 5 skills'), findsOneWidget);
      expect(find.text('+ Summaries'), findsNothing);
    });
  });
}
