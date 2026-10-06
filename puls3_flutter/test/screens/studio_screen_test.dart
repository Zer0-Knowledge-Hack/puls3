import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_flutter/src/wallet/mock_wallet.dart';

import '../helpers.dart';

void main() {
  testWidgets('Studio shows the form and the live preview', (tester) async {
    await pumpApp(tester, location: '/studio');

    expect(find.text('Agent Studio'), findsOneWidget);
    expect(find.text('MARKETPLACE PREVIEW'), findsOneWidget);
    expect(find.text('Deploy to Stellar'), findsOneWidget);
    // The default name appears in both the field and the preview card.
    expect(find.text('Nomad Concierge'), findsNWidgets(2));
  });

  testWidgets('Preview updates as the name changes', (tester) async {
    await pumpApp(tester, location: '/studio');

    await tester.enterText(
      find.byKey(const Key('agent-name-field')),
      'Visa Scout',
    );
    await tester.pump();

    expect(find.text('Visa Scout'), findsNWidgets(2));
  });

  testWidgets('Studio lays out on a phone without overflow', (tester) async {
    await pumpApp(tester, location: '/studio', size: const Size(390, 844));
    expect(find.text('Agent Studio'), findsOneWidget);
  });

  testWidgets('Deploy runs the staged flow, goes live and opens the agent', (
    tester,
  ) async {
    await pumpApp(tester, location: '/studio');

    await acceptPolicies(tester);
    await tester.tap(find.text('Deploy to Stellar'));
    await advance(tester, const Duration(milliseconds: 400));
    expect(find.text('Deploy agent'), findsOneWidget);
    expect(find.text('Preparing deployment'), findsOneWidget);
    expect(find.text('Waiting for signature'), findsOneWidget);
    expect(find.text('Registering on-chain'), findsOneWidget);

    // Demo gateway and mock wallet: about 4 s from tap to live.
    await advance(tester, const Duration(milliseconds: 4500));
    expect(find.text('Agent deployed'), findsOneWidget);
    expect(find.text('#100'), findsWidgets);

    await tester.tap(find.text('Open agent'));
    await advance(tester, const Duration(milliseconds: 600));
    // The freshly deployed agent has its own detail page.
    expect(find.text('Nomad Concierge'), findsWidgets);
    expect(find.text('Deploy to Stellar'), findsNothing);
  });

  testWidgets('A rejected signature can be tried again from the sheet', (
    tester,
  ) async {
    final wallet = MockWallet()..rejectSignatures = true;
    await pumpApp(tester, location: '/studio', wallet: wallet);

    await acceptPolicies(tester);
    await tester.tap(find.text('Deploy to Stellar'));
    await advance(tester, const Duration(milliseconds: 2500));
    expect(find.text('Signature rejected'), findsOneWidget);

    wallet.rejectSignatures = false;
    await tester.tap(find.text('Try again'));
    await advance(tester, const Duration(milliseconds: 3500));
    expect(find.text('Agent deployed'), findsOneWidget);
  });

  // From 360 px. At 320 px the top bar itself does not fit (logo, links and
  // wallet chip), before any deploy; that layout is outside #27. The deploy
  // flow alone is checked from 320 px in test/deploy/deploy_flow_test.dart.
  for (final size in const [Size(360, 800), Size(390, 844), Size(414, 896)]) {
    testWidgets(
      'The deploy sheet fits a ${size.width.toInt()} px phone from start to live',
      (tester) async {
        await pumpApp(tester, location: '/studio', size: size);

        await tester.ensureVisible(find.text('Deploy to Stellar'));
        await acceptPolicies(tester);
        await tester.tap(find.text('Deploy to Stellar'));
        await advance(tester, const Duration(milliseconds: 1000));
        expect(find.text('Deploy agent'), findsOneWidget);

        await advance(tester, const Duration(milliseconds: 4000));
        expect(find.text('Agent deployed'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
