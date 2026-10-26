import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_flutter/src/domain/agent_filter.dart';
import 'package:puls3_flutter/src/ui/molecules/agent_card.dart';

import '../helpers.dart';

/// The Marketplace on a phone: search, a Filters sheet for skills and sort
/// order, and removable active filters.
void main() {
  const phone = Size(390, 844);

  List<String> cardNames(WidgetTester tester) => [
    for (final card in tester.widgetList<AgentCard>(find.byType(AgentCard)))
      card.name,
  ];

  Future<void> openFilters(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('market-filters-button')));
    await advance(tester, const Duration(milliseconds: 500));
  }

  Future<void> apply(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('market-filters-apply')));
    await tester.tap(find.byKey(const Key('market-filters-apply')));
    await advance(tester, const Duration(milliseconds: 500));
  }

  testWidgets('a phone shows search and Filters instead of every skill chip', (
    tester,
  ) async {
    await pumpApp(tester, location: '/market', size: phone);

    expect(find.byKey(const Key('market-search')), findsOneWidget);
    expect(find.byKey(const Key('market-filters-button')), findsOneWidget);
    // The skill chips live in the sheet now.
    expect(find.text('Security'), findsNothing);
    expect(find.byType(AgentCard), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the sheet filters by skill, counts the result and applies', (
    tester,
  ) async {
    await pumpApp(tester, location: '/market', size: phone);
    await openFilters(tester);

    expect(find.byKey(const Key('market-filters')), findsOneWidget);
    expect(find.text('Show 2 agents'), findsOneWidget);

    await tester.tap(find.text('Security'));
    await tester.pump();
    expect(find.text('Show 1 agent'), findsOneWidget);

    await apply(tester);
    expect(find.byKey(const Key('market-filters')), findsNothing);
    expect(cardNames(tester), ['Soroban Auditor']);
    expect(find.text('SHOWING 1 OF 2'), findsOneWidget);
    // One active filter, shown as a removable chip.
    expect(find.byKey(const Key('market-active-filters')), findsOneWidget);
    expect(find.text('Security'), findsOneWidget);
  });

  testWidgets('closing the sheet without applying keeps the old filters', (
    tester,
  ) async {
    await pumpApp(tester, location: '/market', size: phone);
    await openFilters(tester);
    await tester.tap(find.text('Security'));
    await tester.pump();

    await tester.tapAt(const Offset(20, 20));
    await advance(tester, const Duration(milliseconds: 500));
    expect(find.byKey(const Key('market-filters')), findsNothing);
    expect(cardNames(tester), hasLength(2));
    expect(find.byKey(const Key('market-active-filters')), findsNothing);
  });

  testWidgets('sorting by price reorders the agents for real', (tester) async {
    await pumpApp(tester, location: '/market', size: phone);
    expect(cardNames(tester), ['Ledger Scout', 'Soroban Auditor']);

    await openFilters(tester);
    await tester.tap(find.byKey(const Key('market-sort-priceHighToLow')));
    await tester.pump();
    await apply(tester);

    expect(cardNames(tester), ['Soroban Auditor', 'Ledger Scout']);
    expect(find.text('Price: high to low'), findsOneWidget);
  });

  testWidgets('Clear all removes every filter', (tester) async {
    await pumpApp(tester, location: '/market', size: phone);
    await openFilters(tester);
    await tester.tap(find.text('Security'));
    await tester.tap(find.byKey(const Key('market-sort-topRated')));
    await tester.pump();
    await apply(tester);
    expect(cardNames(tester), ['Soroban Auditor']);

    await tester.tap(find.byKey(const Key('market-clear-all')));
    await tester.pump();
    expect(cardNames(tester), ['Ledger Scout', 'Soroban Auditor']);
    expect(find.byKey(const Key('market-active-filters')), findsNothing);
  });

  testWidgets('Studio in the phone bar opens the Studio', (tester) async {
    await pumpApp(tester, location: '/market', size: phone);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Studio'),
      ),
    );
    await advance(tester, const Duration(milliseconds: 500));

    expect(find.text('Agent Studio'), findsOneWidget);
  });

  testWidgets('desktop keeps the skill chips and sorts from a menu', (
    tester,
  ) async {
    await pumpApp(tester, location: '/market');

    expect(find.byKey(const Key('market-filters-button')), findsNothing);
    expect(find.text('Security'), findsOneWidget);

    await tester.tap(find.byKey(const Key('market-sort-menu')));
    await advance(tester, const Duration(milliseconds: 400));
    await tester.tap(find.text('Price: low to high').last);
    // Let the menu close.
    await advance(tester, const Duration(milliseconds: 1000));
    expect(cardNames(tester), ['Ledger Scout', 'Soroban Auditor']);
    expect(find.text('Price: low to high'), findsOneWidget);
  });

  group('sortAgents', () {
    test('keeps the catalog order for Featured and ties', () {
      final sorted = sortAgents(testAgents, AgentSort.featured);
      expect([for (final a in sorted) a.id], ['agt-001', 'agt-003']);
    });

    test('orders by price and by rating', () {
      expect(
        [
          for (final a in sortAgents(testAgents, AgentSort.priceHighToLow))
            a.id,
        ],
        ['agt-003', 'agt-001'],
      );
      expect(
        [for (final a in sortAgents(testAgents, AgentSort.topRated)) a.id],
        ['agt-001', 'agt-003'],
      );
    });
  });
}
