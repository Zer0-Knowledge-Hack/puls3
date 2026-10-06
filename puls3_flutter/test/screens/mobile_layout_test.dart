import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  const phones = [Size(360, 800), Size(390, 844), Size(414, 896)];

  group('phone layout', () {
    testWidgets('destinations move to a bottom navigation bar', (
      tester,
    ) async {
      await pumpApp(tester, location: '/market', size: const Size(390, 844));

      expect(find.byType(NavigationBar), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Studio'),
        ),
      );
      await advance(tester, const Duration(milliseconds: 400));
      expect(find.text('Agent Studio'), findsOneWidget);
    });

    testWidgets('desktop keeps the top links and no bottom bar', (
      tester,
    ) async {
      await pumpApp(tester, location: '/market');
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('Studio'), findsOneWidget);
    });

    testWidgets('Studio keeps Deploy fixed at the bottom', (tester) async {
      await pumpApp(tester, location: '/studio', size: const Size(390, 844));

      final deploy = find.text('Deploy to Stellar');
      expect(deploy, findsOneWidget);
      // Visible without scrolling the long form.
      expect(tester.getCenter(deploy).dy, lessThan(844));
    });

    testWidgets('agent detail keeps price and Hire fixed at the bottom', (
      tester,
    ) async {
      await pumpApp(
        tester,
        location: '/agent/agt-001',
        size: const Size(390, 844),
      );

      expect(find.text('Price per task'), findsOneWidget);
      expect(tester.getCenter(find.text('Hire')).dy, lessThan(844));
    });

    testWidgets('search: clear button, empty state and recovery', (
      tester,
    ) async {
      await pumpApp(tester, location: '/market', size: const Size(390, 844));

      expect(find.byTooltip('Clear search'), findsNothing);
      await tester.enterText(find.byType(TextField), 'zzz-nothing');
      await tester.pump();

      expect(find.text('No agents found'), findsOneWidget);
      expect(find.text('Try another search.'), findsOneWidget);

      await tester.tap(find.byTooltip('Clear search'));
      await tester.pump();
      expect(find.text('No agents found'), findsNothing);
      expect(inResults('Ledger Scout'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'zzz-nothing');
      await tester.pump();
      await tester.tap(find.text('Clear filters'));
      await tester.pump();
      expect(inResults('Ledger Scout'), findsOneWidget);
    });
  });

  group('no overflow on phones', () {
    for (final size in phones) {
      for (final location in ['/', '/studio', '/market', '/agent/agt-001']) {
        testWidgets('$location at ${size.width.toInt()} px', (tester) async {
          await pumpApp(tester, location: location, size: size);
          await advance(tester, const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
