import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_flutter/src/domain/agent_draft.dart';
import 'package:puls3_flutter/src/state/review_store.dart';
import 'package:puls3_flutter/src/wallet/mock_wallet.dart';
import 'package:puls3_flutter/src/wallet/wallet_port.dart';

import '../helpers.dart';

const _phone = Size(390, 844);

Future<void> _openHire(WidgetTester tester, MockWallet wallet) async {
  await pumpApp(
    tester,
    location: '/agent/agt-001',
    size: _phone,
    wallet: wallet,
  );
  await tester.tap(find.text('Hire'));
  await advance(tester, const Duration(milliseconds: 500));
  await tester.tap(find.text('Connect wallet to pay'));
  await advance(tester, const Duration(milliseconds: 700));
}

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

  group('payment', () {
    testWidgets('a rejected payment explains it and can be retried', (
      tester,
    ) async {
      final wallet = MockWallet()..rejectSignatures = true;
      await _openHire(tester, wallet);

      expect(find.text('Protected by escrow'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);

      await tester.tap(find.text('Confirm & sign'));
      await advance(tester, const Duration(milliseconds: 1500));
      expect(
        find.byKey(const ValueKey('hire-failure-rejected')),
        findsOneWidget,
      );
      expect(find.textContaining('No funds moved'), findsOneWidget);

      wallet.rejectSignatures = false;
      await tester.tap(find.text('Try again'));
      await advance(tester, const Duration(milliseconds: 1500));
      expect(find.text('Payment confirmed'), findsOneWidget);
    });

    testWidgets('not enough funds is reported', (tester) async {
      final wallet = MockWallet();
      await _openHire(tester, wallet);
      wallet.failure = const WalletInsufficientFunds();

      await tester.tap(find.text('Confirm & sign'));
      await advance(tester, const Duration(milliseconds: 1500));
      expect(find.text('Not enough funds'), findsOneWidget);
    });
  });

  group('ratings', () {
    testWidgets('detail shows the summary and reviews', (tester) async {
      await pumpApp(tester, location: '/agent/agt-001', size: _phone);

      expect(find.text('RATINGS & REVIEWS'), findsOneWidget);
      expect(find.text('3 reviews'), findsOneWidget);
      expect(find.text('María G.'), findsOneWidget);
      // Rating is locked until a paid hire.
      expect(find.text('Rate this agent'), findsNothing);
    });

    testWidgets('after paying, the client rates once with validation', (
      tester,
    ) async {
      final wallet = MockWallet();
      await _openHire(tester, wallet);
      await tester.tap(find.text('Confirm & sign'));
      await advance(tester, const Duration(milliseconds: 1500));

      await tester.tap(find.text('Rate agent'));
      await advance(tester, const Duration(milliseconds: 500));
      await tester.tap(find.text('Submit review'));
      await tester.pump();
      expect(find.text('Choose 1 to 5 stars'), findsOneWidget);

      await tester.tap(find.byTooltip('4 stars'));
      await tester.enterText(
        find.byKey(const Key('review-comment')),
        'Fast and clear.',
      );
      await tester.tap(find.text('Submit review'));
      await advance(tester, const Duration(milliseconds: 500));

      // Back on the detail page behind the sheets.
      await tester.tap(find.text('Back to Marketplace'));
      await advance(tester, const Duration(milliseconds: 500));
      await tester.tap(inResults('Ledger Scout'));
      await advance(tester, const Duration(milliseconds: 500));
      expect(find.text('4 reviews'), findsOneWidget);
      expect(find.text('You (you)'), findsOneWidget);
      expect(find.text('Rate this agent'), findsNothing);
    });

    test('rating needs a paid hire and happens once', () {
      final store = ReviewStore(seed: []);
      expect(
        () => store.add(agentId: 'a', author: 'x', rating: 5, comment: ''),
        throwsStateError,
      );
      store.markHired('a');
      expect(store.canRate('a'), isTrue);
      store.add(agentId: 'a', author: 'x', rating: 5, comment: '');
      expect(store.canRate('a'), isFalse);
      expect(store.summaryFor('a').average, 5);
    });
  });
}
