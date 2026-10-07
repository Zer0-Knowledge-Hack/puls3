import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_flutter/src/theme/puls3_theme.dart';

import '../helpers.dart';

void main() {
  group('phone shell', () {
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
      expect(Puls3Text.compact, isFalse);
    });

    testWidgets('phones get the compact type scale and 44 px buttons', (
      tester,
    ) async {
      await pumpApp(tester, location: '/studio', size: const Size(390, 844));

      expect(Puls3Text.compact, isTrue);
      expect(Puls3Text.body.fontSize, 14);
      expect(Puls3Text.h2Compact.fontSize, 20);
      final deploy = find.ancestor(
        of: find.text('Deploy to Stellar'),
        matching: find.byType(TextButton),
      );
      // 44 px visible button inside a 48 px tap target.
      final visible = find.descendant(
        of: deploy,
        matching: find.byType(Material),
      );
      expect(tester.getSize(visible.first).height, 44);
      expect(tester.getSize(deploy).height, 48);
    });
  });

  group('no overflow on phones', () {
    const phones = [
      Size(320, 568),
      Size(360, 800),
      Size(390, 844),
      Size(414, 896),
    ];
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
