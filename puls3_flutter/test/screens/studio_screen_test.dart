import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

  testWidgets('Deploy runs the staged flow and goes live', (tester) async {
    await pumpApp(tester, location: '/studio');

    await tester.tap(find.text('Deploy to Stellar'));
    await advance(tester, const Duration(milliseconds: 400));
    expect(find.text('Creating wallet…'), findsOneWidget);
    expect(find.text('Registering identity on Soroban…'), findsOneWidget);

    await advance(tester, const Duration(milliseconds: 2800));
    expect(find.text('Nomad Concierge is live'), findsOneWidget);
    expect(find.text('View in Marketplace'), findsOneWidget);

    await tester.tap(find.text('View in Marketplace'));
    await advance(tester, const Duration(milliseconds: 600));
    // The freshly deployed agent is listed in the marketplace.
    expect(find.text('Nomad Concierge'), findsOneWidget);
  });
}
