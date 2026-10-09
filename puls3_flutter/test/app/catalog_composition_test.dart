import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_client/puls3_client.dart';
import 'package:puls3_flutter/src/data/agent_repository.dart';
import 'package:puls3_flutter/src/data/server_agent_repository.dart';

import '../helpers.dart';

AgentSummary _summary(String id, String name) => AgentSummary(
  id: id,
  registryId: 1,
  name: name,
  description: 'Reads chains',
  skills: ['on-chain-analytics'],
  priceUsdcStroops: 5000000,
  wallet: 'GABC',
);

/// Mirrors the composition in `main.dart`: the server catalog, with the
/// bundled demo catalog (here in memory) when the server fails.
Future<void> pumpComposed(WidgetTester tester, AgentSummarySource source) =>
    pumpApp(
      tester,
      location: '/market',
      repository: ServerAgentRepository(source),
      demoRepository: const InMemoryAgentRepository(testAgents),
    );

void main() {
  testWidgets('the market lists server agents with readable skills', (
    tester,
  ) async {
    await pumpComposed(tester, () async => [_summary('srv-1', 'Chain Atlas')]);

    expect(find.text('Chain Atlas'), findsOneWidget);
    expect(find.text('On-chain analytics'), findsWidgets);
    expect(find.text('Ledger Scout'), findsNothing);
    expect(find.text('1 AGENTS LIVE'), findsOneWidget);
  });

  testWidgets('a failing server shows the demo catalog, labelled, and Retry '
      'brings the server agents back', (tester) async {
    var fail = true;
    await pumpComposed(tester, () async {
      if (fail) throw StateError('server down');
      return [_summary('srv-1', 'Chain Atlas')];
    });

    expect(find.byKey(const ValueKey('market-demo')), findsOneWidget);
    expect(find.text('Showing the demo catalog'), findsOneWidget);
    expect(find.text('DEMO CATALOG'), findsOneWidget);
    expect(find.text('Ledger Scout'), findsOneWidget);

    fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('market-demo')), findsNothing);
    expect(find.text('Chain Atlas'), findsOneWidget);
    expect(find.text('Ledger Scout'), findsNothing);
  });

  testWidgets('an empty server catalog shows an empty market', (tester) async {
    await pumpComposed(tester, () async => []);

    expect(find.byKey(const ValueKey('market-empty')), findsOneWidget);
    expect(find.text('No agents yet'), findsOneWidget);
    expect(find.text('Ledger Scout'), findsNothing);
  });
}
