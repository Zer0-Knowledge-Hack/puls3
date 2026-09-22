import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  testWidgets('Marketplace lists agents', (tester) async {
    await pumpApp(tester, location: '/market');

    expect(find.text('Marketplace'), findsWidgets);
    expect(find.text('Ledger Scout'), findsOneWidget);
    expect(find.text('Soroban Auditor'), findsOneWidget);
    expect(find.text('Connect wallet'), findsOneWidget);
  });

  testWidgets('Search filters the grid', (tester) async {
    await pumpApp(tester, location: '/market');

    await tester.enterText(find.byType(TextField), 'soroban');
    await tester.pump();

    expect(find.text('Soroban Auditor'), findsOneWidget);
    expect(find.text('Ledger Scout'), findsNothing);
  });

  testWidgets('Skill chips filter the grid', (tester) async {
    await pumpApp(tester, location: '/market');

    await tester.tap(find.text('Monitoring'));
    await tester.pump();

    expect(find.text('Ledger Scout'), findsOneWidget);
    expect(find.text('Soroban Auditor'), findsNothing);
  });

  testWidgets('Connect wallet shows a shortened address', (tester) async {
    await pumpApp(tester, location: '/market');

    await tester.tap(find.text('Connect wallet'));
    await advance(tester, const Duration(milliseconds: 700));

    expect(find.text('Connect wallet'), findsNothing);
    expect(find.textContaining('…'), findsWidgets);
  });

  testWidgets('Marketplace lays out on a phone', (tester) async {
    await pumpApp(tester, location: '/market', size: const Size(390, 844));
    expect(find.text('Ledger Scout'), findsOneWidget);
  });
}
