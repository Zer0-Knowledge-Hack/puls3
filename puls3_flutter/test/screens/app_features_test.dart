import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

const _phone = Size(390, 844);

Finder _navItem(String label) => find.descendant(
  of: find.byType(NavigationBar),
  matching: find.text(label),
);

void main() {
  group('bottom navigation', () {
    testWidgets('has four sections and an unread badge on Activity', (
      tester,
    ) async {
      await pumpApp(tester, location: '/market', size: _phone);

      for (final label in ['Marketplace', 'Studio', 'Activity', 'Profile']) {
        expect(_navItem(label), findsOneWidget);
      }
      // The demo feed starts with two unread notifications.
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
    });
  });

  group('activity', () {
    testWidgets('lists notifications and marks them read', (tester) async {
      await pumpApp(tester, location: '/activity', size: _phone);

      expect(find.text('Activity'), findsWidgets);
      expect(find.text('2 unread'), findsOneWidget);
      expect(find.text('Payment received'), findsOneWidget);
      expect(find.byKey(const ValueKey('unread-dot')), findsNWidgets(2));

      await tester.tap(find.text('Mark all read'));
      await tester.pump();
      expect(find.text('You are all caught up.'), findsOneWidget);
      expect(find.byKey(const ValueKey('unread-dot')), findsNothing);
    });

    testWidgets('tapping a notification opens its agent', (tester) async {
      await pumpApp(tester, location: '/activity', size: _phone);

      await tester.tap(find.text('Payment received'));
      await advance(tester, const Duration(milliseconds: 400));
      expect(find.text('Price per task'), findsOneWidget);
    });
  });

  group('profile', () {
    testWidgets('connect, validate, create, then disconnect', (tester) async {
      await pumpApp(tester, location: '/profile', size: _phone);

      expect(find.text('Connect your wallet'), findsOneWidget);
      await tester.tap(find.text('Connect wallet').last);
      await advance(tester, const Duration(milliseconds: 700));

      expect(find.text('Create your profile'), findsOneWidget);
      await tester.tap(find.text('Create profile'));
      await tester.pump();
      expect(find.text('Enter a name'), findsOneWidget);
      expect(find.text('3–20 letters, numbers or _'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('profile-name')), 'Ana Ruiz');
      await tester.enterText(find.byKey(const Key('profile-handle')), 'ana_r');
      await tester.tap(find.text('Create profile'));
      await tester.pump();

      expect(find.text('Ana Ruiz'), findsOneWidget);
      expect(find.text('@ana_r'), findsOneWidget);
      expect(find.text('AR'), findsOneWidget);
      expect(find.text('MY AGENTS'), findsOneWidget);

      await tester.ensureVisible(find.text('Disconnect wallet'));
      await tester.tap(find.text('Disconnect wallet'));
      await tester.pump();
      expect(find.text('Connect your wallet'), findsOneWidget);
    });
  });

  group('marketplace', () {
    testWidgets('shows the Top rated carousel until the user filters', (
      tester,
    ) async {
      await pumpApp(tester, location: '/market', size: _phone);
      expect(find.byKey(const ValueKey('featured-carousel')), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'soroban');
      await tester.pump();
      expect(find.byKey(const ValueKey('featured-carousel')), findsNothing);
      expect(find.text('Results'), findsOneWidget);
    });

    testWidgets('sorts by price from the sort sheet', (tester) async {
      await pumpApp(tester, location: '/market', size: _phone);

      await tester.tap(find.byTooltip('Sort and filter'));
      await advance(tester, const Duration(milliseconds: 400));
      await tester.tap(find.text('Price: high to low'));
      await advance(tester, const Duration(milliseconds: 400));

      // Soroban Auditor (45 USDC) now comes before Ledger Scout (0.50).
      final auditor = tester.getTopLeft(inResults('Soroban Auditor')).dy;
      final scout = tester.getTopLeft(inResults('Ledger Scout')).dy;
      expect(auditor, lessThan(scout));
      expect(find.text('Price: high to low'), findsOneWidget);
    });
  });

  group('studio', () {
    testWidgets('a deploy shows up in My agents and in Activity', (
      tester,
    ) async {
      await pumpApp(tester, location: '/studio', size: _phone);

      await tester.tap(find.text('My agents'));
      await tester.pump();
      expect(find.text('No agents yet'), findsOneWidget);

      await tester.tap(find.text('Create an agent'));
      await tester.pump();
      await tester.tap(find.text('Deploy to Stellar'));
      await advance(tester, const Duration(milliseconds: 5000));
      expect(find.text('Agent deployed'), findsOneWidget);

      await tester.tap(find.text('Done'));
      await advance(tester, const Duration(milliseconds: 400));
      await tester.ensureVisible(find.text('My agents'));
      await tester.tap(find.text('My agents'));
      await tester.pump();
      expect(find.text('Nomad Concierge'), findsOneWidget);

      await tester.tap(_navItem('Activity'));
      await advance(tester, const Duration(milliseconds: 400));
      expect(find.text('Agent deployed'), findsOneWidget);
      expect(find.text('3 unread'), findsOneWidget);
    });
  });

  group('no overflow', () {
    for (final size in const [Size(360, 800), Size(390, 844), Size(414, 896)]) {
      for (final location in ['/activity', '/profile']) {
        testWidgets('$location at ${size.width.toInt()} px', (tester) async {
          await pumpApp(tester, location: location, size: size);
          await advance(tester, const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull);
        });
      }
    }
    testWidgets('desktop shows four links in the top bar', (tester) async {
      await pumpApp(tester, location: '/activity');
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('Profile'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
