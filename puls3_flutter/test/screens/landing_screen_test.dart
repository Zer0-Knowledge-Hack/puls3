import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_flutter/src/domain/landing_content.dart';
import 'package:puls3_flutter/src/screens/landing_screen.dart';
import 'package:puls3_flutter/src/ui/organisms/landing/how_it_works_diagram.dart';

import '../helpers.dart';

const _headline = 'Build. Discover. Pay.\nAI agents on Stellar.';

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
    expect(find.text('View documentation'), findsOneWidget);
    expect(
      find.text('AI agents can work. Getting them paid is the hard part.'),
      findsOneWidget,
    );
    expect(find.text('For builders'), findsOneWidget);
    expect(find.text('For hirers'), findsOneWidget);
    expect(
      find.text('From a prompt to a paid task, in eight steps.'),
      findsOneWidget,
    );
    expect(find.text('Agents you can hire today.'), findsOneWidget);
    expect(find.text('More than a list of agents.'), findsOneWidget);
    expect(find.text('~5s settlement'), findsOneWidget);
    expect(find.text('Built by the Zer0-Knowledge team.'), findsOneWidget);
    expect(find.text('Questions, answered.'), findsOneWidget);
  });

  testWidgets('reviews never invent quotes: an invitation until real ones '
      'exist', (tester) async {
    await pumpApp(tester);

    expect(landingTestimonials, isEmpty);
    expect(find.byKey(const Key('landing-reviews-open')), findsOneWidget);
    expect(find.text('Reviews open with the first hires.'), findsOneWidget);
  });

  testWidgets('the team lists the repository contributors', (tester) async {
    await pumpApp(tester);

    for (final member in landingTeam) {
      expect(find.text('@${member.handle}'), findsOneWidget);
    }
  });

  testWidgets('a FAQ opens to its answer', (tester) async {
    await pumpApp(tester);
    await tester.ensureVisible(find.text('Is this real money?'));
    await tester.pump();
    await tester.tap(find.text('Is this real money?'));
    await advance(tester, const Duration(milliseconds: 500));

    expect(find.textContaining('runs on Stellar Testnet'), findsOneWidget);
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
      'Verify the payment',
    ]);
    expect(byStatus[FlowStepStatus.inDevelopment], [
      'Create an agent',
      'Register its identity',
      'Publish',
      'Run the task',
      'Result and release',
    ]);
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

  testWidgets('every flow step shows its number, title and status', (
    tester,
  ) async {
    await pumpApp(tester);

    for (var i = 1; i <= LandingScreen.flow.length; i++) {
      expect(find.byKey(Key('flow-step-$i')), findsOneWidget);
    }
    // Legend plus one pill per step.
    // The legend lists every status; no step is planned any more.
    expect(find.text('Planned'), findsOneWidget);
    expect(find.text('In development'), findsWidgets);
  });

  testWidgets('the marketplace preview shows real catalog agents', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.byKey(const ValueKey('landing-agent-agt-001')), findsOneWidget);
    expect(find.byKey(const ValueKey('landing-agent-agt-003')), findsOneWidget);
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

  testWidgets('View all agents opens the Marketplace', (tester) async {
    await pumpApp(tester);
    await _tapKey(tester, 'landing-view-all');

    expect(find.text('SHOWING 2 OF 2'), findsOneWidget);
  });

  testWidgets('the footer links to the brand page', (tester) async {
    await pumpApp(tester);
    await tester.ensureVisible(find.text('Brand'));
    await tester.pump();
    await tester.tap(find.text('Brand'));
    await advance(tester, const Duration(milliseconds: 800));

    expect(find.text(_headline), findsNothing);
  });

  testWidgets('the phone menu lists the destinations', (tester) async {
    await pumpApp(tester, size: const Size(390, 844));

    await tester.tap(find.byKey(const Key('landing-menu')));
    await advance(tester, const Duration(milliseconds: 400));
    expect(find.text('Marketplace'), findsWidgets);
    expect(find.text('Agent Studio'), findsWidgets);
    expect(find.text('Docs'), findsOneWidget);
    expect(find.text('GitHub'), findsWidgets);
  });

  testWidgets('with reduced motion the diagram still reads, without the '
      'pulse', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpApp(tester);

    expect(find.byKey(const Key('flow-step-1')), findsOneWidget);
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
