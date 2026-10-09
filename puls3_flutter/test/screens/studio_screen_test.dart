import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_flutter/src/ui/atoms/primary_button.dart';
import 'package:puls3_flutter/src/ui/molecules/agent_card.dart';
import 'package:puls3_flutter/src/wallet/mock_wallet.dart';

import '../helpers.dart';

Finder _field(String key) => find.byKey(Key(key));

PrimaryButton _deployButton(WidgetTester tester) =>
    tester.widget<PrimaryButton>(_field('studio-deploy'));

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.ensureVisible(_field(key));
  await tester.enterText(_field(key), text);
  await tester.pump();
}

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).last);
  await tester.pump();
  await tester.tap(find.text(text).last);
  await tester.pump(const Duration(milliseconds: 300));
}

/// Fills a manifest the domain accepts.
Future<void> _fillValid(WidgetTester tester) async {
  await _type(tester, 'agent-name-field', 'Brief Bot');
  await _type(
    tester,
    'agent-description-field',
    'Summarizes long text into a short brief.',
  );
  await tester.ensureVisible(_field('agent-model-field'));
  await tester.tap(_field('agent-model-field'));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.text('Llama 3.3 70B · free').last);
  await tester.pump(const Duration(milliseconds: 300));
  await _type(
    tester,
    'agent-prompt-field',
    'You are Brief Bot. Reply with at most five bullet points.',
  );
  await _tapText(tester, '+ Summaries');
  await _type(tester, 'agent-input-max-field', '6000');
  await _type(tester, 'agent-output-max-field', '2000');
  await _type(tester, 'agent-price-field', '0.10');
}

void main() {
  testWidgets('an empty Studio keeps Deploy disabled and shows no errors '
      'until a field is edited', (tester) async {
    await pumpApp(tester, location: '/studio');

    expect(find.text('Agent Studio'), findsOneWidget);
    expect(find.text('MARKETPLACE PREVIEW'), findsOneWidget);
    expect(_deployButton(tester).onPressed, isNull);
    expect(find.text('Give your agent a name.'), findsNothing);
    expect(find.text('8 fields to complete'), findsOneWidget);
  });

  testWidgets('invalid fields show the domain errors', (tester) async {
    await pumpApp(tester, location: '/studio');

    await _type(tester, 'agent-name-field', 'AB');
    expect(find.text('The name is too short.'), findsOneWidget);

    await _type(tester, 'agent-prompt-field', 'Too short');
    expect(find.text('The instructions are too short.'), findsOneWidget);

    await _type(tester, 'agent-price-field', '0');
    expect(find.text('The price must be more than 0.'), findsOneWidget);

    await _type(tester, 'agent-input-max-field', '99999');
    expect(
      find.text('The input limit is above what agents accept.'),
      findsOneWidget,
    );
    expect(_deployButton(tester).onPressed, isNull);
  });

  testWidgets('"What is missing?" reveals every remaining problem', (
    tester,
  ) async {
    await pumpApp(tester, location: '/studio');
    await _tapText(tester, 'What is missing?');

    expect(find.text('Give your agent a name.'), findsOneWidget);
    expect(find.text('Choose a model.'), findsOneWidget);
    expect(find.text('Add at least one skill.'), findsOneWidget);
    expect(find.text('Set a price.'), findsOneWidget);
  });

  testWidgets('a valid manifest enables Deploy; the preview is the '
      'Marketplace AgentCard', (tester) async {
    await pumpApp(tester, location: '/studio');
    await _fillValid(tester);

    expect(find.text('Ready to deploy'), findsOneWidget);
    expect(_deployButton(tester).onPressed, isNotNull);

    final card = tester.widget<AgentCard>(_field('studio-preview-card'));
    expect(card.name, 'Brief Bot');
    expect(card.topSkill, 'Summaries');
    expect(card.priceUsdcStroops, 1000000);
    // A new agent has no reviews: no invented rating.
    expect(card.rating, 0.0);
  });

  testWidgets('Studio lays out on a phone without overflow', (tester) async {
    await pumpApp(tester, location: '/studio', size: const Size(390, 844));
    expect(find.text('Agent Studio'), findsOneWidget);
    await _tapText(tester, 'What is missing?');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Deploy runs the staged flow and ends as a labelled demo', (
    tester,
  ) async {
    await pumpApp(tester, location: '/studio');
    await _fillValid(tester);

    await _tapText(tester, 'Deploy to Stellar');
    await advance(tester, const Duration(milliseconds: 400));
    expect(find.text('Deploy agent'), findsOneWidget);
    expect(find.byKey(const ValueKey('deploy-demo-banner')), findsOneWidget);

    // Demo gateway and mock wallet: about 4 s from tap to the end.
    await advance(tester, const Duration(milliseconds: 4500));
    expect(find.text('Demo deploy only'), findsOneWidget);
    expect(find.textContaining('live on Stellar'), findsNothing);

    await tester.tap(find.text('Back to Studio'));
    await advance(tester, const Duration(milliseconds: 600));
    expect(find.text('Deploy agent'), findsNothing);
    expect(find.text('Agent Studio'), findsOneWidget);
  });

  testWidgets('A rejected signature can be tried again from the sheet', (
    tester,
  ) async {
    final wallet = MockWallet()..rejectSignatures = true;
    await pumpApp(tester, location: '/studio', wallet: wallet);
    await _fillValid(tester);

    await _tapText(tester, 'Deploy to Stellar');
    await advance(tester, const Duration(milliseconds: 2500));
    expect(find.text('Signature rejected'), findsOneWidget);

    wallet.rejectSignatures = false;
    await tester.tap(find.text('Try again'));
    await advance(tester, const Duration(milliseconds: 3500));
    expect(find.text('Demo deploy only'), findsOneWidget);
  });
}
