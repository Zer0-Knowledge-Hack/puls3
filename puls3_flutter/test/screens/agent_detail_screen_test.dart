import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  testWidgets('Agent detail shows profile and Hire', (tester) async {
    await pumpApp(tester, location: '/agent/agt-001');

    expect(find.text('Ledger Scout'), findsOneWidget);
    expect(find.text('GCDS…QFXZ'), findsOneWidget);
    expect(find.text('Hire'), findsOneWidget);
  });

  testWidgets('Unknown agent shows not found', (tester) async {
    await pumpApp(tester, location: '/agent/nope');
    expect(find.text('Agent not found'), findsOneWidget);
  });

  testWidgets('Hire flow ends in the demo result without claiming a payment', (
    tester,
  ) async {
    await pumpApp(tester, location: '/agent/agt-001');

    await tester.tap(find.text('Hire'));
    await advance(tester, const Duration(milliseconds: 500));
    expect(find.text('Confirm & sign'), findsOneWidget);

    await tester.tap(find.text('Confirm & sign'));
    await advance(tester, const Duration(milliseconds: 2200));

    expect(find.text('Demo signature only'), findsOneWidget);
    expect(find.text('Payment confirmed'), findsNothing);

    await tester.tap(find.text('Back to Marketplace'));
    await advance(tester, const Duration(milliseconds: 600));
    expect(inResults('Soroban Auditor'), findsOneWidget);
  });

  testWidgets('Agent detail lays out on a phone', (tester) async {
    await pumpApp(
      tester,
      location: '/agent/agt-001',
      size: const Size(390, 844),
    );
    expect(find.text('Hire'), findsOneWidget);
  });
}
