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

  testWidgets('Deploy runs the staged flow and ends as a labelled demo', (
    tester,
  ) async {
    await pumpApp(tester, location: '/studio');

    await tester.tap(find.text('Deploy to Stellar'));
    await advance(tester, const Duration(milliseconds: 400));
    expect(find.text('Deploy agent'), findsOneWidget);
    expect(find.byKey(const ValueKey('deploy-demo-banner')), findsOneWidget);
    expect(find.text('Preparing deployment'), findsOneWidget);

    // Demo gateway and mock wallet: about 4 s from tap to the end.
    await advance(tester, const Duration(milliseconds: 4500));
    expect(find.text('Demo deploy only'), findsOneWidget);
    expect(find.textContaining('live on Stellar'), findsNothing);

    await tester.tap(find.text('Back to Studio'));
    await advance(tester, const Duration(milliseconds: 600));
    // Nothing was created, so nothing new is listed.
    expect(find.text('Deploy agent'), findsNothing);
    expect(find.text('Agent Studio'), findsOneWidget);
  });

  testWidgets('A rejected signature can be tried again from the sheet', (
    tester,
  ) async {
    final wallet = MockWallet()..rejectSignatures = true;
    await pumpApp(tester, location: '/studio', wallet: wallet);

    await tester.tap(find.text('Deploy to Stellar'));
    await advance(tester, const Duration(milliseconds: 2500));
    expect(find.text('Signature rejected'), findsOneWidget);

    wallet.rejectSignatures = false;
    await tester.tap(find.text('Try again'));
    await advance(tester, const Duration(milliseconds: 3500));
    expect(find.text('Demo deploy only'), findsOneWidget);
  });
}
