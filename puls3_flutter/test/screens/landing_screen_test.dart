import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_flutter/src/domain/landing_content.dart';
import 'package:puls3_flutter/src/screens/landing_screen.dart';
import 'package:puls3_flutter/src/ui/organisms/landing/how_it_works_diagram.dart';

import '../helpers.dart';

const _headline = 'Your AI works. It still can\'t get paid.';

Future<void> _tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pump();
  await tester.tap(find.byKey(Key(key)));
  await advance(tester, const Duration(milliseconds: 800));
}

void main() {
  testWidgets('Landing explains puls3 section by section', (tester) async {
    await pumpApp(tester);

    expect(find.text(_headline), findsOneWidget);
    expect(find.text('Explore agents'), findsWidgets);
    expect(find.text('Build an agent'), findsWidgets);
    expect(find.text('Press Hire'), findsOneWidget);
    expect(
      find.text(
        'Press Hire. Watch USDC lock, the agent work, deliver, and only then get paid.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('landing-hire-scene')), findsOneWidget);
    for (var i = 1; i <= 6; i++) {
      expect(find.byKey(Key('landing-hire-step-$i')), findsOneWidget);
    }
    expect(find.text('You already use AI. Can it get paid?'), findsOneWidget);
    expect(find.text('See the first hire paid into escrow'), findsOneWidget);
    expect(find.text('Coming'), findsOneWidget);
    expect(find.text('Marketplace'), findsWidgets);
    expect(find.text('Studio'), findsWidgets);
    expect(find.text('Connect wallet'), findsWidgets);
    expect(find.text('Docs'), findsWidgets);
    expect(find.text('GitHub'), findsWidgets);
    expect(find.text('Brand'), findsWidgets);
  });

  testWidgets('the footer states the network is testnet', (tester) async {
    await pumpApp(tester);
    await tester.ensureVisible(find.textContaining('Stellar Testnet').last);
    expect(find.textContaining('Stellar Testnet'), findsWidgets);
  });

  test('the flow labels only what is built as live', () {
    final byStatus = {
      for (final status in FlowStepStatus.values)
        status: [
          for (final step in LandingScreen.flow)
            if (step.status == status) step.title,
        ],
    };
    // Only what runs end to end today is live (review on #175): the
    // Studio is a labelled demo until #35, the runner has no live results
    // yet, and approving or rejecting from the app is not built.
    expect(byStatus[FlowStepStatus.live], [
      'Discover and hire',
      'Pay into escrow',
    ]);
    expect(byStatus[FlowStepStatus.inDevelopment], ['Create an agent']);
    expect(byStatus[FlowStepStatus.planned], isEmpty);
  });

  test('copy never claims Studio deploy as shipped', () {
    // What builders get: hirers already see the catalog agents' on-chain
    // identity today, so their copy is not checked here.
    final copy = [
      for (final p in landingProblems) p.answer,
      ...landingAudiences.first.points,
      for (final c in landingComparison) c.puls3,
      for (final f in landingFaqs) f.answer,
    ];
    for (final line in copy) {
      final claimsIdentity =
          line.contains('Identity Registry') ||
          line.contains('on-chain id') ||
          line.contains('Soroban registry') ||
          line.contains('on-chain identity');
      // Only promises to the builder: agents already in the catalog do
      // have an on-chain identity today.
      final aboutBuilder =
          line.contains('Studio') ||
          line.toLowerCase().contains('your agent') ||
          line.contains('Builders');
      if (claimsIdentity && aboutBuilder) {
        expect(
          line.contains('coming') ||
              line.contains('Coming') ||
              line.contains('once Studio deploy ships'),
          isTrue,
          reason: 'reads as shipped: "$line"',
        );
      }
    }
  });

  testWidgets('every flow step shows its number and title', (tester) async {
    await pumpApp(tester);

    for (var i = 1; i <= LandingScreen.flow.length; i++) {
      expect(find.byKey(Key('flow-step-$i')), findsOneWidget);
    }
    expect(find.text('Create an agent'), findsWidgets);
    expect(find.text('Discover and hire'), findsOneWidget);
    expect(find.text('Pay into escrow'), findsOneWidget);
  });

  testWidgets('the hero embeds a hire demo', (tester) async {
    await pumpApp(tester);

    expect(find.byKey(const Key('landing-hire-demo')), findsOneWidget);
    expect(find.text('Press Hire'), findsOneWidget);
    expect(find.byKey(const Key('landing-hire-run')), findsOneWidget);
    expect(find.byKey(const Key('landing-explore')), findsOneWidget);
    expect(find.byKey(const Key('landing-build')), findsOneWidget);
  });

  testWidgets('Hire walks lock, work, deliver, review, then pay', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('landing-hire-run')));
    await tester.pump();

    await advance(tester, const Duration(milliseconds: 400));
    expect(find.textContaining('the agent is not paid yet'), findsOneWidget);

    await advance(tester, const Duration(milliseconds: 4600));
    expect(find.textContaining('cannot leave on its own'), findsOneWidget);

    await advance(tester, const Duration(milliseconds: 4500));
    expect(find.textContaining('vault stays locked the whole time'), findsOneWidget);

    await advance(tester, const Duration(milliseconds: 4500));
    expect(find.textContaining('work comes to you'), findsOneWidget);

    await advance(tester, const Duration(milliseconds: 4500));
    expect(find.textContaining('Nothing is paid until you accept'), findsOneWidget);

    await advance(tester, const Duration(milliseconds: 9000));
    expect(find.textContaining('No accept, no payout'), findsOneWidget);
    expect(find.text('Replay'), findsOneWidget);
  });

  testWidgets('Explore agents opens the Marketplace', (tester) async {
    await pumpApp(tester);
    await _tapKey(tester, 'landing-explore');

    expect(find.text('SHOWING 2 OF 2'), findsOneWidget);
    expect(find.text(_headline), findsNothing);
  });

  testWidgets('Build an agent opens the Studio', (tester) async {
    await pumpApp(tester);
    await _tapKey(tester, 'landing-build');

    expect(find.text('Agent Studio'), findsWidgets);
    expect(find.text(_headline), findsNothing);
  });

  testWidgets('the footer links to the brand page', (tester) async {
    await pumpApp(tester);
    await tester.ensureVisible(find.text('Brand'));
    await tester.pump();
    await tester.tap(find.text('Brand'));
    await advance(tester, const Duration(milliseconds: 800));

    expect(find.text(_headline), findsNothing);
  });

  testWidgets('the phone bar lists Home, Marketplace and Studio', (
    tester,
  ) async {
    await pumpApp(tester, size: const Size(390, 844));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Home'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Marketplace'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Studio'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('with reduced motion the landing still reads', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpApp(tester);

    expect(find.text(_headline), findsOneWidget);
    await advance(tester, const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 360.0, 390.0, 430.0, 768.0, 1024.0, 1280.0]) {
    testWidgets('lays out at ${width.toInt()} px without overflow', (
      tester,
    ) async {
      await pumpApp(tester, size: Size(width, 900));
      expect(find.text(_headline), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
