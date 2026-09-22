import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  testWidgets('Landing shows headline, CTAs and Why Stellar', (tester) async {
    await pumpApp(tester);

    expect(find.text('The agent hub on Stellar'), findsOneWidget);
    expect(
      find.text('Create agents. Find agents. Pay them in seconds.'),
      findsOneWidget,
    );
    expect(find.text('Open Studio'), findsOneWidget);
    expect(find.text('Explore Marketplace'), findsOneWidget);
    expect(find.text('~5s settlement'), findsOneWidget);
    expect(find.text('Fees of a fraction of a cent'), findsOneWidget);
    expect(find.text('Native USDC'), findsOneWidget);
  });

  testWidgets('Landing CTA navigates to the Marketplace', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Explore Marketplace'));
    await advance(tester, const Duration(milliseconds: 500));

    expect(find.text('Ledger Scout'), findsOneWidget);
  });

  testWidgets('Landing lays out on a phone without overflow', (tester) async {
    await pumpApp(tester, size: const Size(390, 844));
    expect(find.text('The agent hub on Stellar'), findsOneWidget);
  });
}
