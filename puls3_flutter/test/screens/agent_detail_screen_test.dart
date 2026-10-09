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

    // The hire needs a task, then two demo prompts (create_job and fund).
    await tester.enterText(
      find.byKey(const ValueKey('hire-input')),
      'Summarize my account',
    );
    await tester.pump();
    await tester.ensureVisible(find.text('Confirm & sign'));
    await tester.pump();
    await tester.tap(find.text('Confirm & sign'));
    await advance(tester, const Duration(seconds: 6));

    expect(find.text('Demo signature only'), findsOneWidget);
    expect(find.text('Payment confirmed'), findsNothing);

    await tester.ensureVisible(find.text('Back to Marketplace'));
    await tester.pump();
    await tester.tap(find.text('Back to Marketplace'));
    await advance(tester, const Duration(milliseconds: 600));
    expect(find.text('Soroban Auditor'), findsOneWidget);
  });

  testWidgets('Agent detail lays out on a phone', (tester) async {
    await pumpApp(
      tester,
      location: '/agent/agt-001',
      size: const Size(390, 844),
    );
    expect(find.text('Hire'), findsOneWidget);
  });

  testWidgets('on a phone the hire sheet sits above the bottom navigation', (
    tester,
  ) async {
    await pumpApp(
      tester,
      location: '/agent/agt-001',
      size: const Size(390, 844),
    );
    await tester.ensureVisible(find.text('Hire'));
    await tester.pump();
    await tester.tap(find.text('Hire'));
    await advance(tester, const Duration(milliseconds: 500));

    final confirm = find.text('Confirm & sign');
    await tester.ensureVisible(confirm);
    await tester.pump();
    // The tap reaches the button, not the navigation bar over it.
    final hit = tester.hitTestOnBinding(tester.getCenter(confirm));
    final button = tester.renderObject(confirm);
    expect(hit.path.any((entry) => entry.target == button), isTrue);
    expect(tester.takeException(), isNull);
  });
}
